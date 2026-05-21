export default function Home() {
  const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000'

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">Dashboard</h1>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-8">
        <StatCard label="Active Rides" value="—" color="blue" />
        <StatCard label="Available Drivers" value="—" color="green" />
        <StatCard label="Hospitals Online" value="5" color="purple" />
      </div>
      <p className="text-sm text-gray-500">API: {apiUrl} — implement analytics in Milestone 7</p>
    </div>
  )
}

function StatCard({ label, value, color }: { label: string; value: string; color: string }) {
  const colors: Record<string, string> = {
    blue: 'border-blue-500 bg-blue-50',
    green: 'border-green-500 bg-green-50',
    purple: 'border-purple-500 bg-purple-50',
  }
  return (
    <div className={`rounded-lg border-l-4 p-5 shadow-sm ${colors[color] ?? ''}`}>
      <p className="text-sm text-gray-500 uppercase tracking-wide">{label}</p>
      <p className="text-3xl font-bold mt-1">{value}</p>
    </div>
  )
}
