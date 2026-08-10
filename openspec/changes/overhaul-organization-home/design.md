## Context

The current home is a fixed `HStack`: a dark employee sidebar, a central SpriteKit office, and a long paper-colored work rail. Each region is individually competent, but they use different hierarchy, material, density, and interaction models. The existing 2D office artwork and product behavior are valuable and remain in scope; the surrounding composition is the redesign target.

The owner has explicitly requested an overhaul and identified cross-region incoherence as the failure. `PRODUCT.md` and `DESIGN.md` keep the cosy golden-hour dollhouse world, human employee identity, native Mac semantics, and real-work truth as durable constraints.

## Goals / Non-Goals

**Goals:**

- Make the living workplace the organizing model for the whole window.
- Give owner attention and active work a short, glanceable path.
- Reveal employee and work detail contextually instead of maintaining an exhaustive always-visible ledger.
- Use a single material, portrait, spacing, and control vocabulary.
- Adapt structurally at narrow widths while retaining a native non-scene control path.

**Non-Goals:**

- Rebuilding the employee runtime, persistence, workday, research, recurring duty, skills, or permissions.
- Adding another employee, capability, integration, scheduler, cloud service, or marketplace behavior.
- Replacing the existing 2D office with 3D art or a generic dashboard.
- Treating generated probes as pixel-perfect screenshots to trace.

## Decisions

### Use an owner-approved composition probe as the implementation contract

Three high-fidelity probes preserve the same visual world while testing different topologies:

1. **Living Floorplan** — the office fills the window; employee and work detail appear as spatial pins, a selected-desk drawer, and a shallow owner tray.
2. **Studio Ledger** — employee shelf, office, and one contextual folio remain visible but become a single contiguous walnut cabinet.
3. **Rooms in Motion** — navigation becomes a connected multi-room floorplan with a shallow handoff timeline.

The selected probe will define hierarchy and interaction framing. Generated portraits, exact copy, furniture placement, and rasterized controls will not be copied literally.

The owner approved **Living Floorplan**. The implementation contract is: the existing office expands to become the dominant ground; employee selection is a compact spatial/navigation layer; a selected employee opens one contextual work drawer; and a shallow owner tray exposes only Needs you, In motion, and Delivered. The exact generated character art, room geometry, text density, and oversized floating card are illustrative rather than literal. Native SwiftUI text and controls remain semantic and the existing SpriteKit room remains the shipped scene asset.

After reviewing the first implementation, the owner kept the cartoon office direction but rejected its low-contrast brown-on-brown treatment. The refinement contract keeps the Living Floorplan topology and gives color stable roles: deep spruce is painted structural chrome, warm yellow paper is the work surface, butter marks selection and construction edges, and apricot remains a scarce attention accent. Walnut stays inside the illustrated room and as a minor outline rather than owning the application shell. This is a contrast and cohesion pass, not a second composition redesign.

After reviewing the contrast pass, the owner set a substantially higher craft bar. The remaining defect is not palette but embodiment: the top shelf, outcome ribbon, contextual drawer, and bottom tray still read as ordinary application panels placed over a cartoon office. The final refinement keeps the approved topology and behavior but makes each supporting surface a recognizable workplace object: painted employee cubbies, a pinned outcome sheet, a clipped activity note, one bound desk folio, and physical inbox/outbox trays. Native controls remain semantic and familiar inside those objects; decoration must clarify hierarchy rather than disguise interaction.

### Preserve one source of operational truth

Existing `AppModel` and core state remain authoritative. The new shell derives presentations from the same employees, tasks, blockers, assignments, occurrences, artifacts, and activity. No parallel view-only task model will be introduced.

### Make selection the progressive-disclosure boundary

The default overview prioritizes the workplace, the active/attention state, and the next owner action. Selecting an employee or work item reveals deeper controls through a contextual native surface. This prevents the current right rail from growing whenever a capability is added.

### Keep critical actions outside SpriteKit

SpriteKit continues to render position and movement, but SwiftUI owns buttons, focus, accessibility labels, inspectors/drawers, and text. Scene selection may coordinate with the same selected-employee state, but no action depends exclusively on hit-testing illustrated furniture or characters.

### Replace fixed three-column compression with structural breakpoints

The normal-width composition follows the approved probe. At narrower widths, secondary navigation and detail become a native inspector, drawer, or toolbar surface instead of simultaneously squeezing a sidebar, scene, and rail. Semantic type sizes remain unchanged.

### Treat the day counter as historical metadata

The workday state and Start/End action remain. Prominent `DAY N` labels leave the primary composition because the count does not currently help the owner choose or supervise work.

## Risks / Trade-offs

- **[Risk] Spatial UI can hide operational state** → Keep an explicit owner-attention summary and native selected-employee detail path outside the scene.
- **[Risk] Generated comps imply assets or layout beyond the current scene** → Inventory every visible ingredient after approval and implement only what can be supported by existing assets or a separately reviewed generated asset.
- **[Risk] Removing the full ledger can reduce expert scan density** → Preserve a compact overview of Needs you, In motion, and Delivered, with deeper lists available contextually.
- **[Risk] The scene may dominate smaller windows** → Define and visually verify a structural minimum-width state rather than scaling the whole interface down.
- **[Risk] Overhaul work can accidentally change behavior** → Keep core models untouched where possible and run the existing full test suite plus focused interaction checks.

## Migration Plan

1. Record owner selection or explicit delegation in the design receipt and this design.
2. Introduce the new composition around existing views and actions, keeping behavior wired to `AppModel`.
3. Replace the old shell only after the new normal and narrow layouts build and remain keyboard-accessible.
4. Package and visually inspect the native app; retain the current implementation in version control for ordinary rollback until the change is accepted.
