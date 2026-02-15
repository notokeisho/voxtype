import { beforeEach, describe, expect, it, vi } from 'vitest'
import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'

import { DictionaryPage } from '@/pages/Dictionary'

const mockedApi = vi.hoisted(() => ({
  getGlobalDictionary: vi.fn(),
  getBackupSettings: vi.fn(),
  runBackupNow: vi.fn(),
}))

vi.mock('@/lib/api', () => ({
  getGlobalDictionary: mockedApi.getGlobalDictionary,
  addGlobalDictionaryEntry: vi.fn(),
  deleteGlobalDictionaryEntry: vi.fn(),
  downloadGlobalDictionaryXlsx: vi.fn(),
  importGlobalDictionaryXlsx: vi.fn(),
  getBackupSettings: mockedApi.getBackupSettings,
  updateBackupSettings: vi.fn(),
  runBackupNow: mockedApi.runBackupNow,
}))

vi.mock('@/lib/i18n', () => ({
  useLanguage: () => ({
    language: 'ja',
    t: (key: string) => key,
    tWithParams: (key: string) => key,
  }),
}))

describe('DictionaryPage manual backup UI', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    mockedApi.getGlobalDictionary.mockResolvedValue([])
    mockedApi.getBackupSettings.mockResolvedValue({ enabled: false, last_run_at: null })
  })

  it('shows manual backup run button', async () => {
    render(
      <MemoryRouter initialEntries={['/dictionary']}>
        <DictionaryPage />
      </MemoryRouter>
    )

    expect(await screen.findByText('dictionary.title')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'dictionary.backupRunNow' })).toBeInTheDocument()
  })

  it('disables manual backup run button while running', async () => {
    mockedApi.runBackupNow.mockImplementation(
      () => new Promise((resolve) => setTimeout(() => resolve({
        created_file: 'global_dictionary_2026-02-16_12-30-45.xlsx',
        created_at: '2026-02-16T12:30:45',
        kept: 3,
        deleted: 0,
      }), 50))
    )

    render(
      <MemoryRouter initialEntries={['/dictionary']}>
        <DictionaryPage />
      </MemoryRouter>
    )

    const button = await screen.findByRole('button', { name: 'dictionary.backupRunNow' })
    fireEvent.click(button)
    expect(button).toBeDisabled()
    await waitFor(() => expect(button).not.toBeDisabled())
  })

  it('shows error when manual backup run fails', async () => {
    mockedApi.runBackupNow.mockRejectedValue(new Error('manual backup failed'))

    render(
      <MemoryRouter initialEntries={['/dictionary']}>
        <DictionaryPage />
      </MemoryRouter>
    )

    const button = await screen.findByRole('button', { name: 'dictionary.backupRunNow' })
    fireEvent.click(button)

    expect(await screen.findByText('manual backup failed')).toBeInTheDocument()
  })
})
