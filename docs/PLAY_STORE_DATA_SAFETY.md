# Play Store Data Safety — SmartRide Patient App

Source of truth for the Play Console **Data safety** form. This app handles
health and precise location data, so the declaration must be accurate — Google
rejects mismatches between the form and observed behavior.

## Summary

- **Data is encrypted in transit** — HTTPS only; cleartext blocked
  (`network_security_config.xml`), backend sends HSTS.
- **No data sold.** No advertising/marketing sharing.
- Third parties receive data only as processors needed to deliver transport
  (see Sharing below).

## Data collected

| Data type | Category | Collected | Shared | Purpose |
|-----------|----------|-----------|--------|---------|
| Symptom text, mobility needs | Health info (sensitive) | Yes | Hospital (care) | Triage + hospital pre-alert |
| Precise location (pickup, live GPS) | Location | Yes | Assigned driver, hospital | Dispatch + navigation |
| Name, date of birth | Personal info | Yes | Driver, hospital | Identify patient for pickup/care |
| Phone number | Personal info | Yes | Driver (for pickup) | Account + ride coordination |
| Emergency contact name/phone | Personal info (third party) | Yes | No | Family SMS alert on dispatch |
| FCM push token / device id | App activity / IDs | Yes | No | Push notifications |
| Crash logs | App diagnostics | Yes | Firebase (processor) | Crash reporting (Crashlytics) |

## Required answers (Data safety form)

- **Is all data encrypted in transit?** Yes.
- **Do you provide a way to request data deletion?** Currently **no in-app
  deletion** — this is an open item (see `PHI_COMPLIANCE_AUDIT.md` #4). Before
  store submission, either ship an account-deletion path or provide a documented
  deletion request channel (email + SLA) and declare it.
- **Is any collected data required?** Health + location are required to provide
  emergency transport; account data is required to operate.

## Sharing / processors

| Recipient | Data | Why | Not for |
|-----------|------|-----|---------|
| Assigned driver | Name, phone, pickup location, mobility needs | Perform the pickup | (driver does NOT receive raw symptom text — scoped out, see PHI audit #2) |
| Hospital | Patient UUID, specialty, severity, location | Pre-alert for incoming patient | Raw identifiers minimized (FHIR uses UUID, not name) |
| Twilio | Emergency-contact phone + message | Send the family SMS | Marketing |
| Firebase (Google) | Push token, crash logs | Notifications + crash reporting | Ads |

## Pre-submission checklist

- [ ] Account/data-deletion path shipped **or** documented deletion channel declared.
- [ ] Privacy policy URL live and linked in the listing.
- [ ] Form matches this table exactly.
- [ ] Release build signed with the upload key (see `OPERATIONS.md` / `key.properties`).
- [ ] `flutter build appbundle --release --obfuscate --split-debug-info=build/symbols`
      (upload the symbols for crash de-obfuscation).
