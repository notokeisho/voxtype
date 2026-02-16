import { beforeEach, describe, expect, it, vi } from 'vitest'
import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'

import { BackupPage } from '@/pages/Backup'

const mockedApi = vi.hoisted(() => ({
  getBackupSettings: vi.fn(),
  getBackupFiles: vi.fn(),
  runBackupNow: vi.fn(),
  restoreBackupFile: vi.fn(),
  updateBackupSettings: vi.fn(),
  downloadBackupFile: vi.fn(),
}))

vi.mock('@/lib/api', () => ({
  getBackupSettings: mockedApi.getBackupSettings,
  getBackupFiles: mockedApi.getBackupFiles,
  runBackupNow: mockedApi.runBackupNow,
  restoreBackupFile: mockedApi.restoreBackupFile,
  updateBackupSettings: mockedApi.updateBackupSettings,
  downloadBackupFile: mockedApi.downloadBackupFile,
}))

vi.mock('@/lib/i18n', () => ({
  useLanguage: () => ({
    language: 'ja',
    t: (key: string) => key,
    tWithParams: (key: string) => key,
  }),
}))

describe('BackupPage UI', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    mockedApi.getBackupSettings.mockResolvedValue({ enabled: true, last_run_at: '2026-02-16T03:00:00' })
    mockedApi.getBackupFiles.mockResolvedValue({
      files: [
        {
          filename: 'global_dictionary_2026-02-16_03-00-00.xlsx',
          created_at: '2026-02-16T03:00:00',
          size_bytes: 1024,
        },
      ],
    })
    mockedApi.runBackupNow.mockResolvedValue({
      created_file: 'global_dictionary_2026-02-16_12-30-45.xlsx',
      created_at: '2026-02-16T12:30:45',
      kept: 3,
      deleted: 0,
    })
    mockedApi.restoreBackupFile.mockResolvedValue({
      restored_file: 'global_dictionary_2026-02-16_03-00-00.xlsx',
      mode: 'merge',
      total: 1,
      added: 1,
      skipped: 0,
      failed: 0,
      restored_at: '2026-02-16T03:10:00',
    })
    mockedApi.updateBackupSettings.mockResolvedValue({ enabled: false, last_run_at: '2026-02-16T03:00:00' })
    mockedApi.downloadBackupFile.mockResolvedValue(new Blob(['backup']))

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

  it('shows backup controls and files list', async () => {
    render(
      <MemoryRouter initialEntries={['/backup']}>
        <BackupPage />
      </MemoryRouter>
    )

    expect(await screen.findByText('backup.title')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'dictionary.backupRunNow' })).toBeInTheDocument()
    expect(screen.getByText('global_dictionary_2026-02-16_03-00-00.xlsx')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'backup.download' })).toBeInTheDocument()
  })

  it('requires second confirmation for replace mode', async () => {
    render(
      <MemoryRouter initialEntries={['/backup']}>
        <BackupPage />
      </MemoryRouter>
    )

    const restoreButton = await screen.findByRole('button', { name: 'dictionary.backupRestore' })
    fireEvent.click(restoreButton)
    fireEvent.click(screen.getByRole('radio', { name: 'dictionary.restoreModeReplace' }))
    fireEvent.click(screen.getByRole('button', { name: 'dictionary.restoreConfirmRun' }))

    expect(await screen.findByText('dictionary.restoreReplaceFinalConfirm')).toBeInTheDocument()
    fireEvent.click(screen.getByRole('button', { name: 'dictionary.restoreReplaceRun' }))

    await waitFor(() => expect(mockedApi.restoreBackupFile).toHaveBeenCalledTimes(1))
  })

  it('downloads backup file from list', async () => {
    const createObjectURLSpy = vi.spyOn(URL, 'createObjectURL').mockReturnValue('blob:mock-url')
    const revokeObjectURLSpy = vi.spyOn(URL, 'revokeObjectURL').mockImplementation(() => {})
    const appendSpy = vi.spyOn(document.body, 'appendChild')
    const clickSpy = vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(() => {})
    const removeSpy = vi.spyOn(HTMLElement.prototype, 'remove').mockImplementation(() => {})

    render(
      <MemoryRouter initialEntries={['/backup']}>
        <BackupPage />
      </MemoryRouter>
    )

    const downloadButton = await screen.findByRole('button', { name: 'backup.download' })
    fireEvent.click(downloadButton)

    await waitFor(() =>
      expect(mockedApi.downloadBackupFile).toHaveBeenCalledWith(
        'global_dictionary_2026-02-16_03-00-00.xlsx'
      )
    )

    createObjectURLSpy.mockRestore()
    revokeObjectURLSpy.mockRestore()
    appendSpy.mockRestore()
    clickSpy.mockRestore()
    removeSpy.mockRestore()
  })
})
