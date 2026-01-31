# VoiceClient

macOS menu bar application for voice-to-text transcription using KumaKuma AI server.

## Installation

### Quick Start (Pre-built)

1. Download `VoiceClient-v0.1.0.zip` from [Releases](../../releases)
2. Unzip and move `VoiceClient.app` to `/Applications`
3. Open the app (right-click > Open for first launch to bypass Gatekeeper)
4. Grant permissions when prompted:
   - Microphone: Required for voice recording
   - Accessibility: Required for global hotkey and auto-paste
   - Notifications: Required for error notifications

### First Launch

1. Click the microphone icon in the menu bar
2. Select "Login with GitHub" to authenticate
3. Use Cmd+Shift+V to start/stop recording
4. Transcribed text will be pasted at cursor position

## Requirements

### For Users
- macOS 13.0 or later
- KumaKuma AI server running

### For Development
- Xcode 15.0 or later
- XcodeGen (`brew install xcodegen`)

## Project Setup (Development)

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
├── VoiceClientApp.swift      # App entry point and coordinator
├── AppState.swift            # Application state management
├── Views/
│   ├── MenuBarView.swift     # Menu bar dropdown view
│   └── SettingsView.swift    # Settings window (General, Account, Hotkey, Dictionary)
├── Services/
│   ├── AuthService.swift     # GitHub OAuth authentication
│   ├── KeychainHelper.swift  # Secure token storage
│   ├── AudioRecorder.swift   # Voice recording (AVFoundation)
│   ├── HotkeyManager.swift   # Global hotkey monitoring (CGEvent)
│   ├── APIClient.swift       # Server communication
│   ├── ClipboardManager.swift # Clipboard and auto-paste
│   └── NotificationManager.swift # macOS notifications
├── Info.plist                # App configuration
└── VoiceClient.entitlements  # Sandbox entitlements
```

## Usage

### Recording Voice

1. Press and hold Cmd+Shift+V to start recording
2. Speak your message (Japanese supported)
3. Release Cmd+Shift+V to stop recording
4. Wait for transcription (icon turns orange)
5. Transcribed text is automatically pasted at cursor

### Menu Bar Icons

| Color | Status |
|-------|--------|
| Default | Idle, ready to record |
| Red | Recording in progress |
| Orange | Processing transcription |
| Green | Transcription complete |

### Settings

- General: Server URL configuration and connection test
- Account: Login/logout and user information
- Hotkey: Accessibility permission status
- Dictionary: Personal dictionary for transcription corrections

## Configuration

Settings are stored in UserDefaults:
- `serverURL`: KumaKuma AI server URL (default: http://localhost:8000)
- `hotkey`: Global hotkey for recording (default: Cmd+Shift+V)

## Troubleshooting

### Hotkey not working

1. Open System Settings > Privacy & Security > Accessibility
2. Enable VoiceClient in the list
3. Restart the app

### Cannot record audio

1. Open System Settings > Privacy & Security > Microphone
2. Enable VoiceClient in the list

### "Developer cannot be verified" error

Right-click the app and select "Open" to bypass Gatekeeper on first launch.

## License

MIT License
