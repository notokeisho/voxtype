import { createContext, useContext, useState, useEffect, useRef, type ReactNode } from 'react'
import { Globe, ChevronDown } from 'lucide-react'

type Language = 'ja' | 'en'

const translations = {
  ja: {
    // Navigation
    'nav.dashboard': 'ダッシュボード',
    'nav.users': 'ユーザー管理',
    'nav.whitelist': 'ホワイトリスト',
    'nav.dictionary': 'グローバル辞書',
    'nav.logout': 'ログアウト',

    // Dashboard
    'dashboard.title': 'ダッシュボード',
    'dashboard.error': 'エラー',
    'dashboard.serverStatus': 'サーバー状態',
    'dashboard.mainServer': 'メインサーバー',
    'dashboard.ok': '正常',
    'dashboard.whisperServer': 'Whisper サーバー',
    'dashboard.speechEngine': '音声認識エンジン',
    'dashboard.connected': '接続済み',
    'dashboard.degraded': '注意',
    'dashboard.whisperOverall': '全体',
    'dashboard.whisperFast': 'Fast',
    'dashboard.whisperSmart': 'Smart',
    'dashboard.database': 'データベース',

    // Users
    'users.title': 'ユーザー管理',
    'users.listTitle': '登録ユーザー一覧',
    'users.avatar': 'アバター',
    'users.username': 'ユーザー名',
    'users.role': 'ロール',
    'users.createdAt': '登録日時',
    'users.lastLogin': '最終ログイン',
    'users.actions': '操作',
    'users.admin': '管理者',
    'users.member': 'メンバー',
    'users.you': '(自分)',
    'users.changeToMember': 'メンバーに変更',
    'users.changeToAdmin': '管理者に変更',
    'users.delete': '削除',
    'users.noUsers': 'ユーザーがいません',
    'users.roleChangeTitle': 'ロールの変更',
    'users.roleChangeToMember': '{name} をメンバーに変更しますか？',
    'users.roleChangeToAdmin': '{name} を管理者に変更しますか？',
    'users.change': '変更',
    'users.changing': '変更中...',
    'users.deleteTitle': 'ユーザーの削除',
    'users.deleteConfirm': '{name} を削除しますか？この操作は取り消せません。',
    'users.deleting': '削除中...',

    // Dictionary
    'dictionary.title': 'グローバル辞書管理',
    'dictionary.info': 'グローバル辞書は全ユーザーの音声認識結果に適用されます。よくある認識ミスや固有名詞の変換ルールを登録してください。',
    'dictionary.addTitle': 'エントリを追加',
    'dictionary.addDescription': '認識パターンと置換後のテキストを入力してください',
    'dictionary.pattern': '認識パターン',
    'dictionary.replacement': '置換後',
    'dictionary.patternPlaceholder': '例: くろーど',
    'dictionary.replacementPlaceholder': '例: Claude',
    'dictionary.add': '追加',
    'dictionary.adding': '追加中...',
    'dictionary.listTitle': '辞書エントリ一覧',
    'dictionary.entryCount': '{count} 件のエントリが登録されています',
    'dictionary.createdAt': '登録日時',
    'dictionary.actions': '操作',
    'dictionary.delete': '削除',
    'dictionary.deleting': '削除中...',
    'dictionary.noEntries': '辞書エントリがありません',
    'dictionary.deleteTitle': 'エントリの削除',
    'dictionary.deleteConfirm': '「{pattern}」→「{replacement}」を削除しますか？',

    // Whitelist
    'whitelist.title': 'ホワイトリスト管理',
    'whitelist.searchPlaceholder': 'GitHubユーザー名を入力',
    'whitelist.search': '検索',
    'whitelist.add': '追加',
    'whitelist.delete': '削除',
    'whitelist.confirmDelete': 'このユーザーを削除しますか？',
    'whitelist.alreadyExists': '既に登録済みです',
    'whitelist.confirmAdd': 'このユーザーを追加しますか？',
    'whitelist.cannotDeleteSelf': '自分自身を削除することはできません',
    'whitelist.notFound': 'ユーザーが見つかりません',
    'whitelist.rateLimitExceeded': 'GitHub APIの制限に達しました。しばらく待ってください',
    'whitelist.addSuccess': 'ホワイトリストに追加しました',
    'whitelist.deleteSuccess': 'ホワイトリストから削除しました',
    'whitelist.githubId': 'GitHub ID',
    'whitelist.githubUsername': 'GitHubユーザー名',
    'whitelist.createdAt': '追加日時',
    'whitelist.actions': '操作',
    'whitelist.noEntries': 'ホワイトリストが空です',
    'whitelist.searching': '検索中...',

    // Common
    'common.cancel': 'キャンセル',
    'common.confirm': '確認',
    'common.error': 'エラー',
    'common.loading': '読み込み中...',
    'common.close': '閉じる',
  },
  en: {
    // Navigation
    'nav.dashboard': 'Dashboard',
    'nav.users': 'User Management',
    'nav.whitelist': 'Whitelist',
    'nav.dictionary': 'Global Dictionary',
    'nav.logout': 'Logout',

    // Dashboard
    'dashboard.title': 'Dashboard',
    'dashboard.error': 'Error',
    'dashboard.serverStatus': 'Server Status',
    'dashboard.mainServer': 'Main Server',
    'dashboard.ok': 'OK',
    'dashboard.whisperServer': 'Whisper Server',
    'dashboard.speechEngine': 'Speech Recognition Engine',
    'dashboard.connected': 'Connected',
    'dashboard.degraded': 'Degraded',
    'dashboard.whisperOverall': 'Overall',
    'dashboard.whisperFast': 'Fast',
    'dashboard.whisperSmart': 'Smart',
    'dashboard.database': 'Database',

    // Users
    'users.title': 'User Management',
    'users.listTitle': 'Registered Users',
    'users.avatar': 'Avatar',
    'users.username': 'Username',
    'users.role': 'Role',
    'users.createdAt': 'Created At',
    'users.lastLogin': 'Last Login',
    'users.actions': 'Actions',
    'users.admin': 'Admin',
    'users.member': 'Member',
    'users.you': '(You)',
    'users.changeToMember': 'Change to Member',
    'users.changeToAdmin': 'Change to Admin',
    'users.delete': 'Delete',
    'users.noUsers': 'No users found',
    'users.roleChangeTitle': 'Change Role',
    'users.roleChangeToMember': 'Change {name} to Member?',
    'users.roleChangeToAdmin': 'Change {name} to Admin?',
    'users.change': 'Change',
    'users.changing': 'Changing...',
    'users.deleteTitle': 'Delete User',
    'users.deleteConfirm': 'Delete {name}? This action cannot be undone.',
    'users.deleting': 'Deleting...',

    // Dictionary
    'dictionary.title': 'Global Dictionary Management',
    'dictionary.info': 'The global dictionary applies to all users\' speech recognition results. Register rules for common recognition errors and proper nouns.',
    'dictionary.addTitle': 'Add Entry',
    'dictionary.addDescription': 'Enter the recognition pattern and replacement text',
    'dictionary.pattern': 'Recognition Pattern',
    'dictionary.replacement': 'Replacement',
    'dictionary.patternPlaceholder': 'e.g., kuroad',
    'dictionary.replacementPlaceholder': 'e.g., Claude',
    'dictionary.add': 'Add',
    'dictionary.adding': 'Adding...',
    'dictionary.listTitle': 'Dictionary Entries',
    'dictionary.entryCount': '{count} entries registered',
    'dictionary.createdAt': 'Created At',
    'dictionary.actions': 'Actions',
    'dictionary.delete': 'Delete',
    'dictionary.deleting': 'Deleting...',
    'dictionary.noEntries': 'No dictionary entries',
    'dictionary.deleteTitle': 'Delete Entry',
    'dictionary.deleteConfirm': 'Delete "{pattern}" → "{replacement}"?',

    // Whitelist
    'whitelist.title': 'Whitelist Management',
    'whitelist.searchPlaceholder': 'Enter GitHub username',
    'whitelist.search': 'Search',
    'whitelist.add': 'Add',
    'whitelist.delete': 'Delete',
    'whitelist.confirmDelete': 'Are you sure you want to delete this user?',
    'whitelist.alreadyExists': 'Already registered',
    'whitelist.confirmAdd': 'Add this user to whitelist?',
    'whitelist.cannotDeleteSelf': 'Cannot remove yourself from whitelist',
    'whitelist.notFound': 'User not found',
    'whitelist.rateLimitExceeded': 'GitHub API rate limit exceeded. Please wait.',
    'whitelist.addSuccess': 'Added to whitelist',
    'whitelist.deleteSuccess': 'Removed from whitelist',
    'whitelist.githubId': 'GitHub ID',
    'whitelist.githubUsername': 'GitHub Username',
    'whitelist.createdAt': 'Created At',
    'whitelist.actions': 'Actions',
    'whitelist.noEntries': 'Whitelist is empty',
    'whitelist.searching': 'Searching...',

    // Common
    'common.cancel': 'Cancel',
    'common.confirm': 'Confirm',
    'common.error': 'Error',
    'common.loading': 'Loading...',
    'common.close': 'Close',
  },
} as const

