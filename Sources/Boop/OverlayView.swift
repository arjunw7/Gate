// Sources/Boop/OverlayView.swift
import SwiftUI
import AppKit

struct OverlayView: View {
    let payload: PermissionPayload
    let whyText: String?
    let onAllow: () -> Void
    let onAllowSession: () -> Void
    let onAllowPermanently: () -> Void
    let onDeny: () -> Void

    private var category: ToolCategory { ToolCategory.from(toolName: payload.tool_name) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Text(category.icon)
                    .font(.system(size: 22))
                    .frame(width: 40, height: 40)
                    .background(riskColor.opacity(0.15))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(riskColor.opacity(0.3), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(toolDisplayName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Text(subtitleText)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.55))
                }

                Spacer()

                Text(riskLabel)
                    .font(.system(size: 9, weight: .semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(riskColor.opacity(0.15))
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(riskColor.opacity(0.3), lineWidth: 1))
                    .foregroundColor(riskColor)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .padding(.bottom, 12)

            // Primary field (command / file / URL)
            if !payload.tool_input.primaryDisplay.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(primaryFieldLabel)
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.0)
                        .foregroundColor(.white.opacity(0.5))
                    Text(payload.tool_input.primaryDisplay)
                        .font(.system(size: 12.5, design: .monospaced))
                        .foregroundColor(primaryFieldColor)
                        .lineLimit(3)
                        .truncationMode(.middle)
                }
                .padding(10)
                .background(Color.black.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.bottom, 10)
            }

            // "Why Claude needs this"
            if let why = whyText {
                Divider().background(Color.white.opacity(0.12)).padding(.bottom, 10)
                VStack(alignment: .leading, spacing: 4) {
                    Text("WHY CLAUDE NEEDS THIS")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.0)
                        .foregroundColor(.white.opacity(0.5))
                    Text(why)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, 12)
            }

            // Action buttons
            Divider().background(Color.white.opacity(0.12)).padding(.bottom, 10)
            VStack(spacing: 6) {
                ActionButton(label: "Allow this time", keyHint: "↵",
                             style: .primary, action: onAllow)
                ActionButton(label: "Allow for this session", keyHint: "⇧↵",
                             style: .secondary, action: onAllowSession)
                ActionButton(label: "Allow permanently", keyHint: "⌘↵",
                             style: .secondary, action: onAllowPermanently)
                ActionButton(label: "Deny", keyHint: "⎋",
                             style: .destructive, action: onDeny)
            }
        }
        .padding(20)
        .frame(width: 360)
        .background(
            ZStack {
                // Dark base — doesn't wash out on light wallpapers
                Color(red: 0.07, green: 0.07, blue: 0.12)
                // Subtle tint so it reads as glass, not a black box
                Color.white.opacity(0.04)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
                .mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .bottom))
        )
        .shadow(color: .black.opacity(0.7), radius: 50, y: 24)
    }

    // MARK: - Computed helpers

    private var toolDisplayName: String {
        switch payload.tool_name {
        case "Bash":     return "Run Shell Command"
        case "Edit":     return "Edit File"
        case "Write":    return "Write File"
        case "WebFetch": return "Fetch URL"
        default:         return payload.tool_name
        }
    }

    private var subtitleText: String {
        "Session \(String(payload.session_id.prefix(6))) · \(payload.tool_name)"
    }

    private var primaryFieldLabel: String {
        switch category {
        case .shell:      return "COMMAND"
        case .fileWrite:  return "FILE"
        case .web:        return "URL"
        case .fileRead:   return "PATH"
        }
    }

    private var primaryFieldColor: Color {
        switch category {
        case .shell:     return Color(red: 0.65, green: 0.95, blue: 1.0)
        case .fileWrite: return Color(red: 0.99, green: 0.88, blue: 0.54)
        case .web:       return Color(red: 0.77, green: 0.71, blue: 0.99)
        case .fileRead:  return Color(red: 0.77, green: 0.71, blue: 0.99)
        }
    }

    private var riskColor: Color {
        switch category.riskLevel {
        case .high:   return Color(red: 0.95, green: 0.43, blue: 0.43)
        case .medium: return Color(red: 0.98, green: 0.74, blue: 0.27)
        case .low:    return Color(red: 0.61, green: 0.64, blue: 0.99)
        }
    }

    private var riskLabel: String {
        switch category.riskLevel {
        case .high:   return "HIGH RISK"
        case .medium: return "MEDIUM"
        case .low:    return "LOW"
        }
    }
}

// MARK: - ActionButton

struct ActionButton: View {
    enum Style { case primary, secondary, destructive }
    let label: String
    let keyHint: String
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(.system(size: 12.5, weight: style == .primary ? .bold : .medium))
                Spacer()
                Text(keyHint).font(.system(size: 11)).opacity(0.4)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundColor(foregroundColor)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(borderColor, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:     return .white
        case .secondary:   return .white.opacity(0.75)
        case .destructive: return Color(red: 0.95, green: 0.43, blue: 0.43)
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primary:     return Color(red: 0.06, green: 0.73, blue: 0.51).opacity(0.65)
        case .secondary:   return Color.white.opacity(0.08)
        case .destructive: return Color(red: 0.95, green: 0.27, blue: 0.27).opacity(0.12)
        }
    }

    private var borderColor: Color {
        switch style {
        case .primary:     return Color(red: 0.06, green: 0.73, blue: 0.51).opacity(0.5)
        case .secondary:   return Color.white.opacity(0.14)
        case .destructive: return Color(red: 0.95, green: 0.27, blue: 0.27).opacity(0.25)
        }
    }
}
