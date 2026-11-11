import { useCallback, useEffect, useRef, useState, type PointerEvent as ReactPointerEvent, type ReactNode } from 'react'
import { House, Minus, Plus } from 'lucide-react'
import { nui, useNuiEvent } from '@/lib/nui'
import { cn, pad } from '@/lib/utils'
import type { Result, SpawnData, SpawnFrame, SpawnPoint } from '@/lib/types'
import { Toast } from '@/components/common'
import { useShutter } from '@/components/Shutter'
import Pegman from '@/components/Pegman'
import { BrandPill, PlaceCallout } from '@/views/SpawnPlaces'

// The spawn map. The city behind it is the real game world, filmed by an aerial camera (client/spawn.lua);
// this page only draws the pins and a few small controls, map-app style, and sends the mouse and keys back.
// With Config.Spawn.FreeSpawn the little guy in the corner can be dragged onto the map to spawn anywhere.
export default function SpawnMap({ data }: { data: SpawnData }) {
  const [frame, setFrame] = useState<SpawnFrame | null>(null)
  const [points, setPoints] = useState<SpawnPoint[]>(data.points)
  const [selected, setSelected] = useState<string | null>(data.selected ?? null)
  const [hover, setHover] = useState<string | null>(null)
  const [dragging, setDragging] = useState(false)
  const [leaving, setLeaving] = useState(false)
  const [peg, setPeg] = useState<{ x: number; y: number; over: boolean } | null>(null)
  const [toast, setToast] = useState<string | null>(null)
  const toastTimer = useRef(0)
  useNuiEvent<SpawnFrame>('spawnFrame', setFrame)

  // Arrives behind the shutter that closed on the character screen; opens it once the city is on screen.
  const shutter = useShutter()
  useEffect(() => {
    const t = window.setTimeout(() => shutter.open(), 350)
    return () => window.clearTimeout(t)
  }, [shutter])

  const current = points.find((p) => p.id === selected) ?? null
  const numbered = points.filter((p) => p.kind === 'location')
  const numberOf = (p: SpawnPoint) => numbered.indexOf(p) + 1

  const notify = useCallback((message?: string) => {
    window.clearTimeout(toastTimer.current)
    setToast(message || 'Something went wrong.')
    toastTimer.current = window.setTimeout(() => setToast(null), 3500)
  }, [])

  // ---- camera input: drags and scrolls are added up and sent once per frame ----
  const pending = useRef({ dx: 0, dy: 0, steps: 0 })
  const raf = useRef(0)
  const flush = useCallback(() => {
    raf.current = 0
    const p = pending.current
    pending.current = { dx: 0, dy: 0, steps: 0 }
    if (p.dx || p.dy) nui('spawnPan', { dx: p.dx, dy: p.dy })
    if (p.steps) nui('spawnZoom', { steps: p.steps })
  }, [])
  const queue = useCallback(() => {
    if (!raf.current) raf.current = requestAnimationFrame(flush)
  }, [flush])
  useEffect(() => () => cancelAnimationFrame(raf.current), [])

  const drag = useRef<{ x: number; y: number } | null>(null)
  const onPointerDown = (e: ReactPointerEvent) => {
    if (leaving || e.button !== 0) return
    e.currentTarget.setPointerCapture(e.pointerId)
    drag.current = { x: e.clientX, y: e.clientY }
    setDragging(true)
  }
  const onPointerMove = (e: ReactPointerEvent) => {
    if (!drag.current) return
    pending.current.dx += (e.clientX - drag.current.x) / window.innerWidth
    pending.current.dy += (e.clientY - drag.current.y) / window.innerHeight
    drag.current = { x: e.clientX, y: e.clientY }
    queue()
  }
  const onPointerUp = () => {
    drag.current = null
    setDragging(false)
  }
  const onWheel = (e: React.WheelEvent) => {
    if (leaving) return
    pending.current.steps += Math.max(-3, Math.min(3, -e.deltaY / 100))
    queue()
  }
  const zoomBy = (steps: number) => !leaving && nui('spawnZoom', { steps })

  const select = useCallback((id: string) => {
    if (leaving) return
    setSelected(id)
    nui('spawnFocus', { id })
  }, [leaving])

  const confirm = useCallback(async () => {
    if (!selected || leaving) return
    setLeaving(true)
    const res = await nui<Result>('spawnConfirm', { id: selected })
    if (!res.ok) {
      setLeaving(false)
      notify(res.error)
    }
  }, [selected, leaving, notify])

  // ---- the little guy: drag him out of the corner and let go over the map ----
  const overMap = (x: number, y: number) => {
    const el = document.elementFromPoint(x, y) as HTMLElement | null
    return !!el && !el.closest('[data-ui]')
  }
  const pegDown = (e: ReactPointerEvent) => {
    if (leaving || e.button !== 0) return
    e.currentTarget.setPointerCapture(e.pointerId)
    setPeg({ x: e.clientX, y: e.clientY, over: false })
  }
  const pegMove = (e: ReactPointerEvent) => {
    if (peg) setPeg({ x: e.clientX, y: e.clientY, over: overMap(e.clientX, e.clientY) })
  }
  const pegUp = async (e: ReactPointerEvent) => {
    if (!peg) return
    setPeg(null)
    if (!overMap(e.clientX, e.clientY)) return
    const res = await nui<Result & { point?: SpawnPoint }>('spawnDrop', { x: e.clientX / window.innerWidth, y: e.clientY / window.innerHeight })
    if (!res.ok || !res.point) return notify(res.error)
    const point = res.point
    setPoints((list) => [point, ...list.filter((p) => p.kind !== 'drop')])
    setSelected(point.id)
  }

  // ---- keyboard: Q / E rotate and WASD pan while held, the rest are presses ----
  useEffect(() => {
    const held = new Set<string>()
    let sent = ''
    const sendKeys = () => {
      const has = (...k: string[]) => k.some((x) => held.has(x))
      const keys = {
        rotate: (has('q') ? 1 : 0) - (has('e') ? 1 : 0),
        x: (has('d', 'arrowright') ? 1 : 0) - (has('a', 'arrowleft') ? 1 : 0),
        y: (has('w', 'arrowup') ? 1 : 0) - (has('s', 'arrowdown') ? 1 : 0),
      }
      const key = JSON.stringify(keys)
      if (key !== sent) {
        sent = key
        nui('spawnKeys', keys)
      }
    }
    const down = (e: KeyboardEvent) => {
      if (leaving || e.target instanceof HTMLInputElement) return
      const k = e.key.toLowerCase()
      if (['q', 'e', 'w', 'a', 's', 'd', 'arrowup', 'arrowdown', 'arrowleft', 'arrowright'].includes(k)) {
        held.add(k)
        sendKeys()
      } else if (k === 'enter') confirm()
      else if (k === ' ') { if (selected) select(selected) }
      else if (k === 'n') nui('spawnNorth')
      else if (k === '+' || k === '=') nui('spawnZoom', { steps: 1.5 })
      else if (k === '-') nui('spawnZoom', { steps: -1.5 })
      else if (k === 'l' && points.some((p) => p.kind === 'last')) select('last')
      else if (/^[1-9]$/.test(k) && numbered[Number(k) - 1]) select(numbered[Number(k) - 1].id)
    }
    const up = (e: KeyboardEvent) => {
      held.delete(e.key.toLowerCase())
      sendKeys()
    }
    const blur = () => {
      held.clear()
      sendKeys()
    }
    window.addEventListener('keydown', down)
    window.addEventListener('keyup', up)
    window.addEventListener('blur', blur)
    return () => {
      window.removeEventListener('keydown', down)
      window.removeEventListener('keyup', up)
      window.removeEventListener('blur', blur)
      held.clear()
      nui('spawnKeys', { rotate: 0, x: 0, y: 0 })
    }
  }, [leaving, confirm, select, selected, points, numbered])

  const pinFor = (id: string) => frame?.pins.find((p) => p.id === id)

  return (
    <div className={cn('fixed inset-0 overflow-clip transition-opacity duration-500', leaving && 'opacity-0')}>
      {/* the whole screen is the map: drag to move, scroll to zoom */}
      <div
        className={cn('absolute inset-0', dragging ? 'cursor-grabbing' : 'cursor-grab')}
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={onPointerUp}
        onPointerCancel={onPointerUp}
        onWheel={onWheel}
      />
      <div className="pointer-events-none absolute inset-0 shadow-[inset_0_0_10rem_rgba(0,0,0,0.45)]" />

      {/* pins */}
      <div className="pointer-events-none fade-in absolute inset-0" style={{ animationDelay: '0.45s' }}>
        {points.map((p) => {
          const at = pinFor(p.id)
          if (!at?.visible) return null
          return (
            <Pin
              key={p.id}
              point={p}
              number={numberOf(p)}
              x={at.x}
              y={at.y}
              active={p.id === selected}
              hot={p.id === hover}
              compact={(frame?.zoom ?? 1) < 0.2}
              onHover={(on) => setHover(on ? p.id : null)}
              onClick={() => select(p.id)}
            />
          )
        })}
      </div>

      <BrandPill data={data} offMap={points.filter((p) => p.nopin)} selected={selected} onSelect={select} />

      {/* the picked place, standing on its pin */}
      {current && (() => {
        const at = pinFor(current.id)
        return <PlaceCallout point={current} number={numberOf(current)} at={at?.visible ? at : null} leaving={leaving} onConfirm={confirm} />
      })()}

      {/* bottom right: map controls */}
      <div data-ui style={{ animationDelay: '0.6s' }} className="fade-in absolute right-5 bottom-5 flex flex-col items-end gap-2">
        {frame && <span className="tnum rounded-md bg-black/55 px-1.5 py-0.5 text-[0.5rem] font-black tracking-[0.1em] text-white/70">{frame.altitude.toLocaleString('en-US')} m</span>}
        {frame && <Compass heading={frame.heading} />}
        {data.freeSpawn && (
          <button
            onPointerDown={pegDown}
            onPointerMove={pegMove}
            onPointerUp={pegUp}
            onPointerCancel={() => setPeg(null)}
            title="Drag onto the map to spawn there"
            className={cn(control, 'size-9 cursor-grab touch-none active:cursor-grabbing')}
          >
            <Pegman className={cn('h-5 transition', peg ? 'opacity-25' : 'text-white')} />
          </button>
        )}
        <div className="flex flex-col overflow-hidden rounded-md border border-white/[0.08] bg-[#111317]/95 shadow-[0_8px_24px_rgba(0,0,0,0.5)]">
          <button onClick={() => zoomBy(1.5)} title="Zoom in (+)" className="flex size-9 items-center justify-center text-white/80 transition hover:bg-white/[0.08] hover:text-white"><Plus className="size-4" /></button>
          <span className="mx-2 h-px bg-white/[0.08]" />
          <button onClick={() => zoomBy(-1.5)} title="Zoom out (-)" className="flex size-9 items-center justify-center text-white/80 transition hover:bg-white/[0.08] hover:text-white"><Minus className="size-4" /></button>
        </div>
      </div>

      {/* the little guy while he's being dragged */}
      {peg && (
        <div className="pointer-events-none fixed z-50" style={{ left: peg.x, top: peg.y }}>
          <span className={cn('absolute h-1.5 w-5 -translate-x-1/2 -translate-y-1/2 rounded-[50%] bg-black/60 transition-opacity', peg.over ? 'opacity-100' : 'opacity-0')} />
          <span className="absolute bottom-2 -translate-x-1/2 origin-top animate-[peg-swing_0.9s_ease-in-out_infinite]">
            <Pegman className={cn('h-9 drop-shadow-[0_4px_8px_rgba(0,0,0,0.6)]', peg.over ? 'text-white' : 'text-white/50')} />
          </span>
        </div>
      )}

      <Toast message={toast} />
    </div>
  )
}

