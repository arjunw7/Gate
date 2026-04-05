import Foundation

// MARK: - Tool Classification

enum RiskLevel {
    case high, medium, low
}

enum ToolCategory: String, Codable, Equatable {
    case shell      // Bash — HIGH risk
    case fileWrite  // Edit, Write, MultiEdit — MEDIUM risk
    case web        // WebFetch, WebSearch — MEDIUM risk
    case fileRead   // Read, Glob, Grep — LOW risk

    static func from(toolName: String) -> ToolCategory {
        switch toolName {
        case "Edit", "Write", "MultiEdit":     return .fileWrite
        case "WebFetch", "WebSearch":          return .web
        case "Read", "Glob", "Grep":           return .fileRead
        default:                               return .shell
        }
    }

    var riskLevel: RiskLevel {
        switch self {
        case .shell:      return .high
        case .fileWrite:  return .medium
        case .web:        return .medium
        case .fileRead:   return .low
        }
    }

    var displayName: String {
        switch self {
        case .shell:      return "shell commands"
        case .fileWrite:  return "file edits"
        case .web:        return "web requests"
        case .fileRead:   return "file reads"
        }
    }

    var icon: String {
        switch self {
        case .shell:      return "⚡"
        case .fileWrite:  return "📝"
        case .web:        return "🌐"
        case .fileRead:   return "📖"
        }
    }
}

// MARK: - Permission Mode

enum PermissionMode: String, Codable, CaseIterable {
    case `default`    = "default"
    case smartScope   = "smart_scope"
    case permanent    = "permanent"

    var displayName: String {
        switch self {
        case .default:      return "Default"
        case .smartScope:   return "Smart Scope"
        case .permanent:    return "Permanent"
        }
    }

    var description: String {
        switch self {
        case .default:
            return "Asks for every action — no permanent permissions"
        case .smartScope:
            return "File reads auto-allowed; everything else asks"
        case .permanent:
            return "All actions auto-allowed — never asks"
        }
    }
}

// MARK: - Hook Payload (received from Claude Code)

struct PermissionPayload: Codable {
    let tool_name: String
    let tool_input: ToolInput
    let session_id: String
    let cwd: String
    let transcript_path: String?

    struct ToolInput: Codable {
        let command: String?
        let file_path: String?
        let url: String?
        let pattern: String?

        // Returns the most relevant display string for this tool input
        var primaryDisplay: String {
            return command ?? file_path ?? url ?? pattern ?? ""
        }

        enum CodingKeys: String, CodingKey {
            case command, file_path, url, pattern
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            command    = try container.decodeIfPresent(String.self, forKey: .command)
            file_path  = try container.decodeIfPresent(String.self, forKey: .file_path)
            url        = try container.decodeIfPresent(String.self, forKey: .url)
            pattern    = try container.decodeIfPresent(String.self, forKey: .pattern)
        }
    }
}

// MARK: - Hook Response (returned to Claude Code)

struct HookResponse: Codable {
    let hookSpecificOutput: HookSpecificOutput

    struct HookSpecificOutput: Codable {
        let hookEventName: String
        let decision: Decision
    }

    struct Decision: Codable {
        let behavior: String
        let message: String?

        init(allow: Bool, message: String? = nil) {
            self.behavior = allow ? "allow" : "deny"
            self.message = message
        }
    }

    static func allow() -> HookResponse {
        HookResponse(hookSpecificOutput: .init(
            hookEventName: "PermissionRequest",
            decision: .init(allow: true)
        ))
    }

    static func deny(message: String = "User denied via Boop") -> HookResponse {
        HookResponse(hookSpecificOutput: .init(
            hookEventName: "PermissionRequest",
            decision: .init(allow: false, message: message)
        ))
    }
}
