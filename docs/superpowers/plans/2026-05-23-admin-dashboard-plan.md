# SmartRide Admin Dashboard Improvement Plan (Stage 8)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add empty states, fix the missing error-reset bug in HospitalsPage, extract a shared DataTable component, and eliminate repeated table markup across all admin pages.

**Architecture:** Next.js 14 App Router, TypeScript, Tailwind CSS. All data-fetching pages live under `admin-dashboard/app/`. Shared UI components live under `admin-dashboard/components/ui/`. The `lib/api.ts` file holds all typed API calls and response interfaces — no `any` types exist there and must stay that way.

**Tech Stack:** Next.js 14, React 18, TypeScript 5, Tailwind CSS 3, Lucide React.

---

### Task 1: Fix Missing Error-Reset in HospitalsPage

**Files:**
- Modify: `admin-dashboard/app/hospitals/page.tsx`

The `load` function in HospitalsPage never calls `setError('')` before a retry, so a previous error message persists even after a successful reload.

- [ ] **Step 1: Locate the load function**

Open `admin-dashboard/app/hospitals/page.tsx`. Find the `load` function (inside `useCallback`). It currently starts with:

```typescript
const load = useCallback(async () => {
  setLoading(true)
  try {
    const d = await api.hospitals()
```

- [ ] **Step 2: Add the error reset**

Change it to:

```typescript
const load = useCallback(async () => {
  setLoading(true)
  setError('')
  try {
    const d = await api.hospitals()
```

- [ ] **Step 3: Verify TypeScript compiles**

```bash
cd admin-dashboard && npx tsc --noEmit
```
Expected: zero errors.

- [ ] **Step 4: Commit**

```bash
git add admin-dashboard/app/hospitals/page.tsx
git commit -m "fix: clear error state before retry in HospitalsPage"
```

---

### Task 2: Create Shared EmptyState Component

**Files:**
- Create: `admin-dashboard/components/ui/EmptyState.tsx`

All list pages (rides, drivers, hospitals, patients) render an empty table with no message when the API returns zero items. Add a reusable EmptyState.

- [ ] **Step 1: Create the component**

```tsx
// admin-dashboard/components/ui/EmptyState.tsx
import { type LucideIcon } from 'lucide-react'

interface EmptyStateProps {
  icon: LucideIcon
  title: string
  description?: string
}

export default function EmptyState({ icon: Icon, title, description }: EmptyStateProps) {
  return (
    <div className="flex flex-col items-center justify-center py-16 text-center">
      <div className="rounded-full bg-blue-50 p-4 mb-4">
        <Icon className="text-blue-300" size={32} />
      </div>
      <p className="text-blue-900 font-semibold text-base">{title}</p>
      {description && (
        <p className="text-gray-400 text-sm mt-1 max-w-xs">{description}</p>
      )}
    </div>
  )
}
```

- [ ] **Step 2: Verify TypeScript compiles**

```bash
cd admin-dashboard && npx tsc --noEmit
```
Expected: zero errors.

- [ ] **Step 3: Commit**

```bash
git add admin-dashboard/components/ui/EmptyState.tsx
git commit -m "feat: add shared EmptyState component for zero-data pages"
```

---

### Task 3: Add Empty State to RidesPage

**Files:**
- Modify: `admin-dashboard/app/rides/page.tsx`

When `rides.length === 0` and `!loading`, the page renders an empty table with no feedback. Show EmptyState instead.

- [ ] **Step 1: Add the import**

At the top of `admin-dashboard/app/rides/page.tsx`, add:

```typescript
import EmptyState from '@/components/ui/EmptyState'
import { Car } from 'lucide-react'
```

(`Car` is already imported — just add `EmptyState`.)

- [ ] **Step 2: Locate the table body**

Find the `<tbody>` that renders `rides.map(...)`. It will look like:

```tsx
<tbody>
  {loading ? (
    <LoadingRows cols={6} />
  ) : (
    rides.map(r => (
      <tr key={r.id} ...>
```

- [ ] **Step 3: Add the empty state branch**

Replace the inner content with:

```tsx
<tbody>
  {loading ? (
    <LoadingRows cols={6} />
  ) : rides.length === 0 ? (
    <tr>
      <td colSpan={6}>
        <EmptyState
          icon={Car}
          title="No rides found"
          description={search || statusFilter || typeFilter ? 'Try adjusting your filters.' : 'Rides will appear here once patients book.'}
        />
      </td>
    </tr>
  ) : (
    rides.map(r => (
      <tr key={r.id} ...>
```

