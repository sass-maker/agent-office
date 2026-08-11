---
target: Mission task page, face-first portraits, and employee folios
total_score: 36
max_score: 40
na_heuristics: 
p0_count: 0
p1_count: 0
timestamp: 2026-08-09T23-21-22Z
slug: sources-agentoffice-missionview-swift
---
Method: dual-agent (A: mission_finish_design · B: mission_finish_detector)

## Design Health Score

| # | Heuristic | Score | Key issue |
|---|---|---:|---|
| 1 | Visibility of System Status | 4 | Counts, ownership, task state, selection, and inspector position are explicit. |
| 2 | Match System / Real World | 4 | Mission, owners, reviewers, blockers, artifacts, and activity match the workplace model. |
| 3 | User Control and Freedom | 4 | Filters clear, groups collapse, sheets dismiss, and compact inspection moves between tasks. |
| 4 | Consistency and Standards | 4 | Native controls and the ink-and-paper system remain consistent across widths. |
| 5 | Error Prevention | 3 | Empty mission saves and dirty navigation are guarded; broader task mutation is intentionally absent. |
| 6 | Recognition Rather Than Recall | 4 | Faces, names, roles, statuses, counts, grouping value, and artifact labels stay visible. |
| 7 | Flexibility and Efficiency | 3 | Search, filters, grouping, keyboard dismissal, and inspector traversal support repeat use. |
| 8 | Aesthetic and Minimalist Design | 4 | The surface is restrained, product-specific, and deliberately monochrome. |
| 9 | Error Recovery | 3 | Empty search recovery is explicit; uncommon artifact/save failures rely on the app-level alert. |
| 10 | Help and Documentation | 3 | Labels and tooltips cover controls; first-time guidance remains intentionally light. |
| **Total** |  | **36/40** | **Excellent; release-ready with lower-severity polish remaining.** |

## Design Specificity Verdict

The result is strongly authored for this product. The serif Grand Mission, black/bone task instrument, named employee faces, folio inspector, relationship wall, and monochrome status language feel like one quiet company operating system rather than a generic project dashboard. The deterministic scanner returned no findings because it does not understand native SwiftUI; the independent native audit used source and signed-window evidence instead and scored 16/20.

## Overall Impression

The Mission surface now leads with purpose but behaves like a practical daily task tool. The largest improvement is compact usability: summaries are readable in place, grouping is named, and task details can be compared without repeatedly dismissing the inspector.

## What's Working

- Mission, filters, grouped work, and task evidence form a clear operational hierarchy.
- Face-first portraits make employee identity scannable without reintroducing HR-dashboard styling.
- Monochrome meaning is carried by type, symbols, rules, fill, and contrast instead of status hue.

## Priority Issues

- **[P2] Activity history remains visually repetitive.** Collapse older entries or emphasize only the latest event when histories grow.
- **[P2] Compact detail remains modal.** Previous/next traversal mitigates the context switch; a future resizable inspector could preserve more list context.
- **[P3] Some first-time guidance is implicit.** Keyboard shortcuts and less-common inspector actions could be surfaced contextually.

## Persona Red Flags

- **Alex:** Core scanning and traversal are efficient now; shortcut discovery remains the only notable power-user gap.
- **Jordan:** Visible Status grouping, named employees, and readable summaries reduce guesswork; task keys still require brief familiarization.
- **Sam:** Semantic labels contain the full task detail and critical headings scale; a future pass should verify the complete VoiceOver focus order on-device.

## Minor Observations

- Portrait decoding and cropping are synchronous and uncached, though the current employee count is small.
- Long artifact paths remain single-line in the inspector.
- Repeated identical demo timestamps make activity feel less chronological than production data will.

## Questions to Consider

- When activity histories become long, should the inspector show the latest decision or the full timeline by default?
- Should task-key shortcuts become part of the visible product language once the board supports task creation?
