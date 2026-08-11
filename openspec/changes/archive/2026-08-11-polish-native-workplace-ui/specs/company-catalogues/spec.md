## ADDED Requirements

### Requirement: Compact Company uses a readable employee directory
At compact widths, Company SHALL replace horizontally constrained relationship geometry with a vertical employee directory while preserving employee identity, reporting context, employment state, and access to full details.

#### Scenario: Owner opens Members in a compact window
- **WHEN** the Company surface is narrower than its relationship-wall layout can support
- **THEN** members appear as vertically scannable rows without horizontal scrolling
- **AND** selecting a row opens the same durable employee details available from the wide relationship wall

#### Scenario: Owner returns to a wide window
- **WHEN** sufficient width becomes available
- **THEN** Company may restore the authored relationship wall without losing the current member selection