- [ ] **Step 4: Verify TypeScript**

```bash
cd admin-dashboard && npx tsc --noEmit
```
Expected: zero errors.

- [ ] **Step 5: Commit**

```bash
git add admin-dashboard/app/rides/page.tsx
git commit -m "feat: add empty state to rides table"
```

---

### Task 4: Add Empty State to DriversPage

**Files:**
- Modify: `admin-dashboard/app/drivers/page.tsx`

- [ ] **Step 1: Add imports**

At the top of `admin-dashboard/app/drivers/page.tsx`:

```typescript
import EmptyState from '@/components/ui/EmptyState'
import { Users } from 'lucide-react'
```

(`Users` is already imported — just add `EmptyState`.)

- [ ] **Step 2: Find the tbody and add empty branch**

Locate the `<tbody>` rendering `drivers.map(...)` and replace with:

```tsx
<tbody>
  {loading ? (
    <LoadingRows cols={6} />
  ) : drivers.length === 0 ? (
    <tr>
      <td colSpan={6}>
        <EmptyState
          icon={Users}
          title="No drivers found"
          description={search || statusFilter || verifiedFilter ? 'Try adjusting your filters.' : 'Registered drivers will appear here.'}
        />
      </td>
    </tr>
  ) : (
    drivers.map(d => (
      <tr key={d.id} ...>
```

- [ ] **Step 3: Verify TypeScript**

```bash
cd admin-dashboard && npx tsc --noEmit
```
Expected: zero errors.

- [ ] **Step 4: Commit**

```bash
git add admin-dashboard/app/drivers/page.tsx
git commit -m "feat: add empty state to drivers table"
```

---

### Task 5: Add Empty State to HospitalsPage

**Files:**
- Modify: `admin-dashboard/app/hospitals/page.tsx`

- [ ] **Step 1: Add imports**

```typescript
import EmptyState from '@/components/ui/EmptyState'
import { Building2 } from 'lucide-react'
```

(`Building2` is already imported — just add `EmptyState`.)

- [ ] **Step 2: Find the hospital list render**

Hospitals renders a grid or list of cards rather than a table. Find where `hospitals.map(...)` is called and wrap it:

```tsx
{loading ? (
  <LoadingRows cols={4} />
) : hospitals.length === 0 ? (
  <EmptyState
    icon={Building2}
    title="No hospitals yet"
    description="Add a hospital using the button above."
  />
) : (
  hospitals.map(h => (
    // existing hospital card JSX
  ))
)}
```

- [ ] **Step 3: Verify TypeScript**

```bash
cd admin-dashboard && npx tsc --noEmit
```
Expected: zero errors.

- [ ] **Step 4: Commit**

```bash
git add admin-dashboard/app/hospitals/page.tsx
git commit -m "feat: add empty state to hospitals list"
```

---

### Task 6: Add Empty State to PatientsPage

**Files:**
- Modify: `admin-dashboard/app/patients/page.tsx`

- [ ] **Step 1: Add imports**

```typescript
import EmptyState from '@/components/ui/EmptyState'
import { UserCircle } from 'lucide-react'
```

(`UserCircle` is already imported — just add `EmptyState`.)

- [ ] **Step 2: Find the patients tbody and add empty branch**

```tsx
<tbody>
  {loading ? (
    <LoadingRows cols={5} />
  ) : patients.length === 0 ? (
    <tr>
      <td colSpan={5}>
        <EmptyState
          icon={UserCircle}
          title="No patients found"
          description={search ? 'Try a different search term.' : 'Registered patients will appear here.'}
        />
      </td>
    </tr>
  ) : (
    patients.map(p => (
      <tr key={p.id} ...>
```

- [ ] **Step 3: Verify TypeScript**

```bash
cd admin-dashboard && npx tsc --noEmit
```
Expected: zero errors.

- [ ] **Step 4: Commit**

```bash
git add admin-dashboard/app/patients/page.tsx
git commit -m "feat: add empty state to patients table"
```

---

### Task 7: Extract Shared DataTable Component

**Files:**
- Create: `admin-dashboard/components/ui/DataTable.tsx`
- Modify: `admin-dashboard/app/rides/page.tsx`

Rides, Drivers, and Patients all repeat the same `<table>` + `<thead>` + `<tbody>` + pagination scaffold. Extract it into a typed `DataTable` component.

- [ ] **Step 1: Create DataTable.tsx**

