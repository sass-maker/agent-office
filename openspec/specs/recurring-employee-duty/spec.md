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
The system SHALL show whether the weekly duty is upcoming, due, running,
delivered, or blocked and SHALL offer `Run now` while the app is open. The first
version MUST NOT wake the app, run while the app is closed, or create a generic
schedule builder.

#### Scenario: Weekly occurrence becomes due
- **WHEN** the stored next-due date has arrived
- **THEN** the workplace shows Iris and the duty as due without starting work automatically

#### Scenario: Owner starts a due or upcoming occurrence
- **WHEN** the owner chooses `Run now` and no other work is active
- **THEN** one attributable duty run starts and the employee workplace reflects Iris working and Mira reviewing

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
The system SHALL advance the next-due date by one week only after a successfully
persisted delivery. Re-running a delivered occurrence MUST NOT create duplicate
artifacts, while stopping, failure, persistence failure, or reopening an
interrupted run MUST leave the same occurrence resumable.

#### Scenario: Delivery persists
- **WHEN** the brief, handoff, and terminal organization state save successfully
- **THEN** the next-due date advances by seven days and the completed run remains in history

#### Scenario: Run is interrupted
- **WHEN** the owner stops, the model fails, persistence fails, or the app reopens during a run
- **THEN** the current occurrence remains resumable and the next-due date does not advance
