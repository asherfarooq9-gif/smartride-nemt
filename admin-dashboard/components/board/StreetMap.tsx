'use client'
import { useEffect, useRef } from 'react'
import type { Map as LeafletMap, LayerGroup } from 'leaflet'
import 'leaflet/dist/leaflet.css'

export type PinKind = 'emergency' | 'ride' | 'available' | 'busy' | 'hospital'
export interface Pin {
  id: string
  kind: PinKind
  lat: number
  lng: number
  label: string
}

// Islamabad and Rawalpindi, shown while there is nothing to fit the view to.
const DEFAULT_CENTER: [number, number] = [33.65, 73.05]
const TILES = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
const ATTRIBUTION = '&copy; <a href="https://www.openstreetmap.org/copyright" rel="noopener noreferrer">OpenStreetMap</a>'

/**
 * Street map. Leaflet touches `window`, so it loads inside an effect and never on the server.
 * The view fits the pins once; after that a refresh moves the markers but not the person's pan or zoom.
 */
export default function StreetMap({ pins }: { pins: Pin[] }) {
  const container = useRef<HTMLDivElement>(null)
  const map = useRef<LeafletMap | null>(null)
  const layer = useRef<LayerGroup | null>(null)
  const hasFitted = useRef(false)
  const latestPins = useRef(pins)

  async function draw(list: Pin[]) {
    const L = await import('leaflet')
    if (!map.current || !layer.current) return
    layer.current.clearLayers()
    for (const p of list) {
      const text = `${p.label}`
      if (p.kind === 'hospital') {
        const icon = L.divIcon({
          className: '',
          iconSize: [22, 22],
          html: '<span class="grid h-[22px] w-[22px] place-items-center rounded-md border-2 border-ink bg-panel-raised text-sm font-bold leading-none text-lamp-red">+</span>',
        })
        L.marker([p.lat, p.lng], { icon, title: text, alt: text }).addTo(layer.current)
      } else {
        L.circleMarker([p.lat, p.lng], {
          radius: p.kind === 'emergency' ? 10 : 7,
          weight: 2,
          fillOpacity: 1,
          className: `pin-${p.kind}`,
        })
          .bindTooltip(text)
          .addTo(layer.current)
      }
    }
    if (!hasFitted.current && list.length > 0) {
      map.current.fitBounds(L.latLngBounds(list.map(p => [p.lat, p.lng] as [number, number])), { padding: [40, 40], maxZoom: 14 })
      hasFitted.current = true
    }
  }

  useEffect(() => {
    let cancelled = false
    import('leaflet').then(L => {
      if (cancelled || !container.current || map.current) return
      const instance = L.map(container.current, { center: DEFAULT_CENTER, zoom: 11 })
      L.tileLayer(TILES, { maxZoom: 19, attribution: ATTRIBUTION }).addTo(instance)
      map.current = instance
      layer.current = L.layerGroup().addTo(instance)
      void draw(latestPins.current)
    })
    return () => {
      cancelled = true
      map.current?.remove()
      map.current = null
      layer.current = null
      hasFitted.current = false
    }
  }, [])

  useEffect(() => {
    latestPins.current = pins
    void draw(pins)
  }, [pins])

  return <div ref={container} className="street-map h-[34rem] w-full rounded-xl" role="application" aria-label="Street map of rides, drivers and hospitals" />
}
