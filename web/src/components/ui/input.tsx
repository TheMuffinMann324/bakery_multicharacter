import * as React from 'react'
import { cn } from '@/lib/utils'

function Input({ className, type, ...props }: React.ComponentProps<'input'>) {
  return (
    <input
      type={type}
      data-slot="input"
      className={cn(
        'h-11 w-full min-w-0 rounded-md border border-white/[0.08] bg-field px-3.5 text-[0.875rem] font-semibold text-white/90 outline-none transition-[border-color,box-shadow] placeholder:font-medium placeholder:text-white/22 selection:bg-white selection:text-ink disabled:opacity-50',
        'focus-visible:border-white/35 focus-visible:shadow-[0_0_0_3px_rgba(255,255,255,0.06)]',
        'aria-invalid:border-bad/50',
        className,
      )}
      {...props}
    />
  )
}

export { Input }
