import { useEffect, useState } from 'react'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Label } from '@/components/ui/label'
import {
  getBackupFiles,
  getBackupSettings,
  restoreBackupFile,
  runBackupNow,
  updateBackupSettings,
  type BackupFile,
  type BackupRestoreResult,
  type BackupRunResult,
} from '@/lib/api'
import { useLanguage } from '@/lib/i18n'

export function BackupPage() {
  const { t, tWithParams, language } = useLanguage()
  const [error, setError] = useState<string | null>(null)
  const [backupEnabled, setBackupEnabled] = useState(false)
  const [backupLastRun, setBackupLastRun] = useState<string | null>(null)
  const [backupUpdating, setBackupUpdating] = useState(false)
  const [runningBackupNow, setRunningBackupNow] = useState(false)
  const [manualBackupResult, setManualBackupResult] = useState<BackupRunResult | null>(null)
  const [manualBackupDismissed, setManualBackupDismissed] = useState(false)
  const [isBackupConfirmOpen, setIsBackupConfirmOpen] = useState(false)
  const [backupFiles, setBackupFiles] = useState<BackupFile[]>([])
  const [backupFilesLoading, setBackupFilesLoading] = useState(false)
  const [restoreTarget, setRestoreTarget] = useState<BackupFile | null>(null)
  const [restoreMode, setRestoreMode] = useState<'merge' | 'replace'>('merge')
  const [isRestoreReplaceFinalOpen, setIsRestoreReplaceFinalOpen] = useState(false)
  const [restoring, setRestoring] = useState(false)
  const [restoreResult, setRestoreResult] = useState<BackupRestoreResult | null>(null)

  const formatDate = (dateString: string) => {
    const utcDate = dateString.endsWith('Z') ? dateString : dateString + 'Z'
    return new Date(utcDate).toLocaleString(language === 'ja' ? 'ja-JP' : 'en-US')
  }

  const fetchBackupFiles = async () => {
    try {
      setBackupFilesLoading(true)
      const data = await getBackupFiles()
      setBackupFiles(data.files)
    } catch (err) {
      setError(err instanceof Error ? err.message : t('dictionary.backupFilesFetchFailed'))
    } finally {
      setBackupFilesLoading(false)
    }
  }

  useEffect(() => {
    fetchBackupFiles()
  }, [])

  useEffect(() => {
    const fetchBackupSettings = async () => {
      try {
        const data = await getBackupSettings()
        setBackupEnabled(data.enabled)
        setBackupLastRun(data.last_run_at)
      } catch (err) {
        setError(err instanceof Error ? err.message : t('dictionary.backupFetchFailed'))
      }
    }

    fetchBackupSettings()
  }, [])

  const executeRunBackupNow = async () => {
    try {
      setRunningBackupNow(true)
      const result = await runBackupNow()
      setManualBackupResult(result)
      setManualBackupDismissed(false)
      setBackupLastRun(result.created_at)
      setError(null)
      await fetchBackupFiles()
    } catch (err) {
      setError(err instanceof Error ? err.message : t('dictionary.backupRunFailed'))
    } finally {
      setRunningBackupNow(false)
    }
  }

  const handleOpenRestore = (file: BackupFile) => {
    setRestoreTarget(file)
    setRestoreMode('merge')
    setIsRestoreReplaceFinalOpen(false)
  }

  const handleCloseRestoreDialogs = () => {
    if (restoring) return
    setRestoreTarget(null)
    setRestoreMode('merge')
    setIsRestoreReplaceFinalOpen(false)
  }

  const executeRestore = async (mode: 'merge' | 'replace') => {
    if (!restoreTarget) return

    try {
      setRestoring(true)
      const result = await restoreBackupFile(restoreTarget.filename, mode)
      setRestoreResult(result)
      setError(null)
      await fetchBackupFiles()
      handleCloseRestoreDialogs()
    } catch (err) {
      setError(err instanceof Error ? err.message : t('dictionary.restoreFailed'))
    } finally {
      setRestoring(false)
    }
  }

  return (
    <div>
      <h2 className="text-2xl font-bold mb-6">{t('backup.title')}</h2>

      {error && (
        <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4">
          {error}
        </div>
      )}

      <Card>
        <CardHeader className="space-y-2">
          <CardTitle>{t('dictionary.backupTitle')}</CardTitle>
          <div className="flex items-center justify-between rounded-lg border border-gray-200 bg-gray-50 px-4 py-3">
            <div>
              <div className="text-sm font-semibold">{t('dictionary.backupTitle')}</div>
              <div className="text-xs text-gray-600">
                {backupLastRun
                  ? tWithParams('dictionary.backupLastRun', {
                      datetime: formatDate(backupLastRun),
                    })
                  : t('dictionary.backupNotRun')}
              </div>
            </div>
            <button
              type="button"
              role="switch"
              aria-checked={backupEnabled}
              onClick={() => {
                const nextValue = !backupEnabled
                setBackupEnabled(nextValue)
                setBackupUpdating(true)
                updateBackupSettings(nextValue)
                  .then((data) => {
                    setBackupEnabled(data.enabled)
                    setBackupLastRun(data.last_run_at)
                  })
                  .catch((err) => {
                    setError(err instanceof Error ? err.message : t('dictionary.backupUpdateFailed'))
                    setBackupEnabled((prev) => !prev)
                  })
                  .finally(() => setBackupUpdating(false))
              }}
              disabled={backupUpdating}
              className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${
                backupEnabled ? 'bg-blue-600' : 'bg-gray-200'
              }`}
            >
              <span
                className={`inline-block h-5 w-5 transform rounded-full bg-white shadow transition-transform ${
                  backupEnabled ? 'translate-x-5' : 'translate-x-1'
                }`}
              />
            </button>
          </div>
          <div>
            <Button
              type="button"
              variant="outline"
              size="sm"
              disabled={runningBackupNow}
              onClick={() => setIsBackupConfirmOpen(true)}
            >
              {runningBackupNow ? t('dictionary.backupRunning') : t('dictionary.backupRunNow')}
            </Button>
          </div>
          {manualBackupResult && !manualBackupDismissed && (
            <div className="rounded-lg border border-gray-200 bg-gray-50 px-4 py-3">
              <div className="flex items-start justify-between gap-4">
                <div className="space-y-1 text-xs text-gray-700">
                  <div>
                    {tWithParams('dictionary.backupManualLastRun', {
                      datetime: formatDate(manualBackupResult.created_at),
                    })}
                  </div>
                  <div>
                    {tWithParams('dictionary.backupManualCreatedFile', {
                      file: manualBackupResult.created_file,
                    })}
                  </div>
                  <div>
                    {tWithParams('dictionary.backupManualSummary', {
                      kept: manualBackupResult.kept,
                      deleted: manualBackupResult.deleted,
                    })}
                  </div>
                </div>
                <button
                  type="button"
                  className="text-gray-500 hover:text-gray-700"
                  aria-label={t('common.close')}
                  onClick={() => setManualBackupDismissed(true)}
                >
                  ×
                </button>
              </div>
            </div>
          )}

          <div className="rounded-lg border border-gray-200 bg-gray-50 px-4 py-3">
            <div className="text-sm font-semibold mb-2">{t('dictionary.backupFilesTitle')}</div>
            {backupFilesLoading ? (
              <div className="text-xs text-gray-600">{t('common.loading')}</div>
            ) : backupFiles.length === 0 ? (
              <div className="text-xs text-gray-600">{t('dictionary.backupFilesEmpty')}</div>
            ) : (
              <div className="space-y-2">
                {backupFiles.map((file) => (
                  <div
                    key={file.filename}
                    className="flex items-center justify-between gap-3 rounded border border-gray-200 bg-white px-3 py-2"
                  >
                    <div className="min-w-0">
                      <div className="text-xs font-medium truncate">{file.filename}</div>
                      <div className="text-xs text-gray-500">
                        {formatDate(file.created_at)}
                      </div>
                    </div>
                    <Button
                      type="button"
                      variant="outline"
                      size="sm"
                      onClick={() => handleOpenRestore(file)}
                    >
                      {t('dictionary.backupRestore')}
                    </Button>
                  </div>
                ))}
              </div>
            )}
          </div>
          {restoreResult && (
            <div className="rounded-lg border border-gray-200 bg-gray-50 px-4 py-3">
              <div className="flex items-start justify-between gap-4">
                <div className="space-y-1 text-xs text-gray-700">
                  <div className="font-medium text-gray-900">{t('dictionary.restoreSuccess')}</div>
                  <div>
                    {tWithParams('dictionary.restoreFile', {
                      file: restoreResult.restored_file,
                    })}
                  </div>
                  <div>
                    {tWithParams('dictionary.restoreSummary', {
                      mode: restoreResult.mode,
                      total: restoreResult.total,
                      added: restoreResult.added,
                      skipped: restoreResult.skipped,
                      failed: restoreResult.failed,
                    })}
                  </div>
                  <div>
                    {tWithParams('dictionary.restoreLastRun', {
                      datetime: formatDate(restoreResult.restored_at),
                    })}
                  </div>
                </div>
                <button
                  type="button"
                  className="text-gray-500 hover:text-gray-700"
                  aria-label={t('common.close')}
                  onClick={() => setRestoreResult(null)}
                >
                  ×
                </button>
              </div>
            </div>
          )}
        </CardHeader>
        <CardContent />
      </Card>

      <Dialog open={isBackupConfirmOpen} onOpenChange={setIsBackupConfirmOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{t('dictionary.backupConfirmTitle')}</DialogTitle>
            <DialogDescription>{t('dictionary.backupConfirmDescription')}</DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setIsBackupConfirmOpen(false)} disabled={runningBackupNow}>
              {t('common.cancel')}
            </Button>
            <Button
              onClick={async () => {
                await executeRunBackupNow()
                setIsBackupConfirmOpen(false)
              }}
              disabled={runningBackupNow}
            >
              {runningBackupNow ? t('dictionary.backupRunning') : t('dictionary.backupConfirmRun')}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog
        open={!!restoreTarget}
        onOpenChange={(open) => {
          if (!open) {
            handleCloseRestoreDialogs()
          }
        }}
      >
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{t('dictionary.restoreConfirmTitle')}</DialogTitle>
            <DialogDescription>
              {restoreTarget
                ? tWithParams('dictionary.restoreConfirmDescription', {
                    filename: restoreTarget.filename,
                  })
                : t('dictionary.restoreConfirmDescriptionEmpty')}
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-2">
            <Label>{t('dictionary.restoreModeLabel')}</Label>
            <div className="space-y-2">
              <label className="flex items-center gap-2">
                <input
                  type="radio"
                  name="restore-mode"
                  value="merge"
                  checked={restoreMode === 'merge'}
                  onChange={() => setRestoreMode('merge')}
                  disabled={restoring}
                />
                <span>{t('dictionary.restoreModeMerge')}</span>
              </label>
              <label className="flex items-center gap-2">
                <input
                  type="radio"
                  name="restore-mode"
                  value="replace"
                  checked={restoreMode === 'replace'}
                  onChange={() => setRestoreMode('replace')}
                  disabled={restoring}
                />
                <span>{t('dictionary.restoreModeReplace')}</span>
              </label>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={handleCloseRestoreDialogs} disabled={restoring}>
              {t('common.cancel')}
            </Button>
            <Button
              onClick={async () => {
                if (restoreMode === 'replace') {
                  setIsRestoreReplaceFinalOpen(true)
                  return
                }
                await executeRestore('merge')
              }}
              disabled={restoring}
            >
              {restoring ? t('dictionary.restoreRunning') : t('dictionary.restoreConfirmRun')}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog
        open={isRestoreReplaceFinalOpen}
        onOpenChange={(open) => {
          if (!open && !restoring) {
            setIsRestoreReplaceFinalOpen(false)
          }
        }}
      >
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{t('dictionary.restoreReplaceFinalTitle')}</DialogTitle>
            <DialogDescription>{t('dictionary.restoreReplaceFinalConfirm')}</DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button
              variant="outline"
              onClick={() => setIsRestoreReplaceFinalOpen(false)}
              disabled={restoring}
            >
              {t('common.cancel')}
            </Button>
            <Button onClick={() => executeRestore('replace')} disabled={restoring}>
              {restoring ? t('dictionary.restoreRunning') : t('dictionary.restoreReplaceRun')}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
