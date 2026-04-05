import Foundation

enum TranscriptReader {
    static func read(from path: String) -> String? {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return nil
        }
        return extractLastAssistantMessage(from: content)
    }

    static func extractLastAssistantMessage(from jsonl: String) -> String? {
        let lines = jsonl.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        guard !lines.isEmpty else { return nil }

        var lastText: String? = nil

        for line in lines {
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  (obj["role"] as? String) == "assistant"
            else { continue }

            if let text = obj["content"] as? String {
                lastText = text
            } else if let array = obj["content"] as? [[String: Any]] {
                let text = array
                    .compactMap { item -> String? in
                        guard (item["type"] as? String) == "text" else { return nil }
                        return item["text"] as? String
                    }
                    .joined(separator: " ")
                if !text.isEmpty { lastText = text }
            }
        }

        return lastText
    }
}
