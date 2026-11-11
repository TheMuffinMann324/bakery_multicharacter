import { useEffect, useRef } from 'react'
import { mockNui } from './mock'

declare global {
  interface Window {
    GetParentResourceName?: () => string
  }
}

export const isNui = typeof window !== 'undefined' && typeof window.GetParentResourceName === 'function'
const resource = isNui ? window.GetParentResourceName!() : 'bakery_multicharacter'

// Client NUI callback (client/main.lua). timeoutMs = 0 waits forever.
export async function nui<T = unknown>(event: string, data?: unknown, timeoutMs = 30000): Promise<T> {
  if (!isNui) return mockNui(event, data) as Promise<T>
  const controller = new AbortController()
  const timer = timeoutMs > 0 ? window.setTimeout(() => controller.abort(), timeoutMs) : 0
  try {
    const res = await fetch(`https://${resource}/${event}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data ?? {}),
      signal: controller.signal,
    })
    return (await res.json()) as T
  } catch {
    return { ok: false, error: 'No response.' } as T
  } finally {
    if (timer) window.clearTimeout(timer)
  }
}

type Handler = (data: any) => void
const handlers = new Map<string, Set<Handler>>()

if (typeof window !== 'undefined') {
  window.addEventListener('message', (event) => {
    const { action, data } = event.data ?? {}
    if (!action) return
    handlers.get(action)?.forEach((h) => h(data))
  })
}

export function useNuiEvent<T = any>(action: string, handler: (data: T) => void) {
  const saved = useRef(handler)
  saved.current = handler
  useEffect(() => {
    const fn: Handler = (d) => saved.current(d)
    if (!handlers.has(action)) handlers.set(action, new Set())
    handlers.get(action)!.add(fn)
    return () => {
      handlers.get(action)?.delete(fn)
    }
  }, [action])
}
