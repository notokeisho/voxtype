const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:8000'

// Token management
const TOKEN_KEY = 'admin_token'

export function getToken(): string | null {
  return localStorage.getItem(TOKEN_KEY)
}

export function setToken(token: string): void {
  localStorage.setItem(TOKEN_KEY, token)
}

export function removeToken(): void {
  localStorage.removeItem(TOKEN_KEY)
}

export function isAuthenticated(): boolean {
  return getToken() !== null
}

// API fetch wrapper
async function apiFetch<T>(
  endpoint: string,
  options: RequestInit = {}
): Promise<T> {
  const token = getToken()

  const headers: HeadersInit = {
    'Content-Type': 'application/json',
    ...options.headers,
  }

  if (token) {
    (headers as Record<string, string>)['Authorization'] = `Bearer ${token}`
  }

  const response = await fetch(`${API_BASE_URL}${endpoint}`, {
    ...options,
    headers,
  })

  if (response.status === 401) {
    removeToken()
    window.location.href = '/login'
    throw new Error('Unauthorized')
  }

  if (!response.ok) {
    const error = await response.json().catch(() => ({ detail: 'Unknown error' }))
    throw new Error(error.detail || `HTTP ${response.status}`)
  }

  // 204 No Content has no body
  if (response.status === 204) {
    return undefined as T
  }

  return response.json()
}

// Auth API
export function getLoginUrl(): string {
  const redirectUri = encodeURIComponent(`${window.location.origin}/auth/callback`)
  return `${API_BASE_URL}/auth/login?redirect_uri=${redirectUri}`
}

export async function getMe(): Promise<User> {
  return apiFetch<User>('/api/me')
}

// Users API (admin)
export async function getUsers(): Promise<User[]> {
  return apiFetch<User[]>('/admin/api/users')
}

export async function deleteUser(userId: number): Promise<void> {
  await apiFetch(`/admin/api/users/${userId}`, { method: 'DELETE' })
}

export async function updateUser(userId: number, isAdmin: boolean): Promise<User> {
  return apiFetch<User>(`/admin/api/users/${userId}`, {
    method: 'PATCH',
    body: JSON.stringify({ is_admin: isAdmin }),
  })
}

// Whitelist API (admin)
export async function getWhitelist(): Promise<WhitelistEntry[]> {
  return apiFetch<WhitelistEntry[]>('/admin/api/whitelist')
}

export async function addToWhitelist(
  githubId: string,
  githubUsername: string
): Promise<WhitelistEntry> {
  return apiFetch<WhitelistEntry>('/admin/api/whitelist', {
    method: 'POST',
    body: JSON.stringify({ github_id: githubId, github_username: githubUsername }),
  })
}

export async function removeFromWhitelist(id: number): Promise<void> {
  await apiFetch(`/admin/api/whitelist/${id}`, { method: 'DELETE' })
}

export async function searchGitHubUser(username: string): Promise<GitHubUser> {
  return apiFetch<GitHubUser>(`/admin/api/github/user/${encodeURIComponent(username)}`)
}

export async function checkWhitelist(githubId: string): Promise<{ exists: boolean }> {
  return apiFetch<{ exists: boolean }>(`/admin/api/whitelist/check/${encodeURIComponent(githubId)}`)
}

// Global Dictionary API (admin)
export async function getGlobalDictionary(): Promise<DictionaryEntry[]> {
  return apiFetch<DictionaryEntry[]>('/admin/api/dictionary')
}

export async function addGlobalDictionaryEntry(
  pattern: string,
  replacement: string
): Promise<DictionaryEntry> {
  return apiFetch<DictionaryEntry>('/admin/api/dictionary', {
    method: 'POST',
    body: JSON.stringify({ pattern, replacement }),
  })
}

export async function deleteGlobalDictionaryEntry(id: number): Promise<void> {
  await apiFetch(`/admin/api/dictionary/${id}`, { method: 'DELETE' })
}

export async function downloadGlobalDictionaryCsv(): Promise<Blob> {
  const token = getToken()
  const response = await fetch(`${API_BASE_URL}/admin/api/dictionary/export`, {
    headers: token ? { Authorization: `Bearer ${token}` } : undefined,
  })

  if (response.status === 401) {
    removeToken()
    window.location.href = '/login'
    throw new Error('Unauthorized')
  }

  if (!response.ok) {
    throw new Error(`HTTP ${response.status}`)
  }

  return response.blob()
}

// Dictionary Requests API (admin)
export async function getDictionaryRequests(): Promise<DictionaryRequestList> {
  return apiFetch<DictionaryRequestList>('/admin/api/dictionary-requests')
}

export async function approveDictionaryRequest(requestId: number): Promise<DictionaryRequest> {
  return apiFetch<DictionaryRequest>(`/admin/api/dictionary-requests/${requestId}/approve`, {
    method: 'POST',
  })
}

export async function rejectDictionaryRequest(requestId: number): Promise<DictionaryRequest> {
  return apiFetch<DictionaryRequest>(`/admin/api/dictionary-requests/${requestId}/reject`, {
    method: 'POST',
  })
}

export async function deleteDictionaryRequest(requestId: number): Promise<void> {
  await apiFetch(`/admin/api/dictionary-requests/${requestId}`, { method: 'DELETE' })
}

// Status API
export async function getStatus(): Promise<StatusResponse> {
  return apiFetch<StatusResponse>('/api/status')
}

// Types
export interface User {
  id: number
  github_id: string
  github_username: string | null
  github_avatar: string | null
  is_admin: boolean
  created_at: string
  last_login_at: string | null
}

export interface WhitelistEntry {
  id: number
  github_id: string
  github_username: string | null
  created_at: string
  created_by: number | null
}

export interface GitHubUser {
  id: string
  login: string
  avatar_url: string
  html_url: string
}

export interface DictionaryEntry {
  id: number
  pattern: string
  replacement: string
  created_at: string
  created_by: number | null
}

export interface DictionaryRequest {
  id: number
  user_id: number
  user_name?: string | null
  user_github_id?: string | null
  pattern: string
  replacement: string
  status: string
  created_at: string
  conflict_entry_id?: number | null
  conflict_replacement?: string | null
}

export interface DictionaryRequestList {
  entries: DictionaryRequest[]
  count: number
}

export interface StatusResponse {
  status: string
  whisper_fast: string
  whisper_smart: string
  whisper_overall: string
  database: string
}
