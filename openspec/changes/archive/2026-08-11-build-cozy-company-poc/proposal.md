## Why

Basic AI employees need a place where they can persist responsibilities,
coordinate visible work, create useful local artifacts, and ask their owner for
help without requiring the owner to manage prompts or automation machinery.
The smallest proof is a cosy native Mac organization whose content team can
complete a bounded workday and resume later.

## What Changes

- Add a standalone native macOS application with a two-dimensional workplace,
  employee roster, goals, blockers, task board, and Start Day/End Day controls.
- Add a short first-run journey that creates the local organization, introduces
  the starter team, and carries the owner into the first real workday.
- Model named employees as durable organizational identities with roles,
  managers, state, workspaces, and attributed activity.
- Add a bounded content-team work cycle: research, draft, manager review,
  revision, approval, and daily report.
- Persist organization state and employee artifacts to a local folder.
- Allow a work cycle to call the locally authenticated Codex CLI within an
  employee workspace, while preserving a deterministic demo path when Codex is
  unavailable.
- Keep external integrations, publishing, human onboarding, permission
  management, coding employees, scheduling, and token accounting out of scope.

## Capabilities

### New Capabilities

- `organization-workday`: Hiring basic employees, assigning an outcome,
  advancing bounded work, surfacing blockers, and ending or resuming a day.
- `local-employee-work`: Durable employee identity, attributed tasks, local
  workspaces, artifacts, review handoffs, and inspectable execution state.
- `living-workplace`: A native, accessible, cosy 2D representation whose
  characters continuously inhabit the room, travel between meaningful work
  destinations, and reflect the actual organization and task state.

### Modified Capabilities

None.

## Impact

- New standalone Swift package and native macOS executable.
- Local JSON organization state plus Markdown artifacts under a user-selected
  organization folder.
- Optional subprocess boundary to the installed Codex CLI; no API key,
  network service, deployment, cloud resource, or third-party dependency.
