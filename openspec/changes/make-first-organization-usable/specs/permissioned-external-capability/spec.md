## Purpose

Introduce one narrow permission boundary so employees can use real external research without giving every employee ambient or unrecorded access.

## ADDED Requirements

### Requirement: External capabilities are explicit grants
The system SHALL represent web research as a named capability and MUST check the assigned employee's active grant before invoking an external research runtime.

#### Scenario: Capability is withheld
- **WHEN** an employee attempts web research without an active grant
- **THEN** no external research process starts and the workplace shows the capability request to the owner

#### Scenario: Capability is granted
- **WHEN** the owner grants web research to the responsible employee
- **THEN** subsequent research work may invoke the configured local runtime and the grant remains visible and revocable

### Requirement: Capability use is attributable
The system SHALL record who requested the capability, who granted or revoked it, which task used it, and whether the attempt succeeded, failed, or fell back.

#### Scenario: Permitted research completes
- **WHEN** a granted web research action completes
- **THEN** the organization timeline contains the employee, capability, task, outcome, and resulting evidence artifact

#### Scenario: Runtime is unavailable
- **WHEN** web research is granted but the local runtime is unavailable or fails
- **THEN** the action is recorded as unavailable or failed, the employee does not claim external evidence, and the owner receives a recoverable next action

### Requirement: External writes remain denied
The first usable version MUST keep publishing, messaging, repository mutation, and other external writes unavailable even when web research is granted.

#### Scenario: Article is approved
- **WHEN** the content manager approves an article
- **THEN** the article is stored locally and no external publication action is attempted

