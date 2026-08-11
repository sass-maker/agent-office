## Why

The employment system is functionally complete, but its narrow-window navigation, onboarding team disclosure, fixed geometry, and light-only presentation still make the native workplace feel heavier and less adaptable than the underlying product model. This pass should remove those last usability seams without replacing the Editorial Office visual language or concealing any hiring and supervision facts.

## What Changes

- Keep destination names visible at the supported minimum window width while preserving the full-height ink navigation rail.
- Replace the compact Company relationship canvas with a readable vertical employee directory and native detail presentation.
- Distill the onboarding Team step into selectable candidate summaries with progressively disclosed contract details.
- Make primary windows and supporting sheets resize cleanly across compact, intermediate, and wide macOS window sizes.
- Add an authored dark appearance that preserves the monochrome paper-and-ink hierarchy rather than applying a mechanical inversion.
- Preserve keyboard navigation, Dynamic Type, Reduce Motion, local-only execution, and all existing employment behavior.

## Capabilities

### New Capabilities

- `native-interface-adaptivity`: Defines resizable macOS geometry and coherent light and dark Editorial Office appearances.

### Modified Capabilities

- `product-navigation`: Compact navigation keeps destination labels and recognizable orientation cues.
- `coherent-organization-home`: Narrow layouts retain usable controls without an icon-only global rail.
- `company-catalogues`: Compact Company presents employees as a vertical directory rather than a horizontally constrained relationship wall.
- `agent-employment-lifecycle`: Candidate contract disclosure becomes progressive while remaining complete before hire.

## Impact

- Affects SwiftUI shell, onboarding, Company, theme tokens, supporting sheets, and related visual evidence.
- Does not change persisted organization schema, employee execution, permissions, package semantics, or external integrations.
- Adds no dependencies and performs no cloud, publishing, or infrastructure work.
