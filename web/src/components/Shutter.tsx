import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from 'react'
import { cn } from '@/lib/utils'
import { Logo } from '@/components/common'

// Every change of screen happens behind this: two black blades close, the game changes what's behind them
// (camera cut, backdrop swap, spawn map, the world itself), and the blades open on the new shot.
// There is one shutter for the whole UI, so it can stay shut from the character screen through to the
// spawn map and the world without ever flickering. The game can also close / open it (Nui.shutter in Lua).
export const SHUTTER_CLOSE_MS = 200
export const SHUTTER_OPEN_MS = 440
const SAFETY_MS = 25000   // never leave the screen covered if nothing comes to open it

const wait = (ms: number) => new Promise((r) => window.setTimeout(r, ms))

export interface ShutterControl {
  /** close the blades; label shows under the logo while they are shut (null clears it) */
  close: (label?: string | null) => Promise<void>
  open: () => Promise<void>
  isClosed: () => boolean
}

interface ShutterState { closed: boolean; cycle: number; label: string | null }

export function useShutterState(): [ShutterState, ShutterControl] {
  const [state, setState] = useState<ShutterState>({ closed: false, cycle: 0, label: null })
  const closed = useRef(false)
  const safety = useRef(0)

  const open = useCallback(async () => {
    window.clearTimeout(safety.current)
    if (!closed.current) return
    closed.current = false
    setState((s) => ({ ...s, closed: false }))
    await wait(SHUTTER_OPEN_MS)
    if (!closed.current) setState((s) => ({ ...s, label: null }))
  }, [])

  const close = useCallback(async (label?: string | null) => {
    window.clearTimeout(safety.current)
    safety.current = window.setTimeout(open, SAFETY_MS)
    const was = closed.current
    closed.current = true
    setState((s) => ({
      closed: true,
      cycle: was ? s.cycle : s.cycle + 1,
      label: label === undefined ? (was ? s.label : null) : label,
    }))
    if (!was) await wait(SHUTTER_CLOSE_MS + 30)
  }, [open])

  useEffect(() => () => window.clearTimeout(safety.current), [])

  const control = useMemo(() => ({ close, open, isClosed: () => closed.current }), [close, open])
  return [state, control]
}

const ShutterContext = createContext<ShutterControl | null>(null)
export const ShutterProvider = ShutterContext.Provider
export function useShutter() {
  const control = useContext(ShutterContext)
  if (!control) throw new Error('useShutter outside ShutterProvider')
  return control
}

const ease = (closed: boolean) =>
  `transform ${closed ? SHUTTER_CLOSE_MS : SHUTTER_OPEN_MS}ms ${closed ? 'cubic-bezier(0.7, 0, 0.84, 0)' : 'cubic-bezier(0.16, 1, 0.3, 1)'}`

export default function Shutter({ closed, cycle, label }: ShutterState) {
  return (
    <div className="pointer-events-none fixed inset-0 z-[60]">
      <div className="absolute inset-x-0 top-0 h-1/2 bg-black" style={{ transform: closed ? 'none' : 'translateY(-100%)', transition: ease(closed) }} />
      <div className="absolute inset-x-0 bottom-0 h-1/2 bg-black" style={{ transform: closed ? 'none' : 'translateY(100%)', transition: ease(closed) }} />

      <div className={cn('absolute inset-0 transition-opacity', closed ? 'opacity-100 duration-150' : 'opacity-0 duration-200')}>
        {/* the seam: a line runs across exactly where the blades meet */}
        <div key={cycle} className="seam absolute top-1/2 left-0 h-px w-full -translate-y-1/2 bg-gradient-to-r from-transparent via-white/70 to-transparent" />

        {/* while loading, the logo sits on the seam (the black box cuts the line around it), the label under it */}
        {label && (
          <div className="fade-in absolute inset-0">
            <div className="absolute top-1/2 left-1/2 flex h-24 -translate-x-1/2 -translate-y-1/2 items-center bg-black px-6">
              <Logo className="h-16 w-16" />
            </div>
            <p className="eyebrow pulse-dot absolute top-[calc(50%+3.5rem)] left-1/2 -translate-x-1/2 whitespace-nowrap">{label}</p>
          </div>
        )}
      </div>
    </div>
  )
}
