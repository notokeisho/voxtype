import { Link, useLocation, useNavigate } from 'react-router-dom'
import { Button } from '@/components/ui/button'
import { removeToken, type User } from '@/lib/api'
import { cn } from '@/lib/utils'
import { LanguageSwitcher } from '@/lib/i18n'

interface LayoutProps {
  children: React.ReactNode
  user: User | null
}

const navItems = [
  { path: '/', label: 'ダッシュボード', icon: '📊' },
  { path: '/users', label: 'ユーザー管理', icon: '👥' },
  { path: '/whitelist', label: 'ホワイトリスト', icon: '✅' },
  { path: '/dictionary', label: 'グローバル辞書', icon: '📖' },
]

export function Layout({ children, user }: LayoutProps) {
  const location = useLocation()
  const navigate = useNavigate()

  const handleLogout = () => {
    removeToken()
    navigate('/login')
  }

  return (
    <div className="min-h-screen bg-gray-100">
      {/* Header */}
      <header className="bg-white shadow">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between h-16 items-center">
            <h1 className="text-xl font-bold text-gray-900">
              VoiceServer Admin
            </h1>
            <div className="flex items-center gap-4">
              <LanguageSwitcher />
              {user && (
                <>
                  <div className="flex items-center gap-2">
                    {user.github_avatar && (
                      <img
                        src={user.github_avatar}
                        alt={user.github_id}
                        className="w-8 h-8 rounded-full"
                      />
                    )}
                    <span className="text-sm text-gray-700">{user.github_id}</span>
                  </div>
                  <Button variant="outline" size="sm" onClick={handleLogout}>
                    ログアウト
                  </Button>
                </>
              )}
            </div>
          </div>
        </div>
      </header>

      <div className="flex">
        {/* Sidebar */}
        <nav className="w-64 min-h-[calc(100vh-4rem)] bg-white shadow-sm">
          <ul className="py-4">
            {navItems.map((item) => (
              <li key={item.path}>
                <Link
                  to={item.path}
                  className={cn(
                    'flex items-center gap-3 px-6 py-3 text-gray-700 hover:bg-gray-50',
                    location.pathname === item.path && 'bg-gray-100 font-medium'
                  )}
                >
                  <span>{item.icon}</span>
                  <span>{item.label}</span>
                </Link>
              </li>
            ))}
          </ul>
        </nav>

        {/* Main content */}
        <main className="flex-1 p-8">
          {children}
        </main>
      </div>
    </div>
  )
}
