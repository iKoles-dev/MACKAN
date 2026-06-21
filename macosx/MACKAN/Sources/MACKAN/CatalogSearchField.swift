import AppKit
import SwiftUI

struct CatalogSearchField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> ArrowKeySearchField {
        let field = ArrowKeySearchField()
        field.delegate = context.coordinator
        field.stringValue = text
        field.placeholderString = placeholder
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.isBezeled = false
        field.usesSingleLineMode = true
        field.lineBreakMode = .byTruncatingTail
        field.font = .systemFont(ofSize: NSFont.systemFontSize)
        field.setAccessibilityLabel(placeholder)
        field.onMoveUp = onMoveUp
        field.onMoveDown = onMoveDown
        return field
    }

    func updateNSView(_ nsView: ArrowKeySearchField, context: Context) {
        context.coordinator.text = $text
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.placeholderString = placeholder
        nsView.onMoveUp = onMoveUp
        nsView.onMoveDown = onMoveDown
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else {
                return
            }
            text.wrappedValue = field.stringValue
        }
    }

    final class ArrowKeySearchField: NSTextField {
        var onMoveUp: () -> Void = {}
        var onMoveDown: () -> Void = {}

        override func keyDown(with event: NSEvent) {
            guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty else {
                super.keyDown(with: event)
                return
            }

            switch event.keyCode {
            case 126:
                onMoveUp()
            case 125:
                onMoveDown()
            default:
                super.keyDown(with: event)
            }
        }
    }
}
