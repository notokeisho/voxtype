import { useEffect, useRef, useState } from 'react'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'
import {
  approveDictionaryRequest,
  deleteDictionaryRequest,
  getDictionaryRequests,
  rejectDictionaryRequest,
  type DictionaryRequest,
} from '@/lib/api'
import { useLanguage } from '@/lib/i18n'

export function DictionaryRequestsPage() {
  const { t, tWithParams, language } = useLanguage()
  const [requests, setRequests] = useState<DictionaryRequest[]>([])
  const [loading, setLoading] = useState(true)
  const [isRefreshing, setIsRefreshing] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [pendingAction, setPendingAction] = useState<{
    type: 'approve' | 'reject' | 'delete'
    request: DictionaryRequest
  } | null>(null)
  const [processing, setProcessing] = useState(false)
  const [lastCount, setLastCount] = useState<number | null>(null)
  const processingRef = useRef(processing)
  const isRefreshingRef = useRef(isRefreshing)
  const loadingRef = useRef(loading)
  const lastCountRef = useRef(lastCount)

  const fetchRequests = async (notify = false, showLoading = true) => {
    try {
      if (showLoading) {
        setLoading(true)
      } else {
        setIsRefreshing(true)
      }
      const data = await getDictionaryRequests()
      setRequests(data.entries)
      setLastCount(data.count)
      lastCountRef.current = data.count
      setError(null)
      if (notify) {
        window.dispatchEvent(
          new CustomEvent('dictionaryRequestsUpdated', {
            detail: { count: data.count },
          })
        )
      }
      return data
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch requests')
      return null
    } finally {
      if (showLoading) {
        setLoading(false)
      } else {
        setIsRefreshing(false)
      }
    }
  }

  useEffect(() => {
    processingRef.current = processing
  }, [processing])

  useEffect(() => {
    isRefreshingRef.current = isRefreshing
  }, [isRefreshing])

  useEffect(() => {
    loadingRef.current = loading
  }, [loading])

  useEffect(() => {
    lastCountRef.current = lastCount
  }, [lastCount])

  useEffect(() => {
    fetchRequests()

    const refreshCount = async () => {
      if (processingRef.current || isRefreshingRef.current || loadingRef.current) {
        return
      }
      try {
        const data = await getDictionaryRequests()
        window.dispatchEvent(
          new CustomEvent('dictionaryRequestsUpdated', {
            detail: { count: data.count },
          })
        )
        if (lastCountRef.current !== null && data.count !== lastCountRef.current) {
          await fetchRequests(true, false)
        } else if (lastCountRef.current === null) {
          setLastCount(data.count)
        }
      } catch {
        // Ignore polling failures
      }
    }

    const intervalId = window.setInterval(refreshCount, 30000)

    const handleFocus = async () => {
      await refreshCount()
    }

    const handleVisibilityChange = async () => {
      if (!document.hidden) {
        await refreshCount()
      }
    }

    window.addEventListener('focus', handleFocus)
    document.addEventListener('visibilitychange', handleVisibilityChange)

    return () => {
      window.clearInterval(intervalId)
      window.removeEventListener('focus', handleFocus)
      document.removeEventListener('visibilitychange', handleVisibilityChange)
    }
  }, [])

  const handleAction = async () => {
    if (!pendingAction) return

    try {
      setProcessing(true)
      if (pendingAction.type === 'approve') {
        await approveDictionaryRequest(pendingAction.request.id)
      } else if (pendingAction.type === 'reject') {
        await rejectDictionaryRequest(pendingAction.request.id)
      } else {
        await deleteDictionaryRequest(pendingAction.request.id)
      }
      setPendingAction(null)
      await fetchRequests(true)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to process request')
    } finally {
      setProcessing(false)
    }
  }

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
          {isRefreshing && (
            <div className="text-xs text-gray-500 mb-2">
              {t('dictionaryRequests.processing')}
            </div>
          )}
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>{t('dictionaryRequests.pattern')}</TableHead>
                <TableHead>{t('dictionaryRequests.replacement')}</TableHead>
                <TableHead>{t('dictionaryRequests.requestedAt')}</TableHead>
                <TableHead>{t('dictionaryRequests.requestedBy')}</TableHead>
                <TableHead>{t('dictionary.actions')}</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {requests.map((request) => (
                <TableRow key={request.id}>
                  <TableCell className="font-medium">{request.pattern}</TableCell>
                  <TableCell>
                    <div className="space-y-1">
                      <div>{request.replacement}</div>
                      {request.conflict_replacement && (
                        <div className="text-xs text-amber-700">
                          <div className="font-medium">{t('dictionaryRequests.conflictLabel')}</div>
                          <div>
                            {t('dictionaryRequests.conflictCurrent')}: {request.conflict_replacement}
                          </div>
                          <div>
                            {t('dictionaryRequests.conflictProposed')}: {request.replacement}
                          </div>
                        </div>
                      )}
                    </div>
                  </TableCell>
                  <TableCell>{formatDate(request.created_at)}</TableCell>
                  <TableCell>
                    {request.user_name || request.user_github_id || request.user_id}
                  </TableCell>
                  <TableCell>
                    <div className="flex gap-2">
                      <Button
                        size="sm"
                        onClick={() => setPendingAction({ type: 'approve', request })}
                        disabled={processing}
                      >
                        {t('dictionaryRequests.approve')}
                      </Button>
                      <Button
                        size="sm"
                        variant="outline"
                        onClick={() => setPendingAction({ type: 'reject', request })}
                        disabled={processing}
                      >
                        {t('dictionaryRequests.reject')}
                      </Button>
                      <Button
                        size="sm"
                        variant="destructive"
                        onClick={() => setPendingAction({ type: 'delete', request })}
                        disabled={processing}
                      >
                        {t('dictionaryRequests.delete')}
                      </Button>
                    </div>
                    {request.conflict_replacement && (
                      <div className="mt-2 space-y-1 text-xs text-gray-500">
                        <div>{t('dictionaryRequests.approveHint')}</div>
                        <div>{t('dictionaryRequests.rejectHint')}</div>
                      </div>
                    )}
                  </TableCell>
                </TableRow>
              ))}
              {requests.length === 0 && (
                <TableRow>
                  <TableCell colSpan={5} className="text-center text-gray-500">
                    {t('dictionaryRequests.noEntries')}
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        </CardContent>
      </Card>

      <Dialog open={!!pendingAction} onOpenChange={() => setPendingAction(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{t('common.confirm')}</DialogTitle>
            <DialogDescription>
              {pendingAction?.type === 'approve' && t('dictionaryRequests.approveConfirm')}
              {pendingAction?.type === 'reject' && t('dictionaryRequests.rejectConfirm')}
              {pendingAction?.type === 'delete' && t('dictionaryRequests.deleteConfirm')}
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setPendingAction(null)}>
              {t('common.cancel')}
            </Button>
            <Button
              onClick={handleAction}
              disabled={processing}
              variant={pendingAction?.type === 'delete' ? 'destructive' : 'default'}
            >
              {processing
                ? t('dictionaryRequests.processing')
                : pendingAction?.type === 'approve'
                  ? t('dictionaryRequests.approve')
                  : pendingAction?.type === 'reject'
                    ? t('dictionaryRequests.reject')
                    : t('dictionaryRequests.delete')}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
