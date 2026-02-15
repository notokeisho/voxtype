import { beforeEach, describe, expect, it, vi } from 'vitest'
import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'

import { DictionaryPage } from '@/pages/Dictionary'

const mockedApi = vi.hoisted(() => ({
  getGlobalDictionary: vi.fn(),
  getBackupSettings: vi.fn(),
  runBackupNow: vi.fn(),
  downloadGlobalDictionaryXlsx: vi.fn(),
}))

vi.mock('@/lib/api', () => ({
  getGlobalDictionary: mockedApi.getGlobalDictionary,
  addGlobalDictionaryEntry: vi.fn(),
  deleteGlobalDictionaryEntry: vi.fn(),
  downloadGlobalDictionaryXlsx: mockedApi.downloadGlobalDictionaryXlsx,
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
    mockedApi.downloadGlobalDictionaryXlsx.mockResolvedValue(new Blob(['test']))
    if (!URL.createObjectURL) {
      Object.defineProperty(URL, 'createObjectURL', {
        value: vi.fn(() => 'blob:mock-url'),
        writable: true,
      })
    }
    if (!URL.revokeObjectURL) {
      Object.defineProperty(URL, 'revokeObjectURL', {
        value: vi.fn(),
        writable: true,
      })
    }
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

    const openButton = await screen.findByRole('button', { name: 'dictionary.backupRunNow' })
    fireEvent.click(openButton)
    const confirmButton = await screen.findByRole('button', { name: 'dictionary.backupConfirmRun' })
    fireEvent.click(confirmButton)
    expect(confirmButton).toBeDisabled()
    await waitFor(() => expect(screen.queryByRole('button', { name: 'dictionary.backupConfirmRun' })).not.toBeInTheDocument())
  })

  it('shows error when manual backup run fails', async () => {
    mockedApi.runBackupNow.mockRejectedValue(new Error('manual backup failed'))

    render(
      <MemoryRouter initialEntries={['/dictionary']}>
        <DictionaryPage />
      </MemoryRouter>
    )

    const openButton = await screen.findByRole('button', { name: 'dictionary.backupRunNow' })
    fireEvent.click(openButton)
    const confirmButton = await screen.findByRole('button', { name: 'dictionary.backupConfirmRun' })
    fireEvent.click(confirmButton)

    expect(await screen.findByText('manual backup failed')).toBeInTheDocument()
  })

  it('runs manual backup only after confirmation', async () => {
    mockedApi.runBackupNow.mockResolvedValue({
      created_file: 'global_dictionary_2026-02-16_12-30-45.xlsx',
      created_at: '2026-02-16T12:30:45',
      kept: 3,
      deleted: 0,
    })

    render(
      <MemoryRouter initialEntries={['/dictionary']}>
        <DictionaryPage />
      </MemoryRouter>
    )

    const openButton = await screen.findByRole('button', { name: 'dictionary.backupRunNow' })
    fireEvent.click(openButton)
    expect(mockedApi.runBackupNow).not.toHaveBeenCalled()

    const confirmButton = await screen.findByRole('button', { name: 'dictionary.backupConfirmRun' })
    fireEvent.click(confirmButton)

    await waitFor(() => expect(mockedApi.runBackupNow).toHaveBeenCalledTimes(1))
  })

  it('runs export only after confirmation', async () => {
    const createObjectURLSpy = vi.spyOn(URL, 'createObjectURL').mockReturnValue('blob:mock-url')
    const revokeObjectURLSpy = vi.spyOn(URL, 'revokeObjectURL').mockImplementation(() => {})
    const appendSpy = vi.spyOn(document.body, 'appendChild')
    const clickSpy = vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(() => {})
    const removeSpy = vi.spyOn(HTMLElement.prototype, 'remove').mockImplementation(() => {})

    render(
      <MemoryRouter initialEntries={['/dictionary']}>
        <DictionaryPage />
      </MemoryRouter>
    )

    const openButton = await screen.findByRole('button', { name: 'dictionary.export' })
    fireEvent.click(openButton)
    expect(mockedApi.downloadGlobalDictionaryXlsx).not.toHaveBeenCalled()

    const confirmButton = await screen.findByRole('button', { name: 'dictionary.exportConfirmRun' })
    fireEvent.click(confirmButton)

    await waitFor(() => expect(mockedApi.downloadGlobalDictionaryXlsx).toHaveBeenCalledTimes(1))

    createObjectURLSpy.mockRestore()
    revokeObjectURLSpy.mockRestore()
    appendSpy.mockRestore()
    clickSpy.mockRestore()
    removeSpy.mockRestore()
  })
})
