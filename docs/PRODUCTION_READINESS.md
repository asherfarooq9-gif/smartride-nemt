# Production readiness (2026-11-06)

**Verdict: ready for a supervised pilot in Islamabad/Rawalpindi, not for an open public launch.**
Code and tests are in good shape. What is left is mostly accounts, legal and real-world testing that code cannot supply.

## Done and verified (tests pass)

- Backend: 856 tests, ruff clean. Flutter: 119 core and 320 app tests, analyze clean.
- Auth: bcrypt, login lockout, JWT revocation, log out of all devices, account deletion that anonymizes.
- Duplicate-booking protection in the database; claims, repeat bookings and payment methods have race tests.
- Production guards: the app refuses to boot with DEBUG on, wildcard CORS, a default secret or rate limits off.
- Pickups limited to the pilot area (`SERVICE_AREA_BBOX` in `render.yaml`), minimum ride-leg time, pickup arrival radius, symptom text retention of 90 days.
- A driver is pushed when a claimed scheduled ride starts.

## Open: needs the owner

| Item | Why it matters |
|---|---|
| Paid hosting plan, domain and TLS | The free plan sleeps when idle; an emergency app cannot |
| Firebase and Twilio keys | Push and SMS do nothing without them |
| Android release keystore, Play Store listing | Cannot ship an APK to users otherwise |
| Privacy policy and PHI review, hospital agreements | Legal; health data |
| External penetration test | Never done |
| Real-phone test with real drivers | Only emulator testing so far |
| Alertmanager receiver | Alerts exist but go nowhere |
| Native Urdu speaker review | Wording is unreviewed |

## Open: code, not yet done

- Admin dashboard keeps its token in `localStorage` (needs an httpOnly cookie session).
- Urdu covers only Settings, side menu, Scheduled, booking and delete-account.
- Flutter accessibility labels.
- Redis outage makes token revocation fail open (a documented choice).
- Load test on dispatch was run once (`docs/LOAD_TEST_RESULTS.md`); repeat it against the real hosting plan.
