## Decisions

### Waiting is not skipping

A capacity condition is temporary, so the occurrence stays due and is tried
again. Skipping is for things that will never become startable — a finished
commitment, an unhired employee. Conflating them would either drop work that was
merely busy, or retry work that can never run.

### The host supplies only what the organization cannot see

`DispatchCapacity` carries one fact: whether the employee's runtime is reachable.
Everything else — who is working, how many are running, whether a plan is
reviewed, whether a connection exists — is already organization state, and asking
the host for it would invite two answers to the same question.

### Responsibilities reuse their own occurrence

A scheduled responsibility begins the duty occurrence the domain already models
and dispatches its canonical commitment. Giving schedules a second execution path
for duties is exactly the parallel work model #24 forbids.
