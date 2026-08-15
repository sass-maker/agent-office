## Why

Employees backed by different runtimes cannot yet ask each other for anything.
Office OS already has coworkers, commitments, delegation, handoffs, and a
Communication skill; what is missing is a bridge that lets a foreign runtime use
those existing operations without gaining the power to rewrite accountability or
start invisible agent loops.

## What Changes

- Expose a permission-filtered coworker directory to an eligible runtime,
  containing only employees visible to the source employee and relevant to the
  current commitment, with a safe reason when someone is excluded.
- Add a small provider-neutral collaboration protocol with three distinct
  operations: request a bounded consultation, propose delegation of existing
  work, and send a structured handoff message through the existing
  communication path.
- Run every target under its own runtime binding, working contract, grants,
  commitment context, and attribution. A source employee cannot lend its tools,
  credentials, data access, or permissions.
- Contain collaboration hard: reject self-calls, repeated correlation
  identifiers, cycles, and anything past one hop; enforce turn and time budgets;
  reject or queue unavailable targets by existing rules.
- Share the least context required — references to commitments and artifacts,
  never transcripts, hidden prompts, or unrelated organization history.
- Map accepted results into existing communication and delegation records so
  nothing becomes runtime-only shadow work, and let only validated Office OS
  commands change assignment, ownership, or accountability.

## Capabilities

### New Capabilities

- `bounded-employee-collaboration`: One-hop, permission-filtered collaboration
  between employees on different runtimes, expressed through the organization's
  existing communication and delegation operations.

### Modified Capabilities

None. Delegation, reassignment, handoffs, and review policy keep their current
behaviour and remain the only way accountability changes.

## Non-goals

- A chat room, swarm framework, or autonomous organization planner.
- Multi-hop delegation graphs. One hop only; deeper graphs need their own design.
- Letting foreign runtimes hire, grant, revise contracts, or reassign
  accountability directly.
- Any new production dependency, machine layer, or computer control.

## Impact

- Adds a collaboration protocol, directory, containment guard, and broker to
  `AgentOfficeCore`. No existing model changes shape; results are recorded through
  existing outcome messages and supervision events.
