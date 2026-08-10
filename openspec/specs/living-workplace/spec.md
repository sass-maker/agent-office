## Purpose

Defines the native two-dimensional workplace as an accessible, truthful view
of the organization rather than decorative simulation disconnected from work.

## Requirements

### Requirement: Workplace activity reflects real organization state
Employee location, animation, status, and nearby objects SHALL be derived from
the employee's current task, presence, review state, or blocker.

#### Scenario: Writer submits work for review
- **WHEN** the writer's draft moves to manager review
- **THEN** the workplace and task board both reflect the handoff to the manager

### Requirement: Employees continuously inhabit the workplace
Outside Reduce Motion mode, each employee SHALL retain a position, walk through
the room along valid routes toward task-derived destinations, face their travel
direction, and perform restrained idle movement when resting. Employees SHALL
not teleport between workstations or pass through authored obstacles.

#### Scenario: A workday begins
- **WHEN** the owner starts a resting organization
- **THEN** available employees walk from their resting areas to the stations or meetings required by their current work

#### Scenario: A destination becomes occupied
- **WHEN** an employee's route or destination conflicts with another employee
- **THEN** the scene selects an available nearby route or waiting position without overlapping the two characters

### Requirement: Core work state is available outside the scene
Goals, blockers, tasks, employees, and primary workday controls SHALL be
available as native text and controls outside the rendered workplace.

#### Scenario: Scene is not used
- **WHEN** a user navigates with keyboard or assistive technology instead of interacting with the 2D scene
- **THEN** they can still inspect work state, start or end the day, and select an employee or task

### Requirement: The scene remains cosy without becoming corporate software
The opening surface SHALL lead with a warm inhabited workplace and use compact
supporting work surfaces instead of presenting a generic analytics dashboard,
HR directory, or kanban application as the dominant experience.

#### Scenario: Organization opens
- **WHEN** the owner opens the organization home
- **THEN** the living workplace is the largest region while goals, blockers, and tasks remain immediately scannable

### Requirement: Supporting rails belong to the visual world
The employee roster and work rail SHALL read as an inviting team shelf and
studio work ledger, using portraits, ownership, progress, paper hierarchy, and
room-derived materials rather than generic navigation rows or dashboard cards.

#### Scenario: Owner inspects the home surface
- **WHEN** the organization home is visible
- **THEN** the two rails support the office with richer employee and work detail without competing with the room or resembling HR software

### Requirement: Motion respects platform preferences
The application SHALL reduce ambient movement and non-essential transitions
when macOS Reduce Motion is enabled while keeping status changes legible.

#### Scenario: Reduce Motion is enabled
- **WHEN** the operating system reports reduced motion preference
- **THEN** employees change meaningful positions without continuous idle movement or decorative animation