```tsx
// admin-dashboard/components/ui/DataTable.tsx
import { ChevronLeft, ChevronRight } from 'lucide-react'

interface Column<T> {
  header: string
  key: keyof T | string
  render: (row: T) => React.ReactNode
  className?: string
}

interface DataTableProps<T> {
  columns: Column<T>[]
  rows: T[]
  keyFn: (row: T) => string
  loading: boolean
  loadingCols?: number
  emptySlot?: React.ReactNode
  page: number
  totalPages: number
  onPageChange: (p: number) => void
}

import LoadingRows from './LoadingRows'

export default function DataTable<T>({
  columns,
  rows,
  keyFn,
  loading,
  loadingCols,
  emptySlot,
  page,
  totalPages,
  onPageChange,
}: DataTableProps<T>) {
  return (
    <div className="bg-white border border-blue-100 rounded-2xl shadow-sm overflow-hidden">
      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead className="bg-blue-50 text-blue-700 text-xs uppercase tracking-wider">
            <tr>
              {columns.map(col => (
                <th
                  key={String(col.key)}
                  className={`px-4 py-3 text-left font-semibold ${col.className ?? ''}`}
                >
                  {col.header}
                </th>
              ))}
            </tr>
          </thead>
          <tbody className="divide-y divide-blue-50">
            {loading ? (
              <LoadingRows cols={loadingCols ?? columns.length} />
            ) : rows.length === 0 ? (
              emptySlot ? (
                <tr>
                  <td colSpan={columns.length}>{emptySlot}</td>
                </tr>
              ) : null
            ) : (
              rows.map(row => (
                <tr
                  key={keyFn(row)}
                  className="hover:bg-blue-50/40 transition-colors"
                >
                  {columns.map(col => (
                    <td
                      key={String(col.key)}
                      className={`px-4 py-3 ${col.className ?? ''}`}
                    >
                      {col.render(row)}
                    </td>
                  ))}
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {totalPages > 1 && (
        <div className="flex items-center justify-between px-4 py-3 border-t border-blue-50 text-sm text-gray-500">
          <span>Page {page} of {totalPages}</span>
          <div className="flex gap-2">
            <button
              onClick={() => onPageChange(page - 1)}
              disabled={page <= 1}
              className="p-1.5 rounded-lg hover:bg-blue-50 disabled:opacity-30 disabled:cursor-not-allowed transition"
            >
              <ChevronLeft size={16} />
            </button>
            <button
              onClick={() => onPageChange(page + 1)}
              disabled={page >= totalPages}
              className="p-1.5 rounded-lg hover:bg-blue-50 disabled:opacity-30 disabled:cursor-not-allowed transition"
            >
              <ChevronRight size={16} />
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
```

- [ ] **Step 2: Verify TypeScript**

```bash
cd admin-dashboard && npx tsc --noEmit
```
Expected: zero errors.

- [ ] **Step 3: Replace the rides table with DataTable**

In `admin-dashboard/app/rides/page.tsx`, delete the existing `<div className="bg-white ..."><table>...</table></div>` + pagination block and replace with:

```tsx
import DataTable from '@/components/ui/DataTable'
import EmptyState from '@/components/ui/EmptyState'
import { Car } from 'lucide-react'

// Inside the return JSX:
<DataTable
  columns={[
    { header: 'Type', key: 'ride_type', render: r => <span className={`text-xs font-bold px-2 py-0.5 rounded-full ${r.ride_type === 'emergency' ? 'bg-red-100 text-red-700' : 'bg-blue-100 text-blue-700'}`}>{r.ride_type}</span> },
    { header: 'Status', key: 'status', render: r => <StatusBadge status={r.status} /> },
    { header: 'Pickup', key: 'pickup_address', render: r => <span className="text-gray-600 text-xs">{r.pickup_address ?? `${r.pickup_lat?.toFixed(4)}, ${r.pickup_lng?.toFixed(4)}`}</span> },
    { header: 'Requested', key: 'requested_at', render: r => <span className="text-gray-400 text-xs">{new Date(r.requested_at).toLocaleString()}</span> },
    { header: '', key: 'id', render: r => <button onClick={() => openDetail(r.id)} className="text-blue-600 hover:underline text-xs">Detail</button> },
  ]}
  rows={rides}
  keyFn={r => r.id}
  loading={loading}
  emptySlot={
    <EmptyState
      icon={Car}
      title="No rides found"
      description={search || statusFilter || typeFilter ? 'Try adjusting your filters.' : 'Rides will appear here once patients book.'}
    />
  }
  page={page}
  totalPages={pages}
  onPageChange={setPage}
/>
```

- [ ] **Step 4: Verify TypeScript and spot-check the page renders**

