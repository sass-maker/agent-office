## Context

Everything this needs already exists: memory entries, skills, contracts,
commitments, artifacts, supervision events, and — since the journal — an
append-only record of accepted transitions. What is missing is a way to ask.

## Decisions

### One service, no second store

Retrieval reads the existing collections. Adding an index or a wiki would create
a second truth that can disagree with the first, which is exactly what #23
forbids.

### Scope is computed per query, not cached

Visibility depends on the employee's contract, grants, and current commitment,
all of which change. Computing scope per query keeps a revoked grant from
lingering in a stale index.

### Provenance is mandatory

A result without a source is an assertion. Every result names the record it came
from and why it was in scope, so a retrieved passage stays a citation rather
than becoming new company truth.

### Unknown beats zero

A phase that never happened reports unknown, not `0`. Zero is a measurement;
unknown is the truth when nothing was recorded — the same rule the run receipts
already follow for usage.
