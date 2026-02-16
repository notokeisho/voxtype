import { useLanguage } from '@/lib/i18n'

export function BackupPage() {
  const { t } = useLanguage()

  return (
    <div>
      <h2 className="text-2xl font-bold mb-6">{t('backup.title')}</h2>
    </div>
  )
}
