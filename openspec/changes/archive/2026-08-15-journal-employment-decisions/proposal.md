## Why

Commitment decisions travel the command boundary, but employment decisions —
hiring, pausing, resuming, retiring — still mutate state directly. Who works
here is at least as consequential as what a hired employee is doing, and it left
no attributable, replayable record.

This finishes slice 4 of #23 for the app's owner actions.

## What Changes

- Add an employment decision payload and route hire, pause, resume, and retire
  through the organization command boundary.
- Restrict them to the owner: a runtime cannot retire a coworker.
- Make the records they write reproducible, so a journalled employment decision
  replays to the same state.

## Capabilities

### Modified Capabilities

- `organization-command-boundary`: employment decisions now travel the same path
  as commitment decisions.

## Non-goals

- Working-contract revisions, which carry a much wider payload and deserve their
  own change.
- Changing any employment rule or its existing guards.

## Impact

- One payload case and deterministic identifiers for employment records.