const control = 'flex items-center justify-center rounded-md border border-white/[0.08] bg-[#111317]/95 shadow-[0_8px_24px_rgba(0,0,0,0.5)] outline-none transition hover:bg-[#1b1d23]'

// Map pins: a teardrop for each place, a pulsing dot for the last location, the little guy for a drop.
function Pin({
  point, number, x, y, active, hot, compact, onHover, onClick,
}: {
  /** zoomed far out: just the marker, the name only on hover */
  compact?: boolean
  point: SpawnPoint
  number: number
  x: number
  y: number
  active: boolean
  hot: boolean
  onHover: (on: boolean) => void
  onClick: () => void
}) {
  const lit = active || hot
  const label = point.kind === 'location' || point.kind === 'home' ? point.label : point.kind === 'last' ? 'Last location' : 'Dropped pin'
  const events = { onMouseEnter: () => onHover(true), onMouseLeave: () => onHover(false), onClick }

  let marker: ReactNode
  if (point.kind === 'last') {
    marker = (
      <span className="relative block size-4 -translate-x-1/2 -translate-y-1/2">
        <span className="absolute inset-[-0.4rem] animate-ping rounded-full bg-white/30" />
        <span className={cn('absolute inset-0 rounded-full border-[3px] border-white shadow-[0_0_0_2px_rgba(0,0,0,0.4)]', lit ? 'bg-white' : 'bg-ink')} />
      </span>
    )
  } else if (point.kind === 'drop') {
    marker = (
      <span className="relative block -translate-x-1/2 -translate-y-full">
        <span className="absolute -bottom-0.5 left-1/2 h-1.5 w-5 -translate-x-1/2 rounded-[50%] bg-black/55" />
        <Pegman className={cn('relative h-8 drop-shadow-[0_4px_8px_rgba(0,0,0,0.6)] transition-transform', lit && 'scale-110')} />
      </span>
    )
  } else if (point.kind === 'home') {
    // a home: a white teardrop with a house, a little larger than the public spots
    marker = (
      <span className={cn('relative block -translate-x-1/2 -translate-y-full transition-transform', lit && 'scale-[1.15]')} style={{ transformOrigin: '50% 100%' }}>
        {lit && <span className="absolute inset-x-[-0.35rem] top-[-0.35rem] bottom-0 animate-ping rounded-full bg-white/25" />}
        <span className="relative mb-[0.25rem] flex size-7 rotate-45 items-center justify-center rounded-[50%_50%_0_50%] border-2 border-white bg-white text-ink shadow-[0_0_0_2px_rgba(0,0,0,0.35),0_6px_14px_rgba(0,0,0,0.5)]">
          <House className="size-3.5 -rotate-45" strokeWidth={2.5} />
        </span>
      </span>
    )
  } else {
    marker = (
      <span className={cn('relative block -translate-x-1/2 -translate-y-full transition-transform', lit && 'scale-[1.18]')} style={{ transformOrigin: '50% 100%' }}>
        <span className={cn(
          'mb-[0.2rem] flex size-6 rotate-45 items-center justify-center rounded-[50%_50%_0_50%] border-2 shadow-[0_6px_14px_rgba(0,0,0,0.5)]',
          lit ? 'border-white bg-white text-ink' : 'border-white bg-ink text-white',
        )}>
          <span className="tnum -rotate-45 text-[0.5625rem] font-black">{pad(number)}</span>
        </span>
      </span>
    )
  }

  return (
    <div className="absolute" style={{ left: `${x * 100}%`, top: `${y * 100}%`, zIndex: active ? 3 : hot ? 2 : 1 }}>
      <button {...events} className="pointer-events-auto absolute top-0 left-0 outline-none">{marker}</button>
      {!active && (!compact || hot) && <button
        {...events}
        className={cn(
          'pointer-events-auto absolute left-3 -translate-y-1/2 rounded-[0.25rem] px-1.5 py-0.5 text-[0.5625rem] font-black tracking-[0.06em] whitespace-nowrap uppercase outline-none transition',
          point.kind === 'location' ? 'top-[-0.95rem]' : point.kind === 'home' ? 'top-[-1.1rem] left-3.5' : point.kind === 'drop' ? 'top-[-1.1rem] left-4' : 'top-0',
          lit ? 'bg-white text-ink' : 'bg-black/70 text-white/90',
        )}
      >
        {label}
      </button>}
    </div>
  )
}

// North needle; turns as the camera turns. Click to face north again.
function Compass({ heading }: { heading: number }) {
  return (
    <button onClick={() => nui('spawnNorth')} title="Face north (N)" className={cn(control, 'relative size-9 rounded-full')}>
      <span className="absolute inset-0" style={{ transform: `rotate(${heading}deg)` }}>
        <span className="absolute top-[0.3rem] left-1/2 h-0 w-0 -translate-x-1/2 border-x-[0.25rem] border-b-[0.7rem] border-x-transparent border-b-bad" />
        <span className="absolute bottom-[0.3rem] left-1/2 h-0 w-0 -translate-x-1/2 border-x-[0.25rem] border-t-[0.7rem] border-x-transparent border-t-white/70" />
      </span>
    </button>
  )
}
