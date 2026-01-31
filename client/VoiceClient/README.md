# VoiceClient

macOS menu bar application for voice-to-text transcription using KumaKuma AI server.

## Requirements

- macOS 13.0 or later
- Xcode 15.0 or later

## Project Setup

### Option 1: Using XcodeGen (Recommended)

1. Install XcodeGen:
   ```bash
   brew install xcodegen
   ```

2. Generate the Xcode project:
   ```bash
   cd client/VoiceClient
   xcodegen generate
   ```

3. Open the generated project:
   ```bash
   open VoiceClient.xcodeproj
   ```

### Option 2: Manual Xcode Project Creation

1. Open Xcode
2. Create a new project:
   - Template: macOS > App
   - Product Name: VoiceClient
   - Team: (Your team or None)
   - Organization Identifier: com.kumakuma
   - Interface: SwiftUI
   - Language: Swift
3. Replace the generated files with the files in `VoiceClient/` directory
4. Configure Info.plist to include microphone permission
5. Configure entitlements for audio input and network access

## Building

```bash
# Build with Xcode
xcodebuild -project VoiceClient.xcodeproj -scheme VoiceClient -configuration Release build

# Or open in Xcode and build from there
open VoiceClient.xcodeproj
```

## Features

- Menu bar application (no dock icon)
- Voice recording with global hotkey (⌘⇧V)
- Automatic transcription via KumaKuma AI server
- Personal dictionary management
- GitHub OAuth authentication

## Project Structure

```
VoiceClient/
├── VoiceClientApp.swift    # App entry point
├── AppState.swift          # Application state management
├── Views/
│   ├── MenuBarView.swift   # Menu bar dropdown view
│   └── SettingsView.swift  # Settings window
├── Info.plist              # App configuration
└── VoiceClient.entitlements # Sandbox entitlements
```

## Configuration

Settings are stored in UserDefaults:
- `serverURL`: KumaKuma AI server URL (default: http://localhost:8000)
- `hotkey`: Global hotkey for recording (default: ⌘⇧V)

## License

MIT License
