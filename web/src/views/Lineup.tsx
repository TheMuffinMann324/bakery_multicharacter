import { Plus } from 'lucide-react'
import { cn } from '@/lib/utils'
import type { Anchor, Character } from '@/lib/types'
import { Hint, SlotNumber } from '@/components/common'

// The line-up. The peds, rings and lights are drawn by the game (client/scene.lua); this puts a
// click area over each one and a name plate at its feet.
export default function Lineup({
  anchors, characters, slots, hover, onHover, onSelect,
}: {
  anchors: Anchor[]
  characters: Character[]
  slots: number
  hover: number | null
  onHover: (slot: number | null) => void
  onSelect: (slot: number) => void
}) {
  return (
    <div className="absolute inset-0">
      <div className="pointer-events-none absolute inset-x-0 top-0 h-48 bg-gradient-to-b from-black/80 to-transparent" />
      <div className="pointer-events-none absolute inset-x-0 bottom-0 h-56 bg-gradient-to-t from-black/85 to-transparent" />

      <div className="rise absolute inset-x-0 top-10 text-center">
        <p className="eyebrow">{characters.length} of {slots} slots in use</p>
        <h1 className="display mt-2 text-[2.25rem] text-white">Who are you today?</h1>
      </div>

      {anchors.filter((a) => a.visible).map((a, i) => {
        const c = characters.find((x) => x.slot === a.slot)
        const hot = hover === a.slot
        const enter = () => onHover(a.slot)
        const leave = () => onHover(null)
        return (
          <div key={a.slot}>
            {/* the character itself is clickable */}
            <button
              onMouseEnter={enter}
              onMouseLeave={leave}
              onClick={() => onSelect(a.slot)}
              className="absolute outline-none"
              style={{ left: `${(a.x - a.width / 2) * 100}%`, width: `${a.width * 100}%`, top: `${a.top * 100}%`, height: `${(a.bottom - a.top) * 100}%` }}
            />

            {/* name plate at the feet */}
            <button
              onMouseEnter={enter}
              onMouseLeave={leave}
              onClick={() => onSelect(a.slot)}
              className="rise absolute -translate-x-1/2 outline-none"
              style={{ width: `min(15rem, calc(${a.width * 100}vw - 0.75rem))`, left: `${a.x * 100}%`, top: `calc(${a.bottom * 100}% + 1.5rem)`, animationDelay: `${0.15 + i * 0.06}s` }}
            >
              <span className={cn(
                'flex items-center gap-3 rounded-md px-2.5 py-2 text-left transition-all duration-150',
                hot ? 'bg-white text-ink shadow-[0_12px_32px_rgba(0,0,0,0.5)]' : c ? 'bg-black/55 text-white' : 'border border-dashed border-white/15 bg-black/30 text-white/50',
              )}>
                <SlotNumber slot={a.slot} active={hot} className={cn(hot && 'bg-ink text-white', !hot && !c && 'border-dashed')} />
                <span className="min-w-0 flex-1">
                  {c ? (
                    <>
                      <span className="block truncate text-[0.8125rem] leading-tight font-black tracking-[0.04em] uppercase">{c.firstName} {c.lastName}</span>
                      <span className={cn('mt-0.5 block truncate text-[0.5625rem] font-extrabold tracking-[0.14em] uppercase', hot ? 'text-ink/55' : 'text-white/40')}>
                        {[c.job, c.grade].filter(Boolean).join(' · ') || 'Unemployed'}
                      </span>
                    </>
                  ) : (
                    <span className="flex items-center gap-1.5 text-[0.75rem] font-black tracking-[0.08em] uppercase">
                      <Plus className="size-3" strokeWidth={3} /> Create
                    </span>
                  )}
                </span>
              </span>
            </button>
          </div>
        )
      })}

      <div className="fade-up absolute inset-x-0 bottom-8 flex items-center justify-center gap-7" style={{ animationDelay: '0.4s' }}>
        <Hint keys={['←', '→']}>Browse</Hint>
        <Hint keys={['Enter']}>Select</Hint>
      </div>
    </div>
  )
}
