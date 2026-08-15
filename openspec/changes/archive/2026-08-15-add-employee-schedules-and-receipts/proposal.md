## Why

Office OS knows what employees owe and what they delivered, but not *when* work
is expected, whether a scheduled run actually happened, or what a run left
behind. Iris's weekly duty carries a single next-due date; there is no durable
record of an occurrence, no separation between planned and actual, and no
receipt that can distinguish "ran and found nothing" from "never ran".

This change delivers the first two slices of #24's order: schedule policies with
durable occurrences, and planned-versus-actual execution with honest receipts.

## What Changes

- Add a schedule policy an employee's commitment or recurring responsibility can
  declare: one-time or recurring, with a window, expected duration, flexibility,
  timezone, and the actor who authored it.
- Generate durable scheduled occurrences with deterministic identifiers, so a
  restart, retry, or clock change cannot produce a duplicate.
- Keep scheduled start and window separate from actual start, end, and duration,
  and give occurrences honest terminal states: delivered, quiet, blocked,
  failed, skipped, cancelled, or missed.
- Add a structured run receipt that records what was scheduled and why, who
  owned it, what actually ran and for how long, which runtime powered it when
  known, what evidence resulted, whether anything changed, and what usage was
  observed, unknown, or not applicable.
- Let the owner pause a policy and skip, move, or cancel future occurrences
  without deleting or rewriting completed ones.
- Reconcile missed windows deterministically on reopen: a window that passed
  without a run becomes missed, never silently successful.

## Capabilities

### New Capabilities

- `employee-work-schedule`: When work is expected, whether it happened, and what
  it left behind — as projections of existing commitments and responsibilities.

### Modified Capabilities

None. Commitments, recurring responsibilities, contracts, and supervision keep
their current behaviour; schedules point at them rather than replacing them.

## Non-goals

- The calendar surface itself (#24 slice 3) and owner catch-up UI (slice 4).
- Capacity-aware placement and approval projection (slices 5 to 7).
- Background execution. Nothing here claims the Mac will run work while asleep
  or the app is closed.
- External calendar accounts, invitations, meetings, or hosted scheduling.

## Impact

- Adds schedule policies, occurrences, and receipts to organization knowledge,
  decoded permissively so existing organizations load unchanged with none.
- No existing model changes shape; no new production dependency.
