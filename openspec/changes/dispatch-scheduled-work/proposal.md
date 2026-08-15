## Why

Schedules record when work is expected and receipts record what happened, but
nothing connects them: an occurrence never becomes a run. The calendar shows
windows that pass and turn missed, which is honest and useless.

This is slice 5 of #24, using the runtime presence substrate from #23.

## What Changes

- Start work whose window is open, through the employee pipeline that already
  exists, and record the actual start against the occurrence.
- Register a runtime session for the dispatched work so presence, heartbeats and
  crash recovery apply to scheduled runs exactly as they do to owner-assigned
  ones.
- Close an occurrence with what the commitment actually amounted to, rather than
  assuming success: delivered, quiet, blocked, failed, or never ran.
- Skip an occurrence with a stated reason when its commitment has finished or
  its employee is not hired.
- Keep this foreground-only: nothing claims the Mac will run work while asleep
  or while the app is closed.

## Capabilities

### Modified Capabilities

- `employee-work-schedule`: occurrences can now become runs, and their receipts
  reflect what the run actually amounted to.

## Non-goals

- Background execution of any kind.
- Capacity-aware placement and approval projection (slice 6).
- Dispatching recurring responsibilities; those still start from their own
  surface until their schedule subject is modelled the same way.

## Impact

- Adds dispatch and completion to `AgentOfficeCore` and one call site in the app.
