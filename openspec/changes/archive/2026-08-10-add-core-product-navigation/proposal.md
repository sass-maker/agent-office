## Why

The current organization home is trying to be a live office, company profile, member directory, mission overview, and task board at the same time. The product now has enough real state to give those jobs stable homes: an office for presence, a mission workspace for coordinated work, and a company book for durable organizational memory.

## What Changes

- Add a persistent native product shell with exactly three primary destinations: **Office**, **Mission**, and **Company**.
- Keep the living office as the default home while removing detailed planning and organization administration from that surface.
- Add a Mission page that joins the current mission, definition of success, outcomes, blockers, owner decisions, and a grouped task list with contextual inspection.
- Add a Company page whose overview exposes the information captured during onboarding and whose sections cover Members, Skills, and Connections.
- Treat humans and AI employees as members in one directory while preserving their different kind, role, status, assistant relationship, skills, and capabilities.
- Expand onboarding enough to collect grounded organization and product context, then persist those answers into the editable Company page.
- Preserve native access, keyboard navigation, local-only execution, and the existing Company Library, research, Customer Voice, permission, workday, and artifact behavior.
- Replace the superseded Dawn Stage shell with the owner-approved **Editorial Office** visual system across Office, Mission, Company, employee details, and onboarding: one full-height black sidebar, warm ink-and-paper working surfaces, expressive monochrome people, and contextual employee folios.
- Make Mission deliberately more software-like than Office: a dense Linear-inspired native list with grouped task states, fast filters, small employee portraits, and one task inspector, adapted to the product rather than copied from Linear.
- Add a complete Employee Details destination reached from Office or Company Members, preserving the employee as a durable identity with responsibilities, relationships, active work, skills, artifacts, blockers, and attributable activity.
- Exclude cloud invitations, shared sync, marketplace flows, external publishing, and a generalized permission redesign from this slice.

## Capabilities

### New Capabilities

- `product-navigation`: A native three-destination shell that makes Office, Mission, and Company independently addressable without duplicating their responsibilities.
- `mission-workspace`: A mission hierarchy and task board that connect the organization objective to outcomes, assigned tasks, blockers, reviews, and delivered evidence.
- `organization-memory`: Editable organization context and a unified member directory derived from onboarding and existing employee, skill, and connection state.

### Modified Capabilities

None. The repository has no archived baseline specifications yet; this change adds the first navigation, mission, and organization-memory contracts without rewriting the active feature deltas.

## Impact

- Native app composition in `AgentOfficeApp.swift` and new SwiftUI shell, Mission, and Company views.
- Shared Editorial Office tokens and authored monochrome illustration assets while keeping text and controls native.
- A contextual Office employee card and full Employee Details page derived from existing employee, task, skill, artifact, blocker, and activity state.
- Organization state and persistence for additional onboarding/company context, with backward-compatible defaults for existing local organizations.
- Onboarding and existing Company Library entry points.
- Focused behavior tests, full Swift test/build checks, local app packaging, native visual evidence against the five approved references, and a Fleet design-review receipt.
- No new dependencies, services, credentials, or production deployment.
