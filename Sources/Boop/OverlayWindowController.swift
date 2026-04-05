// Sources/Boop/OverlayWindowController.swift
import AppKit
import SwiftUI

class OverlayWindowController {
    private var window: NSPanel?
    private var keyMonitor: Any?

    func show(payload: PermissionPayload,
              whyText: String?,
              onAllow: @escaping () -> Void,
              onAllowSession: @escaping () -> Void,
              onAllowPermanently: @escaping () -> Void,
              onDeny: @escaping () -> Void) {
        DispatchQueue.main.async { [weak self] in
            self?.presentPanel(payload: payload, whyText: whyText,
                               onAllow: onAllow, onAllowSession: onAllowSession,
                               onAllowPermanently: onAllowPermanently, onDeny: onDeny)
        }
    }

    func dismiss() {
        DispatchQueue.main.async { [weak self] in
            if let monitor = self?.keyMonitor {
                NSEvent.removeMonitor(monitor)
                self?.keyMonitor = nil
            }
            self?.window?.close()
            self?.window = nil
        }
    }

    private func presentPanel(payload: PermissionPayload,
                               whyText: String?,
                               onAllow: @escaping () -> Void,
                               onAllowSession: @escaping () -> Void,
                               onAllowPermanently: @escaping () -> Void,
                               onDeny: @escaping () -> Void) {
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

        let overlayView = OverlayView(
            payload: payload,
            whyText: whyText,
            onAllow: { [weak self] in self?.dismiss(); onAllow() },
            onAllowSession: { [weak self] in self?.dismiss(); onAllowSession() },
            onAllowPermanently: { [weak self] in self?.dismiss(); onAllowPermanently() },
            onDeny: { [weak self] in self?.dismiss(); onDeny() }
        )

        let hostingView = NSHostingView(rootView: overlayView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 360, height: 10)
        panel.contentView = hostingView

        // Let SwiftUI size the view naturally
        let fittingSize = hostingView.fittingSize
        panel.setContentSize(fittingSize)

        // Position bottom-right, respecting Dock + menu bar
        if let screen = NSScreen.main {
            let visibleFrame = screen.visibleFrame
            let margin: CGFloat = 16
            let origin = NSPoint(
                x: visibleFrame.maxX - fittingSize.width - margin,
                y: visibleFrame.minY + margin
            )
            panel.setFrameOrigin(origin)
        }

        // Keyboard shortcuts: Enter = Allow, Shift+Enter = Session, Cmd+Enter = Permanent, Escape = Deny
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            switch event.keyCode {
            case 36: // Return
                if event.modifierFlags.contains(.command) {
                    self?.dismiss(); onAllowPermanently(); return nil
                } else if event.modifierFlags.contains(.shift) {
                    self?.dismiss(); onAllowSession(); return nil
                } else {
                    self?.dismiss(); onAllow(); return nil
                }
            case 53: // Escape
                self?.dismiss(); onDeny(); return nil
            default: return event
            }
        }

        panel.makeKeyAndOrderFront(nil)
        self.window = panel

        // Slide-in animation
        panel.alphaValue = 0
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }
}
