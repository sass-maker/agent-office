---
target: existing Agent Office product philosophy fit
total_score: 27
max_score: 40
na_heuristics: 
p0_count: 0
p1_count: 4
timestamp: 2026-08-11T08-24-12Z
slug: sources-agentoffice-organizationshellview-swift
---
Method: dual-agent (A: /root/design_assessment · B: /root/detector_assessment)

## Design Health Score

| # | Heuristic | Score | Key Issue |
|---|-----------|-------|-----------|
| 1 | Visibility of System Status | 3 | Employee status, progress, blockers, activity, and artifacts are visible; generic outcome ownership is not consistently reflected in the shell. |
| 2 | Match System / Real World | 3 | Names, roles, responsibilities, outcomes, and handoffs feel natural; several internal work concepts leak into the owner's experience. |
| 3 | User Control and Freedom | 2 | Stop, retry, cancel, Back, and reopening recovery exist, but owners cannot revise a generated plan, reassign work, answer arbitrary help, or undo key changes. |
| 4 | Consistency and Standards | 3 | The visual system is cohesive; mission/outcome/duty/assignment and Resting/Available describe overlapping concepts inconsistently. |
| 5 | Error Prevention | 3 | Bounded plans, validation, explicit grants, and local write boundaries are strong; some disabled states do not explain what is missing. |
| 6 | Recognition Rather Than Recall | 3 | Faces, names, inspectors, and contextual folios are strong; compact icon-only navigation and hidden scene labels weaken recognition. |
| 7 | Flexibility and Efficiency | 2 | Useful keyboard shortcuts and search exist, but the single active outcome and lack of triage/reassignment form a rigid operating path. |
| 8 | Aesthetic and Minimalist Design | 3 | The editorial office is distinctive and restrained; Mission and Employee Details expose too many simultaneous layers. |
| 9 | Error Recovery | 3 | Specific errors, retry, stop, and resumable state are real strengths; recovery is limited to coarse actions. |
| 10 | Help and Documentation | 2 | Onboarding and boundary copy teach the basics; the competing work mechanisms and employee contract lack persistent explanation. |
| **Total** | | **27/40** | **Acceptable — strong foundation, significant product-model refinement needed.** |

## Design Specificity Verdict

**LLM assessment:** The product is highly authored visually and moderately authored operationally. The monochrome illustrated Office, employee portraits, paper folios, relationship wall, and continuity of identity across Office, Mission, and Company are unmistakably specific to this product. The Office and Company surfaces could not be transplanted into an unrelated SaaS product unchanged. Specificity weakens in Mission and employee ledgers, which fall back toward familiar project-management and admin patterns. The luxury architectural backdrop is memorable but sometimes overpowers the employees and feels more like a showroom than a lived-in small workplace.

**Deterministic scan:** The detector returned zero findings for `Sources/AgentOffice`, but this is not a meaningful clean pass: its directory walker excludes `.swift`, so it scanned no Swift source. A fallback scan of `OrganizationShellView.swift` also returned zero findings, but the detector has no declared Swift/native grammar. Manual source evidence therefore owns the technical conclusions.

**Visual overlays:** Not applicable. This is a native SwiftUI/SpriteKit macOS target with no DOM or browser injection surface. Representative native screenshots were inspected directly; no user-visible browser overlay exists.

## Overall Impression

The product already believes the right thing: an employee is a durable organizational member, not a prompt, chat, workflow, or model session. That belief is visible in the data model and the strongest UI surfaces. The implemented product, however, begins after employment. It seeds a fixed roster and offers a single execution lane. The largest opportunity is to build the employment and management layer around the strong employee core rather than add more special-purpose workflows.

## What's Working

1. **Employee identity is genuinely durable.** The same name, face, role, responsibility, reporting relationship, skills, work, artifacts, and history recur across surfaces and survive restarts in inspectable local employee homes.

2. **Outcome ownership is real.** The owner can select an AI employee, assign a result, and let that employee select assigned skills, create one to four tickets, produce local artifacts, communicate progress, ask for precise help, and recover after interruption. Focused outcome-engine tests pass for planning, delivery, permissions, interruption, and the single-active boundary.

3. **Trust is expressed through work rather than transcripts.** Status, tasks, blockers, handoffs, evidence basis, artifacts, stop/retry, and local persistence make agent work inspectable without reducing the employee to a chat window.

## Priority Issues

### [P1] The product begins after hiring

**Why it matters:** The product proposition says the owner hires an agent that arrives with a role, skills, tools, and capabilities. The implemented onboarding simply reveals a seeded content team. There is no owner-facing hire, accept, pause, retire, remove, or replace lifecycle.

