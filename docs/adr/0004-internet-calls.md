# ADR 0004: Internet calls between the patient and the driver

- Status: accepted
- Date: 2026-11-08

## Context

Patient and driver could phone each other, which meant each saw the other's real
number, and the patient kept the driver's number in the ride history for good. The
product owner wants inDrive-style contact: chat and calls inside the app, with no
number shown to the other person.

## Decision

1. **Numbers are hidden.** The ride details no longer carry the other person's
   phone number: a driver never gets the patient's, a patient never gets the
   driver's. Each still sees their own, and dispatch (admin) sees both.
2. **Calls are WebRTC voice calls** between the two phones (`flutter_webrtc`).
3. **The server only does set-up.** `WS /ws/call/{ride_id}` passes `invite`,
   `accept`, `decline`, `offer`, `answer`, `ice` and `hangup` between the two
   participants. It rebuilds every message from known fields, sets `from` itself,
   caps sizes and rate, and uses the chat's rule: the ride's own patient or driver,
   while the ride is live. It never sees or records the audio.
4. **Relay: our own coturn.** Mobile networks often cannot connect two phones
   directly, so a TURN relay is required. We run coturn (compose profile `calls`)
   rather than a paid third party, so call traffic stays under our control. The
   backend mints a login per person with coturn's REST-API scheme (username
   `expiry:userid`, password = HMAC of it with the shared secret), valid for one
   hour. Peers on private and loopback addresses are denied so the relay cannot be
   used to reach services inside our network. With no relay configured no login is
   issued.
5. **Ringing works while the app is open (version 1).** A caller whose `invite`
   reaches no open app is told `unreachable`, and the other phone gets a push,
   "Your driver is calling. Open SmartRide to answer." Ringing a locked or closed
   phone (Android full-screen alerts, iOS CallKit) is a later version.
6. **Chat is the fallback** when a call cannot connect, and 1122 stays one tap away.

## Consequences

- A dispute cannot be settled from a recording: there is none.
- Dispatch still has both numbers, so a ride can be handled by phone from the office.
- coturn needs a public address and open UDP ports; see the runbook. Until it is
  deployed, calls connect only when both phones can reach each other directly.
- Microphone permission is requested the first time someone starts or answers a call.
