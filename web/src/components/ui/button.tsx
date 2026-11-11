import * as React from 'react'
import { Slot } from 'radix-ui'
import { cva, type VariantProps } from 'class-variance-authority'
import { cn } from '@/lib/utils'

// Same button as bakery_racing / bakery_boosting, sized in rem so it follows the screen height.
const buttonVariants = cva(
  "relative inline-flex shrink-0 items-center justify-center gap-[0.375rem] rounded-md font-extrabold tracking-[0.06em] whitespace-nowrap uppercase transition-all outline-none select-none active:translate-y-px disabled:pointer-events-none disabled:opacity-35 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4 focus-visible:ring-2 focus-visible:ring-ring",
  {
    variants: {
      variant: {
        default: 'bg-white text-ink hover:bg-white/85',
        destructive: 'bg-bad/12 text-bad hover:bg-bad/20',
        outline: 'border border-white/[0.1] text-white/75 hover:bg-white/[0.07] hover:text-white',
        secondary: 'bg-white/[0.07] text-white/85 hover:bg-white/[0.12] hover:text-white',
        ghost: 'text-white/50 hover:bg-white/[0.07] hover:text-white',
        link: 'text-white underline-offset-4 hover:underline',
      },
      size: {
        default: 'h-8 px-3 text-[0.6875rem]',
        sm: 'h-7 px-2.5 text-[0.65625rem] [&_svg:not([class*=size-])]:size-3.5',
        lg: 'h-10 px-4 text-[0.75rem]',
        xl: 'h-14 px-5 text-[1.0625rem] tracking-[0.08em] [&_svg:not([class*=size-])]:size-5',
        icon: 'size-8',
        'icon-lg': 'size-10',
        'icon-xl': 'size-14 [&_svg:not([class*=size-])]:size-5',
      },
    },
    defaultVariants: { variant: 'default', size: 'default' },
  },
)

function Button({
  className, variant, size, asChild = false, ...props
}: React.ComponentProps<'button'> & VariantProps<typeof buttonVariants> & { asChild?: boolean }) {
  const Comp = asChild ? Slot.Root : 'button'
  return <Comp data-slot="button" className={cn(buttonVariants({ variant, size, className }))} {...props} />
}

export { Button, buttonVariants }