**Fix:** Introduce the smallest honest hiring moment before a marketplace: a candidate employee folio with identity, role, responsibilities, outcomes they can own, included skills, required tools/connections, execution needs, and boundaries. Let the owner explicitly hire a starter employee or starter team into the organization. Persist employment state separately from work status.

**Suggested command:** `$impeccable shape`

### [P1] Work is split into competing ontologies

**Why it matters:** Fixed content day, generic outcome, research assignment, recurring Customer Voice duty, Grand Mission, and Start Day all appear to be ways to make work happen. Owners must understand the engines instead of simply managing people.

**Fix:** Make the employee-owned Outcome the canonical work object. Research and Customer Voice become reusable outcome templates or recurring responsibilities. Mission shows the tickets produced by every outcome. Start/End Day becomes scheduling and interruption, not a separate fixed workflow launcher.

**Suggested command:** `$impeccable shape`

### [P1] The employee's working contract is missing

**Why it matters:** The philosophy depends on preserving the distinction between employee identity, skills, tools, permissions, execution environment, and model. Today the runtime is organization-wide; employees have no explicit model/runtime/machine record; tools and capabilities are mostly catalogue or hard-coded concepts. Employee Details even labels the global organization mission as each employee's current outcome.

**Fix:** Add a concise Working Contract to every AI employee: identity and role; responsibilities; skills; tools/connections; capability grants; execution provider/model/environment; autonomy limits; local home; current scoped outcomes. Lead Employee Details with `latestEmployeeOutcome(for:)`, and demote the organization mission to shared context.

**Suggested command:** `$impeccable clarify`

### [P1] Management is mostly observation plus stop/retry

**Why it matters:** The owner can inspect work, grant one permission, stop, and retry, but cannot revise a generated plan, answer a help request in context, reassign a ticket, request a correction, approve a generic delivery, change reporting lines, or coordinate multiple active employees. Generic outcomes never delegate and only one can be active organization-wide.

**Fix:** Build a manager loop before broad autonomy: employee proposes plan; owner may approve/edit scope; employee works; owner can answer, redirect, reassign, request changes, accept delivery, or queue the next outcome. Then replace the global single `workTask` with per-employee runs and an explicit organization queue before adding arbitrary concurrency.

**Suggested command:** `$impeccable shape`

### [P2] The Office's next action and compact behavior are fragile

**Why it matters:** Resting employees blend into the detailed room, supplied screenshots say “Work complete,” and the next action is hidden behind selecting a person. Compact navigation becomes icon-only, the relationship wall retains a wide horizontal canvas, and the assignment sheet has a 760-point minimum.

**Fix:** Verify the current “Office ready” state and employee desk bar in the built app. Keep names/status and “Give an outcome” discoverable without hunting in the scene. Use a vertical member directory at compact widths and stack employee identity above the assignment form.

**Suggested command:** `$impeccable adapt`

## Persona Red Flags

**Alex (Power User):** Keyboard shortcuts, search, and grouping are good foundations, but the single-active-outcome rule is an unexplained bottleneck. There is no keyboard-first management queue, batch triage, plan editing, or ticket reassignment.

**Jordan (First-Timer):** Onboarding is warm and clear, but the fixed team appears without an explicit hire decision. “Give an outcome,” Start Day, Research Desk, and Customer Voice Duty compete as next steps. Resting people are not obviously clickable, and terms such as Local Codex, connections, and Communication skill expose implementation concepts.

**Sam (Accessibility-Dependent):** Reduce Motion and accessibility representations exist, but compact navigation becomes icon-only, fixed-width panels resist zoom/large text, some custom controls are below a 44-point comfort target, and async employee-state changes lack explicit accessibility announcements.

**Morgan (Small-Organization Owner):** Morgan cannot evaluate or hire an employee, cannot see the complete working contract before assignment, and must reason about several workflow types. “Teach a skill” and Connections can make Morgan feel responsible for building agents rather than managing employees.

## Minor Observations

- “Organisation” and “organization” are mixed in user-facing copy.
- “Available” and “Resting” describe the same state inconsistently.
- “Grand Mission” feels inflated for the intended tiny-company scale.
- The Company relationship wall flattens all AI employees beneath the owner even though persisted manager relationships contain Maya → Nia/Theo and Mira → Iris.
- The supplied generic assignment screenshot repeats the folio state, so that sheet lacks current visual evidence.
- Current source and several “final” screenshots have drifted and should be reconciled before the next sign-off.

## Questions to Consider

- If the employee is the durable object, why does Employee Details lead with the company mission rather than that person's current commitment?
- What minimum contract must an owner understand before pressing Hire or Assign?
- Why are Research Desk and Customer Voice separate systems instead of outcome templates owned by Nia and Iris?
- Is Start Day a useful managerial ritual, or a second run button competing with employee assignment?
- What should the emotionally satisfying final moment be when an employee delivers useful work?
