# Phase 4 service-booking entry slice

## Implemented baseline

The customer application now consumes the booking contract pinned to backend
commit `bf0b8b1cf01e559dccca030e237459e882dc0331`.

- Service discovery uses a serviceable saved address and shows verified-provider
  trust, ratings, completed work, live engagements, duration and payment policy.
- Live slots show timezone, remaining/capacity and authoritative price. Selecting
  a slot creates an expiring server hold and displays its countdown.
- Booking supports wallet, Razorpay and Paystack methods. Provider payments use
  native handoff while capture remains server-confirmed.
- Booking activity displays authoritative status, revision, payment, amount due,
  free-reschedule balance, allowed actions and timeline.
- Rescheduling first locks the replacement slot and requires a reason.
  Cancellation, completion confirmation and disputes are server-policy gated.
- The customer start code is displayed only when returned for that role. Provider
  completion evidence is required before customer confirmation.
- Contract/unit/controller/widget coverage includes a 390 x 844 viewport at 130%
  text. `MOB-E2E-004` covers hold -> payment -> reschedule -> start code ->
  completion evidence -> customer confirmation.

## Boundary

This is the Phase 4 entry slice, not the Phase 4 exit. Vendor KYC and operations,
food, rider fulfilment, messaging, settlement, franchise operations and paired
acceptance journeys remain in the active backlog.
