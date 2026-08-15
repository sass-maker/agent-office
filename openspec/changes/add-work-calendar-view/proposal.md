## Why

#37 gave Office OS durable occurrences, planned-versus-actual execution, and run
receipts — but nothing shows them. The owner can only see scheduled work by
reading JSON. And a missed window stays missed forever, which is honest but not
actionable.

This is slices 3 and 4 of #24: a temporal view across existing surfaces, and an
owner-authored catch-up policy.

## What Changes

- Add a Calendar destination beside Office, Mission, and Company: a day and week
  view derived from schedules, occurrences, and receipts. It shows expected work
  and actual work distinctly, and never invents a block that no policy produced.
- Make each block carry its employee, subject, status, planned window, actual
  run, and receipt headline, reachable by keyboard with non-colour status cues.
- Let the owner skip an upcoming occurrence from the view.
- Add a per-policy catch-up policy — leave a missed window missed, or reschedule
  it into the next window — applied deterministically during reconciliation and
  never executing anything late.

## Capabilities

### Modified Capabilities

- `employee-work-schedule`: adds the owner-authored catch-up decision and the
  calendar projection over existing occurrences.

## Non-goals

- Dispatching scheduled work. Nothing here starts a run; that is slice 5.
- Capacity-aware placement and approval projection (slice 6).
- External calendars, invitations, or meetings.

## Impact

- Adds one navigation destination and a projection helper. No existing surface
  changes behaviour, and Office remains the organization home.
