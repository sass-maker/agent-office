# Native Workplace Polish — Native Audit

Date: 2026-08-11  
Score: **18/20**  
Unresolved severity: **P0 0 · P1 0**

| Category | Score | Evidence |
|---|---:|---|
| Accessibility | 3/4 | Labelled compact navigation, selected traits, keyboard shortcuts, native scene accessibility representation, Reduce Motion, and corrected dark contrast are present. Larger-text coverage remains partial. |
| Performance | 4/4 | Primary growth surfaces use lazy collections; SpriteKit frame rate adapts to motion and Reduce Motion; retired nodes are explicitly removed. |
| Appearance | 4/4 | Semantic light/dark roles, warm reading surfaces, fixed on-ink content, and a dark tonal Office treatment preserve the Editorial Office character. |
| Platform conformance | 4/4 | SwiftUI and SpriteKit use native buttons, menus, pickers, toggles, sheets, alerts, focus, help, and keyboard commands without third-party UI dependencies. |
| Adaptivity | 3/4 | The labelled compact rail, vertical Company directory, progressive candidate contracts, and relaxed sheet geometry cover supported widths. Compact Employee Details and larger text merit a later pass. |

## Acceptance

The native polish meets the 16/20 audit floor and has no unresolved release-level
finding. Compact, intermediate, wide, light, and dark evidence was reviewed.
