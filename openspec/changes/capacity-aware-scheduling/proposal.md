## Why

Scheduled work now runs, but it runs blindly: it ignores whether the employee is
already busy, whether the organization is at its concurrency limit, whether the
runtime is reachable, whether a plan is still awaiting review, and whether a
required connection exists. It also cannot start a recurring responsibility.

This is slices 6 and 7 of #24.

## What Changes

- Defer an occurrence, with a stated reason, when a bounded capacity condition
  is in the way: runtime unavailable, employee already working, organization at
  its concurrency limit, plan awaiting review, or a required connection missing.
- Keep a deferred occurrence due rather than skipping it, so it starts on a
  later pass once the condition clears.
- Start recurring responsibilities from their schedule by beginning the
  occurrence they already define and dispatching its canonical commitment.

## Capabilities

### Modified Capabilities

- `employee-work-schedule`: dispatch is now capacity-aware and covers recurring
  responsibilities as well as commitments.

## Non-goals

- Vendor quota models. Model or provider quota data is not the organization's
  capacity model.
- Automatic optimisation. Placement follows owner-authored policy and existing
  limits; nothing is reordered to look busier.

## Impact

- Extends dispatch in `AgentOfficeCore` and passes runtime availability from the
  app, which is the only capacity fact the organization cannot see for itself.
