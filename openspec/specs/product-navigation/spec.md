## Purpose

Defines the stable native information architecture that separates live workplace presence, coordinated work, and durable company memory without turning the product into dashboard software.

## Requirements

### Requirement: Three primary destinations
The application SHALL expose exactly three primary destinations named Office, Mission, and Company after onboarding, and SHALL preserve the current destination while organization state changes.

#### Scenario: Owner navigates the product
- **WHEN** the owner selects Office, Mission, or Company
- **THEN** the application displays that destination without opening a new window or losing organization state

### Requirement: Office remains the home destination
The application SHALL open the Office after onboarding and on normal subsequent launches unless a system restoration policy restores another explicit destination.

#### Scenario: First organization setup completes
- **WHEN** the owner finishes onboarding
- **THEN** the application opens the living Office with the created organization and team

### Requirement: Destination responsibilities remain distinct
The Office SHALL prioritize live people and current activity, Mission SHALL own planned work and goal hierarchy, and Company SHALL own organization context and catalogues.

#### Scenario: Owner needs detailed work state
- **WHEN** the owner follows a mission or task affordance from the Office
- **THEN** the application opens the Mission destination rather than embedding a duplicate full task board in the Office

### Requirement: Native navigation remains accessible
Every primary destination SHALL be reachable with labelled native controls and keyboard shortcuts independently of the SpriteKit workplace.

#### Scenario: Keyboard user changes destination
- **WHEN** the owner invokes the documented shortcut for a destination
- **THEN** focus and visible content move to that destination with an accessible destination label

### Requirement: Destinations share one committed visual world
Office, Mission, Company, Employee Details, and onboarding SHALL use the Editorial Office visual system so navigation, controls, work state, and organization context feel like parts of one premium 2D workplace rather than separate themed applications.

#### Scenario: Owner moves between destinations
- **WHEN** the owner opens Office, Mission, Company, or revisits onboarding
- **THEN** each surface preserves native semantics while using a full-height ink sidebar, warm bone and soft-grey working fields, graphite rules, and expressive monochrome employee portraits
- **AND** the surface has no global top or bottom bar and avoids dashboard-style equal card grids

### Requirement: Employee inspection has two depths
Selecting an employee in Office SHALL reveal a dismissible floating employee folio, and opening that folio or selecting a member in Company SHALL reveal the full Employee Details page.

#### Scenario: Owner inspects an employee from the Office
- **WHEN** the owner selects an employee in the living Office
- **THEN** a floating card shows identity, role, current duty, responsibility, collaborators, skills, and blocker state without resizing the scene
- **AND** opening the profile reveals the employee's durable details without creating a fourth primary sidebar destination
