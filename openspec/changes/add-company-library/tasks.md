## 1. Catalogue domain and migration

- [x] 1.1 Add Codable skill definition, employee assignment, skill source, connection definition, and teaching activity data to organization knowledge.
- [x] 1.2 Seed stable built-in content-team skills, assignments, and recognized local connections through an idempotent version-four migration.
- [x] 1.3 Add exact coverage and lookup helpers without inferring skills from employee roles.
- [x] 1.4 Project the organization skill catalogue and each AI employee's assigned skills into inspectable Markdown files.

## 2. Teachable skills and execution

- [x] 2.1 Implement validated creation of a version-one owner-taught skill plus one employee assignment and attributable activity.
- [x] 2.2 Implement duplicate-safe assignment of an existing catalogue skill to another employee.
- [x] 2.3 Resolve assigned skill definitions into each employee work request and include a delimited organizational-skills section in Local Codex prompts.
- [x] 2.4 Preserve deterministic demo behavior while ensuring employees without a skill never receive its instructions.

## 3. Native Company Library

- [x] 3.1 Create the preserve-lane design receipt and capture the existing workplace before adding the library surface.
- [x] 3.2 Add a Company Library entry point and native Employee, Skills, and Connections catalogue navigation.
- [x] 3.3 Show employee coverage gaps, skill versions and sources, required connections, assignees, runtime availability, and permission grants from live organization state.
- [x] 3.4 Add a focused Teach Skill form with validation, target employee selection, honest training language, and immediate catalogue updates.
- [x] 3.5 Add duplicate-safe assignment of existing skills from the Skill catalogue.

## 4. Verification and handoff

- [x] 4.1 Add migration, idempotency, catalogue coverage, teaching, duplicate assignment, prompt isolation, projection, and quit/reopen tests.
- [x] 4.2 Run Swift tests, a clean Swift build, strict OpenSpec validation, and `git diff --check`.
- [x] 4.3 Inspect the Company Library and teaching states at normal and narrow Mac window sizes; record the unresolved rejected character system separately from this preserved surface.
  - Normal-width Employee, Skills, Connections, and Teach Skill states were inspected. The first pass found unreadable native controls in dark appearance; the form now forces a light control scheme. The corrected form was rechecked at 1420 points and at the 1060-point minimum width. The rejected character system remains outside this change.
- [x] 4.4 Update durable project truth, record completed Fleet skill runs, and leave GitHub issue #4 ready for a reviewed commit or PR without deploying.
