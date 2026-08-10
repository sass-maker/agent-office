## Why

Agent Office can complete one owner-directed assignment, but employees still
wait for bespoke instructions. The first live Nia run identified a safer,
measurable next step: a Customer Voice Analyst who repeatedly turns deliberately
supplied local feedback into one decision-ready weekly brief.

## What Changes

- Add a named Customer Voice Analyst employee with a narrow, inspectable role.
- Add one recurring `Customer Voice Weekly` duty rather than a generic schedule
  or workflow builder.
- Let the owner choose a local feedback inbox inside the organization and run
  the due duty while the app is open.
- Read supported local text, Markdown, and CSV inputs without modifying them or
  accessing external systems.
- Produce a cited local brief, manager handoff, next-due state, and an honest
  blocker when input, permission, runtime, or evidence is insufficient.
- Preserve Stop, retry, resume, attribution, local persistence, and bounded
  review behavior.
- Keep background wake, CRM/support integrations, customer contact, roadmap
  writes, publishing, and a generic scheduler out of scope.

## Capabilities

### New Capabilities

- `recurring-employee-duty`: A durable employee duty with local input scope,
  due state, bounded execution, evidence-linked output, and an explicit next
  occurrence.

### Modified Capabilities

None.

## Impact

- Extends the organization schema, persistence projections, and migration.
- Adds a focused customer-voice duty engine and deterministic/Local Codex work
  request behavior to `AgentOfficeCore`.
- Adds one native duty surface to the existing company home and catalogue while
  preserving the current cosy visual language.
- Adds local fixture and engine tests; no third-party dependency, cloud service,
  credential, external write, deployment, or background daemon is introduced.
- Tracks implementation in GitHub issue #7.
