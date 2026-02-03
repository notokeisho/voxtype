import { createContext, useContext, useState, type ReactNode } from 'react'

type Language = 'ja' | 'en'

const translations = {
  ja: {
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

  return (
    <LanguageContext.Provider value={{ language, setLanguage, t }}>
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

  return (
    <div className="flex items-center gap-1 text-sm">
      <button
        onClick={() => setLanguage('ja')}
        className={`px-2 py-1 rounded ${
          language === 'ja'
            ? 'bg-blue-600 text-white'
            : 'bg-gray-200 text-gray-700 hover:bg-gray-300'
        }`}
      >
        JA
      </button>
      <button
        onClick={() => setLanguage('en')}
        className={`px-2 py-1 rounded ${
          language === 'en'
            ? 'bg-blue-600 text-white'
            : 'bg-gray-200 text-gray-700 hover:bg-gray-300'
        }`}
      >
        EN
      </button>
    </div>
  )
}