```bash
cd admin-dashboard && npx tsc --noEmit
```
Expected: zero errors.

- [ ] **Step 5: Commit**

```bash
git add admin-dashboard/components/ui/DataTable.tsx admin-dashboard/app/rides/page.tsx
git commit -m "feat: extract shared DataTable component and use it in rides page"
```

---

### Task 8: Use DataTable in DriversPage and PatientsPage

**Files:**
- Modify: `admin-dashboard/app/drivers/page.tsx`
- Modify: `admin-dashboard/app/patients/page.tsx`

- [ ] **Step 1: Replace drivers table**

In `admin-dashboard/app/drivers/page.tsx`, replace the table + pagination with:

```tsx
import DataTable from '@/components/ui/DataTable'
import EmptyState from '@/components/ui/EmptyState'
import { Users } from 'lucide-react'

<DataTable
  columns={[
    { header: 'Name', key: 'full_name', render: d => <span className="font-medium text-blue-900">{d.full_name}</span> },
    { header: 'Phone', key: 'phone', render: d => <span className="text-gray-500 text-xs">{d.phone}</span> },
    { header: 'Status', key: 'status', render: d => <StatusBadge status={d.status} /> },
    { header: 'Vehicle', key: 'vehicle_plate', render: d => <span className="text-gray-600 text-xs">{d.vehicle_plate}</span> },
    { header: 'Verified', key: 'is_verified', render: d => d.is_verified
      ? <CheckCircle size={16} className="text-green-500" />
      : <XCircle size={16} className="text-red-400" /> },
    { header: '', key: 'id', render: d => (
      <div className="flex gap-2">
        <button onClick={() => setSelected(d)} className="text-blue-600 hover:underline text-xs">Detail</button>
        <button
          onClick={() => verify(d.id, !d.is_verified)}
          disabled={verifying === d.id}
          className="text-xs text-gray-500 hover:text-blue-600 disabled:opacity-40"
        >
          {d.is_verified ? 'Unverify' : 'Verify'}
        </button>
      </div>
    )},
  ]}
  rows={drivers}
  keyFn={d => d.id}
  loading={loading}
  emptySlot={
    <EmptyState
      icon={Users}
      title="No drivers found"
      description={search || statusFilter || verifiedFilter ? 'Try adjusting your filters.' : 'Registered drivers will appear here.'}
    />
  }
  page={page}
  totalPages={pages}
  onPageChange={setPage}
/>
```

- [ ] **Step 2: Replace patients table**

In `admin-dashboard/app/patients/page.tsx`, replace the table + pagination with:

```tsx
import DataTable from '@/components/ui/DataTable'
import EmptyState from '@/components/ui/EmptyState'
import { UserCircle } from 'lucide-react'

<DataTable
  columns={[
    { header: 'Name', key: 'full_name', render: p => <span className="font-medium text-blue-900">{p.full_name}</span> },
    { header: 'Phone', key: 'phone', render: p => <span className="text-gray-500 text-xs">{p.phone}</span> },
    { header: 'Date of Birth', key: 'date_of_birth', render: p => <span className="text-gray-400 text-xs">{p.date_of_birth ? new Date(p.date_of_birth).toLocaleDateString() : '—'}</span> },
    { header: 'Emergency Contact', key: 'emergency_contact_phone', render: p => <span className="text-gray-400 text-xs">{p.emergency_contact_phone ?? '—'}</span> },
    { header: '', key: 'id', render: p => <button onClick={() => setSelected(p)} className="text-blue-600 hover:underline text-xs">Detail</button> },
  ]}
  rows={patients}
  keyFn={p => p.id}
  loading={loading}
  emptySlot={
    <EmptyState
      icon={UserCircle}
      title="No patients found"
      description={search ? 'Try a different search term.' : 'Registered patients will appear here.'}
    />
  }
  page={page}
  totalPages={pages}
  onPageChange={setPage}
/>
```

- [ ] **Step 3: Verify TypeScript**

```bash
cd admin-dashboard && npx tsc --noEmit
```
Expected: zero errors.

- [ ] **Step 4: Commit**

```bash
git add admin-dashboard/app/drivers/page.tsx admin-dashboard/app/patients/page.tsx
git commit -m "refactor: use shared DataTable in drivers and patients pages"
```

---

## Final Verification

- [ ] TypeScript clean: `cd admin-dashboard && npx tsc --noEmit`
- [ ] Production build succeeds: `cd admin-dashboard && npm run build`
- [ ] All four list pages show a labelled empty state when the list is empty
- [ ] Retrying after an error in HospitalsPage clears the previous error message
