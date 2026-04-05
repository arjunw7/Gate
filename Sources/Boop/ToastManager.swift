// Sources/Boop/ToastManager.swift
import AppKit
import SwiftUI

/// Manages stackable auto-approve toast notifications in the bottom-right corner.
class ToastManager {
    static let shared = ToastManager()

    private struct ToastEntry {
        let id: UUID
        let panel: NSPanel
        let hostingView: NSHostingView<ToastView>
        var dismissTimer: DispatchWorkItem?
    }

    private var toasts: [ToastEntry] = []
    private let toastWidth: CGFloat = 320
    private let margin: CGFloat = 16
    private let spacing: CGFloat = 8
    private let dismissDuration: TimeInterval = 5

    func show(payload: PermissionPayload) {
        DispatchQueue.main.async { [weak self] in
            self?.presentToast(payload: payload)
        }
    }

    private func presentToast(payload: PermissionPayload) {
        let toastId = UUID()
        let category = ToolCategory.from(toolName: payload.tool_name)

        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let toastView = ToastView(
            toolName: toolDisplayName(for: payload.tool_name),
            detail: payload.tool_input.primaryDisplay,
            category: category,
            onClose: { [weak self] in
                self?.dismissToast(id: toastId)
            }
        )

        let hostingView = NSHostingView(rootView: toastView)
        hostingView.frame = NSRect(x: 0, y: 0, width: toastWidth, height: 10)
        panel.contentView = hostingView

        let fittingSize = hostingView.fittingSize
        panel.setContentSize(fittingSize)

        // Position off-screen initially (will be placed by repositionToasts)
        if let screen = NSScreen.main {
            let visibleFrame = screen.visibleFrame
            let origin = NSPoint(
                x: visibleFrame.maxX - fittingSize.width - margin,
                y: visibleFrame.minY + margin
            )
            panel.setFrameOrigin(origin)
        }

        // Auto-dismiss timer
        let timer = DispatchWorkItem { [weak self] in
            self?.dismissToast(id: toastId)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + dismissDuration, execute: timer)

        let entry = ToastEntry(id: toastId, panel: panel, hostingView: hostingView, dismissTimer: timer)
        toasts.append(entry)

        panel.alphaValue = 0
        panel.orderFrontRegardless()

        repositionToasts(animated: false)

        // Fade in
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    private func dismissToast(id: UUID) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard let index = self.toasts.firstIndex(where: { $0.id == id }) else { return }

            let entry = self.toasts[index]
            entry.dismissTimer?.cancel()

            // Fade out then remove
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.2
                ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                entry.panel.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                guard let self = self else { return }
                entry.panel.close()
                self.toasts.removeAll { $0.id == id }
                self.repositionToasts(animated: true)
            })
        }
    }

    /// Repositions all active toasts, stacking from the bottom-right upward.
    private func repositionToasts(animated: Bool) {
        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame

        var yOffset: CGFloat = margin

        for entry in toasts {
            let size = entry.hostingView.fittingSize
            entry.panel.setContentSize(size)
            let origin = NSPoint(
                x: visibleFrame.maxX - size.width - margin,
                y: visibleFrame.minY + yOffset
            )

            if animated {
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.25
                    ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    entry.panel.animator().setFrameOrigin(origin)
                }
            } else {
                entry.panel.setFrameOrigin(origin)
            }

            yOffset += size.height + spacing
        }
    }

    private func toolDisplayName(for toolName: String) -> String {
        switch toolName {
        case "Bash":     return "Shell Command"
        case "Edit":     return "Edit File"
        case "Write":    return "Write File"
        case "Read":     return "Read File"
        case "Glob":     return "Search Files"
        case "Grep":     return "Search Content"
        case "WebFetch": return "Fetch URL"
        case "WebSearch": return "Web Search"
        default:         return toolName
        }
    }
}

// MARK: - ToastView

struct ToastView: View {
    let toolName: String
    let detail: String
    let category: ToolCategory
    let onClose: () -> Void

    private let gateGreen = Color(red: 0.06, green: 0.73, blue: 0.51)

    var body: some View {
        HStack(spacing: 10) {
            // Green checkmark icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(gateGreen)

            // Tool info
            VStack(alignment: .leading, spacing: 2) {
                Text(toolName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                if !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer(minLength: 4)

            // Close button
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(width: 20, height: 20)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: 320)
        .background(
            ZStack {
                Color(red: 0.07, green: 0.07, blue: 0.12)
                Color.white.opacity(0.04)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
                .mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .bottom))
        )
        .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
    }
}