type TranslationKey = keyof typeof translations['ja']

interface LanguageContextType {
  language: Language
  setLanguage: (lang: Language) => void
  t: (key: TranslationKey) => string
  tWithParams: (key: TranslationKey, params: Record<string, string | number>) => string
}

const LanguageContext = createContext<LanguageContextType | null>(null)

const LANGUAGE_STORAGE_KEY = 'admin_language'

export function LanguageProvider({ children }: { children: ReactNode }) {
  const [language, setLanguageState] = useState<Language>(() => {
    const saved = localStorage.getItem(LANGUAGE_STORAGE_KEY)
    return (saved === 'en' ? 'en' : 'ja') as Language
  })

  const setLanguage = (lang: Language) => {
    setLanguageState(lang)
    localStorage.setItem(LANGUAGE_STORAGE_KEY, lang)
  }

  const t = (key: TranslationKey): string => {
    return translations[language][key] || key
  }

  const tWithParams = (key: TranslationKey, params: Record<string, string | number>): string => {
    let text: string = translations[language][key] || key
    Object.entries(params).forEach(([k, v]) => {
      text = text.replace(`{${k}}`, String(v))
    })
    return text
  }

  return (
    <LanguageContext.Provider value={{ language, setLanguage, t, tWithParams }}>
      {children}
    </LanguageContext.Provider>
  )
}

