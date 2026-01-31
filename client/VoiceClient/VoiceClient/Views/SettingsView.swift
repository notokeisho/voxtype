import SwiftUI

/// Settings view for the application.
struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            DictionarySettingsView()
                .tabItem {
                    Label("Dictionary", systemImage: "text.book.closed")
                }

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 450, height: 300)
    }
}

/// General settings tab.
struct GeneralSettingsView: View {
    @AppStorage("serverURL") private var serverURL: String = "http://localhost:8000"
    @AppStorage("hotkey") private var hotkey: String = "⌘⇧V"

    var body: some View {
        Form {
            Section {
                TextField("Server URL", text: $serverURL)
                    .textFieldStyle(.roundedBorder)
            } header: {
                Text("Server")
            }

            Section {
                HStack {
                    Text("Hotkey:")
                    Text(hotkey)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                    Spacer()
                    Button("Change...") {
                        // TODO: Implement hotkey picker
                    }
                }
            } header: {
                Text("Keyboard Shortcut")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

/// Dictionary settings tab (placeholder).
struct DictionarySettingsView: View {
    var body: some View {
        VStack {
            Text("Dictionary Settings")
                .font(.headline)
            Text("Coming in Task 4.3.1")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// About tab.
struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            Text("VoiceClient")
                .font(.title)
                .fontWeight(.bold)

            Text("Version 1.0.0")
                .foregroundColor(.secondary)

            Text("Voice-to-text client for KumaKuma AI")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AppState())
    }
}
#endif
