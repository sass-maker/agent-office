## Why

The organization home currently reads as three unrelated products: a dark employee roster, a 2D office simulation, and a beige operational ledger. The product's strongest idea is the living workplace itself, so the shell should make employee identity, work state, and owner attention feel like parts of one coherent spatial environment before more capabilities are added.

## What Changes

- Overhaul the whole native organization-home composition while preserving the existing employee, workday, research, duty, skill, permission, artifact, and local-execution behavior.
- Keep the high-quality 2D office as the visual authority and integrate navigation and work controls into the same spruce, walnut, paper, portrait, and label system.
- Replace the current always-visible three-column hierarchy with an owner-approved spatial model that reveals detail contextually and gives the office substantially more of the window.
- Remove day-number prominence from the primary hierarchy; retain any durable day state only where it helps history or workday controls.
- Make owner attention, active work, selected-employee responsibility, and delivered output immediately legible without forcing a long ledger scan.
- Preserve a complete native text/control path outside the SpriteKit scene, keyboard access, reduced-motion behavior, and usable narrow-window adaptation.
- Produce and review three high-fidelity composition probes before implementation. The selected probe is an explicit design gate, not a pixel-perfect implementation contract.

## Capabilities

### New Capabilities

- `coherent-organization-home`: A unified spatial organization home that makes the living office primary while keeping employee navigation, owner attention, active work, and contextual actions legible and accessible.

### Modified Capabilities

None. The change preserves the existing operational contracts and changes their presentation and navigation.

## Impact

- Primarily affects `Sources/AgentOffice/OrganizationHomeView.swift` and supporting SwiftUI views/components around the SpriteKit office.
- May add small view-state and layout helpers, but does not change persistence schemas, employee execution, permissions, integrations, or stored artifacts.
- Uses existing Apple SDK frameworks and bundled assets; no production dependency or deployment change.
- Tracked by GitHub issue #8 and a Fleet overhaul design-review receipt.
