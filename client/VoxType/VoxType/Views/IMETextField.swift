import SwiftUI
import AppKit

/// A TextField wrapper that properly handles IME (Input Method Editor) input.
/// This resolves issues where Japanese/Chinese input confirmation doesn't work
/// correctly with standard SwiftUI TextField in certain macOS configurations.
struct IMETextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onSubmit: (() -> Void)?
    var isFocused: Binding<Bool>?

    init(text: Binding<String>, placeholder: String, onSubmit: (() -> Void)? = nil, isFocused: Binding<Bool>? = nil) {
        self._text = text
        self.placeholder = placeholder
        self.onSubmit = onSubmit
        self.isFocused = isFocused
    }

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
        context.coordinator.textField = textField
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        // Only update if the text actually changed from outside
        // This prevents cursor jumping during IME composition
        if nsView.stringValue != text && !context.coordinator.isEditing {
            nsView.stringValue = text
        }

        // Handle focus changes from SwiftUI
        if let isFocused = isFocused?.wrappedValue, isFocused {
            DispatchQueue.main.async {
                if nsView.window?.firstResponder != nsView.currentEditor() {
                    nsView.window?.makeFirstResponder(nsView)
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit, isFocused: isFocused)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>
        var onSubmit: (() -> Void)?
        var isFocused: Binding<Bool>?
        var isEditing = false
        weak var textField: NSTextField?

        init(text: Binding<String>, onSubmit: (() -> Void)?, isFocused: Binding<Bool>?) {
            self.text = text
            self.onSubmit = onSubmit
            self.isFocused = isFocused
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else { return }
            isEditing = true
            text.wrappedValue = textField.stringValue
            isEditing = false
        }

        func controlTextDidBeginEditing(_ notification: Notification) {
            isEditing = true
            DispatchQueue.main.async {
                self.isFocused?.wrappedValue = true
            }
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else { return }
            text.wrappedValue = textField.stringValue
            isEditing = false
            DispatchQueue.main.async {
                self.isFocused?.wrappedValue = false
            }
        }

        // Handle Enter key press
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                // Enter key pressed
                onSubmit?()
                return true
            }
            return false
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
