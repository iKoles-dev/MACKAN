import AppKit
import SwiftUI

import MACKANKit

struct MainWindowPlacementGuard: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = WindowPlacementView()
        view.onMoveToWindow = { window in
            Task { @MainActor in
                context.coordinator.constrainIfNeeded(window: window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        Task { @MainActor in
            context.coordinator.constrainIfNeeded(window: nsView.window)
        }
    }

    final class Coordinator {
        private var didConstrain = false

        @MainActor
        func constrainIfNeeded(window: NSWindow?) {
            guard !didConstrain, let window else {
                return
            }

            didConstrain = true
            window.minSize = NSSize(
                width: CGFloat(MainWindowLayoutPolicy.minimumWindowWidth),
                height: CGFloat(MainWindowLayoutPolicy.minimumWindowHeight)
            )

            guard let visibleFrame = (window.screen ?? NSScreen.main)?.visibleFrame else {
                return
            }

            let constrainedFrame = MainWindowLayoutPolicy.constrainedStartupFrame(
                window.frame,
                visibleFrame: visibleFrame
            )

            guard constrainedFrame != window.frame else {
                return
            }

            window.setFrame(constrainedFrame, display: true, animate: false)
        }
    }

    private final class WindowPlacementView: NSView {
        var onMoveToWindow: ((NSWindow?) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }
                self.onMoveToWindow?(self.window)
            }
        }
    }
}
