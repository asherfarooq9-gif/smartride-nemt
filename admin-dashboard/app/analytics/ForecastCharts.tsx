'use client'
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,
  LineChart, Line, Legend,
} from 'recharts'
import { CHART_HEIGHT } from './chartHeight'

export interface ChartPoint {
  time: string
  rides: number
}

const AXIS_TICK = { fontSize: 11, fill: 'rgb(var(--c-dim))' }
const TOOLTIP_STYLE = { borderRadius: '12px', border: '1px solid rgb(var(--c-edge))', background: 'rgb(var(--c-raised))', color: 'rgb(var(--c-ink))', fontSize: 12 }

/** Kept in its own file so recharts loads only when a chart is drawn (next/dynamic). */
export default function ForecastCharts({ data, variant }: { data: ChartPoint[]; variant: 'forecast' | 'volume' }) {
  if (variant === 'forecast') {
    return (
      <ResponsiveContainer width="100%" height={CHART_HEIGHT}>
        <BarChart data={data} margin={{ top: 5, right: 20, left: 0, bottom: 5 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="rgb(var(--c-edge))" />
          <XAxis dataKey="time" tick={AXIS_TICK} />
          <YAxis tick={AXIS_TICK} />
          <Tooltip contentStyle={TOOLTIP_STYLE} formatter={(v: number) => [`${v} rides`, 'Predicted']} />
          <Bar dataKey="rides" fill="rgb(var(--c-steel))" radius={[6, 6, 0, 0]} />
        </BarChart>
      </ResponsiveContainer>
    )
  }
  return (
    <ResponsiveContainer width="100%" height={CHART_HEIGHT}>
      <LineChart data={data} margin={{ top: 5, right: 20, left: 0, bottom: 5 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="rgb(var(--c-edge))" />
        <XAxis dataKey="time" tick={AXIS_TICK} />
        <YAxis tick={AXIS_TICK} />
        <Tooltip contentStyle={TOOLTIP_STYLE} />
        <Legend />
        <Line type="monotone" dataKey="rides" stroke="rgb(var(--c-steel))" strokeWidth={2} dot={{ r: 3, fill: 'rgb(var(--c-steel))' }} name="Predicted rides" />
      </LineChart>
    </ResponsiveContainer>
  )
}
