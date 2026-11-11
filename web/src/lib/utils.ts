import { clsx, type ClassValue } from 'clsx'
import { twMerge } from 'tailwind-merge'

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

/** The slots standing in the line-up (same as client/scene.lua): every character, then the first free slot. */
export function shownSlots(characters: { slot: number }[], slots: number) {
  const used = new Set(characters.map((c) => c.slot))
  const out = [...used].filter((s) => s >= 1 && s <= slots).sort((a, b) => a - b)
  for (let s = 1; s <= slots; s++) {
    if (!used.has(s)) {
      out.push(s)
      break
    }
  }
  return out
}

export function money(n: number) {
  return '$' + Math.round(n).toLocaleString('en-US')
}

/** 3 -> "03" */
export function pad(n: number) {
  return n.toString().padStart(2, '0')
}

export function ago(unix: number, nowUnix: number) {
  const d = Math.max(0, nowUnix - unix)
  if (d < 120) return 'just now'
  if (d < 3600) return `${Math.floor(d / 60)} min ago`
  if (d < 86400) {
    const h = Math.floor(d / 3600)
    return `${h} hour${h === 1 ? '' : 's'} ago`
  }
  const days = Math.floor(d / 86400)
  return `${days} day${days === 1 ? '' : 's'} ago`
}

/** Whole years between a date and now. */
export function ageOn(y: number, m: number, d: number, nowUnix: number) {
  const now = new Date(nowUnix * 1000)
  let age = now.getFullYear() - y
  if (now.getMonth() + 1 < m || (now.getMonth() + 1 === m && now.getDate() < d)) age -= 1
  return age
}

/** "2003-11-20" -> { y, m, d } */
export function parseDob(iso?: string) {
  const match = iso?.match(/^(\d{4})-(\d{2})-(\d{2})$/)
  if (!match) return null
  return { y: Number(match[1]), m: Number(match[2]), d: Number(match[3]) }
}

/** Is this a day that exists (no 31 April)? */
export function realDate(y: number, m: number, d: number) {
  const date = new Date(y, m - 1, d)
  return date.getFullYear() === y && date.getMonth() === m - 1 && date.getDate() === d
}

/** Small stable hash, used to draw the same barcode for the same id every time. */
export function hash(text: string) {
  let h = 2166136261
  for (let i = 0; i < text.length; i++) {
    h ^= text.charCodeAt(i)
    h = Math.imul(h, 16777619)
  }
  return h >>> 0
}
