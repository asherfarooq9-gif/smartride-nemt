import { api, clearToken } from '@/lib/api'

/** Ends the session. AppShell sees the token disappear and navigates to /login. */
export async function signOut(): Promise<void> {
  try {
    await api.logout()
  } catch {
    // Intentional: sign-out is best effort. If the server cannot revoke the token
    // (offline, already expired) the user must still be signed out locally.
  }
  clearToken()
}
