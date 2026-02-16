import { useEffect, useState } from 'react'
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { Layout } from '@/components/Layout'
import { LoginPage } from '@/pages/Login'
import { AuthCallbackPage } from '@/pages/AuthCallback'
import { DashboardPage } from '@/pages/Dashboard'
import { UsersPage } from '@/pages/Users'
import { WhitelistPage } from '@/pages/Whitelist'
import { DictionaryPage } from '@/pages/Dictionary'
import { DictionaryRequestsPage } from '@/pages/DictionaryRequests'
import { BackupPage } from '@/pages/Backup'
import { isAuthenticated, getMe, type User } from '@/lib/api'
import { LanguageProvider } from '@/lib/i18n'

function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    async function checkAuth() {
      if (!isAuthenticated()) {
        setLoading(false)
        return
      }

      try {
        const userData = await getMe()
        if (!userData.is_admin) {
          // Not an admin, redirect to login
          setLoading(false)
          return
        }
        setUser(userData)
      } catch {
        // Token invalid or expired
      } finally {
        setLoading(false)
      }
    }
    checkAuth()
  }, [])

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-gray-900"></div>
      </div>
    )
  }

  if (!isAuthenticated() || !user) {
    return <Navigate to="/login" replace />
  }

  return <Layout user={user}>{children}</Layout>
}

function App() {
  return (
    <LanguageProvider>
      <BrowserRouter>
        <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route path="/auth/callback" element={<AuthCallbackPage />} />
        <Route
          path="/"
          element={
            <ProtectedRoute>
              <DashboardPage />
            </ProtectedRoute>
          }
        />
        <Route
          path="/users"
          element={
            <ProtectedRoute>
              <UsersPage />
            </ProtectedRoute>
          }
        />
        <Route
          path="/whitelist"
          element={
            <ProtectedRoute>
              <WhitelistPage />
            </ProtectedRoute>
          }
        />
        <Route
          path="/dictionary"
          element={
            <ProtectedRoute>
              <DictionaryPage />
            </ProtectedRoute>
          }
        />
        <Route
          path="/backup"
          element={
            <ProtectedRoute>
              <BackupPage />
            </ProtectedRoute>
          }
        />
        <Route
          path="/dictionary-requests"
          element={
            <ProtectedRoute>
              <DictionaryRequestsPage />
            </ProtectedRoute>
          }
        />
        <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </BrowserRouter>
    </LanguageProvider>
  )
}

export default App
