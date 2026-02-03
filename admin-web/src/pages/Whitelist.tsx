import { useEffect, useState } from 'react'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
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
  getWhitelist,
  addToWhitelist,
  removeFromWhitelist,
  searchGitHubUser,
  checkWhitelist,
  type WhitelistEntry,
  type GitHubUser,
} from '@/lib/api'
import { useLanguage } from '@/lib/i18n'

export function WhitelistPage() {
  const { t, language } = useLanguage()

  const [entries, setEntries] = useState<WhitelistEntry[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  // Search state
  const [searchUsername, setSearchUsername] = useState('')
  const [searching, setSearching] = useState(false)
  const [searchResult, setSearchResult] = useState<GitHubUser | null>(null)
  const [isAlreadyRegistered, setIsAlreadyRegistered] = useState(false)

  // Add state
  const [adding, setAdding] = useState(false)

  // Delete state
  const [deleteTarget, setDeleteTarget] = useState<WhitelistEntry | null>(null)
  const [deleting, setDeleting] = useState(false)

  const fetchWhitelist = async () => {
    try {
      setLoading(true)
      const data = await getWhitelist()
      setEntries(data)
      setError(null)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch whitelist')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchWhitelist()
  }, [])

  const handleSearch = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    if (!searchUsername.trim()) return

    try {
      setSearching(true)
      setError(null)
      setSearchResult(null)
      setIsAlreadyRegistered(false)

      // Search GitHub user
      const user = await searchGitHubUser(searchUsername.trim())
      setSearchResult(user)

      // Check if already in whitelist
      const { exists } = await checkWhitelist(user.id)
      setIsAlreadyRegistered(exists)
    } catch (err) {
      if (err instanceof Error) {
        if (err.message.includes('not found')) {
          setError(t('whitelist.notFound'))
        } else if (err.message.includes('rate limit')) {
          setError(t('whitelist.rateLimitExceeded'))
        } else {
          setError(err.message)
        }
      }
      setSearchResult(null)
    } finally {
      setSearching(false)
    }
  }

  const handleAdd = async () => {
    if (!searchResult) return

    try {
      setAdding(true)
      setError(null)
      await addToWhitelist(searchResult.id)
      setSearchResult(null)
      setSearchUsername('')
      await fetchWhitelist()
    } catch (err) {
      if (err instanceof Error) {
        setError(err.message)
      }
    } finally {
      setAdding(false)
    }
  }

  const handleDelete = async () => {
    if (!deleteTarget) return

    try {
      setDeleting(true)
      setError(null)
      await removeFromWhitelist(deleteTarget.id)
      setDeleteTarget(null)
      await fetchWhitelist()
    } catch (err) {
      if (err instanceof Error) {
        if (err.message.includes('Cannot remove yourself')) {
          setError(t('whitelist.cannotDeleteSelf'))
        } else {
          setError(err.message)
        }
      }
    } finally {
      setDeleting(false)
    }
  }

  const clearSearch = () => {
    setSearchResult(null)
    setSearchUsername('')
    setIsAlreadyRegistered(false)
    setError(null)
  }

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleString(language === 'ja' ? 'ja-JP' : 'en-US')
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
      <h2 className="text-2xl font-bold mb-6">{t('whitelist.title')}</h2>

      {error && (
        <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4 flex justify-between items-center">
          <span>{error}</span>
          <button onClick={() => setError(null)} className="text-red-700 hover:text-red-900">
            ×
          </button>
        </div>
      )}

      {/* Search and Add */}
      <Card className="mb-6">
        <CardHeader>
          <CardTitle>{t('whitelist.add')}</CardTitle>
          <CardDescription>
            {t('whitelist.searchPlaceholder')}
          </CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSearch} className="flex gap-4 mb-4">
            <Input
              type="text"
              placeholder={t('whitelist.searchPlaceholder')}
              value={searchUsername}
              onChange={(e) => setSearchUsername(e.target.value)}
              className="max-w-xs"
            />
            <Button type="submit" disabled={searching || !searchUsername.trim()}>
              {searching ? t('whitelist.searching') : t('whitelist.search')}
            </Button>
            {searchResult && (
              <Button type="button" variant="outline" onClick={clearSearch}>
                {t('common.cancel')}
              </Button>
            )}
          </form>

          {/* Search Result */}
          {searchResult && (
            <div className="border rounded-lg p-4 bg-gray-50">
              <div className="flex items-center gap-4">
                <img
                  src={searchResult.avatar_url}
                  alt={searchResult.login}
                  className="w-16 h-16 rounded-full"
                />
                <div className="flex-1">
                  <div className="font-bold text-lg">@{searchResult.login}</div>
                  <div className="text-sm text-gray-500">ID: {searchResult.id}</div>
                  <a
                    href={searchResult.html_url}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-sm text-blue-600 hover:underline"
                  >
                    {searchResult.html_url}
                  </a>
                </div>
                <div>
                  {isAlreadyRegistered ? (
                    <span className="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-yellow-100 text-yellow-800">
                      {t('whitelist.alreadyExists')}
                    </span>
                  ) : (
                    <Button onClick={handleAdd} disabled={adding}>
                      {adding ? t('common.loading') : t('whitelist.add')}
                    </Button>
                  )}
                </div>
              </div>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Whitelist table */}
      <Card>
        <CardHeader>
          <CardTitle>
            {language === 'ja'
              ? `ホワイトリスト一覧 (${entries.length}件)`
              : `Whitelist (${entries.length} entries)`}
          </CardTitle>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>{t('whitelist.githubId')}</TableHead>
                <TableHead>{t('whitelist.createdAt')}</TableHead>
                <TableHead>{t('whitelist.actions')}</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {entries.map((entry) => (
                <TableRow key={entry.id}>
                  <TableCell className="font-medium">{entry.github_id}</TableCell>
                  <TableCell>{formatDate(entry.created_at)}</TableCell>
                  <TableCell>
                    <Button
                      variant="destructive"
                      size="sm"
                      onClick={() => setDeleteTarget(entry)}
                    >
                      {t('whitelist.delete')}
                    </Button>
                  </TableCell>
                </TableRow>
              ))}
              {entries.length === 0 && (
                <TableRow>
                  <TableCell colSpan={3} className="text-center text-gray-500">
                    {t('whitelist.noEntries')}
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
            <DialogTitle>{t('whitelist.delete')}</DialogTitle>
            <DialogDescription>
              {t('whitelist.confirmDelete')}
              <br />
              <span className="font-medium">{deleteTarget?.github_id}</span>
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
              {deleting ? t('common.loading') : t('whitelist.delete')}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
