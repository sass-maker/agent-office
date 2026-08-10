## Purpose

Let an owner employ Nia for one bounded real research outcome and receive an
inspectable, evidence-bearing brief through a durable assistant-mediated flow.

## Requirements

### Requirement: Owner can create a bounded research assignment
The system SHALL let the owner create a research assignment with a required
outcome and optional context, SHALL attribute the request to the owner, and
SHALL show Mira delegating it to Nia. The POC SHALL allow at most one
non-terminal research assignment at a time.

#### Scenario: Owner submits a valid assignment
- **WHEN** the owner submits a non-empty research outcome while no other assignment is active
- **THEN** the system stores an attributable assignment for Nia and exposes its current status and next action

#### Scenario: Owner submits an empty assignment
- **WHEN** the owner submits only whitespace as the research outcome
- **THEN** the system refuses to create the assignment and explains what is missing

#### Scenario: Another assignment is active
- **WHEN** the owner attempts to create a second assignment before the first reaches a terminal state
- **THEN** the system preserves the active assignment and directs the owner back to it

#### Scenario: Owner stops an active or blocked assignment
- **WHEN** the owner stops a non-terminal research assignment
- **THEN** execution is cancelled, the stop is attributable, Nia returns to rest, and another assignment may be created without granting the declined permission

### Requirement: Research execution respects the existing permission boundary
The system MUST require the existing `web-research` grant and an available
Local Codex runtime before treating an assignment as real external research.
The system MUST NOT grant capabilities, perform external writes, or silently
represent a downgraded run as researched work.

#### Scenario: Local research is permitted
- **WHEN** Local Codex is selected, the runtime is available, and Nia has the `web-research` grant
- **THEN** Nia may perform read-only live search for the assignment and the capability use is attributable

#### Scenario: Permission is missing
- **WHEN** Local Codex is selected and Nia lacks the `web-research` grant
- **THEN** the assignment waits without invoking research and surfaces a precise owner permission decision

#### Scenario: Permission is revoked during research
- **WHEN** the owner revokes `web-research` while Nia is researching
- **THEN** the active run is invalidated, the revoked grant remains revoked, and the assignment waits for an explicit next decision without accepting the stale run as delivered

#### Scenario: Runtime is unavailable
- **WHEN** Local Codex is selected but cannot be discovered
- **THEN** the assignment waits with a recoverable runtime blocker and does not claim that research occurred

#### Scenario: Demo mode is selected
- **WHEN** the owner submits an assignment in Demo mode
- **THEN** the system produces an explicitly synthetic research rehearsal without fabricated sources or external-evidence language

### Requirement: Research delivery carries verifiable evidence
For permitted external research, the system SHALL require the delivered brief
to contain source references, findings, uncertainty, and recommended next
actions before presenting it as complete. The system SHALL preserve the exact
brief as an ordinary local artifact.

#### Scenario: Cited research succeeds
- **WHEN** permitted research returns a brief containing at least one source URL
- **THEN** the system stores the brief with a `permitted-web-research` evidence basis and marks the assignment delivered

#### Scenario: Final state cannot be saved
- **WHEN** a verified brief is produced but the selected organization folder cannot persist the terminal assignment state
- **THEN** the application does not present the assignment as durably delivered and explains how to recover

#### Scenario: Research returns no source reference
- **WHEN** a permitted external research run returns content without a source URL
- **THEN** the system records a recoverable failed assignment and does not present the result as a completed researched brief

#### Scenario: Research execution fails
- **WHEN** the research runtime fails or returns no usable output
- **THEN** the system records the failure, restores a truthful resting state, and lets the owner retry without duplicating a successful artifact

### Requirement: Mira prepares one grounded owner delivery
After Nia delivers a verified brief, Mira SHALL create one attributable delivery
note that identifies the assignment, evidence basis, brief artifact, and next
owner decision. Mira MUST NOT invent findings or enter an unbounded review
loop.

#### Scenario: Verified brief is delivered
- **WHEN** Nia's brief passes the evidence gate
- **THEN** Mira leaves one owner-ready delivery note linked to the brief and the assignment reaches a terminal delivered state

#### Scenario: Delivered assignment is reopened
- **WHEN** the owner quits and reopens an organization containing a delivered assignment
- **THEN** the same brief and delivery note remain available without creating duplicate artifacts or notes

### Requirement: Active research survives interruption
The system SHALL persist assignment state, activity, artifacts, and next action
inside the selected organization folder. An interrupted in-flight assignment
SHALL become resumable rather than being reported as completed.

#### Scenario: App closes during research
- **WHEN** the app reopens after an assignment was persisted as researching
- **THEN** the assignment returns to a resumable queued or waiting state with no false completion claim

#### Scenario: Owner ends the day during research
- **WHEN** the owner presses End Day before research completes
- **THEN** execution stops, progress is saved, Nia returns to rest, and the assignment remains available to retry

#### Scenario: Research begins
- **WHEN** Nia starts an accepted assignment
- **THEN** the published organization state immediately shows the assignment as researching and shows Nia and Mira carrying the work before the runner completes
