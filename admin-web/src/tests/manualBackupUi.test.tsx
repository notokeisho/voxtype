import { beforeEach, describe, expect, it, vi } from 'vitest'
import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'

import { DictionaryPage } from '@/pages/Dictionary'

const mockedApi = vi.hoisted(() => ({
  getGlobalDictionary: vi.fn(),
  downloadGlobalDictionaryXlsx: vi.fn(),
}))

vi.mock('@/lib/api', () => ({
  getGlobalDictionary: mockedApi.getGlobalDictionary,
  addGlobalDictionaryEntry: vi.fn(),
  deleteGlobalDictionaryEntry: vi.fn(),
  downloadGlobalDictionaryXlsx: mockedApi.downloadGlobalDictionaryXlsx,
  importGlobalDictionaryXlsx: vi.fn(),
}))

vi.mock('@/lib/i18n', () => ({
  useLanguage: () => ({
    language: 'ja',
    t: (key: string) => key,
    tWithParams: (key: string) => key,
  }),
}))

describe('DictionaryPage export UI', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    mockedApi.getGlobalDictionary.mockResolvedValue([])
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

  it('shows dictionary export button', async () => {
    render(
      <MemoryRouter initialEntries={['/dictionary']}>
        <DictionaryPage />
      </MemoryRouter>
    )

    expect(await screen.findByText('dictionary.title')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'dictionary.export' })).toBeInTheDocument()
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
