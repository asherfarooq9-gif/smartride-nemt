# Product

<!-- impeccable:product-schema 1 -->

Scope: the SmartRide admin dashboard (`admin-dashboard/`). The Flutter apps and the backend are out of scope for this record.

## Platform

web

## Users
Primary: a dispatcher in a control-room situation, watching live rides during a shift and acting when something goes wrong (an emergency waiting too long, a ride with no driver, a hospital not alerted). Secondary, not confirmed: platform owners and project-demo viewers.

## Product Purpose
SmartRide is an emergency and non-emergency medical transport platform piloting in Islamabad and Rawalpindi. The dashboard lets staff see every ride and its state, check drivers, patients and hospitals, verify drivers, and read demand forecasts. Success: a dispatcher spots a problem ride in seconds and reaches the ride, driver or hospital it involves without leaving the page.

## Positioning
A dispatch-first view of medical transport: emergency rides are separated from scheduled ones, and urgency (waiting time, unassigned, hospital not alerted) is the organising idea, not a grid of totals.

## Operating Context
Used on a desktop monitor during a shift, left open for long periods. Data comes from the FastAPI backend at `/api/v1` (rides, drivers, patients, hospitals, analytics). Admin login with phone and password; the token lives in browser storage. Ride states: pending, driver_assigned, driver_en_route, patient_picked_up, arrived_at_hospital, completed, cancelled. Ride types: emergency and scheduled.

## Capabilities and Constraints
- Existing pages: dashboard, rides, drivers, patients, hospitals, analytics, alerts, login.
- No alerts endpoint exists in the backend, so the alerts page has no real data source; any alerts UI must be derived from existing ride data or stay clearly labelled as not connected. Undecided.
- No real-time push channel to the dashboard is confirmed; "live" means polling the existing endpoints. Undecided whether to add a WebSocket feed.
- Stack: Next.js 16 (App Router), TypeScript, Tailwind, lucide-react icons, a charting library already used on the analytics page. Dev server on port 3001 with `NEXT_PUBLIC_API_URL=http://127.0.0.1:18020`; open it as `localhost`, not `127.0.0.1`.
- Do not change the backend, the API contract or the auth architecture as part of design work.
- Patient health data is shown here, so nothing should be logged to the console or put in URLs.

## Brand Commitments
Visual direction pinned by the user (2026-11-02): a light blue-and-white interface, not dark; easy to understand, clearly interactive. Name: SmartRide, "NEMT Admin Portal". No confirmed logo asset: the current header shows an empty box where a logo should be. Not yet decided.

## Evidence on Hand
Real dev data: 24 rides (mostly cancelled test rides), 17 drivers (7 available), 5 hospitals. No real traffic: active rides is 0 and the demand forecast is empty. Future work must not fabricate customers, benchmarks or testimonials; sample data used for screenshots must be labelled as sample.

## Product Principles
1. Urgency first: what needs a human now is the loudest thing on screen.
2. Every row leads to an action: a ride, driver or hospital opens in place, without losing the list.
3. Empty and error states say what happened and what to do next.
4. Calm for a long shift: dense, scannable, readable for hours, no decoration that competes with status.
5. Honest data: never show a placeholder as if it were live.

## Accessibility & Inclusion
Status must never rely on colour alone (label and icon too). Keyboard operable, visible focus, readable contrast, reduced-motion respected. Users read English; names and phone numbers are Pakistani formats.
