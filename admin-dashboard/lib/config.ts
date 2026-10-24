/**
 * Browser-visible API origin. NEXT_PUBLIC_* values are inlined into the bundle at
 * build time (set NEXT_PUBLIC_API_URL as a Docker build arg); changing the
 * environment variable on a running container has no effect. proxy.ts reads the
 * same constant for the CSP connect-src, so the two cannot drift apart.
 */
export const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000'
