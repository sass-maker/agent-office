## Purpose

Let an owner teach reusable local operating knowledge to an employee and make that knowledge affect future work without claiming that model weights were trained.

## Requirements

### Requirement: Owner can teach a local organizational skill
The system SHALL let the owner provide a skill name, purpose, actionable instructions, success criteria, and one target employee. A taught skill SHALL begin at version one and identify the owner as its source.

#### Scenario: Owner teaches a valid skill
- **WHEN** the owner submits all required teaching fields for an employee
- **THEN** the system creates one organization-local skill definition
- **AND** creates one assignment linking that skill to the selected employee
- **AND** records an attributable teaching activity

#### Scenario: Teaching form is incomplete
- **WHEN** the name, purpose, instructions, success criteria, or target employee is missing
- **THEN** the system does not create or assign the skill
- **AND** explains what information is still required

### Requirement: Existing catalogue skills can be assigned without duplication
The system SHALL allow an existing skill to be assigned to another employee while preventing duplicate assignments for the same employee and skill.

#### Scenario: Owner assigns an existing skill
- **WHEN** the owner assigns a catalogue skill to an employee who does not have it
- **THEN** one assignment is persisted and coverage updates immediately

#### Scenario: Owner repeats the same assignment
- **WHEN** the employee already has the selected skill
- **THEN** no duplicate assignment or teaching activity is created

### Requirement: Assigned skills influence future employee work
Every employee work request SHALL include the current definitions of that employee's assigned skills. The local model prompt SHALL clearly separate organizational skill instructions from the task and product brief.

#### Scenario: Trained employee begins later work
- **WHEN** an employee with an assigned organizational skill receives a work request
- **THEN** that request includes the skill's name, purpose, instructions, success criteria, and version

#### Scenario: Another employee performs work
- **WHEN** an employee without that skill receives a work request
- **THEN** the skill instructions are not included in that employee's context

### Requirement: Taught skills remain local and inspectable
Organization-taught skills and assignments SHALL survive quit and reopen and SHALL be projected into ordinary Markdown inside the selected organization folder.

#### Scenario: Organization reopens after teaching
- **WHEN** the owner teaches a skill, saves the organization, and reopens it
- **THEN** the skill definition and assignment remain present
- **AND** the skill catalogue and employee home files reflect them

### Requirement: Teaching makes no unsupported competence claim
The system MUST describe teaching as stored operating guidance supplied to future work and MUST NOT claim that the employee's model weights were fine-tuned or that the skill is verified merely because it was assigned.

#### Scenario: Newly taught skill is displayed
- **WHEN** an organization-taught skill appears in the catalogue
- **THEN** it is labeled as owner-taught guidance
- **AND** no verified, certified, or trained-model badge is shown
