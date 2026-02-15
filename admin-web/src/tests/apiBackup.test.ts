import { beforeEach, describe, expect, it, vi } from 'vitest'

import { runBackupNow, setToken } from '@/lib/api'

describe('runBackupNow', () => {
  beforeEach(() => {
    localStorage.clear()
    vi.restoreAllMocks()
  })

  it('returns backup run response with admin token', async () => {
    setToken('dummy-token')
    const fetchMock = vi.fn().mockResolvedValue({
      status: 200,
      ok: true,
      json: async () => ({
        created_file: 'global_dictionary_2026-02-16_12-30-45.xlsx',
        created_at: '2026-02-16T12:30:45',
        kept: 3,
        deleted: 1,
      }),
    })
    vi.stubGlobal('fetch', fetchMock)

    const result = await runBackupNow()

    expect(result.created_file).toBe('global_dictionary_2026-02-16_12-30-45.xlsx')
    expect(result.created_at).toBe('2026-02-16T12:30:45')
    expect(result.kept).toBe(3)
    expect(result.deleted).toBe(1)
    expect(fetchMock).toHaveBeenCalledWith(
      'http://localhost:8000/admin/api/dictionary/backup/run',
      expect.objectContaining({
        method: 'POST',
        headers: expect.objectContaining({
          Authorization: 'Bearer dummy-token',
          'Content-Type': 'application/json',
        }),
      })
    )
  })
})

