## Why

Two transitions travel the command boundary: the owner assigning an outcome, and
a runtime handing work back. Every other consequential owner decision — approving
a plan, returning one, answering a help request, accepting a delivery, asking for
a revision — still mutates state directly and leaves no attributable, replayable
record.

This is slice 4 of #23.

## What Changes

- Add one command payload covering the owner's commitment decisions, rather than
  a bespoke command per decision: they share an actor, a target, and the rule
  that only the owner may make them.
- Route the app's five supervision actions through it.
- Make the records those decisions write reproducible, so a journalled decision
  replays to the same state instead of writing new identifiers for the same fact.

## Capabilities

### Modified Capabilities

- `organization-command-boundary`: owner decisions about commitments now travel
  the same path as everything else consequential.

## Non-goals

- Employment lifecycle commands (hire, pause, resume, retire, contract
  revisions). Those are the next slice of this work, not this one.
- Changing any decision's behaviour or review rules.

## Impact

- One new payload case and deterministic identifiers for owner-authored records.
- No model changes and no behaviour change to the decisions themselves.
