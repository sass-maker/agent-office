## Purpose

Lets Office OS employ agent software written by other people without that
software becoming the employee's identity, and keeps a broken or missing runtime
from taking an employee's history down with it.

## ADDED Requirements

### Requirement: Runtimes are reached through a versioned driver contract
The system SHALL execute employee work through a driver contract that declares a
stable kind, a version, and the optional runtime facilities it supports. The
host SHALL NOT assume a driver is chat-based, process-based, or network-based.

#### Scenario: Built-in runtimes use the contract
- **WHEN** a demo employee and a local Codex employee each run a commitment turn
- **THEN** both execute through the same driver contract rather than a call-site branch

#### Scenario: An unknown driver is registered
- **WHEN** a driver of a previously unknown kind is registered
- **THEN** it can run a commitment turn without any change to the employee, contract, or commitment models

#### Scenario: Host asks what a driver supports
- **WHEN** the host needs an optional facility such as interruption or resumption
- **THEN** it consults the driver's declared capabilities rather than assuming support

### Requirement: Runtime configuration never carries secret values
Driver configuration SHALL be expressed as literal values or references to
secrets held elsewhere. The system SHALL reject a configuration that supplies a
secret value directly, and SHALL NOT copy process environment into driver
configuration.

#### Scenario: Configuration references a secret
- **WHEN** a driver is configured with a secret reference
- **THEN** validation succeeds and the reference, not the value, is persisted

#### Scenario: Configuration embeds a secret value
- **WHEN** a driver configuration supplies a value for a field the driver declares secret
- **THEN** validation fails and nothing is persisted

### Requirement: A runtime binding is separate from the employee
A runtime binding SHALL record which driver kind, driver version, and
configuration version an employee currently runs on, separately from employee
identity, package, working contract, and model choice. Rebinding or upgrading a
runtime SHALL NOT replace the employee or erase its organizational history.

#### Scenario: Employee is rebound to another driver
- **WHEN** an employee's binding is changed to a different driver kind
- **THEN** the employee keeps its identity, contract, commitments, artifacts, and history, and the binding records the new driver provenance

#### Scenario: Prior provenance is retained
- **WHEN** a binding is replaced
- **THEN** the previous driver kind and version remain recorded as provenance rather than being overwritten silently

### Requirement: Runtime events are normalized and cannot mutate the organization
The system SHALL emit normalized runtime events for session, turn, tool,
assistant output, runtime request, usage, and error activity, each carrying
stable event, employee, binding, session, and correlation identifiers and a
timestamp. Runtime events SHALL be able to propose organization commands but
SHALL NOT mutate organization state directly, and SHALL be rejected when their
declared binding or session does not match the session that produced them.

#### Scenario: Turn produces events
- **WHEN** a driver runs a commitment turn
- **THEN** the session emits ordered runtime events identifying the employee, binding, session, and commitment

#### Scenario: Event claims a foreign session
- **WHEN** an event declares a binding or session other than the one that produced it
- **THEN** it is rejected and no organization state changes

#### Scenario: Runtime evidence stays distinct from organization truth
- **WHEN** a turn completes
- **THEN** raw provider diagnostics, normalized runtime events, and organization events remain separately identifiable, and only organization events are authoritative history

### Requirement: Unavailable runtimes degrade visibly and in isolation
When a driver is missing, newer than the host supports, misconfigured, or
unhealthy, the system SHALL present the binding as an inspectable unavailable
shadow with a human-readable reason and SHALL mark the employee unavailable. It
SHALL NOT delete or corrupt the employee, and one driver's failure SHALL NOT
disable employees bound to other drivers.

#### Scenario: Driver is not installed
- **WHEN** a binding names a driver kind the host cannot resolve
- **THEN** the binding reports an unavailable reason naming the missing kind and the employee remains intact

#### Scenario: Driver is newer than the host
- **WHEN** a binding requires a driver version the host does not support
- **THEN** the binding reports an incompatibility reason rather than running with a mismatched contract

#### Scenario: One driver fails while another works
- **WHEN** one registered driver reports itself unhealthy
- **THEN** employees bound to other drivers continue to run

### Requirement: Resume state is opaque and separate from memory
The system SHALL store an opaque continuation cursor per binding and session,
kept separate from employee memory and organization knowledge. A stale or
invalid cursor SHALL fail recoverably and allow a fresh session without identity
loss.

#### Scenario: Session resumes after restart
- **WHEN** a session with a stored cursor is resumed
- **THEN** the driver receives the cursor and the employee's memory is unchanged by it

#### Scenario: Cursor is stale
- **WHEN** a driver rejects a stored cursor
- **THEN** the cursor is discarded, a fresh session starts, and the employee keeps its identity and history
