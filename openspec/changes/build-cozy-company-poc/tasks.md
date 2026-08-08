## 1. Project foundation

- [x] 1.1 Create a dependency-free Swift package with separate domain, native
  app, and test targets.
- [x] 1.2 Define Codable organization, employee, task, goal, blocker, artifact,
  activity, and workday state models with seeded sample data.
- [x] 1.3 Implement atomic local organization persistence and ordinary Markdown
  artifact storage.

## 2. Employee work loop

- [x] 2.1 Implement the bounded deterministic researcher-writer-manager workday
  engine with attribution, revision limits, cancellation, and resume behavior.
- [x] 2.2 Implement an optional read-only local Codex employee runner with clear
  availability and failure handling.
- [x] 2.3 Add focused tests for persistence, handoffs, bounded review, blockers,
  attribution, and End Day cancellation.

## 3. Native workplace

- [x] 3.1 Build the native Mac organization shell with organization outcome,
  employee roster, Start Day/End Day, and local-folder controls.
- [x] 3.2 Build the goals, blockers, task board, activity, and artifact inspection
  surfaces with keyboard and accessibility labels.
- [x] 3.3 Build the SpriteKit dollhouse workplace whose employee position and
  status reflect domain state and reduced-motion preferences.
- [ ] 3.4 Add authored visual texture, employee silhouettes, furniture, lighting,
  handoff cues, empty states, and narrow-window behavior consistent with
  `DESIGN.md`.

## 4. Verification and handoff

- [x] 4.1 Run strict OpenSpec validation, Swift tests, and a clean Swift build.
- [ ] 4.2 Run native visual critique, polish, accessibility audit, and capture
  representative app screenshots for the design receipt.
- [x] 4.3 Update durable project status and provide local run instructions,
  known POC limits, and the owner design-feedback checkpoint.
