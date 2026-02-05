import SwiftUI
import AppKit

/// A TextField wrapper that properly handles IME (Input Method Editor) input.
/// This resolves issues where Japanese/Chinese input confirmation doesn't work
/// correctly with standard SwiftUI TextField in certain macOS configurations.
struct IMETextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.delegate = context.coordinator
        textField.placeholderString = placeholder
        textField.bezelStyle = .roundedBezel
        textField.isBordered = true
        textField.isBezeled = true
        textField.focusRingType = .exterior
        textField.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        textField.cell?.usesSingleLineMode = true
        textField.cell?.wraps = false
        textField.cell?.isScrollable = true
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        // Only update if the text actually changed from outside
        // This prevents cursor jumping during IME composition
        if nsView.stringValue != text && !context.coordinator.isEditing {
            nsView.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>
        var isEditing = false

        init(text: Binding<String>) {
            self.text = text
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else { return }
            isEditing = true
            text.wrappedValue = textField.stringValue
            isEditing = false
        }

        func controlTextDidBeginEditing(_ notification: Notification) {
            isEditing = true
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else { return }
            text.wrappedValue = textField.stringValue
            isEditing = false
        }
    }
}

#if DEBUG
struct IMETextField_Previews: PreviewProvider {
    static var previews: some View {
        IMETextField(text: .constant(""), placeholder: "Enter text...")
            .frame(width: 200, height: 24)
            .padding()
    }
}
#endif
