## Decisions

### Dispatch reads state; it does not invent it

`beginScheduledWork` returns what happened — dispatched, not due, or skipped with
a reason — rather than throwing. An employee who is paused or a commitment that
already finished is an ordinary state of the world, not an error, and the owner
should see the reason in the calendar rather than a failure.

### Completion asks the commitment

The receipt's result is read from the commitment's own state rather than assumed
from the fact that a run happened. A run that delivered nothing is quiet; a run
that never started is neither quiet nor failed. This is the distinction the whole
receipt model exists to preserve.

### Foreground only, stated plainly

Dispatch happens while the app is open. Nothing here schedules background
execution, and #24 explicitly forbids implying otherwise.
