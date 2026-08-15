## Why

The Office shows named employees, skills, and work state, but it still asks the
owner to use special-purpose flows such as the fixed content day or Nia's
research desk. The minimum employee product is simpler: select any AI employee,
give them an outcome, and let that person decide the bounded local work required
to deliver it or ask for help.

## What Changes

- Let the owner assign one free-form outcome and optional context to any AI
  employee directly from that employee's Office folio.
- Have the employee select from their existing assigned skills, create a small
  local ticket plan, execute it through the existing employee runner, and leave
  inspectable artifacts and activity.
- Add Communication as a foundational built-in skill for every AI employee so
  acceptance, planning, progress, blockers, help requests, and delivery are
  attributable organizational behavior.
- Preserve employee autonomy inside explicit boundaries: the employee can
  choose its process, but cannot grant itself capabilities, write outside the
  organization folder, publish, spend, or contact services.
- Make Office movement and labels represent real work state rather than ambient
  wandering.

## Capabilities

### New Capabilities

- `outcome-driven-employees`: Generic, skill-aware, bounded local outcome
  ownership for any AI employee, including self-created tickets, progress
  communication, help requests, delivery, persistence, and interruption.

### Modified Capabilities

- `coherent-organization-home`: The selected employee folio becomes the entry
  point for assigning work, and the scene reflects purposeful employee state.

## Impact

- Adds one backward-compatible outcome-assignment record to organizational
  knowledge and a focused engine that reuses `WorkTask`, `Artifact`, `Blocker`,
  `Activity`, `EmployeeRunner`, and `LocalOrganizationStore`.
- Extends the runner with bounded planning and general analysis operations.
- Adds an Editorial Office assignment sheet and current-outcome summary to the
  existing employee folio.
- Adds no dependency, credential, integration, cloud action, scheduler, or
  external write.
- Tracked by GitHub issue #10.
