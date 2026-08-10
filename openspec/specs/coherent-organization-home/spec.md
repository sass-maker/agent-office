## Purpose

Make the native organization home feel like one living workplace while preserving clear, accessible control over employees and their real work.

## Requirements

### Requirement: The workplace is the primary surface
The organization home SHALL give the 2D workplace visual and spatial priority over navigation, summaries, and operational controls.

#### Scenario: Owner opens an established organization
- **WHEN** the owner enters the organization home
- **THEN** the workplace occupies the dominant part of the window and supporting controls read as part of the same visual system

### Requirement: Work state is contextual and truthful
The organization home MUST show active work, due or blocked attention, selected-employee responsibility, and delivered output from persisted organization state without decorative fake activity.

#### Scenario: Employee needs owner attention
- **WHEN** an assignment or recurring duty is due or blocked
- **THEN** the relevant employee and work item receive a visible, textual attention treatment reachable from the primary surface

#### Scenario: Owner selects an employee
- **WHEN** the owner selects a named employee from the workplace or its native navigation mirror
- **THEN** the home reveals that employee's real role, responsibility, status, and applicable actions without replacing the workplace with a generic dashboard

### Requirement: One coherent navigation and material system
The organization home SHALL use one consistent hierarchy, control vocabulary, portrait treatment, spacing rhythm, and material language across the scene and all supporting interface regions.

#### Scenario: Owner scans the whole window
- **WHEN** the organization home is visible at its normal width
- **THEN** employee navigation, workplace state, owner attention, and contextual work detail appear compositionally connected rather than as three independent columns

### Requirement: Structural chrome contrasts with the illustrated office
The organization home SHALL use a high-contrast storybook palette that keeps native controls distinct from the warm wooden scene while still reading as painted office furniture and paper work surfaces.

#### Scenario: Owner scans controls over the office
- **WHEN** the command shelf, outcome ribbon, contextual drawer, and owner tray appear over the illustrated workplace
- **THEN** deep spruce structure, warm paper, and limited butter or apricot accents create clear visual separation without making the home resemble a corporate dashboard

### Requirement: Supporting controls are embodied as workplace objects
The organization home SHALL present navigation, outcome, activity, contextual detail, and owner queues as recognizable objects within the illustrated office world rather than as generic floating dashboard panels.

#### Scenario: Owner scans the supporting interface
- **WHEN** the command shelf, outcome, activity, employee detail, and owner queues are visible
- **THEN** they read respectively as painted cubbies, pinned paper, a clipped note, a bound desk folio, and physical work trays while preserving native control semantics

### Requirement: Day numbering is secondary
The organization home SHALL NOT use the organization's day number as a primary navigation or hierarchy element.

#### Scenario: Workday is resting or complete
- **WHEN** no workday is active
- **THEN** the primary surface explains the current organization state and next useful action without relying on a prominent Day N label

### Requirement: Accessible native control path
Every consequential workplace action and state MUST remain available through native semantic controls and text outside of scene-only interaction.

#### Scenario: Scene interaction is unavailable
- **WHEN** a user navigates by keyboard, VoiceOver, Reduce Motion, or a non-interactive scene state
- **THEN** they can still select employees, inspect attention, run or stop eligible work, and reveal artifacts through native controls

### Requirement: Structural narrow-window adaptation
The organization home MUST adapt its topology at the supported minimum window width without shrinking functional text below native semantic sizes or clipping primary actions.

#### Scenario: Window reaches minimum supported width
- **WHEN** the owner narrows the application window
- **THEN** secondary information collapses into contextual inspectors, drawers, or native navigation while the workplace and primary owner action remain usable

### Requirement: Existing employee behavior is preserved
The overhaul MUST preserve the established employee, workday, research, recurring-duty, permission, skill, task, blocker, artifact, and local-persistence behavior.

#### Scenario: Owner uses an existing workflow after the overhaul
- **WHEN** the owner starts or stops a workday, assigns research, runs Customer Voice Weekly, grants or revokes research permission, teaches a skill, or reveals an artifact
- **THEN** the operation follows the same existing state and safety contract while appearing in the new shell
