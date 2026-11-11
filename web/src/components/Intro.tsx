import { useEffect, useState, type ReactNode } from 'react'
import { Clock3, Cloud, CloudFog, CloudLightning, CloudRain, CloudSun, MapPin, Snowflake, Sun } from 'lucide-react'
import { cn } from '@/lib/utils'
import type { IntroData } from '@/lib/types'
import { Logo } from '@/components/common'

// Shown once the character is in the world (client/intro.lua): the logo snaps in, their name wipes on,
// then where and when they are. No focus is taken, the player can move the whole time.
const EXIT_MS = 800

export default function Intro({ data, onDone }: { data: IntroData; onDone: () => void }) {
  const [leaving, setLeaving] = useState(false)

  useEffect(() => {
    const out = window.setTimeout(() => setLeaving(true), Math.max(2000, data.duration - EXIT_MS))
    const done = window.setTimeout(onDone, data.duration)
    return () => {
      window.clearTimeout(out)
      window.clearTimeout(done)
    }
  }, [data, onDone])

  const place = data.indoors && !data.street ? 'Indoors' : [data.street, data.cross].filter(Boolean).join(' / ')
  const name = [data.firstName, data.lastName].filter(Boolean)

  return (
    <div className={cn('pointer-events-none fixed inset-0 z-[70]', leaving && 'intro-leave')}>
      <div className="intro-shade absolute inset-0 bg-[radial-gradient(ellipse_70%_65%_at_0%_100%,rgba(0,0,0,0.78),transparent_70%)]" />

      <div className="absolute bottom-[4.5rem] left-14 max-w-[60rem]">
        {/* logo + greeting */}
        <div className="flex items-center gap-4">
          <span className="intro-logo"><Logo className="size-14" /></span>
          <span className="intro-rule h-10 w-px bg-white/30" />
          <div className="intro-fade" style={{ animationDelay: '0.35s' }}>
            <p className="eyebrow">{data.isNew ? 'A new life begins' : 'Welcome back'}</p>
            <p className="mt-1 text-[0.8125rem] font-black tracking-[0.18em] text-white uppercase">{data.server}</p>
          </div>
        </div>

        {/* name */}
        {name.length > 0 && (
          <h1 className="intro-wipe display mt-6 text-[5rem] leading-[0.9] text-white [text-shadow:0_6px_30px_rgba(0,0,0,0.6)]" style={{ animationDelay: '0.55s' }}>
            {name[0]} {name[1] && <span className="text-white/45">{name[1]}</span>}
          </h1>
        )}
        <span className="intro-line mt-5 block h-[2px] w-[22rem] bg-gradient-to-r from-white to-transparent" style={{ animationDelay: '0.85s' }} />

        {/* the world around them */}
        <div className="mt-5 flex flex-wrap items-stretch gap-2">
          <Chip delay={1.05} icon={<MapPin />} label={data.zone} value={place || 'San Andreas'} />
          <Chip delay={1.2} icon={<Clock3 />} label={data.partOfDay} value={data.time} />
          {data.weather && <Chip delay={1.35} icon={<WeatherIcon weather={data.weather} />} label="Weather" value={data.weather} />}
        </div>
      </div>
    </div>
  )
}

function Chip({ icon, label, value, delay }: { icon: ReactNode; label: string; value: string; delay: number }) {
  return (
    <div className="intro-chip flex items-center gap-3 rounded-md border border-white/[0.08] bg-black/55 py-2.5 pr-4 pl-3" style={{ animationDelay: `${delay}s` }}>
      <span className="flex size-8 items-center justify-center rounded-[0.3125rem] bg-white text-ink [&_svg]:size-4">{icon}</span>
      <span>
        <span className="eyebrow block">{label}</span>
        <span className="tnum mt-1 block text-[0.875rem] leading-none font-black tracking-[0.04em] text-white uppercase">{value}</span>
      </span>
    </div>
  )
}

function WeatherIcon({ weather }: { weather: string }) {
  const w = weather.toLowerCase()
  if (w.includes('thunder')) return <CloudLightning />
  if (w.includes('rain')) return <CloudRain />
  if (w.includes('snow') || w.includes('blizzard')) return <Snowflake />
  if (w.includes('fog') || w.includes('smog')) return <CloudFog />
  if (w.includes('sunny') || w.includes('clear')) return w.includes('clearing') ? <CloudSun /> : <Sun />
  return <Cloud />
}
