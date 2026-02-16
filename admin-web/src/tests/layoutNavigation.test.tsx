import { describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'

import { Layout } from '@/components/Layout'

vi.mock('@/lib/api', () => ({
  getDictionaryRequests: vi.fn().mockResolvedValue({ entries: [], count: 0 }),
  removeToken: vi.fn(),
}))

vi.mock('@/lib/i18n', () => ({
  useLanguage: () => ({
    t: (key: string) => key,
  }),
  LanguageSwitcher: () => <div>lang</div>,
}))

describe('Layout navigation', () => {
  it('shows backup nav item and marks it active on /backup', async () => {
    render(
      <MemoryRouter initialEntries={['/backup']}>
        <Layout
          user={{
            id: 1,
            github_id: '1',
            github_username: 'admin',
            github_avatar: null,
            is_admin: true,
            created_at: '2026-01-01T00:00:00',
            last_login_at: null,
            request_remaining: 200,
          }}
        >
          <div>content</div>
        </Layout>
      </MemoryRouter>
    )

    const backupLink = await screen.findByRole('link', { name: /nav\.backup/ })
    expect(backupLink).toBeInTheDocument()
    expect(backupLink).toHaveClass('bg-gray-100')
  })
})
