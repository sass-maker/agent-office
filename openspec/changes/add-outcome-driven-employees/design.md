## Context

Agent Office already persists employees, skills, tasks, blockers, artifacts,
memory, permissions, and an attributable activity trail. It also has one local
execution boundary shared by the fixed workday, research assignment, and
recurring duty. The new slice should make those primitives usable through the
primary Office without turning the product into a workflow builder.

The approved visual system is the monochrome Editorial Office: black structural
chrome, warm paper, face-first portraits, serif editorial hierarchy, no top or
bottom application bar, and a large illustrated workplace. This change is a
preserve-lane extension of that system.

## Goals / Non-Goals

**Goals:**

- Make “select employee → assign outcome → employee plans → employee works →
  employee delivers or asks for help” usable today.
- Let the employee create a bounded set of ordinary task-board tickets from its
  own plan and choose relevant assigned skills.
- Communicate every material transition through persisted attributable state.
- Make employee position, labels, and motion explain real work state.

**Non-Goals:**

- Concurrent autonomous employees, background work while the app is closed,
  arbitrary command execution, computer use, external writes, publishing,
  credentials, new permissions, or a generic workflow editor.
- Unlimited planning or retry loops, manager review graphs, hierarchy-driven
  delegation, or organization-wide scheduling.
- New character art, a new office topology, or a departure from the approved
  black-and-white design language.

## Decisions

### Store one generic outcome assignment beside organizational knowledge

An `EmployeeOutcome` records the requested outcome, assignee, chosen skills,
created task identifiers, produced artifacts, current status, help request,
delivery summary, attempts, and timestamps. The POC allows only one
non-terminal generic employee outcome across the organization so the existing
single local execution boundary remains truthful.

The fixed content day, Nia research, and Iris duty remain unchanged. Generic
outcome tickets reuse `WorkTask` and carry a stable outcome-id prefix instead of
introducing another task board.

### Separate planning from execution but keep one bounded engine

The employee runner first receives a planning request and returns one to four
structured ticket proposals. The engine validates the plan, creates those
tickets, then executes them sequentially. Each ticket produces at most one
local Markdown artifact. Demo mode returns an explicit synthetic plan and
artifacts; Local Codex receives the employee's responsibility, organization
context, memory, assigned skills, and existing capability grants.

Planning and execution stop after one plan and four tickets. Failures become a
precise blocker or help request rather than triggering open-ended reflection.

### Make Communication foundational behavior

`communication` is a built-in skill assigned to every AI employee during seed
and migration. It requires the employee to acknowledge the outcome, announce
the ticket plan, record meaningful progress, state a precise blocker and owner
ask when blocked, and leave a concise delivery summary. These messages use the
existing `Activity` timeline so they are attributable and inspectable.

Communication does not imply chat. It is the minimum protocol that makes an
employee supervisable.

### Bound autonomy at the capability edge

Employees may choose task order and operation from their assigned skills, but
may use only capabilities already granted to them. If a planned research ticket
requires web access and the employee lacks it, the outcome enters `waiting`, a
`Blocker` is created, and the employee asks the owner for help. The runtime never
self-grants permission or silently fabricates researched evidence.

The existing Codex runner remains read-only and scoped to the selected
organization directory. The app writes returned artifacts through the local
store.

### Use the employee folio as the assignment boundary

Selecting an AI employee reveals a prominent “Give an outcome” action and the
latest outcome's status, skills, tickets, help request, or delivery. The focused
assignment sheet contains a required outcome, optional context, the employee's
available skills, and plain-language autonomy boundaries.

Motion thesis:

- **Focal moment:** accepting an outcome changes the selected employee from
  resting to planning and routes them to their working station.
- **Continuity:** the same face, name, outcome, and task identifiers connect the
  folio, office scene, Mission board, and local files.
- **Feedback:** labels appear for the selected or active employee; blockers move
  the employee to the help desk; review/handoff paper appears only when real
  review work exists.
- **Budget:** no ambient wandering, no decorative repeating motion, and Reduce
  Motion applies the destination and status immediately.

## Risks / Trade-offs

- **[Generic outcomes produce shallow plans]** → Keep the plan small, expose the
  chosen skills and tickets, and judge usefulness from delivered artifacts.
- **[A role cannot fulfill a requested outcome]** → The employee asks for a
  precise missing skill, context, or permission instead of pretending.
- **[New tickets pollute the fixed workday]** → Prefix and associate them with
  the generic outcome; the fixed engine continues selecting only its existing
  eligible flow.
- **[Cancellation accepts stale work]** → AppModel guards terminal replacement
  with the existing session identifier and persists start and finish states.
- **[The employee folio becomes dense]** → Show only the latest assignment and
  its next action; the Mission board and local projection hold the full ticket
  history.

## Migration Plan

1. Add empty outcome arrays to backward-compatible knowledge decoding and raise
   the local schema version.
2. Add Communication once and assign it idempotently to every AI employee.
3. Convert persisted planning or working outcomes to resumable queued state on
   reopen; preserve delivered, failed, waiting, and cancelled history.
4. Materialize outcome history as `EMPLOYEE_OUTCOMES.md` in the selected
   organization folder.
