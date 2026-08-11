## Purpose

Defines how one named employee repeatedly owns a bounded local duty, reports
evidence-linked work, and preserves the next occurrence without requiring a
generic scheduler or unattended background service.

## Requirements

### Requirement: The organization includes one durable Customer Voice Analyst
The system SHALL onboard Iris as a named Customer Voice Analyst whose first
responsibility is the `Customer Voice Weekly` duty and whose manager is Mira.
The employee identity, responsibility, assigned skill, input boundary, and
current duty state MUST remain inspectable after reopening the organization.

#### Scenario: Existing organization migrates
- **WHEN** an organization created before this capability is reopened
- **THEN** Iris and the weekly duty are added without losing existing employees, assignments, artifacts, skills, permissions, or workday state

### Requirement: The duty has one local read boundary
The system SHALL create a designated feedback inbox inside the selected local
organization and SHALL consider only regular `.txt`, `.md`, and `.csv` files
directly inside that inbox. It MUST NOT follow symbolic links, modify inputs,
read sibling folders, contact external services, or perform external writes.

#### Scenario: Owner reveals the inbox
- **WHEN** the owner chooses to add feedback
- **THEN** the system reveals the designated local inbox where supported files can be deliberately placed

#### Scenario: Unsupported or unsafe entry exists
- **WHEN** the inbox contains a directory, symbolic link, hidden file, or unsupported extension
- **THEN** the entry is excluded and the run records that it was not analyzed

### Requirement: Input processing is bounded and attributable
The system SHALL snapshot at most 25 eligible files and 250 KB of combined
content for one run, assign stable source labels to included files, and record
the included and excluded filenames. An empty eligible snapshot MUST block
before model execution with a clear owner action.

#### Scenario: Inbox has no eligible feedback
- **WHEN** the owner runs the duty with no supported readable file
- **THEN** Iris does not invoke a model, the duty becomes blocked, and the owner is asked to add feedback files

#### Scenario: Inbox exceeds the run boundary
- **WHEN** eligible input exceeds the file or content limit
- **THEN** the system analyzes a deterministic bounded snapshot and reports which files were excluded

### Requirement: The duty runs only by an explicit in-app action
The system SHALL show whether the recurring responsibility is upcoming, due, queued, running, delivered, accepted, or blocked and SHALL create a canonical employee-owned outcome for each occurrence. The first version MUST NOT wake the app or run while the app is closed.

#### Scenario: Weekly occurrence becomes due
- **WHEN** the stored next-due date has arrived
- **THEN** the workplace shows Iris and the duty as due without starting work automatically
- **AND** creates at most one queued outcome for that occurrence

#### Scenario: Owner starts a due or upcoming occurrence
- **WHEN** the owner chooses Run now
- **THEN** the occurrence's canonical outcome enters Iris's employee queue
- **AND** may run alongside eligible work owned by other employees within the organization concurrency limit

### Requirement: Customer voice output is locally evidence-linked
The system SHALL produce a local Markdown brief containing input coverage,
themes, source-labelled evidence, uncertainty, exactly one recommended owner
decision, and the next occurrence. A real Local Codex run MUST reference at
least one valid source label from the captured input before it can be accepted
as delivered. Demo output MUST be labelled synthetic.

#### Scenario: Evidence-linked delivery succeeds
- **WHEN** the employee output has all required sections and references an included source label
- **THEN** Iris's brief and Mira's handoff are saved locally with their evidence basis and the occurrence is delivered

#### Scenario: Output lacks traceable evidence
- **WHEN** a real employee output lacks a required section or valid source label
- **THEN** the occurrence fails honestly, no delivery is claimed, and the owner can retry

### Requirement: A completed occurrence advances without duplicating work
The system SHALL advance the next-due date by one week only after the occurrence's canonical outcome is delivered and successfully persisted. Re-running a delivered or accepted occurrence MUST NOT create duplicate outcomes or artifacts, while stopping, failure, persistence failure, or reopening an interrupted run MUST leave the same occurrence and outcome resumable.

#### Scenario: Delivery persists
- **WHEN** the brief, handoff, delivered outcome, and terminal organization state save successfully
- **THEN** the next-due date advances by seven days and the completed outcome remains available for owner acceptance and history

#### Scenario: Run is interrupted
- **WHEN** the owner stops, the model fails, persistence fails, or the app reopens during a run
- **THEN** the current occurrence's outcome remains resumable and the next-due date does not advance

### Requirement: Recurring responsibilities use the shared employee contract
Every recurring responsibility SHALL identify its accountable hired employee, schedule, outcome template, required inputs, acceptance criteria, and required working-contract capabilities without defining a separate employee execution path.

#### Scenario: Recurring responsibility lacks required input
- **WHEN** a due occurrence cannot satisfy its declared local input boundary
- **THEN** the resulting outcome creates a precise help request through the shared supervision inbox
- **AND** no special-purpose blocker store is created
