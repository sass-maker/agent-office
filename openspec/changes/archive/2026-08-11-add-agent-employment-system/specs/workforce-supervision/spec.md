## Purpose

Defines how an owner manages AI employees through commitments, decisions, feedback, and acceptance rather than prompts, raw execution logs, or workflow configuration.

## ADDED Requirements

### Requirement: Owner decisions appear in one management inbox
The system SHALL provide one owner-facing queue for candidate hires, proposed plans, help requests, permission requests, blocked work, delivered outcomes, and package or contract changes requiring review.

#### Scenario: Several employees need different decisions
- **WHEN** multiple pending decisions exist
- **THEN** the owner sees them ordered by urgency and age with the employee, affected outcome, requested decision, and consequence of waiting

### Requirement: Owners can review plans before execution
The owner SHALL be able to approve an employee plan, revise its scope or acceptance criteria, reassign or remove a proposed ticket, or return the plan with a concise instruction.

#### Scenario: Owner approves a plan
- **WHEN** the owner approves a valid proposed plan
- **THEN** the outcome becomes eligible for execution and the approval is attributed to the owner

#### Scenario: Owner narrows a plan
- **WHEN** the owner removes a ticket or changes an acceptance criterion before approval
- **THEN** the revised plan is persisted and shown to the employee before execution

### Requirement: Help requests support contextual replies
The owner SHALL be able to answer a help request with text, supplied local context, a grant decision, a reassignment, a scope change, or a stop decision without creating a new unrelated outcome.

#### Scenario: Owner supplies missing context
- **WHEN** an employee asks a precise question and the owner replies
- **THEN** the reply is attached to the affected outcome and ticket
- **AND** the employee can resume from the blocked point

### Requirement: Owners can redirect active commitments safely
The owner SHALL be able to pause an employee, change outcome priority, update remaining scope, reorder queued outcomes, or transfer an unstarted ticket without altering completed artifacts.

#### Scenario: Owner transfers an unstarted ticket
- **WHEN** the owner chooses another eligible employee for a queued ticket
- **THEN** accountability, dependency, and activity records are updated
- **AND** completed work remains attributed to its original author

### Requirement: Delivery and acceptance are separate
The owner SHALL be able to accept a delivered outcome, request a bounded revision with feedback, or close it as not accepted while preserving the delivery.

#### Scenario: Owner accepts delivery
- **WHEN** the owner reviews the artifacts and chooses Accept
- **THEN** the outcome records acceptance, accepting actor, time, and any owner note
- **AND** the employee's commitment moves to history

#### Scenario: Owner requests changes
- **WHEN** the owner supplies revision feedback within the configured revision limit
- **THEN** the outcome returns to the accountable employee with a new revision ticket and preserved delivery history

### Requirement: Management actions are attributable
Every hire, pause, retirement, contract change, plan decision, reply, grant, redirect, reassignment, revision request, acceptance, and stop action SHALL identify the actor, affected employee and work, time, and concise reason.

#### Scenario: Owner changes active work
- **WHEN** the owner redirects or stops an employee outcome
- **THEN** the employee profile, Mission, Office, and local history reflect the same attributable decision

