import { ChevronRight, House } from 'lucide-react'
import { cn, pad } from '@/lib/utils'
import type { SpawnData, SpawnPoint } from '@/lib/types'
import { Kbd, Logo } from '@/components/common'

// The spawn map's own UI, kept out of the way of the city; the map itself is the guide.
//   BrandPill     small pill top-left: logo, who is choosing, live; homes with no spot on the map under it
//   PlaceCallout  the picked place, standing on its pin on the map, with the button to wake up there

const glass = 'border border-white/[0.08] bg-[#0f1115]/85 shadow-[0_18px_50px_rgba(0,0,0,0.55)] backdrop-blur-xl'

function distanceText(m?: number) {
  if (m === undefined || m === null) return null
  return m < 1000 ? `${Math.max(10, Math.round(m / 10) * 10)} m` : `${(m / 1000).toFixed(m < 10000 ? 1 : 0)} km`
}

function kindLabel(p: SpawnPoint, number: number) {
  if (p.kind === 'last') return 'Last location'
  if (p.kind === 'drop') return 'Dropped pin'
  if (p.kind === 'home') return 'Your property'
  return `City location ${pad(number)}`
}


export function BrandPill({
  data, offMap, selected, onSelect,
}: {
  data: SpawnData
  /** homes the housing script gave no door position for: no pin, so they are picked here */
  offMap: SpawnPoint[]
  selected: string | null
  onSelect: (id: string) => void
}) {
  return (
    <div data-ui style={{ animationDelay: '0.5s' }} className="fade-in absolute top-5 left-5 flex flex-col items-start gap-1.5">
    <div className={cn('pointer-events-none flex items-center gap-2.5 rounded-full py-1.5 pr-3 pl-2', glass)}>
      <Logo className="size-5" />
      <span className="text-[0.625rem] font-black tracking-[0.08em] text-white uppercase">
        {data.firstName ? `Where to, ${data.firstName}?` : 'Where to?'}
      </span>
      {data.isNew && <span className="text-[0.5rem] font-extrabold tracking-[0.16em] text-white/40 uppercase">A new life begins</span>}
      <span className="h-3 w-px bg-white/15" />
      <span className="flex items-center gap-1 text-[0.5rem] font-extrabold tracking-[0.16em] text-white/70 uppercase">
        <span className="pulse-dot size-1.5 rounded-full bg-bad" /> Live
      </span>
    </div>
    {offMap.map((p) => (
      <button
        key={p.id}
        onClick={() => onSelect(p.id)}
        className={cn(
          'flex items-center gap-1.5 rounded-full py-1 pr-2.5 pl-1.5 text-[0.5625rem] font-black tracking-[0.08em] uppercase transition',
          p.id === selected ? 'bg-white text-ink' : cn(glass, 'text-white/80 hover:text-white'),
        )}
      >
        <span className={cn('flex size-4 items-center justify-center rounded-full', p.id === selected ? 'bg-ink text-white' : 'bg-white text-ink')}><House className="size-2.5" strokeWidth={2.5} /></span>
        {p.label}
      </button>
    ))}
    </div>
  )
}

// The picked place. Stands on its pin when the pin is on screen, otherwise above the dock.
export function PlaceCallout({
  point, number, at, leaving, onConfirm,
}: {
  point: SpawnPoint
  number: number
  /** pin position (0-1), or null when it has no pin / is off screen */
  at: { x: number; y: number } | null
  leaving: boolean
  onConfirm: () => void
}) {
  const onPin = !!at && at.x > 0.12 && at.x < 0.88 && at.y > 0.22 && at.y < 0.8
  const distance = distanceText(point.distance)
  return (
    <div
      data-ui
      className={cn('absolute z-10', onPin ? '-translate-x-1/2 -translate-y-full' : 'bottom-8 left-1/2 -translate-x-1/2')}
      style={onPin ? { left: `${at!.x * 100}%`, top: `calc(${at!.y * 100}% - ${point.kind === 'last' ? 1.25 : 2.6}rem)` } : undefined}
    >
      <div key={point.id} className={cn('pop-in w-[15rem] overflow-hidden rounded-xl', glass)}>
        <div className="px-3 pt-2.5 pb-2">
          <div className="flex items-center gap-2">
            <span className="text-[0.5rem] font-black tracking-[0.16em] text-white/50 uppercase">{kindLabel(point, number)}</span>
            {distance && <span className="tnum ml-auto text-[0.5rem] font-black tracking-[0.12em] text-white/40 uppercase">{distance} away</span>}
          </div>
          <p className="display mt-1.5 truncate text-[1.25rem] text-white">{point.kind === 'last' ? point.zone : point.label}</p>
          <p className="mt-0.5 truncate text-[0.5rem] font-extrabold tracking-[0.14em] text-white/40 uppercase">
            {[point.street, point.kind === 'last' ? null : point.zone].filter(Boolean).join(' · ') || 'San Andreas'}
          </p>
        </div>
        <button
          onClick={onConfirm}
          disabled={leaving}
          className="flex h-9 w-full items-center justify-between bg-white px-3 text-[0.625rem] font-black tracking-[0.12em] text-ink uppercase transition hover:bg-white/85 disabled:opacity-40"
        >
          Wake up here
          <span className="flex items-center gap-1.5"><Kbd className="h-4 bg-ink px-1 text-[0.5rem] text-white shadow-none">Enter</Kbd><ChevronRight className="size-3.5" /></span>
        </button>
      </div>
      {/* pointer down to the pin */}
      {onPin && <span className="mx-auto block h-0 w-0 border-x-[0.4rem] border-t-[0.45rem] border-x-transparent border-t-white" />}
    </div>
  )
}
