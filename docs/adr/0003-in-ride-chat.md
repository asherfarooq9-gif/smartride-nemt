# ADR 0003: In-ride chat between the patient and the driver

- Status: accepted
- Date: 2026-11-08

## Context

Patients and drivers could only phone each other. A phone call is awkward for a
patient who is in pain, hard of hearing, or cannot speak, and the driver cannot
safely take it while driving. The product owner asked for simple in-app chat that
works like inDrive: messages appear at once, and the chat disappears when the ride
ends.

## Decision

1. **Who and when.** Only the ride's own patient and the driver who accepted it,
   and only while a driver has the ride (assigned, on the way, patient on board,
   at the hospital). Admins are not participants. Before a driver accepts, and
   after the ride, the chat is closed (HTTP 409).
2. **Deletion.** Messages are deleted in the same database transaction that
   completes or cancels the ride, or returns it to the queue. A periodic sweep in
   the retention loop removes any left behind by another path. Messages can
   mention health problems, so nothing outlives the trip. Deleting the account or
   the ride cascades.
3. **Delivery.** Sending is a plain `POST`. The server saves the message, then
   publishes it on a Redis channel `ride:{id}:chat`; a WebSocket `/ws/chat/{id}`
   relays it to the open chat screen. The socket is read-only, so there is no
   second write path to secure. If Redis is down the message is still saved and
   the other side catches up by fetching `after_id` when the socket reconnects.
4. **Push.** The other person gets a push notification, "Your driver sent you a
   message", that never contains the text (a lock screen must not show it).
5. **Limits.** 500 characters, plain text only, 30 messages a minute per user.
6. **No history, no attachments, no read receipts** in this version.

## Consequences

- Disputes cannot be settled from chat history, by design.
- The deletion hook lives in `update_ride_status`; a new code path that ends a
  ride without it relies on the sweep (up to six hours) and on the API refusing
  closed chats immediately, so nothing is readable in the meantime.
- Live delivery reuses the GPS socket's authentication, caps and revocation checks.
