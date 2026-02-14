import { useEffect, useState } from 'react'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
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
import { getUsers, deleteUser, updateUser, getMe, type User } from '@/lib/api'
import { useLanguage } from '@/lib/i18n'

export function UsersPage() {
  const { t, tWithParams, language } = useLanguage()
  const [users, setUsers] = useState<User[]>([])
  const [currentUser, setCurrentUser] = useState<User | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [deleteTarget, setDeleteTarget] = useState<User | null>(null)
  const [deleting, setDeleting] = useState(false)
  const [roleChangeTarget, setRoleChangeTarget] = useState<User | null>(null)
  const [changingRole, setChangingRole] = useState(false)

  const fetchData = async () => {
    try {
      setLoading(true)
      const [usersData, meData] = await Promise.all([getUsers(), getMe()])
      setUsers(usersData)
      setCurrentUser(meData)
      setError(null)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch data')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchData()
  }, [])

  const handleDelete = async () => {
    if (!deleteTarget) return

    try {
      setDeleting(true)
      await deleteUser(deleteTarget.id)
      setDeleteTarget(null)
      await fetchData()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to delete user')
    } finally {
      setDeleting(false)
    }
  }

  const handleRoleChange = async () => {
    if (!roleChangeTarget) return

    try {
      setChangingRole(true)
      await updateUser(roleChangeTarget.id, !roleChangeTarget.is_admin)
      setRoleChangeTarget(null)
      await fetchData()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to change role')
    } finally {
      setChangingRole(false)
    }
  }

  const formatDate = (dateString: string | null) => {
    if (!dateString) return '-'
    // Ensure the date is parsed as UTC (server returns UTC without timezone suffix)
    const utcDate = dateString.endsWith('Z') ? dateString : dateString + 'Z'
    return new Date(utcDate).toLocaleString(language === 'ja' ? 'ja-JP' : 'en-US')
  }

  const getUserDisplayName = (user: User) => {
    return user.github_username || user.github_id
  }

  const isCurrentUser = (user: User) => {
    return currentUser?.id === user.id
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
      <h2 className="text-2xl font-bold mb-6">{t('users.title')}</h2>

      {error && (
        <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4">
          {error}
        </div>
      )}

      <Card>
        <CardHeader>
          <CardTitle>{t('users.listTitle')}</CardTitle>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>{t('users.avatar')}</TableHead>
                <TableHead>{t('users.username')}</TableHead>
                <TableHead>{t('users.role')}</TableHead>
                <TableHead>{t('users.createdAt')}</TableHead>
                <TableHead>{t('users.lastLogin')}</TableHead>
                <TableHead>{t('users.requestRemaining')}</TableHead>
                <TableHead>{t('users.actions')}</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {users.map((user) => (
                <TableRow key={user.id}>
                  <TableCell>
                    {user.github_avatar ? (
                      <img
                        src={user.github_avatar}
                        alt={getUserDisplayName(user)}
                        className="w-8 h-8 rounded-full"
                      />
                    ) : (
                      <div className="w-8 h-8 rounded-full bg-gray-200" />
                    )}
                  </TableCell>
                  <TableCell className="font-medium">
                    {getUserDisplayName(user)}
                    {isCurrentUser(user) && (
                      <span className="ml-2 text-xs text-gray-500">{t('users.you')}</span>
                    )}
                  </TableCell>
                  <TableCell>
                    {user.is_admin ? (
                      <span className="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                        {t('users.admin')}
                      </span>
                    ) : (
                      <span className="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                        {t('users.member')}
                      </span>
                    )}
                  </TableCell>
                  <TableCell>{formatDate(user.created_at)}</TableCell>
                  <TableCell>{formatDate(user.last_login_at)}</TableCell>
                  <TableCell>{user.request_remaining}</TableCell>
                  <TableCell>
                    <div className="flex gap-2">
                      <Button
                        variant={user.is_admin ? 'outline' : 'default'}
                        size="sm"
                        className="w-36"
                        onClick={() => setRoleChangeTarget(user)}
                        disabled={isCurrentUser(user)}
                      >
                        {user.is_admin ? t('users.changeToMember') : t('users.changeToAdmin')}
                      </Button>
                      <Button
                        variant="destructive"
                        size="sm"
                        onClick={() => setDeleteTarget(user)}
                        disabled={user.is_admin}
                      >
                        {t('users.delete')}
                      </Button>
                    </div>
                  </TableCell>
                </TableRow>
              ))}
              {users.length === 0 && (
                <TableRow>
                  <TableCell colSpan={7} className="text-center text-gray-500">
                    {t('users.noUsers')}
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        </CardContent>
      </Card>

      {/* Role Change Confirmation Dialog */}
      <Dialog open={!!roleChangeTarget} onOpenChange={() => setRoleChangeTarget(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{t('users.roleChangeTitle')}</DialogTitle>
            <DialogDescription>
              {roleChangeTarget && (
                roleChangeTarget.is_admin
                  ? tWithParams('users.roleChangeToMember', { name: getUserDisplayName(roleChangeTarget) })
                  : tWithParams('users.roleChangeToAdmin', { name: getUserDisplayName(roleChangeTarget) })
              )}
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setRoleChangeTarget(null)}>
              {t('common.cancel')}
            </Button>
            <Button
              onClick={handleRoleChange}
              disabled={changingRole}
            >
              {changingRole ? t('users.changing') : t('users.change')}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Delete Confirmation Dialog */}
      <Dialog open={!!deleteTarget} onOpenChange={() => setDeleteTarget(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{t('users.deleteTitle')}</DialogTitle>
            <DialogDescription>
              {deleteTarget && tWithParams('users.deleteConfirm', { name: getUserDisplayName(deleteTarget) })}
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
              {deleting ? t('users.deleting') : t('users.delete')}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
