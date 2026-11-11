import { useEffect, useRef, useState, type ReactNode } from 'react'
import { ChevronRight, Lock, Trash2 } from 'lucide-react'
import { ageOn, ago, cn, money, pad, parseDob } from '@/lib/utils'
import type { Character, OpenData } from '@/lib/types'
import { Button } from '@/components/ui/button'
import { Kbd, SlotNumber } from '@/components/common'

// One character: the details sit in a dock along the bottom, the character stands above it in front
// of the studio backdrop (web/src/dui).
export default function Detail({
  data, character, onPlay, onDelete,
}: {
  data: OpenData
  character: Character
  onPlay: () => void
  onDelete: () => void
}) {
  const c = character
  const dob = parseDob(c.dob)
  const age = dob ? ageOn(dob.y, dob.m, dob.d, data.now) : null

  const specs: [string, ReactNode][] = [
    ['Cash', money(c.cash)],
    ['Bank', money(c.bank)],
    ['Age', age !== null ? `${age} yrs` : '--'],
    ['Born', dob ? `${pad(dob.d)}.${pad(dob.m)}.${dob.y}` : 'Unknown'],
    c.height ? ['Height', `${c.height} cm`] : ['Nationality', c.nationality || 'Unknown'],
    ['Phone', c.phone || '--'],
  ]

  return (
    <>
      <Dock>
        {/* who */}
        <div className="min-w-[14rem] flex-1">
          <div className="flex flex-wrap items-center gap-1.5">
            <SlotNumber slot={c.slot} active className="size-6 text-[0.625rem]" />
            <Tag solid>{[c.job, c.grade].filter(Boolean).join(' · ') || 'Unemployed'}</Tag>
            {c.gang && <Tag>{c.gang}</Tag>}
            {c.disabled && <Tag className="border-bad/30 text-bad"><Lock className="size-3" /> Disabled</Tag>}
          </div>
          <h2 className="display mt-3 truncate text-[3rem] text-white">
            {c.firstName} <span className="text-white/40">{c.lastName}</span>
          </h2>
          <p className="mt-2 truncate text-[0.65625rem] font-extrabold tracking-[0.14em] text-white/35 uppercase">
            {c.gender}
            {c.lastPlayed ? <> · Last seen {ago(c.lastPlayed, data.now)}</> : null}
            {data.framework !== 'esx' && <> · <span className="font-mono tracking-[0.12em] text-white/55">{c.id}</span></>}
          </p>
        </div>

        {/* spec sheet */}
        <div className="grid grid-cols-3 gap-y-4">
          {specs.map(([label, value]) => (
            <div key={label} className="w-[9.5rem] border-l border-white/10 pl-4">
              <p className="eyebrow">{label}</p>
              <p className="tnum mt-1.5 truncate text-[1.0625rem] leading-none font-black tracking-tight text-white uppercase">{value}</p>
            </div>
          ))}
        </div>

        {/* actions */}
        <div className="w-[17rem]">
          <Button size="xl" className="w-full justify-between" onClick={onPlay} disabled={c.disabled}>
            Enter the city
            <span className="flex items-center gap-2"><Kbd className="bg-ink text-white shadow-none">Enter</Kbd><ChevronRight /></span>
          </Button>
          {data.allowDelete && <HoldToDelete seconds={data.deleteHold} onDone={onDelete} />}
        </div>
      </Dock>
    </>
  )
}

export function Dock({ children }: { children: ReactNode }) {
  return (
    <div className="absolute inset-x-0 bottom-0">
      <div className="pointer-events-none absolute inset-x-0 bottom-0 h-[140%] bg-gradient-to-t from-black/95 via-black/70 to-transparent" />
      <div className="dock-in relative flex items-end justify-between gap-10 border-t border-white/[0.08] px-10 pt-7 pb-9">
        {children}
      </div>
    </div>
  )
}

function Tag({ children, solid, className }: { children: ReactNode; solid?: boolean; className?: string }) {
  return (
    <span className={cn(
      'inline-flex h-6 items-center gap-1.5 rounded-[0.25rem] px-2 text-[0.59375rem] font-extrabold tracking-[0.12em] uppercase',
      solid ? 'bg-white/[0.1] text-white' : 'border border-white/[0.12] text-white/70',
      className,
    )}>
      {children}
    </span>
  )
}

// Deletes only after the button has been held the whole time; letting go cancels.
function HoldToDelete({ seconds, onDone }: { seconds: number; onDone: () => void }) {
  const [progress, setProgress] = useState(0)
  const frame = useRef(0)
  const done = useRef(onDone)
  done.current = onDone

  const stop = () => {
    cancelAnimationFrame(frame.current)
    setProgress(0)
  }
  const start = () => {
    const began = performance.now()
    const tick = (now: number) => {
      const p = Math.min(1, (now - began) / (seconds * 1000))
      setProgress(p)
      if (p >= 1) {
        setProgress(0)
        done.current()
        return
      }
      frame.current = requestAnimationFrame(tick)
    }
    frame.current = requestAnimationFrame(tick)
  }
  useEffect(() => () => cancelAnimationFrame(frame.current), [])

  return (
    <button
      onMouseDown={start}
      onMouseUp={stop}
      onMouseLeave={stop}
      className="relative mt-2 flex h-8 w-full items-center justify-center gap-2 overflow-hidden rounded-md text-[0.625rem] font-extrabold tracking-[0.12em] text-white/35 uppercase transition hover:bg-bad/10 hover:text-bad"
    >
      <span className="absolute inset-y-0 left-0 bg-bad/25" style={{ width: `${progress * 100}%` }} />
      <Trash2 className="relative size-3.5" />
      <span className="relative">{progress > 0 ? 'Keep holding' : `Hold ${seconds}s to delete`}</span>
    </button>
  )
}
