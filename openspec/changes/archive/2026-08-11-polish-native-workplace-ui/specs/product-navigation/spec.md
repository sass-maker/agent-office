## MODIFIED Requirements

### Requirement: Native navigation remains accessible
Every primary destination SHALL be reachable with labelled native controls and keyboard shortcuts independently of the SpriteKit workplace. At the supported minimum width, destination controls MUST retain their visible text labels rather than relying on icon recognition alone.

#### Scenario: Keyboard user changes destination
- **WHEN** the owner invokes the documented shortcut for a destination
- **THEN** focus and visible content move to that destination with an accessible destination label

#### Scenario: Window reaches its supported minimum width
- **WHEN** the global navigation becomes compact
- **THEN** Office, Mission, and Company remain visibly named
- **AND** the current destination remains visually and semantically selected

