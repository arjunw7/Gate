import Foundation

/// Serialises permission requests so only one overlay is shown at a time,
/// even when multiple Claude Code terminals are active simultaneously.
class PermissionQueue {
    private let serialQueue = DispatchQueue(label: "com.loop.boop.permissionqueue")
    private var isProcessing = false
    private var pending: [(sessionId: String,
                           showOverlay: (PermissionPayload?, @escaping (HookResponse) -> Void) -> Void,
                           payload: PermissionPayload?,
                           completion: (HookResponse) -> Void)] = []

    func enqueue(sessionId: String,
                 payload: PermissionPayload? = nil,
                 showOverlay: @escaping (PermissionPayload?, @escaping (HookResponse) -> Void) -> Void,
                 completion: @escaping (HookResponse) -> Void) {
        serialQueue.async { [weak self] in
            self?.pending.append((sessionId, showOverlay, payload, completion))
            self?.processNext()
        }
    }

    private func processNext() {
        guard !isProcessing, !pending.isEmpty else { return }
        isProcessing = true
        let item = pending.removeFirst()

        item.showOverlay(item.payload) { [weak self] response in
            item.completion(response)
            self?.serialQueue.async {
                self?.isProcessing = false
                self?.processNext()
            }
        }
    }
}
