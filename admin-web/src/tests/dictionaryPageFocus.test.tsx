import { describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'

import { DictionaryPage } from '@/pages/Dictionary'

vi.mock('@/lib/api', () => ({
  getGlobalDictionary: vi.fn().mockResolvedValue([]),
  addGlobalDictionaryEntry: vi.fn(),
  deleteGlobalDictionaryEntry: vi.fn(),
  downloadGlobalDictionaryXlsx: vi.fn(),
  importGlobalDictionaryXlsx: vi.fn(),
}))

vi.mock('@/lib/i18n', () => ({
  useLanguage: () => ({
    language: 'ja',
    t: (key: string) => key,
    tWithParams: (key: string) => key,
  }),
}))

describe('DictionaryPage focus', () => {
  it('does not show backup controls', async () => {
    render(
      <MemoryRouter initialEntries={['/dictionary']}>
        <DictionaryPage />
      </MemoryRouter>
    )

    expect(await screen.findByText('dictionary.title')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'dictionary.backupRunNow' })).not.toBeInTheDocument()
    expect(screen.queryByRole('switch')).not.toBeInTheDocument()
  })
})
