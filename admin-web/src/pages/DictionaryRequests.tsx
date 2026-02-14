import { useEffect, useState } from 'react'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'
import { getDictionaryRequests, type DictionaryRequest } from '@/lib/api'
import { useLanguage } from '@/lib/i18n'

export function DictionaryRequestsPage() {
  const { t, tWithParams, language } = useLanguage()
  const [requests, setRequests] = useState<DictionaryRequest[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const fetchRequests = async () => {
    try {
      setLoading(true)
      const data = await getDictionaryRequests()
      setRequests(data.entries)
      setError(null)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch requests')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchRequests()
  }, [])

  const formatDate = (dateString: string) => {
    const utcDate = dateString.endsWith('Z') ? dateString : dateString + 'Z'
    return new Date(utcDate).toLocaleString(language === 'ja' ? 'ja-JP' : 'en-US')
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-gray-900"></div>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-gray-900">{t('dictionaryRequests.title')}</h2>
      </div>

      {error && (
        <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded">
          {error}
        </div>
      )}

      <Card>
        <CardHeader>
          <CardTitle>{t('dictionaryRequests.listTitle')}</CardTitle>
          <CardDescription>
            {tWithParams('dictionaryRequests.entryCount', { count: requests.length })}
          </CardDescription>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>{t('dictionaryRequests.pattern')}</TableHead>
                <TableHead>{t('dictionaryRequests.replacement')}</TableHead>
                <TableHead>{t('dictionaryRequests.requestedAt')}</TableHead>
                <TableHead>{t('dictionaryRequests.requestedBy')}</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {requests.map((request) => (
                <TableRow key={request.id}>
                  <TableCell className="font-medium">{request.pattern}</TableCell>
                  <TableCell>{request.replacement}</TableCell>
                  <TableCell>{formatDate(request.created_at)}</TableCell>
                  <TableCell>{request.user_id}</TableCell>
                </TableRow>
              ))}
              {requests.length === 0 && (
                <TableRow>
                  <TableCell colSpan={4} className="text-center text-gray-500">
                    {t('dictionaryRequests.noEntries')}
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        </CardContent>
      </Card>
    </div>
  )
}
