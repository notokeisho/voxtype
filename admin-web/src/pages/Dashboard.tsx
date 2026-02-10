import { useEffect, useState } from 'react'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { getStatus, type StatusResponse } from '@/lib/api'
import { useLanguage } from '@/lib/i18n'

export function DashboardPage() {
  const { t } = useLanguage()
  const [status, setStatus] = useState<StatusResponse | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    async function fetchStatus() {
      try {
        const data = await getStatus()
        setStatus(data)
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Failed to fetch status')
      } finally {
        setLoading(false)
      }
    }
    fetchStatus()
  }, [])

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'ok':
      case 'connected':
        return 'text-green-600 bg-green-100'
      case 'degraded':
        return 'text-yellow-600 bg-yellow-100'
      case 'error':
      case 'disconnected':
        return 'text-red-600 bg-red-100'
      default:
        return 'text-yellow-600 bg-yellow-100'
    }
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-gray-900"></div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="text-center text-red-600 py-8">
        <p>{t('dashboard.error')}: {error}</p>
      </div>
    )
  }

  return (
    <div>
      <h2 className="text-2xl font-bold mb-6">{t('dashboard.title')}</h2>

      <div className="grid gap-6 md:grid-cols-3">
        <Card>
          <CardHeader>
            <CardTitle>{t('dashboard.serverStatus')}</CardTitle>
            <CardDescription>{t('dashboard.mainServer')}</CardDescription>
          </CardHeader>
          <CardContent>
            <span className={`inline-flex items-center px-3 py-1 rounded-full text-sm font-medium ${getStatusColor(status?.status || '')}`}>
              {status?.status === 'ok' ? t('dashboard.ok') : status?.status}
            </span>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>{t('dashboard.whisperServer')}</CardTitle>
            <CardDescription>{t('dashboard.speechEngine')}</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-3">
              <div className="flex items-center justify-between">
                <span className="text-sm text-gray-600">{t('dashboard.whisperOverall')}</span>
                <span className={`inline-flex items-center px-3 py-1 rounded-full text-sm font-medium ${getStatusColor(status?.whisper_overall || '')}`}>
                  {status?.whisper_overall === 'connected'
                    ? t('dashboard.connected')
                    : status?.whisper_overall === 'degraded'
                      ? t('dashboard.degraded')
                      : status?.whisper_overall}
                </span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-sm text-gray-600">{t('dashboard.whisperFast')}</span>
                <span className={`inline-flex items-center px-3 py-1 rounded-full text-sm font-medium ${getStatusColor(status?.whisper_fast || '')}`}>
                  {status?.whisper_fast === 'connected' ? t('dashboard.connected') : status?.whisper_fast}
                </span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-sm text-gray-600">{t('dashboard.whisperSmart')}</span>
                <span className={`inline-flex items-center px-3 py-1 rounded-full text-sm font-medium ${getStatusColor(status?.whisper_smart || '')}`}>
                  {status?.whisper_smart === 'connected' ? t('dashboard.connected') : status?.whisper_smart}
                </span>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>{t('dashboard.database')}</CardTitle>
            <CardDescription>PostgreSQL</CardDescription>
          </CardHeader>
          <CardContent>
            <span className={`inline-flex items-center px-3 py-1 rounded-full text-sm font-medium ${getStatusColor(status?.database || '')}`}>
              {status?.database === 'connected' ? t('dashboard.connected') : status?.database}
            </span>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
