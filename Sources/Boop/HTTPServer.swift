// Sources/Boop/HTTPServer.swift
import Foundation
import Network

final class HTTPServer {
    private(set) var port: UInt16
    private var listener: NWListener?
    var onPermissionRequest: ((PermissionPayload, @escaping (HookResponse) -> Void) -> Void)?

    init(port: UInt16 = 29001) {
        self.port = port
    }

    /// Tries to start on ports from `basePort` through `basePort + maxAttempts - 1`.
    /// Returns the port that was successfully bound, or throws if all fail.
    func startWithFallback(basePort: UInt16 = 29001, maxAttempts: Int = 10) throws -> UInt16 {
        for offset in 0..<UInt16(maxAttempts) {
            let candidate = basePort + offset
            do {
                try start(on: candidate)
                return candidate
            } catch {
                continue
            }
        }
        throw NSError(domain: "Boop", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "No available port in range \(basePort)-\(basePort + UInt16(maxAttempts) - 1)"])
    }

    func start(on portNumber: UInt16? = nil) throws {
        let targetPort = portNumber ?? port
        let parameters = NWParameters.tcp
        let nwPort = NWEndpoint.Port(rawValue: targetPort)!
        let listener = try NWListener(using: parameters, on: nwPort)

        // Use a semaphore to wait for the listener to either be ready or fail
        let semaphore = DispatchSemaphore(value: 0)
        var startError: NWError?

        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                semaphore.signal()
            case .failed(let error):
                startError = error
                semaphore.signal()
            default:
                break
            }
        }

        listener.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        listener.start(queue: .global(qos: .userInitiated))

        // Wait up to 2 seconds for the listener to start
        let result = semaphore.wait(timeout: .now() + 2)

        if let error = startError {
            listener.cancel()
            throw error
        }

        if result == .timedOut {
            listener.cancel()
            throw NSError(domain: "Boop", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Timed out starting listener on port \(targetPort)"])
        }

        self.port = targetPort
        self.listener = listener
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        receiveHTTPRequest(from: connection)
    }

    private func receiveHTTPRequest(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            guard let data = data, !data.isEmpty else { return }
            guard let raw = String(data: data, encoding: .utf8) else { return }

            // Separate headers from body
            let parts = raw.components(separatedBy: "\r\n\r\n")
            let body = parts.count >= 2
                ? parts[1...].joined(separator: "\r\n\r\n").data(using: .utf8) ?? Data()
                : Data()

            // Route permission requests to the handler
            guard !body.isEmpty,
                  let payload = try? JSONDecoder().decode(PermissionPayload.self, from: body)
            else {
                self?.sendResponse(.allow(), to: connection)
                return
            }

            self?.onPermissionRequest?(payload) { response in
                self?.sendResponse(response, to: connection)
            }
        }
    }

    private func sendResponse(_ response: HookResponse, to connection: NWConnection) {
        guard let bodyData = try? JSONEncoder().encode(response) else { return }
        sendRawResponse(statusCode: 200, body: bodyData, to: connection)
    }

    private func sendRawResponse(statusCode: Int, body: Data, to connection: NWConnection) {
        let statusText: String
        switch statusCode {
        case 200: statusText = "OK"
        case 400: statusText = "Bad Request"
        default:  statusText = "Unknown"
        }
        let header = "HTTP/1.1 \(statusCode) \(statusText)\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        var responseData = header.data(using: .utf8)!
        responseData.append(body)
        connection.send(content: responseData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
