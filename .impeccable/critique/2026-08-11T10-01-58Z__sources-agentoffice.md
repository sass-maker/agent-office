---
target: Agent employment hiring, working contracts, supervision, and canonical Mission
total_score: 33
max_score: 40
na_heuristics: 
p0_count: 0
p1_count: 0
timestamp: 2026-08-11T10-01-58Z
slug: sources-agentoffice
---
Method: dual-agent (A: /root/employment_design_assessment · B: /root/employment_detector_assessment)

# Agent employment and supervision critique

## Design Health Score

| # | Heuristic | Score | Key finding |
|---|---|---:|---|
| 1 | Visibility of System Status | 4 | Management decisions, commitments, child tickets, capacity, and accepted outcomes now use distinct canonical counts. |
| 2 | Match System / Real World | 4 | Hiring, working contracts, commitments, plan review, delivery, and acceptance form a coherent employment vocabulary. |
| 3 | User Control and Freedom | 3 | Pause, resume, stop, revise, reassign, and preserved history are strong; compact supervision remains scroll-heavy. |
| 4 | Consistency and Standards | 3 | The Editorial Office language is cohesive; a few older organisation/organization and compact-navigation inconsistencies remain. |
| 5 | Error Prevention | 4 | Destructive actions are confirmed, authority depends on declared tools, and required skills cannot be removed from open commitments. |
| 6 | Recognition Rather Than Recall | 3 | Candidate contracts and named contract controls are legible; the compact sidebar still becomes icon-only. |
| 7 | Flexibility and Efficiency | 3 | Shortcuts, filters, grouping, queues, and independent employee capacity work well; supervision remains intentionally item-by-item. |
| 8 | Aesthetic and Minimalist Design | 3 | Strong product-specific hierarchy, with unavoidable density where commitments and their ticket plans meet. |
| 9 | Error Recovery | 3 | Work is resumable and attributable; confirmations explain preservation, while contextual import recovery remains limited. |
| 10 | Help and Documentation | 3 | Boundary copy and contract explanations are clear; advanced authority concepts have no persistent help surface. |
| **Total** | | **33/40** | **Good — no release-severity design findings.** |

## Design Specificity Verdict

The result is strongly authored for this product. Named portraits, an illustrated office, paper folios, explicit candidate contracts, employee-owned commitments, and owner acceptance make it recognizably an agent workplace rather than a generic agent dashboard. The contract editor initially broke that spell with raw identifiers; named pickers, dependency-aware grants, human execution labels, and revision consequence copy now keep it understandable to a non-technical owner.

The deterministic web detector returned `[]`, but its directory scanner excludes Swift. It is therefore recorded as unsupported rather than treated as a clean native result. Native source inspection and five real app screenshots were the useful fallback. No browser overlay was attempted because SwiftUI/SpriteKit has no DOM injection surface.

## Overall Impression

The product now expresses the intended philosophy end to end: install a declarative employee package, choose whom to hire, materialize a durable identity and working contract, assign an outcome to that employee, review the plan, observe bounded execution, and judge the delivery separately from acceptance. The biggest remaining opportunity is to reduce density without concealing the contract facts that create trust.

## What's Working

- Employee identity remains stable while package provenance, skills, tools, grants, provider/model, and environment remain visibly separate.
- Mission makes the employee commitment primary and its generated tickets secondary, eliminating competing work systems.
- The native interaction layer is unusually trustworthy: semantic controls, keyboard shortcuts, reduced-motion handling, destructive confirmations, isolated stop behavior, and attributable local history.

## Priority Issues

### [P2] Compact navigation loses recognition

At the minimum window width, global destinations become icon-only and Company Members retains a horizontally scrolling relationship canvas. This increases orientation cost for first-time and low-vision owners.

**Fix:** preserve short destination labels and switch the compact relationship wall to a vertical member directory with details in a sheet.

**Suggested command:** `$impeccable adapt`

### [P2] Complete hiring disclosure is dense

The final onboarding step now discloses responsibility, skills, local environment, review, connection needs, publishing boundary, package provenance, provider preference, and reduced mode for five candidates. That completeness is valuable, but the always-expanded presentation creates a long decision surface.

**Fix:** keep the current facts but collapse each candidate into a concise selectable summary with an expandable contract folio.

**Suggested command:** `$impeccable distill`

## Persona Red Flags

- **Jordan, first-time owner:** the employment model is understandable now, but the five expanded candidate contracts make the last setup step feel heavier than earlier steps.
- **Sam, keyboard/low-vision owner:** native semantics and selected-state traits are strong; icon-only compact navigation and fixed relationship geometry still impair orientation.
- **Alex, power owner:** shortcuts and queues support efficient work, but repeated plan approvals remain deliberately individual because authority changes should not become an unsafe bulk action.

## Minor Observations

- The deliberate light Editorial Office appearance does not adapt to Dark Mode.
- Some fixed sheet minimums and task metadata columns will constrain very large accessibility text.
- A few bounded catalogues remain eager stacks, though primary employee and Mission collections are lazy.

## Questions to Consider

- Can a collapsed candidate folio preserve informed hiring while making the final setup step feel calm?
- Should compact Company prioritize a readable employee directory over retaining the relationship diagram?
- Which advanced contract concepts deserve persistent help after the owner has successfully hired their first team?
