import { useEffect, useState } from 'react'
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
  const [deleteTarget, setDeleteTarget] = useState<DictionaryEntry | null>(null)
  const [deleting, setDeleting] = useState(false)

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
      await deleteGlobalDictionaryEntry(deleteTarget.id)
      setDeleteTarget(null)
      await fetchDictionary()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to delete entry')
    } finally {
      setDeleting(false)
    }
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
        <CardHeader>
          <CardTitle>{t('dictionary.listTitle')}</CardTitle>
          <CardDescription>
            {tWithParams('dictionary.entryCount', { count: entries.length })}
          </CardDescription>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>{t('dictionary.pattern')}</TableHead>
                <TableHead>{t('dictionary.replacement')}</TableHead>
                <TableHead>{t('dictionary.createdAt')}</TableHead>
                <TableHead>{t('dictionary.actions')}</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {entries.map((entry) => (
                <TableRow key={entry.id}>
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
    </div>
  )
}