export function useLanguage() {
  const context = useContext(LanguageContext)
  if (!context) {
    throw new Error('useLanguage must be used within LanguageProvider')
  }
  return context
}

export function LanguageSwitcher() {
  const { language, setLanguage } = useLanguage()
  const [isOpen, setIsOpen] = useState(false)
  const ref = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) {
        setIsOpen(false)
      }
    }
    document.addEventListener('click', handleClickOutside)
    return () => document.removeEventListener('click', handleClickOutside)
  }, [])

  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setIsOpen(false)
    }
    document.addEventListener('keydown', handleEscape)
    return () => document.removeEventListener('keydown', handleEscape)
  }, [])

  return (
    <div className="relative" ref={ref}>
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="flex items-center gap-1 px-2 py-1 text-sm text-gray-700 hover:bg-gray-100 rounded"
      >
        <Globe className="w-4 h-4" />
        {language.toUpperCase()}
        <ChevronDown className="w-4 h-4" />
      </button>
      {isOpen && (
        <div className="absolute right-0 mt-1 bg-white border rounded shadow-lg z-50 min-w-[100px]">
          <button
            onClick={() => {
              setLanguage('ja')
              setIsOpen(false)
            }}
            className={`block w-full text-left px-3 py-2 text-sm hover:bg-gray-100 ${
              language === 'ja' ? 'bg-gray-50 font-medium' : ''
            }`}
          >
            日本語
          </button>
          <button
            onClick={() => {
              setLanguage('en')
              setIsOpen(false)
            }}
            className={`block w-full text-left px-3 py-2 text-sm hover:bg-gray-100 ${
              language === 'en' ? 'bg-gray-50 font-medium' : ''
            }`}
          >
            English
          </button>
        </div>
      )}
    </div>
  )
}
