import { ChevronLeft, ChevronRight, LayoutGrid } from 'lucide-react'
import { cn, pad } from '@/lib/utils'
import { Kbd, Logo } from '@/components/common'

// Logo and server name top-left on every view. On a single character, the way back to the line-up and
// the previous / next slot sit top-right (Esc and Q / E do the same).
export default function TopBar({
  server, slot, slots, onBack, onPrev, onNext,
}: {
  server: string
  /** slot in focus, null on the line-up */
  slot: number | null
  slots: number
  onBack: () => void
  onPrev: () => void
  onNext: () => void
}) {
  return (
    <>
      <div className="fade-in absolute top-9 left-10 z-10 flex items-center gap-3">
        <Logo className="size-9" />
        <span className="eyebrow">{server}</span>
      </div>

      {slot !== null && (
        <div className="fade-in absolute top-8 right-10 z-10 flex items-center gap-2">
          <button onClick={onBack} className={cn(btn, 'gap-2.5 px-3')}>
            <LayoutGrid className="size-3.5" /> All characters <Kbd>Esc</Kbd>
          </button>
          <div className="flex items-center rounded-md bg-black/45">
            <button onClick={onPrev} title="Previous (Q)" className={cn(btn, 'w-9 bg-transparent')}><ChevronLeft className="size-4" /></button>
            <span className="tnum px-1 text-[0.6875rem] font-black text-white">{pad(slot)}<span className="text-white/35"> / {pad(slots)}</span></span>
            <button onClick={onNext} title="Next (E)" className={cn(btn, 'w-9 bg-transparent')}><ChevronRight className="size-4" /></button>
          </div>
        </div>
      )}
    </>
  )
}

const btn = 'flex h-9 items-center justify-center rounded-md bg-black/45 text-[0.625rem] font-extrabold tracking-[0.12em] text-white/70 uppercase transition hover:bg-white/[0.1] hover:text-white'
