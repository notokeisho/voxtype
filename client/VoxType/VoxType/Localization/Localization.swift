import SwiftUI

/// Supported languages for the application.
enum Language: String, CaseIterable {
    case english = "en"
    case japanese = "ja"

    /// Display name for the language picker.
    var displayName: String {
        switch self {
        case .english: return "English"
        case .japanese: return "日本語"
        }
    }
}

/// Manager for application localization.
/// Provides translations for UI strings based on the selected language.
@MainActor
class LocalizationManager: ObservableObject {
    /// Shared instance for global access.
    static let shared = LocalizationManager()

    /// UserDefaults key for storing language preference.
    private static let languageKey = "appLanguage"

    /// Current language setting.
    @Published var language: Language {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Self.languageKey)
        }
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: Self.languageKey) ?? Language.english.rawValue
        self.language = Language(rawValue: saved) ?? .english
    }

    /// Get translated string for the given key.
    /// - Parameter key: The translation key.
    /// - Returns: The translated string, or the key itself if not found.
    func t(_ key: String) -> String {
        return Self.translations[language]?[key] ?? key
    }

    /// Get translated string with parameter substitution.
    /// - Parameters:
    ///   - key: The translation key.
    ///   - params: Dictionary of parameter names and values to substitute.
    /// - Returns: The translated string with parameters replaced.
    func t(_ key: String, params: [String: Any]) -> String {
        var text = Self.translations[language]?[key] ?? key
        for (paramKey, value) in params {
            text = text.replacingOccurrences(of: "{\(paramKey)}", with: String(describing: value))
        }
        return text
    }

    // MARK: - Translations

    private static let translations: [Language: [String: String]] = [
        .english: englishTranslations,
        .japanese: japaneseTranslations
    ]

    // MARK: - English Translations

    private static let englishTranslations: [String: String] = [
        // Settings tabs
        "settings.account": "Account",
        "settings.general": "General",
        "settings.hotkey": "Hotkey",
        "settings.dictionary": "Dictionary",
        "settings.globalDictionaryRequest": "Global Dictionary Request",
        "settings.language": "Language",
        "settings.about": "About",

        // Account tab
        "account.title": "GitHub Account",
        "account.checking": "Checking authentication...",
        "account.notLoggedIn": "Not logged in",
        "account.loginDescription": "Log in with GitHub to sync your settings and use the transcription service.",
        "account.loginButton": "Log in with GitHub",
        "account.loggingIn": "Logging in...",
        "account.loggedIn": "Logged in",
        "account.admin": "(Admin)",
        "account.logoutButton": "Log out",
        "account.authError": "Authentication Error",
        "account.tryAgain": "Try Again",
        "account.features": "Account Features",
        "account.feature.sync": "Your data is synced with the server",
        "account.feature.dictionary": "Personal dictionary is available",
        "account.feature.transcription": "Voice transcription is enabled",

        // General tab
        "general.server": "Server",
        "general.serverURL": "Server URL",
        "general.testConnection": "Test Connection",
        "general.connectionNotTested": "Not tested",
        "general.connectionTesting": "Testing...",
        "general.connectionConnected": "Connected",
        "general.connectionFailed": "Failed: {message}",
        "general.startup": "Startup",
        "general.launchAtLogin": "Launch at Login",
        "general.model": "Transcription Model",
        "general.model.fastDescription": "High speed, everyday use",
        "general.model.smartDescription": "High accuracy, accuracy focused",
        "general.transcriptionModel": "Model",
        "general.noiseFilter": "Noise Filter",
        "general.off": "Off",
        "general.resetToDefaults": "Reset to Defaults",

        // Hotkey tab
        "hotkey.permissions": "Permissions",
        "hotkey.accessGranted": "Accessibility access granted",
        "hotkey.accessRequired": "Accessibility access required",
        "hotkey.accessDescription": "VoxType needs accessibility access to detect global hotkeys",
        "hotkey.grantAccess": "Grant Access",
        "hotkey.accessInstructions": "Go to System Settings > Privacy & Security > Accessibility and enable VoxType",
        "hotkey.title": "Voice Recording Hotkey",
        "hotkey.current": "Current Hotkey",
        "hotkey.recordingEnabled": "Enable Recording Hotkey",
        "hotkey.mouseHoldEnabled": "Enable Mouse Wheel Hold",
        "hotkey.mouseHoldHint": "Hold the mouse wheel for 1 second or longer to start recording.",
        "hotkey.change": "Change Hotkey",
        "hotkey.selectModifiers": "Select modifiers and key",
        "hotkey.modifierRequired": "At least one modifier key is required",
        "hotkey.cancel": "Cancel",
        "hotkey.save": "Save",
        "hotkey.description": "Hold this key combination to start recording, release to stop and transcribe.",
        "hotkey.modelTitle": "Model Change Hotkey",
        "hotkey.modelEnabled": "Enable Model Change Hotkey",
        "hotkey.modelChange": "Change Hotkey",
        "hotkey.modelDescription": "Press this key combination to open the model selection popup.",
        "hotkey.duplicateWarning": "This hotkey is already used. Choose a different combination.",
        "hotkey.howItWorks": "How it works",
        "hotkey.tip.global": "The hotkey works globally across all applications",
        "hotkey.tip.holdRelease": "Hold to record, release to transcribe",
        "hotkey.tip.autoStop": "Recording stops automatically after 60 seconds",
        "hotkey.resetToDefault": "Reset to Default (⌃.)",
        "modelPopup.title": "Model Selection",
        "modelPopup.hint": "Use ↑↓ to select, Enter to confirm",

        // Dictionary tab
        "dictionary.title": "Personal Dictionary",
        "dictionary.loginRequired": "Login Required",
        "dictionary.loginDescription": "Please log in to manage your personal dictionary",
        "dictionary.loading": "Loading dictionary...",
        "dictionary.empty": "No Dictionary Entries",
        "dictionary.emptyDescription": "Add patterns to customize how words are transcribed",
        "dictionary.example": "Example:",
        "dictionary.pattern": "Pattern",
        "dictionary.replacement": "Replacement",
        "dictionary.deleteTitle": "Delete Entry",
        "dictionary.deleteConfirm": "Delete \"{pattern}\" → \"{replacement}\"?",
        "dictionary.delete": "Delete",
        "dictionary.limitReached": "Dictionary limit reached (100 entries)",
        "dictionary.dismiss": "Dismiss",
        "globalRequest.title": "Global Dictionary Request",
        "globalRequest.comingSoon": "This feature will be available soon.",
        "globalRequest.loginRequired": "Login Required",
        "globalRequest.loginDescription": "Please log in to submit a global dictionary request",
        "globalRequest.pattern": "Pattern",
        "globalRequest.replacement": "Replacement",
        "globalRequest.submit": "Submit Request",
        "globalRequest.successNote": "The request will apply from the next recording.",
        "globalRequest.limitReached": "Request limit reached. Please try again later.",

        // Language tab
        "language.title": "Language Settings",
        "language.appLanguage": "App Language",
        "language.description": "Select the display language for the application.",

        // About tab
        "about.version": "Version",
        "about.voiceToText": "Voice to Text",
        "about.licenses": "Open Source Licenses",
        "about.github": "GitHub",
        "about.documentation": "Documentation",

        // Menu bar
        "menu.authenticated": "Authenticated",
        "menu.notLoggedIn": "Not logged in",
        "menu.recording": "Recording",
        "menu.startRecording": "Start Recording",
        "menu.stopRecording": "Stop Recording",
        "menu.processing": "Processing...",
        "menu.lastTranscription": "Last transcription:",
        "menu.copyToClipboard": "Copy to Clipboard",
        "menu.settings": "Settings...",
        "menu.login": "Login with GitHub",
        "menu.logout": "Logout",
        "menu.quit": "Quit VoxType",

        // Status
        "status.idle": "Ready",
        "status.recording": "Recording...",
        "status.processing": "Processing...",
        "status.completed": "Completed",
        "status.error": "Error",

        // Errors
        "error.loginRequired": "Please log in to use voice transcription",

        // Common
        "common.cancel": "Cancel",
        "common.save": "Save",
        "common.delete": "Delete",
        "common.error": "Error",
    ]

    // MARK: - Japanese Translations

    private static let japaneseTranslations: [String: String] = [
        // Settings tabs
        "settings.account": "アカウント",
        "settings.general": "一般",
        "settings.hotkey": "ホットキー",
        "settings.dictionary": "辞書",
        "settings.globalDictionaryRequest": "グローバル辞書申請",
        "settings.language": "言語",
        "settings.about": "このアプリについて",

        // Account tab
        "account.title": "GitHubアカウント",
        "account.checking": "認証を確認中...",
        "account.notLoggedIn": "ログインしていません",
        "account.loginDescription": "GitHubでログインして、設定を同期し、文字起こしサービスを利用できます。",
        "account.loginButton": "GitHubでログイン",
        "account.loggingIn": "ログイン中...",
        "account.loggedIn": "ログイン済み",
        "account.admin": "(管理者)",
        "account.logoutButton": "ログアウト",
        "account.authError": "認証エラー",
        "account.tryAgain": "再試行",
        "account.features": "アカウント機能",
        "account.feature.sync": "データはサーバーと同期されます",
        "account.feature.dictionary": "個人辞書が利用可能です",
        "account.feature.transcription": "音声文字起こしが有効です",

        // General tab
        "general.server": "サーバー",
        "general.serverURL": "サーバーURL",
        "general.testConnection": "接続テスト",
        "general.connectionNotTested": "未テスト",
        "general.connectionTesting": "テスト中...",
        "general.connectionConnected": "接続済み",
        "general.connectionFailed": "失敗: {message}",
        "general.startup": "起動",
        "general.launchAtLogin": "ログイン時に起動",
        "general.model": "文字起こしモデル",
        "general.model.fastDescription": "高速、普段使い向け",
        "general.model.smartDescription": "高精度、正確さ重視",
        "general.transcriptionModel": "モデル",
        "general.noiseFilter": "雑音フィルター",
        "general.off": "オフ",
        "general.resetToDefaults": "デフォルトに戻す",

        // Hotkey tab
        "hotkey.permissions": "権限",
        "hotkey.accessGranted": "アクセシビリティ権限が許可されています",
        "hotkey.accessRequired": "アクセシビリティ権限が必要です",
        "hotkey.accessDescription": "VoxTypeがグローバルホットキーを検出するには、アクセシビリティ権限が必要です",
        "hotkey.grantAccess": "権限を許可",
        "hotkey.accessInstructions": "システム設定 > プライバシーとセキュリティ > アクセシビリティでVoxTypeを有効にしてください",
        "hotkey.title": "音声録音ホットキー",
        "hotkey.current": "現在のホットキー",
        "hotkey.recordingEnabled": "録音ホットキーを有効",
        "hotkey.mouseHoldEnabled": "マウスホイール長押しを有効",
        "hotkey.mouseHoldHint": "1秒以上押し続けると録音が開始されます。",
        "hotkey.change": "ホットキーを変更",
        "hotkey.selectModifiers": "修飾キーとキーを選択",
        "hotkey.modifierRequired": "修飾キーを1つ以上選択してください",
        "hotkey.cancel": "キャンセル",
        "hotkey.save": "保存",
        "hotkey.description": "このキーの組み合わせを押し続けると録音が開始され、離すと停止して文字起こしが行われます。",
        "hotkey.modelTitle": "モデル変更ホットキー",
        "hotkey.modelEnabled": "モデル変更ホットキーを有効",
        "hotkey.modelChange": "ホットキーを変更",
        "hotkey.modelDescription": "このキーの組み合わせでモデル選択のポップアップを表示します。",
        "hotkey.duplicateWarning": "このホットキーは既に使用されています。別の組み合わせを選択してください。",
        "hotkey.howItWorks": "使い方",
        "hotkey.tip.global": "ホットキーは全てのアプリケーションで動作します",
        "hotkey.tip.holdRelease": "押し続けて録音、離して文字起こし",
        "hotkey.tip.autoStop": "録音は60秒後に自動停止します",
        "hotkey.resetToDefault": "デフォルトに戻す (⌃.)",
        "modelPopup.title": "モデル選択",
        "modelPopup.hint": "↑↓で選択、Enterで確定",

        // Dictionary tab
        "dictionary.title": "個人辞書",
        "dictionary.loginRequired": "ログインが必要です",
        "dictionary.loginDescription": "個人辞書を管理するにはログインしてください",
        "dictionary.loading": "辞書を読み込み中...",
        "dictionary.empty": "辞書エントリがありません",
        "dictionary.emptyDescription": "パターンを追加して、単語の文字起こし方法をカスタマイズできます",
        "dictionary.example": "例:",
        "dictionary.pattern": "パターン",
        "dictionary.replacement": "置換後",
        "dictionary.deleteTitle": "エントリを削除",
        "dictionary.deleteConfirm": "「{pattern}」→「{replacement}」を削除しますか？",
        "dictionary.delete": "削除",
        "dictionary.limitReached": "辞書の上限に達しました（100エントリ）",
        "dictionary.dismiss": "閉じる",
        "globalRequest.title": "グローバル辞書申請",
        "globalRequest.comingSoon": "この機能は準備中です。",
        "globalRequest.loginRequired": "ログインが必要です",
        "globalRequest.loginDescription": "グローバル辞書の申請にはログインが必要です",
        "globalRequest.pattern": "パターン",
        "globalRequest.replacement": "置換後",
        "globalRequest.submit": "申請する",
        "globalRequest.successNote": "次の録音から反映されます。",
        "globalRequest.limitReached": "申請の上限に達しました。しばらく待ってから再度申請してください。",

        // Language tab
        "language.title": "言語設定",
        "language.appLanguage": "アプリの言語",
        "language.description": "アプリケーションの表示言語を選択します。",

        // About tab
        "about.version": "バージョン",
        "about.voiceToText": "音声を文字に",
        "about.licenses": "オープンソースライセンス",
        "about.github": "GitHub",
        "about.documentation": "ドキュメント",

        // Menu bar
        "menu.authenticated": "認証済み",
        "menu.notLoggedIn": "ログインしていません",
        "menu.recording": "録音中",
        "menu.startRecording": "録音開始",
        "menu.stopRecording": "録音停止",
        "menu.processing": "処理中...",
        "menu.lastTranscription": "前回の文字起こし:",
        "menu.copyToClipboard": "クリップボードにコピー",
        "menu.settings": "設定...",
        "menu.login": "GitHubでログイン",
        "menu.logout": "ログアウト",
        "menu.quit": "VoxTypeを終了",

        // Status
        "status.idle": "待機中",
        "status.recording": "録音中...",
        "status.processing": "処理中...",
        "status.completed": "完了",
        "status.error": "エラー",

        // Errors
        "error.loginRequired": "音声文字起こしを使用するにはログインしてください",

        // Common
        "common.cancel": "キャンセル",
        "common.save": "保存",
        "common.delete": "削除",
        "common.error": "エラー",
    ]
}
