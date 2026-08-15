## Context

`RuntimeBinding` says which runtime an employee *uses*. Nothing says whether that
runtime is running right now. The existing `resetInterrupted*` helpers already
handle "the app died mid-run" for research, duties, and outcomes, but they infer
it from work state rather than from the runtime itself.

## Decisions

### Presence is persisted, and treated as suspect on load

Presence lives in organization knowledge so a restart can see what was running.
It is never trusted on load: anything still "working" after a reopen is stopped
with a reason, because a process cannot survive the app that hosted it.

### Reconciliation is time-driven, not event-driven

A session becomes unreachable when its heartbeat ages past a timeout, evaluated
whenever reconciliation runs. That keeps the rule deterministic and testable
without a timer, and idempotent when it runs twice.

### Loss blocks, never completes

A lost runtime produces a blocked commitment with a readable reason. It never
marks work delivered, never retires the employee, and never retries on its own.
Deciding what to do about lost work is the owner's, and the honest intermediate
state is "blocked because the runtime went away".
