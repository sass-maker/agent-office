## Context

See `proposal.md` for motivation. The product is a dependency-free SwiftUI and SpriteKit macOS application with a deliberately authored monochrome Editorial Office world. Its central theme tokens are shared, but several roots force light appearance, the main shell becomes icon-only below 820 points, Company retains a fixed relationship canvas, onboarding expands all five candidate contracts, and supporting sheets declare minimum widths that exceed compact host windows.

The product's native Mac identity and local execution boundaries must remain unchanged. This is refinement, not a replacement visual direction.

## Goals / Non-Goals

**Goals:**

- Preserve the full-height editorial navigation while keeping destination recognition at 760-point window width.
- Let onboarding disclose complete candidate contracts without presenting five dense expanded folios simultaneously.
- Give Company an intentional compact topology and remove avoidable sheet width constraints.
- Resolve appearance through shared semantic Editorial Office tokens so all existing surfaces benefit consistently.
- Verify real light and dark native windows at compact, intermediate, and wide sizes.

**Non-Goals:**

- Changing employee behavior, persistence, execution, permissions, or employment vocabulary.
- Replacing the Office scene, typography, portrait language, or monochrome product identity.
- Adding a user-selectable theme preference, third-party design system, or cross-platform client.

## Decisions

### 1. Keep a labelled compact rail instead of switching navigation models

At the supported macOS minimum, the rail will become narrower but retain short labels beneath or beside SF Symbols. This preserves the product's single full-height sidebar contract and avoids inventing a toolbar or tab bar for only one width.

Alternative considered: icon-only rail with tooltips. Rejected because tooltips and memorized symbols do not provide persistent orientation, especially during onboarding and low-vision use.

### 2. Use disclosure per candidate, with one expanded contract at a time

Each candidate row will show identity, role, responsibility, essential skills, selection state, and authority boundary. A native disclosure action expands the complete package contract, and expanding one candidate collapses the previous one. Selection and disclosure remain independent.

Alternative considered: one global contract summary. Rejected because requirements differ by employee and must remain attributable before hire.

### 3. Change Company topology at a semantic width threshold

Wide Company retains the approved relationship wall. Compact Company renders an ordered vertical directory using the same portrait and employment data, with selection opening the existing employee-details depth. The interface changes structure from available width, not device identity.

Alternative considered: horizontally scrolling the relationship wall. Rejected because it hides people and reporting context while making keyboard and magnified use harder.

### 4. Resolve appearance at the theme-token layer

Editorial color roles will use native dynamic colors with deliberate light and dark values. Root-level forced-light modifiers will be removed. Warm bone/paper become warm charcoal/parchment roles in dark appearance; ink and rules invert by role while the structural sidebar remains the darkest anchor.

Alternative considered: preserve light-only appearance. Rejected because system appearance is a native user preference and shared tokens make authored support feasible without a redesign.

### 5. Prefer flexible frames and scrolling over smaller controls

The main window keeps a 760-point supported minimum, but secondary sheets will use ideal/default sizes instead of hard minimum widths wherever content can naturally reflow or scroll. Text remains semantic and primary controls retain native target sizes.

Alternative considered: lower the main minimum below the current product topology. Rejected for this pass because the SpriteKit workplace and Mission supervision need a meaningful desktop canvas.

## Risks / Trade-offs

- **[Dark tokens reveal one-off white or black overlays]** → Inspect each primary destination in a forced dark process and replace only overlays that break semantic contrast.
- **[Disclosure can hide facts owners need]** → Keep the authority boundary and essential capability summary collapsed, use an explicit `Contract details` label, and allow review before selection or completion.
- **[Company layouts drift functionally]** → Derive both relationship wall and compact directory from the same member collection and route both selections through the same employee-details action.
- **[Removing sheet minimums creates cramped controls]** → Retain sensible ideal sizes, add vertical scrolling, and verify at the 760-point host width rather than removing all geometry constraints mechanically.
- **[Existing uncommitted work overlaps these files]** → Keep diffs narrow, inspect the current source as authoritative, and avoid unrelated cleanup.

## Migration Plan

No data migration is required. The change is entirely presentational and behavioral at the SwiftUI layer. Rollback consists of restoring the previous theme roles and layout branches; persisted organizations remain compatible.
