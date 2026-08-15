## MODIFIED Requirements

### Requirement: Employees continuously inhabit the workplace
The Office SHALL route active employees to task-appropriate stations, blocked
employees to the help desk, and resting employees to stable authored stations.
Outside Reduce Motion mode, each employee SHALL retain a position, walk along
valid routes toward the destination derived from current work, and face their
travel direction. Employees SHALL NOT teleport between workstations or pass
through authored obstacles. Labels SHALL emphasize selected or active employees
rather than remaining as a permanent overlay, and ambient movement SHALL NOT
imply work that is absent from persisted state.

#### Scenario: A workday begins
- **WHEN** the owner starts a resting organization
- **THEN** available employees walk from their resting areas to the stations or meetings required by their current work

#### Scenario: Employee accepts an outcome
- **WHEN** a selected employee changes from resting to planning or working
- **THEN** the Office visibly moves that employee to the relevant station and exposes the current state

#### Scenario: Employee is resting
- **WHEN** an employee has no current work or blocker
- **THEN** the employee remains at a stable authored station without decorative wandering

#### Scenario: A destination becomes occupied
- **WHEN** an employee's route or destination conflicts with another employee
- **THEN** the scene selects an available nearby route or waiting position without overlapping the two characters

#### Scenario: Reduce Motion is enabled
- **WHEN** employee state changes while Reduce Motion is enabled
- **THEN** the Office applies the new location and state immediately without travel animation
