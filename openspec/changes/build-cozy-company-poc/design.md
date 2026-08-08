## Context

See `proposal.md` for motivation and the three capability specs for observable
behavior. This is a new standalone native product with no legacy code, product
name, backend, deployment, or third-party dependency. The POC must establish a
real employee-work loop without building the future permission and integration
platform.

## Goals / Non-Goals

**Goals:**

- Produce a runnable native Mac application with a truthful living workplace.
- Keep organization state and artifacts local, inspectable, and resumable.
- Demonstrate bounded researcher-writer-manager coordination.
- Preserve seams for human employees, different models, separate machines,
  skills, permissions, and integrations without implementing them.

**Non-Goals:**

- Background hourly scheduling while the app is closed.
- Publishing, cloud access, browsers, computer use, GCP, Composio, or secrets.
- A generic workflow engine, permission system, agent marketplace, or HR suite.
- Pixel-perfect sprite animation, map editing, or a production app bundle.

## Decisions

### Build a native SwiftUI shell with a SpriteKit workplace

SwiftUI provides the Mac window, sidebar, inspectors, accessibility, settings,
and file actions. SpriteKit provides a real-time 2D scene with characters,
layering, and movement without adding a dependency. A Tauri/React/Pixi stack
would make AI Town code reuse easier but adds a web runtime and production
dependencies before the native product interaction has been proven.

### Separate the domain model from the scene

`OrganizationState` is the single source of truth. The workplace observes
employee and task state and maps it to positions and animation; it never owns
task progress. This prevents attractive but fictitious agent activity and lets
future human or headless clients share the same organization model.

```mermaid
flowchart LR
    O[Owner controls] --> E[Workday engine]
    E --> S[Organization state]
    E --> R[Employee runner]
    R --> A[Local artifacts]
    S --> B[Goals, blockers, task board]
    S --> W[SpriteKit workplace]
    S --> P[Local JSON store]
```

### Use a deterministic runner and an optional Codex runner

`EmployeeRunner` returns structured work results. The deterministic runner
makes the POC demonstrable and testable without consuming model usage. The
Codex runner invokes `codex exec` with an ephemeral session, read-only sandbox,
employee-local working directory, and last-message output, then lets the app
write the returned artifact. The app stores no API credential. App Server is a
future replacement once multi-turn employee sessions are needed.

### Advance one visible work step at a time

Start Day begins a cancellable asynchronous loop. Each step claims one eligible
task, changes the employee's visible state, produces or reviews an artifact,
persists, then yields briefly so the owner can understand progress. End Day
cancels before the next step and persists a resting organization.

### Store one JSON snapshot plus ordinary artifacts

The organization directory contains `organization.json` and employee-owned
Markdown files beneath `employees/<employee-id>/`. Atomic snapshot replacement
is sufficient for one local process. An event ledger and concurrent merge
rules are intentionally deferred until more than one process can mutate state.

### Preserve future authority without implementing permissions

Employee records include stable identity and an empty capability-grant list.
Actions and artifacts are attributed. No POC action is authorized beyond the
selected local organization directory, so a policy engine would add ceremony
without improving current safety.

## Risks / Trade-offs

- **A deterministic demo could look like fake autonomy** → Label Demo and Local
  Codex modes clearly and make every artifact inspectable.
- **Subprocess execution can fail or outlive UI state** → Use cancellation,
  capture errors as blockers, and persist before and after each step.
- **Programmatic art can fall below the AI Town quality bar** → Establish the
  visual world in `DESIGN.md`, use authored native shapes and texture, and keep
  the POC honest about later sprite-production work.
- **One JSON snapshot cannot support concurrent actors** → Restrict the POC to
  one app process and keep persistence behind an actor.
- **A game scene can obscure work** → Maintain parallel native goals,
  blockers, tasks, and employee details with keyboard access.

## Migration Plan

No deployment or data migration is required. Build and run locally. Deleting
the app does not remove a user-selected organization folder. The working
directory and display name can be renamed once the product name is chosen.

