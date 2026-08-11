## Why

The product already treats seeded AI employees as durable organizational members, but the owner cannot actually hire one, inspect their complete working contract, manage their plan and delivery, or let several employees own work independently. The next product step is to turn the fixed starter organization into a coherent employment system for agents without becoming an autonomous-company infrastructure provider or an agent-building tool.

## What Changes

- Add a durable employment lifecycle for AI employees: available package, candidate, hired, paused, and retired, distinct from transient work status.
- Define an importable local employee package that declares identity, role, responsibilities, skills, required connections, execution requirements, default boundaries, and package version without containing credentials.
- Add an explicit hiring experience for the prepared starter employees and locally imported employee packages.
- Give every hired employee a legible working contract that keeps identity, skills, tools, permissions, execution environment, and model configuration separate.
- Make an employee-owned outcome the canonical unit of work. Fixed research assignments and recurring duties become templates or schedules that create ordinary outcomes and Mission tickets.
- Add owner supervision actions: review or revise a proposed plan, answer a help request, redirect scope, reassign a ticket, request delivery changes, accept delivery, pause work, and queue the next outcome.
- Replace the single organization-wide execution lane with bounded per-employee queues and concurrent runs while preserving local sandboxing, cancellation, persistence, and deterministic recovery.
- Allow employees to delegate bounded tickets to other hired employees when the receiving employee's working contract covers the requested work.
- Update Office, Mission, Company, onboarding, and the Company Library so hiring, contracts, commitments, requests for help, and management decisions are primary and competing workflow entry points disappear.
- Preserve the current local-only POC boundaries: no credentials stored by the app, no cloud control plane, no publishing, no financial or legal infrastructure, and no third-party production dependency.

## Capabilities

### New Capabilities

- `agent-employment-lifecycle`: Local employee packages, explicit hiring, employment state, retirement, and durable membership in an organization.
- `employee-working-contracts`: Inspectable separation of employee identity, responsibilities, skills, tools, grants, execution provider, model configuration, workspace, and autonomy boundaries.
- `employee-owned-work`: Canonical one-off and recurring outcomes, employee-created plans, delegation, per-employee queues, bounded concurrency, and durable delivery state.
- `workforce-supervision`: Owner review, replies, redirection, reassignment, revision requests, acceptance, pausing, and management inbox behavior.

### Modified Capabilities

- `company-catalogues`: Extend the employee catalogue from a fixed roster viewer into a local catalogue of hireable and employed agent packages.
- `coherent-organization-home`: Make hiring, employee commitments, help requests, and the next management action legible from the living Office.
- `mission-workspace`: Show employee-owned outcomes and their tickets across multiple active employees with management actions and truthful ownership.
- `recurring-employee-duty`: Represent a recurring responsibility as a schedule that creates canonical employee outcomes instead of a separate work engine.
- `local-employee-work`: Support isolated per-employee runs, bounded parallel execution, cancellation, and reopen-safe recovery inside the selected organization directory.

## Impact

- Extends `AgentOfficeCore` with employee package, employment, working-contract, outcome-plan, supervision-decision, queue, delegation, and run-state records while preserving backward-compatible decoding.
- Reworks the current generic outcome and recurring-duty engines into one canonical employee-work path and migrates existing research/duty state without losing artifacts or activity.
- Replaces the single `AppModel.workTask` execution assumption with a coordinator for per-employee runs.
- Extends the native SwiftUI/SpriteKit product across onboarding, Office folios, Mission, Company Members, Employee Details, and Company Library in the existing Editorial Office visual language.
- Adds focused unit and integration tests for package validation, hiring, migration, contract separation, plan approval, contextual help, delegation, concurrent execution, cancellation, persistence, and recovery.
- Adds no production dependency, credential storage, cloud integration, payment, incorporation, publishing, deployment, or release action.
