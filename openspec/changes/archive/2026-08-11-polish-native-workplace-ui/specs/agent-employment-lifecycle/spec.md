## ADDED Requirements

### Requirement: Candidate folios expose the complete hiring contract
The Employee catalogue and onboarding SHALL show a candidate's package version, creator, role, responsibilities, included skills, required connections, execution requirements, boundaries, and reduced-mode behavior before the owner can hire them. Onboarding MAY progressively disclose these facts behind an explicit contract-detail control, but MUST preserve a concise responsibility and boundary summary in the collapsed state.

#### Scenario: Owner inspects a candidate
- **WHEN** the owner selects an available employee package
- **THEN** the catalogue shows what the employee brings, what the organization must provide, and what remains unavailable
- **AND** offers an explicit Hire action rather than an install action that silently changes the roster

#### Scenario: Owner reviews the starter team
- **WHEN** the owner reaches the onboarding Team step
- **THEN** each candidate begins as a concise selectable summary with name, role, responsibility, essential skills, and authority boundary
- **AND** the owner can expand that candidate to inspect the complete declared contract before hiring
