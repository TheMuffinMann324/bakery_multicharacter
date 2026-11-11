import { useId, useState, useSyncExternalStore, type ReactNode } from 'react'
import { cn } from '@/lib/utils'

// The Bakery B-snap mark (same as bakery_racing).
const B_PATH =
  'M155 118 L274 118 C327 118 353 146 353 188 C353 214 340 234 321 243 C352 253 370 277 370 312 C370 359 336 390 279 390 L155 390Z M216 171 L268 171 C288 171 299 181 299 197 C299 214 288 224 268 224 L216 224Z M216 278 L277 278 C300 278 313 288 313 307 C313 327 300 338 277 338 L216 338Z'

// The server's own logo (Config.Logo), set once the game tells the UI about it. Every Logo uses it.
let customLogo: string | null = null
const logoListeners = new Set<() => void>()
export function setCustomLogo(url?: string | null) {
  const next = url || null
  if (next === customLogo) return
  customLogo = next
  logoListeners.forEach((fn) => fn())
}
const subscribeLogo = (fn: () => void) => {
  logoListeners.add(fn)
  return () => { logoListeners.delete(fn) }
}

export function Logo({ className, still, color = '#f6f6f5' }: { className?: string; still?: boolean; color?: string }) {
  const id = useId().replace(/:/g, '')
  const custom = useSyncExternalStore(subscribeLogo, () => customLogo)
  const [broken, setBroken] = useState<string | null>(null)
  if (custom && custom !== broken) {
    // same height as the default mark; wide logos keep their shape
    return (
      <img
        src={custom}
        alt=""
        draggable={false}
        onError={() => setBroken(custom)}
        className={cn('object-contain', className)}
        style={{ width: 'auto', maxWidth: '12rem' }}
      />
    )
  }
  return (
    <svg viewBox="0 0 512 512" className={cn(still && 'snap-still', className)} role="img" aria-label="Bakery">
      <defs>
        <path id={`b-${id}`} fillRule="evenodd" d={B_PATH} />
        <clipPath id={`top-${id}`}><path d="M0 0H512V212.56L0 274Z" /></clipPath>
        <clipPath id={`bottom-${id}`}><path d="M0 284L512 222.56V512H0Z" /></clipPath>
        <mask id={`stripes-${id}`} maskUnits="userSpaceOnUse" x="0" y="0" width="512" height="512">
          <rect width="512" height="512" fill="white" />
          <path d="M80 233.8L420 131.8 M80 246.8L420 144.8 M80 377.8L420 275.8 M80 390.8L420 288.8" fill="none" stroke="black" strokeWidth="3" />
        </mask>
      </defs>
      <g transform="matrix(1 0 -.13 1 33.28 0)" fill={color}>
        <g className="snap-top"><g clipPath={`url(#top-${id})`}><use href={`#b-${id}`} mask={`url(#stripes-${id})`} /></g></g>
        <g className="snap-bottom"><g clipPath={`url(#bottom-${id})`}><use href={`#b-${id}`} mask={`url(#stripes-${id})`} /></g></g>
      </g>
    </svg>
  )
}

export function Kbd({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <kbd className={cn('inline-flex h-5 min-w-5 items-center justify-center rounded-[0.25rem] bg-[#f2f2f2] px-1.5 font-sans text-[0.625rem] font-black tracking-[0.04em] text-ink uppercase shadow-[inset_0_-2px_0_rgba(0,0,0,0.2)]', className)}>
      {children}
    </kbd>
  )
}

/** "KEY  what it does" */
export function Hint({ keys, children }: { keys: string[]; children: ReactNode }) {
  return (
    <span className="flex items-center gap-2 text-[0.625rem] font-extrabold tracking-[0.14em] text-white/45 uppercase">
      <span className="flex gap-1">{keys.map((k) => <Kbd key={k}>{k}</Kbd>)}</span>
      {children}
    </span>
  )
}

/** Square slot number, white when it is the one in focus. */
export function SlotNumber({ slot, active, className }: { slot: number; active?: boolean; className?: string }) {
  return (
    <span className={cn(
      'tnum inline-flex size-8 shrink-0 items-center justify-center rounded-[0.3125rem] text-[0.75rem] font-black transition-colors',
      active ? 'bg-white text-ink' : 'border border-white/20 text-white/80',
      className,
    )}>
      {slot.toString().padStart(2, '0')}
    </span>
  )
}

export function Toast({ message }: { message: string | null }) {
  if (!message) return null
  return (
    <div className="pointer-events-none absolute top-8 left-1/2 z-[60] -translate-x-1/2">
      <div key={message} className="pop-in rounded-md border border-bad/25 bg-[#1a1113] px-4 py-2.5 text-[0.6875rem] font-extrabold tracking-[0.05em] text-bad uppercase shadow-[0_12px_32px_rgba(0,0,0,0.6)]">
        {message}
      </div>
    </div>
  )
}
