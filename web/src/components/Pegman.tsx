import { cn } from '@/lib/utils'

// The little guy: drag him onto the map, and he stands where you'll spawn.
export default function Pegman({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 20 32" className={cn('aspect-[20/32]', className)} fill="currentColor" stroke="#0b0c0f" strokeWidth="1.4" strokeLinejoin="round">
      <circle cx="10" cy="5.5" r="4.5" />
      <path d="M5.5 11.5h9a2.5 2.5 0 0 1 2.5 2.5v7h-2.6v9.5h-3.4v-7h-2v7H5.6v-9.5H3v-7a2.5 2.5 0 0 1 2.5-2.5z" />
    </svg>
  )
}
