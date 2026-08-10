## Context

See `proposal.md` for motivation. The repository already has a native SwiftUI/SpriteKit workplace, a persisted `OrganizationState`, a bounded deterministic content workday, ordinary Markdown artifacts, and an optional locally authenticated Codex runner. The existing state format is already present in user Application Support, so additions must decode older files safely. The app has no server and must not require an API key or a new production dependency.

## Goals / Non-Goals

**Goals:**

- Make one end-to-end path useful with the owner's actual context while preserving a truthful offline/demo path.
- Establish the smallest durable primitives that future employees can share: human-assistant relationships, employee homes, memory entries, and capability grants.
- Keep all work inspectable and recoverable inside the selected local organization folder.
- Keep the Mac app's workplace metaphor primary; permission and brief interactions should feel like conversations or objects in the office, not administrator consoles.

**Non-Goals:**

- A generic workflow graph, marketplace, integration catalog, remote scheduler, cloud control plane, multi-user synchronization, GCP permissions, publishing, or billing.
- A general-purpose executive assistant with email or calendar access.
- Autonomous background work while the app is closed.
- Token metering or an attempt to make every seeded employee equally capable.
- A browser client in this minimum slice; Mac is the first client, not a permanent product boundary.

## Decisions

### 1. Extend the organization state with small values, not a platform object graph

Add a human `owner`, an AI assistant with `assistantForHumanID`, concise `EmployeeMemoryEntry` records, a `CapabilityGrant` record, and daily brief/handoff records. Keep the existing employee/task/artifact engine and migrate missing values on load.

Alternative considered: introduce actors, policies, skills, sessions, and workflow graphs now. Rejected because those abstractions do not improve the first owner's article and would repeat the earlier platform-first failure mode.

### 2. Treat the filesystem as the employee's inspectable home

Persist canonical structured state in the existing JSON file, then materialize human-readable employee projections:

```text
organization/
├── PRODUCT_BRIEF.md
├── employees/
│   └── maya/
│       ├── IDENTITY.md
│       ├── RESPONSIBILITIES.md
│       ├── MEMORY.md
│       ├── CAPABILITIES.md
│       └── artifacts/
└── artifacts/
```

Artifacts remain canonical organization records and may be linked or copied into an employee view only when that does not create divergent writable copies. The initial implementation can make the employee artifact directory a generated index rather than duplicating content.

Alternative considered: SQLite or a vector database. Rejected because ordinary files are more portable, debuggable, and aligned with the local-first promise; semantic retrieval is unnecessary at this scale.

### 3. Pair assistants through a general relationship field but ship one assistant job

The seed/migration path creates a human owner plus a named executive assistant linked by human ID. The same field supports future human employees without implementing hiring UI today. The assistant derives one `Morning Brief` view from state and writes at most one end-of-day handoff per workday.

Alternative considered: model the assistant as a special global chatbot. Rejected because it would not establish the identity and relationship semantics the product is built around.

### 4. Make Maya the accountable employee and retain specialist delegation

Maya owns the outcome, Nia owns evidence discovery, and Theo owns the draft. This makes Maya genuinely employable without pretending a single prompt is an organization. The engine remains a small explicit state machine with a hard revision limit, and the UI describes Maya as the accountable hire.

Alternative considered: remove Nia and Theo and perform one model call. Rejected because it discards the already useful review/handoff behavior and makes provenance worse; the bounded state machine is small enough to keep.

### 5. Use a product brief as the source of truth for claims

Onboarding collects a short product brief and persists it to `PRODUCT_BRIEF.md`; the main workplace exposes an Edit Product Brief sheet and a file reveal action. Real content work refuses to start when the brief is only the untouched placeholder. Existing organizations receive a starter brief derived from their outcome but are prompted to improve it before Local Codex work.

Alternative considered: point the agent at an arbitrary source-code repository. Rejected because the first employee is non-technical and arbitrary repository interpretation would expand permissions and failure modes.

### 6. Web research is the only external capability

`web-research` is granted to Nia by an explicit owner toggle. The local Codex runner receives search permission only for research requests with an active grant; all other operations retain a read-only, no-command prompt and no search capability. Capability intents and outcomes become attributable activity entries. If unavailable, demo work stays usable but is explicitly labeled owner-context-only.

Alternative considered: add Composio now. Rejected for this slice because one read capability can be proven through the existing authenticated local runtime; Composio remains a likely later adapter boundary when multiple SaaS permissions are needed.

### 7. The workplace surfaces decisions, not control-plane concepts

The right folio gains an assistant note and, only when needed, a warm permission card or product-context blocker. Employee detail reveals home, memory, and grants. No policy tables, run inspectors, or workflow-builder chrome are added.

Alternative considered: a dedicated permissions/settings area. Rejected because one capability does not justify a corporate administration surface.

### 8. Separate the workplace client from the execution provider

`AgentOfficeCore` owns the portable employee, relationship, permission, memory, task, and artifact contracts. SwiftUI/SpriteKit renders the first workplace, while `EmployeeRunner` remains the execution-provider boundary. A later browser client can use the same conceptual contracts and pair with either a local companion or a provisioned remote runtime authenticated through the user's chosen model subscription.

Alternative considered: define the product as a native-only Mac process because Local Codex is available there. Rejected because subscription-backed execution and a web control surface are compatible; binding the organizational model to one windowing environment would unnecessarily constrain the product.

## Runtime Sequence

```text
Owner opens organization
        ↓
Migrate owner + paired assistant + employee homes
        ↓
Assistant derives morning brief from persisted state
        ↓
Owner supplies product brief and grants web research
        ↓
Maya accepts outcome and assigns bounded tasks
        ↓
Nia researches with permitted local Codex search
        ↓
Theo drafts from brief + evidence
        ↓
Maya reviews once, then approves or requests one bounded revision
        ↓
Artifacts + employee memories persist locally
        ↓
Assistant returns the decision-oriented end-of-day handoff
```

## Risks / Trade-offs

- **[Codex CLI behavior changes]** → Keep discovery and argument construction isolated, test the grant gate without invoking the network, and surface runtime failure as an ordinary blocker.
- **[Older state fails to decode after required fields are added]** → Use optional/default-backed decoding or an explicit migration pass before saving the upgraded schema.
- **[Generated employee files drift from JSON state]** → Treat JSON as canonical and regenerate projections after every successful save; label generated files and avoid accepting edits as canonical in this slice.
- **[A polished demo is mistaken for researched work]** → Label execution and evidence basis in artifacts and UI; never show external-source language unless the research capability actually succeeded.
- **[Assistant creates noise]** → Derive morning state in memory and persist only one handoff per workday/state revision.
- **[Visual additions regress the cosy workplace]** → Reuse the existing warm folio, employee shelf, portraits, and sheets; finish with the preserve-lane visual review at the existing Mac window sizes.

## Migration Plan

1. Decode existing organizations and add a stable owner, paired assistant, missing defaults, and employee homes in place.
2. Preserve all existing employee IDs, tasks, artifacts, and activity.
3. Materialize a starter product brief without overwriting an existing owner-authored file.
4. Keep Demo mode as the fallback if Local Codex or web research is unavailable.
5. The rollback path is to read the same canonical JSON with the older optional fields ignored; local Markdown homes and briefs remain harmless user-owned files.
