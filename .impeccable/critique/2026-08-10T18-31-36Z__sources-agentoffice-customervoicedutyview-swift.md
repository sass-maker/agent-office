---
target: Customer Voice Weekly duty folio
total_score: 38
max_score: 40
na_heuristics: ""
p0_count: 0
p1_count: 0
timestamp: 2026-08-10T18-31-36Z
slug: sources-agentoffice-customervoicedutyview-swift
---
Method: dual-agent (A: issue8_design_review · B: issue8_native_audit)

## Design Health Score

| # | Heuristic | Score | Key issue |
|---|---|---:|---|
| 1 | Visibility of system status | 4 | Due state and explicit owner-run behavior are immediately visible. |
| 2 | Match system / real world | 4 | The weekly desk responsibility and local inbox model are concrete. |
| 3 | User control and freedom | 4 | Run, stop, retry, add feedback, and artifact actions are explicit. |
| 4 | Consistency and standards | 4 | The duty follows the Editorial Office folio and native control language. |
| 5 | Error prevention | 4 | The bounded inbox and no-write language set expectations before execution. |
| 6 | Recognition rather than recall | 4 | Delegation, accepted file types, schedule, and next action are shown in place. |
| 7 | Flexibility and efficiency | 3 | The focused duty is intentionally not a general scheduler or workflow builder. |
| 8 | Aesthetic and minimalist design | 3 | The portrait and duty facts repeat slightly within the surrounding folio. |
| 9 | Error recovery | 4 | Blocked, stopped, retry, and latest-brief paths are represented. |
| 10 | Help and documentation | 4 | Trust boundaries and manual execution are explained inline. |
| **Total** | | **38/40** | **Excellent** |

## Design Specificity Verdict

The result is authored for Agent Office: Iris's weekly responsibility appears as a paper duty card inside her employee folio, with `You → Mira → Iris`, a local feedback inbox, and owner-controlled execution. It does not resemble a generic cron editor or automation builder.

The isolated detector assessment returned `[]` (zero primary and advisory findings). Its Swift handling is generic regex scanning rather than SwiftUI parsing, so native source review and signed-window evidence remain authoritative for layout, VoiceOver, and state behavior.

## Overall Impression

The duty is now a complete primary journey rather than hidden implementation. At wide and native-minimum sizes, the owner can understand what Iris owns, what data she reads, when it runs, and what action is available without leaving the folio.

## What's Working

- The status capsule, due copy, and `Run now` action make manual execution unambiguous.
- The local-read/no-write explanation is unusually precise without becoming legalistic.
- The primary recurring duty and secondary general outcome are clearly separated.

## Priority Issues

- **P3 — Repeated portrait:** Iris appears in both the folio header and duty card. This reinforces attribution but adds slight density.
- **P3 — Repeated duty facts:** The standard current-duty and responsibility sections repeat information below the card. The scroll container prevents breakage, so this is optional distillation rather than a release issue.

## Persona Red Flags

- **First-time owner:** No blocking red flags; the card explains the inbox, accepted files, delegation, and manual-run behavior before action.
- **Keyboard and VoiceOver user:** Native labeled controls and scroll containment preserve the path. Status changes receive focused accessibility feedback after the final polish pass.
- **Privacy-conscious operator:** The bounded company inbox and “Nothing is sent or changed” language answer the highest-risk question directly.

## Minor Observations

The compact card correctly omits the long responsibility paragraph and lets `ViewThatFits` stack actions if horizontal room tightens.

## Questions to Consider

- If future duties are added, should standard folio facts collapse when a dedicated duty card already presents them?
- Would removing the second portrait weaken attribution more than it reduces density?
