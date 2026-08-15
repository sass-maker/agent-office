## Why

Office OS holds memory, policies, skills, decisions, commitments, contracts, and
artifacts, and now records an append-only history of how state came to be. None
of it is searchable, and none of it is filtered by what a given employee is
actually allowed to see. Meanwhile the journal can answer "how did this get
here" but nothing asks it.

This is slice 7 of #23: permission-aware retrieval, historical inspection, and
flow evidence derived from what was retained rather than inferred from prose.

## What Changes

- Add one retrieval service over allowed company knowledge, filtered by the
  employee's working contract, grants, and current commitment.
- Return provenance with every result, so retrieval cannot quietly become new
  company truth.
- Add historical inspection: how an employee, contract, commitment, or artifact
  reached its current state, read from retained events in sequence order.
- Derive waiting, working, blocked, review, delivery, and owner-decision timing
  from retained records, presenting it as supervision evidence with an explicit
  basis — never as a productivity score.

## Capabilities

### New Capabilities

- `organization-knowledge-retrieval`: Permission-filtered search across company
  knowledge with provenance, plus history and timing derived from retained
  records.

## Non-goals

- A second wiki, index, or knowledge database. This reads what already exists.
- Ranking employees, scoring output, or treating volume as value.
- Embeddings or any external service.

## Impact

- Adds a retrieval and history service to `AgentOfficeCore`. No model changes,
  no new storage, no new dependency.
