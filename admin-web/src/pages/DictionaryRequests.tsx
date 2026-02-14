import { useLanguage } from '@/lib/i18n'

export function DictionaryRequestsPage() {
  const { t } = useLanguage()

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-gray-900">{t('nav.dictionaryRequests')}</h2>
        <p className="text-sm text-gray-600">
          {t('common.loading')}
        </p>
      </div>
    </div>
  )
}
