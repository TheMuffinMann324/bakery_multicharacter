import { useEffect, useRef, useState } from 'react'
import type { Anchor, OpenData, PosterData, View } from '@/lib/types'

// Browser preview only (npm run dev): stands in for the game. Grey figures where the peds would be,
// and the backdrop page in an iframe where the game draws the DUI behind the selected character.
// Never rendered inside FiveM.
export default function DevStage({ view, data, slot, anchors, hover }: { view: View; data: OpenData; slot: number; anchors: Anchor[]; hover: number | null }) {
  const frame = useRef<HTMLIFrameElement>(null)
  const [scale, setScale] = useState(1)
  const single = view !== 'lineup'
  const character = data.characters.find((c) => c.slot === slot)

  useEffect(() => {
    const fit = () => setScale(window.innerHeight / 1080)
    fit()
    window.addEventListener('resize', fit)
    return () => window.removeEventListener('resize', fit)
  }, [])

  useEffect(() => {
    const send = (action: string, payload?: PosterData) => frame.current?.contentWindow?.postMessage({ action, data: payload }, '*')
    if (!single) return send('hide')
    // what client/backdrop.lua works out with the default config
    send('show', { server: data.server, slot, total: data.slots, empty: !character, scale: 412, floor: 1035, centre: 960, units: 'imperial' })
  }, [single, slot, character, data.server, data.slots])

  return (
    <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_50%_35%,#2b2e36,#08090b_75%)]">
      <iframe
        ref={frame}
        title="backdrop"
        src="./dui.html"
        className="pointer-events-none absolute top-0 left-1/2 origin-top border-0"
        style={{ width: 1920, height: 1080, transform: `translateX(-50%) scale(${scale})`, opacity: single ? 1 : 0 }}
      />
      {single ? (
        <Figure style={{ left: '50%', top: '13%', height: '150%', opacity: character ? 1 : 0.6 }} />
      ) : (
        anchors.map((a) => {
          const ghost = !data.characters.some((c) => c.slot === a.slot)
          return (
            <div key={a.slot}>
              <Figure style={{ left: `${a.x * 100}%`, top: `${a.top * 100}%`, height: `${(a.bottom - a.top) * 100}%`, opacity: ghost ? (hover === a.slot ? 0.5 : 0.25) : 1 }} />
              <span
                className="absolute h-3 -translate-x-1/2 -translate-y-1/2 rounded-[50%] border-2 transition-colors"
                style={{ left: `${a.x * 100}%`, top: `${a.bottom * 100}%`, width: `${a.width * 55}%`, borderColor: hover === a.slot ? '#fff' : 'rgba(255,255,255,0.2)' }}
              />
            </div>
          )
        })
      )}
    </div>
  )
}

function Figure({ style }: { style: React.CSSProperties }) {
  return (
    <svg viewBox="0 0 100 280" className="absolute -translate-x-1/2 transition-opacity" style={style} preserveAspectRatio="xMidYMin meet">
      <g fill="#3a3d45">
        <circle cx="50" cy="22" r="16" />
        <path d="M22 50 Q50 38 78 50 L84 130 L72 132 L68 80 L66 150 L64 276 L52 276 L50 170 L48 276 L36 276 L34 150 L32 80 L28 132 L16 130 Z" />
      </g>
    </svg>
  )
}
