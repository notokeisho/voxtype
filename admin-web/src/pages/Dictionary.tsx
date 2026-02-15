import { useEffect, useRef, useState } from 'react'
import { useLocation } from 'react-router-dom'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import {
  getGlobalDictionary,
  addGlobalDictionaryEntry,
  deleteGlobalDictionaryEntry,
  downloadGlobalDictionaryXlsx,
  importGlobalDictionaryXlsx,
  getBackupSettings,
  updateBackupSettings,
  runBackupNow,
  type BackupRunResult,
  type DictionaryEntry,
} from '@/lib/api'
import { useLanguage } from '@/lib/i18n'

export function DictionaryPage() {
  const { t, tWithParams, language } = useLanguage()
  const location = useLocation()
  const [entries, setEntries] = useState<DictionaryEntry[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [pattern, setPattern] = useState('')
  const [replacement, setReplacement] = useState('')
  const [adding, setAdding] = useState(false)
  const [exporting, setExporting] = useState(false)
  const [importing, setImporting] = useState(false)
  const [importResult, setImportResult] = useState<{ added: number; skipped: number; failed: number } | null>(null)
  const [isImportOpen, setIsImportOpen] = useState(false)
  const [selectedFile, setSelectedFile] = useState<File | null>(null)
  const [isDragging, setIsDragging] = useState(false)
  const [deleteTarget, setDeleteTarget] = useState<DictionaryEntry | null>(null)
  const [deleting, setDeleting] = useState(false)
  const importInputRef = useRef<HTMLInputElement | null>(null)
  const [backupEnabled, setBackupEnabled] = useState(false)
  const [backupLastRun, setBackupLastRun] = useState<string | null>(null)
  const [backupUpdating, setBackupUpdating] = useState(false)
  const [runningBackupNow, setRunningBackupNow] = useState(false)
  const [manualBackupResult, setManualBackupResult] = useState<BackupRunResult | null>(null)
  const [manualBackupDismissed, setManualBackupDismissed] = useState(false)

  const fetchDictionary = async () => {
    try {
      setLoading(true)
      const data = await getGlobalDictionary()
      setEntries(data)
      setError(null)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch dictionary')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    if (location.pathname === '/dictionary') {
      fetchDictionary()
    }
  }, [location.pathname])

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

    if (location.pathname === '/dictionary') {
      fetchBackupSettings()
    }
  }, [location.pathname])

  useEffect(() => {
    if (!isImportOpen) {
      return
    }

    const handleWindowDragOver = (event: DragEvent) => {
      event.preventDefault()
      setIsDragging(true)
    }

    const handleWindowDrop = (event: DragEvent) => {
      event.preventDefault()
      setIsDragging(false)
      const file = event.dataTransfer?.files?.[0] ?? null
      handleFileSelect(file)
    }

    const handleWindowDragLeave = () => {
      setIsDragging(false)
    }

    const handleWindowDragEnd = () => {
      setIsDragging(false)
    }

    window.addEventListener('dragover', handleWindowDragOver)
    window.addEventListener('drop', handleWindowDrop)
    window.addEventListener('dragleave', handleWindowDragLeave)
    window.addEventListener('dragend', handleWindowDragEnd)

    return () => {
      window.removeEventListener('dragover', handleWindowDragOver)
      window.removeEventListener('drop', handleWindowDrop)
      window.removeEventListener('dragleave', handleWindowDragLeave)
      window.removeEventListener('dragend', handleWindowDragEnd)
      setIsDragging(false)
    }
  }, [isImportOpen])

  const handleAdd = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    if (!pattern.trim() || !replacement.trim()) return

    try {
      setAdding(true)
      await addGlobalDictionaryEntry(pattern.trim(), replacement.trim())
      setPattern('')
      setReplacement('')
      await fetchDictionary()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to add entry')
    } finally {
      setAdding(false)
    }
  }

  const handleDelete = async () => {
    if (!deleteTarget) return

    try {
      setDeleting(true)
      const targetId = deleteTarget.id
      await deleteGlobalDictionaryEntry(targetId)
      setDeleteTarget(null)
      setEntries((prev) => prev.filter((entry) => entry.id !== targetId))
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to delete entry')
    } finally {
      setDeleting(false)
    }
  }

  const handleExport = async () => {
    try {
      setExporting(true)
      const blob = await downloadGlobalDictionaryXlsx()
      const url = window.URL.createObjectURL(blob)
      const link = document.createElement('a')
      link.href = url
      link.download = 'global_dictionary.xlsx'
      document.body.appendChild(link)
      link.click()
      link.remove()
      window.URL.revokeObjectURL(url)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to export XLSX')
    } finally {
      setExporting(false)
    }
  }

  const handleImport = async () => {
    const file = selectedFile
    if (!file) return
    if (!file.name.toLowerCase().endsWith('.xlsx')) {
      setError(t('dictionary.importInvalid'))
      return
    }

    try {
      setImporting(true)
      setImportResult(null)
      const result = await importGlobalDictionaryXlsx(file)
      setImportResult(result)
      setError(null)
      await fetchDictionary()
      setIsImportOpen(false)
      setSelectedFile(null)
    } catch (err) {
      setError(err instanceof Error ? err.message : t('dictionary.importFailed'))
    } finally {
      setImporting(false)
    }
  }

  const handleRunBackupNow = async () => {
    try {
      setRunningBackupNow(true)
      const result = await runBackupNow()
      setManualBackupResult(result)
      setManualBackupDismissed(false)
      setBackupLastRun(result.created_at)
      setError(null)
    } catch (err) {
      setError(err instanceof Error ? err.message : t('dictionary.backupRunFailed'))
    } finally {
      setRunningBackupNow(false)
    }
  }

  const handleFileSelect = (file: File | null) => {
    if (!file) return
    if (importInputRef.current) {
      importInputRef.current.value = ''
    }
    setSelectedFile(file)
  }

  const formatDate = (dateString: string) => {
    // Ensure the date is parsed as UTC (server returns UTC without timezone suffix)
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
    <div>
      <h2 className="text-2xl font-bold mb-6">{t('dictionary.title')}</h2>

      {error && (
        <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4">
          {error}
        </div>
      )}

      {/* Info card */}
      <Card className="mb-6 bg-blue-50 border-blue-200">
        <CardContent className="pt-6">
          <p className="text-blue-800">
            {t('dictionary.info')}
          </p>
        </CardContent>
      </Card>

      {/* Add new entry */}
      <Card className="mb-6">
        <CardHeader>
          <CardTitle>{t('dictionary.addTitle')}</CardTitle>
          <CardDescription>
            {t('dictionary.addDescription')}
          </CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleAdd} className="space-y-4">
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="pattern">{t('dictionary.pattern')}</Label>
                <Input
                  id="pattern"
                  type="text"
                  placeholder={t('dictionary.patternPlaceholder')}
                  value={pattern}
                  onChange={(e) => setPattern(e.target.value)}
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="replacement">{t('dictionary.replacement')}</Label>
                <Input
                  id="replacement"
                  type="text"
                  placeholder={t('dictionary.replacementPlaceholder')}
                  value={replacement}
                  onChange={(e) => setReplacement(e.target.value)}
                />
              </div>
            </div>
            <Button
              type="submit"
              disabled={adding || !pattern.trim() || !replacement.trim()}
            >
              {adding ? t('dictionary.adding') : t('dictionary.add')}
            </Button>
          </form>
        </CardContent>
      </Card>

      {/* Dictionary table */}
      <Card>
        <CardHeader className="space-y-2">
          <CardTitle>{t('dictionary.listTitle')}</CardTitle>
          <CardDescription>
            {tWithParams('dictionary.entryCount', { count: entries.length })}
          </CardDescription>
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
              onClick={handleRunBackupNow}
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
          <div>
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={handleExport}
              disabled={exporting}
            >
              {t('dictionary.export')}
            </Button>
          </div>
          <div className="flex items-center gap-2">
            <Button
              type="button"
              variant="outline"
              size="sm"
              disabled={importing}
              onClick={() => setIsImportOpen(true)}
            >
              {importing ? t('dictionary.importing') : t('dictionary.import')}
            </Button>
            {importResult && (
              <span className="text-xs text-gray-600">
                {tWithParams('dictionary.importResult', {
                  added: importResult.added,
                  skipped: importResult.skipped,
                  failed: importResult.failed,
                })}
              </span>
            )}
          </div>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>No.</TableHead>
                <TableHead>{t('dictionary.pattern')}</TableHead>
                <TableHead>{t('dictionary.replacement')}</TableHead>
                <TableHead>{t('dictionary.createdAt')}</TableHead>
                <TableHead>{t('dictionary.actions')}</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {entries.map((entry, index) => (
                <TableRow key={entry.id}>
                  <TableCell className="text-gray-500">{index + 1}</TableCell>
                  <TableCell className="font-medium">{entry.pattern}</TableCell>
                  <TableCell>{entry.replacement}</TableCell>
                  <TableCell>{formatDate(entry.created_at)}</TableCell>
                  <TableCell>
                    <Button
                      variant="destructive"
                      size="sm"
                      onClick={() => setDeleteTarget(entry)}
                    >
                      {t('dictionary.delete')}
                    </Button>
                  </TableCell>
                </TableRow>
              ))}
              {entries.length === 0 && (
                <TableRow>
                  <TableCell colSpan={4} className="text-center text-gray-500">
                    {t('dictionary.noEntries')}
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        </CardContent>
      </Card>

      {/* Delete Confirmation Dialog */}
      <Dialog open={!!deleteTarget} onOpenChange={() => setDeleteTarget(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{t('dictionary.deleteTitle')}</DialogTitle>
            <DialogDescription>
              {deleteTarget && tWithParams('dictionary.deleteConfirm', {
                pattern: deleteTarget.pattern,
                replacement: deleteTarget.replacement,
              })}
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setDeleteTarget(null)}>
              {t('common.cancel')}
            </Button>
            <Button
              variant="destructive"
              onClick={handleDelete}
              disabled={deleting}
            >
              {deleting ? t('dictionary.deleting') : t('dictionary.delete')}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog
        open={isImportOpen}
        onOpenChange={(open) => {
          setIsImportOpen(open)
          if (!open) {
            setSelectedFile(null)
            setIsDragging(false)
            if (importInputRef.current) {
              importInputRef.current.value = ''
            }
          }
        }}
      >
        {isImportOpen && (
          <div
            className={`fixed inset-0 z-[70] transition-colors ${
              isDragging ? 'bg-white/60 pointer-events-auto' : 'pointer-events-none'
            }`}
            onDragOver={(event) => {
              event.preventDefault()
              setIsDragging(true)
            }}
            onDragLeave={() => setIsDragging(false)}
            onDrop={(event) => {
              event.preventDefault()
              setIsDragging(false)
              const file = event.dataTransfer.files?.[0] ?? null
              handleFileSelect(file)
            }}
          />
        )}
        <DialogContent>
          <div
            className="space-y-4"
            onDragOver={(event) => {
              event.preventDefault()
              setIsDragging(true)
            }}
            onDragLeave={() => setIsDragging(false)}
            onDrop={(event) => {
              event.preventDefault()
              setIsDragging(false)
              const file = event.dataTransfer.files?.[0] ?? null
              handleFileSelect(file)
            }}
          >
            <DialogHeader>
              <DialogTitle>{t('dictionary.import')}</DialogTitle>
              <DialogDescription>{t('dictionary.importDropHint')}</DialogDescription>
            </DialogHeader>
            <div
              className={`border border-dashed rounded-md p-6 text-center text-sm text-gray-600 transition-colors ${
                isDragging ? 'border-blue-400 bg-blue-50' : ''
              }`}
            >
              {selectedFile ? (
                <div className="flex flex-col items-center gap-2 text-gray-700">
                  <div className="flex h-12 w-12 items-center justify-center rounded-lg bg-gray-100 text-sm font-semibold text-gray-700">
                    XLSX
                  </div>
                  <div className="text-sm font-medium">
                    {tWithParams('dictionary.importFileName', { name: selectedFile.name })}
                  </div>
                </div>
              ) : (
                <>
                  <div className="mb-4">{t('dictionary.importDropHint')}</div>
                  <Button
                    type="button"
                    variant="outline"
                    size="sm"
                    onClick={() => importInputRef.current?.click()}
                  >
                    {t('dictionary.importSelect')}
                  </Button>
                </>
              )}
              <input
                ref={importInputRef}
                type="file"
                accept=".xlsx"
                className="hidden"
                onChange={(e) => handleFileSelect(e.target.files?.[0] ?? null)}
              />
            </div>
            <DialogFooter>
            <Button
              variant="outline"
              onClick={() => {
                setIsImportOpen(false)
                setSelectedFile(null)
                setIsDragging(false)
                if (importInputRef.current) {
                  importInputRef.current.value = ''
                }
              }}
            >
              {t('common.cancel')}
            </Button>
              <Button
                onClick={handleImport}
                disabled={importing || !selectedFile}
              >
                {importing ? t('dictionary.importing') : t('dictionary.importApply')}
              </Button>
            </DialogFooter>
          </div>
        </DialogContent>
      </Dialog>
    </div>
  )
}
