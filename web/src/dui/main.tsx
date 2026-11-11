import { StrictMode, useEffect, useState, type CSSProperties } from 'react'
import { createRoot } from 'react-dom/client'
import './poster.css'
import type { PosterData } from '@/lib/types'

// The studio backdrop behind the selected character. This page is not the NUI: it is rendered off-screen
// by a DUI and drawn on a wall in the game world (client/backdrop.lua), so the ped stands in front of it.
//
// The game tells the page where the floor and the character are (page pixels), so the height chart
// lines up with the character's real height:
//   show { server, slot, total, empty, scale (px per metre), floor (y), centre (x) }
//   hide

const FALLBACK = { scale: 412, floor: 1035, centre: 960 }
const CHART_HALF = 430      // px either side of the character
const FOOT = 0.3048
const INCH = 0.0254

interface Mark { m: number; major: boolean; label?: string; side?: string; key: string }

// Feet and inches: a line every foot up to 7 ft, a tick every 3 inches. 6 ft is the default ped height.
function imperialMarks(): Mark[] {
  const out: Mark[] = []
  for (let inches = 3; inches <= 84; inches += 3) {
    const major = inches % 12 === 0
    const m = inches * INCH
    out.push({
      m, major, key: `i${inches}`,
      label: major ? `${inches / 12}'0"` : undefined,
      side: major ? `${Math.round(m * 100)} CM` : undefined,
    })
  }
  return out
}

// Metres: a line every 50 cm up to 2.2 m, a tick every 10 cm.
function metricMarks(): Mark[] {
  const out: Mark[] = []
  for (let i = 1; i <= 22; i++) {
    const m = i / 10
    const major = i % 5 === 0
    const ft = Math.floor(m / FOOT)
    const inch = Math.round((m - ft * FOOT) / INCH)
    out.push({ m, major, key: `m${i}`, label: major ? m.toFixed(2) : undefined, side: major ? `${ft}'${inch}"` : undefined })
  }
  return out
}

const pad = (n: number) => n.toString().padStart(2, '0')

function Backdrop() {
  const [data, setData] = useState<PosterData | null>(null)
  const [on, setOn] = useState(false)
  const [run, setRun] = useState(0)   // bumps on every "show" so the build-in plays again

  useEffect(() => {
    const onMessage = (event: MessageEvent) => {
      const { action, data: payload } = event.data ?? {}
      if (action === 'show' && payload) {
        setData(payload)
        setRun((n) => n + 1)
        setOn(true)
      } else if (action === 'hide') {
        setOn(false)
      }
    }
    window.addEventListener('message', onMessage)
    return () => window.removeEventListener('message', onMessage)
  }, [])

  if (!data) return null
  const scale = data.scale ?? FALLBACK.scale
  const floor = data.floor ?? FALLBACK.floor
  const centre = data.centre ?? FALLBACK.centre
  const left = centre - CHART_HALF
  const yAt = (metres: number) => floor - metres * scale
  const marks = (data.units === 'metric' ? metricMarks() : imperialMarks()).filter((mark) => yAt(mark.m) > 90)
  const top = yAt(marks.length ? marks[marks.length - 1].m : 2)

  const at = (style: CSSProperties) => style

  return (
    <div className={on ? 'stage on' : 'stage'}>
      <div key={run}>
        {/* key light on the wall behind the character */}
        <div className="glow" style={at({ left: centre - 520, top: yAt(1.3) - 640, width: 1040, height: 1280 })} />
        <div className="pool" style={at({ left: centre - 640, top: floor - 90, width: 1280, height: 180 })} />

        {/* height chart */}
        <div className="rail" style={at({ left, top, height: floor - top })} />
        <div className="rail" style={at({ left: centre + CHART_HALF, top, height: floor - top })} />
        {marks.map(({ m, major, label, side, key }, i) => (
          <div key={key} style={{ animationDelay: `${0.12 + i * 0.018}s` }} className={major ? 'line major' : 'line'}>
            {major ? (
              <>
                <span className="bar" style={at({ left, top: yAt(m), width: CHART_HALF * 2 })} />
                <span className="label" style={at({ left: left - 82, top: yAt(m) - 8 })}>{label}</span>
                <span className="label unit" style={at({ left: centre + CHART_HALF + 18, top: yAt(m) - 8 })}>{side}</span>
              </>
            ) : (
              <>
                <span className="tick" style={at({ left, top: yAt(m) })} />
                <span className="tick" style={at({ left: centre + CHART_HALF - 26, top: yAt(m) })} />
              </>
            )}
          </div>
        ))}

        {/* floor */}
        <div className="floor" style={at({ left: centre - 760, top: floor, width: 1520 })} />

        {/* slot plate above the chart */}
        <div className="plate" style={at({ left, top: top - 54, width: CHART_HALF * 2 })}>
          <span><b>{pad(data.slot)}</b> / {pad(data.total)}</span>
          <span>{data.empty ? 'Open slot' : data.server}</span>
        </div>
      </div>
    </div>
  )
}

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <Backdrop />
  </StrictMode>,
)
