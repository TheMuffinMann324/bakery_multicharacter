import { useEffect, useRef } from 'react'
import { camera, cameraBasis, project } from '@/lib/mockMap'

// Browser preview only (npm run dev): stands in for the live city under the spawn map. A dark ground
// with a street grid, seen through the same camera as client/spawn.lua. Never rendered inside FiveM.
export default function DevMap() {
  const canvas = useRef<HTMLCanvasElement>(null)

  useEffect(() => {
    let frame = 0
    const draw = () => {
      const el = canvas.current
      if (!el) return
      const w = (el.width = window.innerWidth)
      const h = (el.height = window.innerHeight)
      const g = el.getContext('2d')!
      const sky = g.createLinearGradient(0, 0, 0, h)
      sky.addColorStop(0, '#1d2128')
      sky.addColorStop(1, '#0c0d10')
      g.fillStyle = sky
      g.fillRect(0, 0, w, h)

      const b = cameraBasis()
      const c = camera.cur
      const span = Math.min(9000, c.dist * 3)
      const line = (step: number, alpha: number, width: number) => {
        g.strokeStyle = `rgba(255,255,255,${alpha})`
        g.lineWidth = width
        const x0 = Math.floor((c.x - span) / step) * step
        const y0 = Math.floor((c.y - span) / step) * step
        for (let v = 0; v <= (span * 2) / step; v++) {
          for (const axis of [0, 1]) {
            const k = (axis ? y0 : x0) + v * step
            const pts = []
            for (let t = -span; t <= span; t += span / 20) {
              const p = axis ? project(c.x + t, k, c.z, b) : project(k, c.y + t, c.z, b)
              if (p) pts.push(p)
            }
            g.beginPath()
            pts.forEach((p, i) => (i ? g.lineTo(p.x * w, p.y * h) : g.moveTo(p.x * w, p.y * h)))
            g.stroke()
          }
        }
      }
      line(100, 0.035, 1)
      line(500, 0.08, 2)
      frame = requestAnimationFrame(draw)
    }
    frame = requestAnimationFrame(draw)
    return () => cancelAnimationFrame(frame)
  }, [])

  return <canvas ref={canvas} className="absolute inset-0 size-full" />
}
