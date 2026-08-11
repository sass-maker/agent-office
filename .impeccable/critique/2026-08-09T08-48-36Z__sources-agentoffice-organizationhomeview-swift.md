---
target: coherent spatial organization home overhaul
total_score: 34
max_score: 40
na_heuristics: 
p0_count: 0
p1_count: 0
timestamp: 2026-08-09T08-48-36Z
slug: sources-agentoffice-organizationhomeview-swift
---
Method: dual-agent (A: organization_home_assessment_a · B: organization_home_assessment_b)

## Design Health Score

| # | Heuristic | Score | Key issue |
|---|---|---:|---|
| 1 | Visibility of System Status | 4 | Work, attention, delivery, duty, and employee states are explicit. |
| 2 | Match System / Real World | 4 | Desks, colleagues, handoffs, outcomes, and deliveries form a fluent workplace metaphor. |
| 3 | User Control and Freedom | 3 | Contextual drawers close cleanly; explicit undo remains limited. |
| 4 | Consistency and Standards | 4 | Shelf, office, paper drawers, and owner tray now read as one system. |
| 5 | Error Prevention | 3 | Disabled states, brief validation, and bounded permission copy provide strong guardrails. |
| 6 | Recognition Rather Than Recall | 3 | Core paths are visible; compact secondary tools depend more heavily on symbols and help. |
| 7 | Flexibility and Efficiency | 3 | Command-Return exists for the workday; more employee and tray accelerators could help experts. |
| 8 | Aesthetic and Minimalist Design | 4 | The office is dominant and supporting UI is purposeful rather than dashboard-like. |
| 9 | Error Recovery | 3 | Work is preserved and blockers are contextual, though global errors still use a simple acknowledgement alert. |
| 10 | Help and Documentation | 3 | Tooltips and explanatory states are good; a task-focused help path is still light. |
| **Total** | | **34/40** | **Good** |

## Design Specificity Verdict

The result is strongly authored for a tiny AI organization. Named employees inhabit task-derived stations; selection opens a desk; the outcome ribbon, activity cue, and owner tray map directly to supervision. The Living Floorplan materially solves the previous sidebar, scene, and right-rail incoherence.

The deterministic scan returned zero findings for `Sources/AgentOffice/OrganizationHomeView.swift`. That is advisory only: the scanner does not validate SwiftUI accessibility, keyboard behavior, or native adaptivity. Native source inspection and rendered screenshots supplied the meaningful evidence. Browser overlays were not applicable because this is a native macOS SwiftUI and SpriteKit target.

## Overall Impression

The application now feels like one inhabited workplace instead of three stitched-together products. The single biggest opportunity is no longer composition; it is deeper native refinement around focus, power-user navigation, appearance variants, and idle rendering.

## What's Working

- The office remains visually authoritative while every consequential action has a native SwiftUI route.
- Employee selection, owner attention, active work, and delivered output use one coherent walnut-and-paper vocabulary.
- The compact layout structurally changes instead of squeezing three columns; Iris's complete action path remains visible at the minimum window size.

## Priority Issues

1. **[P2] Contextual drawer focus is not explicitly managed.** VoiceOver and keyboard users may need to rediscover where focus moved after opening a desk or owner tray. Add an accessibility focus target and restore focus on close.
2. **[P2] SpriteKit remains configured for 60 FPS while the office rests.** Reduce idle frame demand or pause updates when no employee is travelling.
3. **[P2] The authored palette is raw-color based.** Verify or introduce appearance-aware variants for Dark Mode and Increased Contrast without discarding the golden-hour world.
4. **[P3] Activity attribution can duplicate names.** A message such as `Iris: Iris joined...` should avoid repeating the actor.
5. **[P3] Compact company tools rely on symbols.** Their labels remain accessible, but stronger visible recognition could help first-time and low-vision users.

## Persona Red Flags

**Alex (Power User):** The workday has Command-Return, but switching among six employees and three owner-tray views still lacks accelerators.

**Jordan (First-Timer):** Product and Library become symbol-only at minimum width, so the owner must learn those two controls despite good accessibility labels and help.

**Sam (Accessibility-Dependent):** The native employee shelf and task mirror are strong alternatives to SpriteKit, but contextual drawers do not explicitly move or announce accessibility focus.

## Minor Observations

- Character source images still have some scale variation even after spatial collisions were removed.
- The disabled completed-work control is calm but not especially celebratory.
- The owner tray deliberately favors current operational state over exhaustive historical density.

## Questions to Consider

- Should opening a colleague's desk feel like moving focus into a native inspector, or like selecting an object that leaves focus in the shelf?
- When the office is resting, how much ambient motion earns its energy cost?
- Should compact Product and Library controls retain short text labels by moving less-frequent controls into overflow?

Questions skipped: the remaining issues are straightforward follow-up polish, and the owner already delegated this implementation pass.
