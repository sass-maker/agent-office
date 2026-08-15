## Context

Office OS runs employees concurrently with a capacity limit and one active run
per employee, which prevents two runs by the *same* employee but nothing about
two employees touching the same artifact, record, or connection.

Projektor's file claims are the inspiration, but files are the wrong unit here:
the things employees contend over are organization objects.

## Decisions

### Time bounds the claim, not trust

Every lease expires. A holder that goes away — crashed runtime, closed app —
cannot block a resource forever, and no one needs to decide whether it is
"really" still working. This is the same reasoning as runtime presence: a
heartbeat or an expiry, never an assumption.

### Refuse, never preempt

A conflict returns a refusal naming the holder, the purpose, and the expiry.
Automatically breaking someone else's lease would make the lease meaningless,
and the interesting cases (a stuck employee, a long job) are owner decisions.

### Expired leases stay readable

Reconciliation marks leases expired rather than deleting them, so "who was
holding this when it went wrong" is answerable after the fact.
