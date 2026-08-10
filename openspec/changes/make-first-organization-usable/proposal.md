## Why

The current proof of concept shows a convincing workplace, but it still behaves like a staged demo: the employees do not begin with the owner's real product context, an owner has no dedicated assistant, and employee work is not yet a durable, permission-aware capability that becomes more useful across days. The minimum usable version must let one person open the Mac app, give a real outcome to one employee, and receive a useful researched artifact without first building a general agent platform.

## What Changes

- Finish the current native Mac workplace as the stable shell for daily use, including first-run setup, readable employee and work surfaces, visible movement, rest/start/end-day states, and honest empty/error states.
- Represent the owner as a human member of the organization and automatically pair that human with a named executive assistant.
- Give the executive assistant a bounded daily job: prepare a morning brief, surface decisions and blockers, and assemble the end-of-day report from attributable organization state.
- Give each employee a durable local home containing inspectable identity, responsibilities, memory, capability grants, and artifacts that survive app restarts and organization-folder changes.
- Make Maya, the content manager, genuinely useful against a user-provided product brief: she owns a bounded research-to-article outcome, coordinates the existing content specialists, reviews the result, and returns the article plus evidence and a concise owner report.
- Add one real external capability: web research through the locally authenticated Codex runtime. The app records the intended capability, requires an explicit grant before use, and falls back visibly when the capability or runtime is unavailable.
- Keep publishing and other external writes out of scope. The first useful result is written to the chosen local organization folder for the owner to inspect.

## Capabilities

### New Capabilities

- `paired-executive-assistance`: Human members receive a dedicated assistant that creates a grounded morning brief, decision queue, and end-of-day summary without pretending to complete unavailable work.
- `durable-employee-homes`: Employees have portable, inspectable local identity, responsibility, memory, grant, and artifact state that persists across workdays.
- `useful-content-employee`: A content manager can turn a real product brief and permitted web research into a reviewed local article and attributable report through a bounded work cycle.
- `permissioned-external-capability`: External capabilities are declared, granted or withheld by the owner, and recorded before an employee uses them.

### Modified Capabilities

None. The repository has no canonical capability specs yet; the existing proof-of-concept change remains responsible for the workplace shell.

## Impact

- Extends `AgentOfficeCore` organization, employee, relationship, memory, permission, and workday models with backward-compatible decoding for existing local state.
- Extends local persistence to materialize employee homes and organization inputs as ordinary files under the selected organization folder.
- Extends the native SwiftUI workplace with an owner/assistant relationship, brief and decision surfaces, product-brief setup, and permission controls while preserving the current cosy visual language.
- Narrows the local Codex runner from an optional demo enhancement into the first real employee capability, without adding an API key, cloud service, generic workflow engine, or new production dependency.
- Adds focused tests for pairing, persistence, permission gating, bounded revision behavior, useful artifact provenance, and restart recovery.
