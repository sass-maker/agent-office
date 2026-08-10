## Why

The organization currently contains employees and one hard-coded capability, but the owner cannot see what the company knows, which employee covers which skill, or what access makes that work possible. A usable organization needs an inspectable library and a small teaching loop before adding more employees or integrations.

## What Changes

- Add a native Company Library with Employee, Skill, and Connection views backed by persisted organization truth.
- Add reusable, versioned skill definitions and per-employee skill assignments with coverage and gap visibility.
- Seed the content team with explicit research, writing, editorial review, reporting, and executive-assistance skills instead of inferring skills from role names.
- Let the owner teach a local organizational skill by providing a name, purpose, instructions, and success criteria, then assign it to one employee.
- Include assigned skill instructions in that employee's future work context so teaching changes behavior rather than adding a decorative badge.
- Represent the currently available Demo, Local Codex, and read-only web research connections without adding OAuth, Composio, cloud credentials, or external-write access.
- Preserve employee identity, memory, permission grants, and existing organizations through a backward-compatible migration.
- Leave marketplace publishing, skill downloads, model fine-tuning, connection setup, billing, and the rejected character-animation direction out of scope.

## Capabilities

### New Capabilities

- `company-catalogues`: Inspect installed employees, reusable skills, current connections, skill coverage, and access requirements from one native Company Library.
- `teachable-organizational-skills`: Create a local versioned skill, assign it to an employee, persist its teaching record, and supply it to future work execution.

### Modified Capabilities

None.

## Impact

- Extends the Codable organization schema and migration path in `AgentOfficeCore`.
- Extends employee work requests and the local Codex prompt with assigned skill context.
- Adds a native SwiftUI Company Library and teaching sheet to the Mac app.
- Adds local Markdown projections for the skill catalogue and employee skill assignments.
- Adds focused migration, coverage, execution-context, teaching, and persistence tests.
- Adds no production dependency, network service, credential, deployment, or external-write capability.
