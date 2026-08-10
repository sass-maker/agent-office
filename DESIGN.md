# Design

## Direction contract

**THESIS:** A tiny company is a living illustrated office for people, while
its operational pages are quiet, serious native software. It refuses both HR
dashboards with avatars and game scenes whose activity is merely decorative.

**OWN WORLD:** Editorial Office uses ink black, warm bone, soft grey, graphite,
and restrained silver. Expressive monochrome people wear simple black office
clothing. Native controls sit among paper folios, thin rules, portrait plates,
and quiet editorial typography.

**STORY:** The owner prepares the office, watches employees advance real work,
selects a person to open their folio, manages the mission through a compact
task list, and inspects the durable identity and history behind each employee.

**FIRST VIEWPORT:** One full-height black sidebar contains company identity,
Office, Mission, Company, and workday control. There is no global top or bottom
bar. The Office begins immediately beside it and fills the remaining window;
an employee folio floats over the scene only after selection.

**FORM:** Operate mode. Five owner-approved references live in
`artifacts/design/approved/editorial-office/` and define the composition,
density, contrast, and component relationships.

## Principles

- People and their real work lead in Office; lists and native controls lead on
  operational pages.
- Large surfaces stay warm bone or soft grey. True black is structural and
  concentrated in the sidebar, typography, portraits, and employee clothing.
- Design in monochrome first. Do not create chromatic status systems, accents,
  or hierarchy and then desaturate them. Meaning comes from language, symbol,
  line weight, texture, fill, and contrast before hue is considered.
- The full-height sidebar is the only global navigation. No global top bar or
  bottom bar appears after onboarding.
- Context appears progressively: scene selection opens a floating employee
  folio; Open profile reveals the complete employee page.
- Real state comes from the existing organization model. Decorative activity,
  invented progress, and duplicated task stores are forbidden.
- Controls use native semantics, focus, shortcuts, tooltips, and contrast.

## Palette

- Sidebar ink: `#090A0B`
- Primary ink: `#181817`
- Warm bone: `#F3EFE7`
- Paper white: `#FAF8F3`
- Soft grey: `#DDD9D1`
- Graphite: `#5D5B57`
- Silver rule: `#B9B5AC`
- Quiet success: `#5D5B57`
- Quiet attention: `#181817`

Black and white describe identity, not maximum contrast. Large reading fields
must never become glaring pure white or full-screen black.

## Typography

Use the macOS system serif face for the grand mission, employee names, and
short editorial display moments. Use the standard system sans face for task
rows, controls, metadata, and body copy. Preserve Dynamic Type and never
rasterize functional text.

## Components

- The sidebar is full height, approximately 136–152 points at normal width,
  with native window controls above company identity and workday control at
  the bottom.
- Employee portraits have unique faces, hair, posture, and silhouette. Their
  clothing remains black while status is expressed with text and a restrained
  dot or rule.
- The Office employee folio is a dismissible floating paper object with margin
  on every side. It never becomes a permanent right sidebar or resizes the
  scene. Its first operational action is giving that selected employee an
  outcome; the folio then shows the real plan, progress, help request, or
  delivery instead of decorative status.
- Mission uses grouped 42–48 point task rows, thin separators, compact employee
  portraits, local filters, a selected-row field, and one contextual task
  inspector.
- Company Members uses portrait folios and fine relationship lines. Employee
  Details expands the folio into identity, responsibilities, relationships,
  active work, skills, artifacts, activity, and blockers.
- Artifact links use a document icon, filename, author, and native Reveal
  action. Start/End Day remains quiet and never uses destructive red.

## Surfaces

- **Office:** a continuous illustrated workplace with meaningful employee
  stations and movement. Selecting an employee opens their floating folio and
  lets the owner assign one outcome directly to that person.
- **Mission:** the grand mission remains visible above a Linear-inspired,
  list-first task workspace grouped into In progress, Review, Next, and
  Delivered. Selection opens a task inspector.
- **Company:** warm editorial organization memory. Members is a relationship
  wall; Skills and Connections preserve their existing operational behavior.
- **Employee Details:** a Company child surface where the employee folio docks
  beside current outcome, active work, responsibilities, relationships,
  skills, artifacts, activity, and blockers.
- **Onboarding:** a bright split composition with a quiet vertical setup spine,
  native paper-line questions, and an illustrated office preview.

## Motion

- Characters move only between meaningful persisted stations. Resting
  employees keep their authored poses rather than wandering decoratively.
- Handoffs briefly move a visible paper or artifact between employees.
- Opening an employee folio uses one short scale-and-fade transition from the
  selected person; Open profile expands that object into the details page.
- Destination changes use a restrained native crossfade. Reduced Motion makes
  all travel immediate while preserving state changes.

## Accessibility

- The Mission task list and Company member directory mirror all critical scene
  state outside SpriteKit.
- Provide keyboard focus, labels, tooltips, sufficient contrast, and no
  information encoded by color alone.
- At narrower windows the sidebar may become a native compact control and
  contextual detail may become a sheet, but labels and functional type do not
  shrink.

## Marketing surface

The landing page is a Persuade surface in the same Editorial Office world. The
real Mac workplace remains the dominant proof; named employee folios explain
optional employees without resembling a pricing table. Use ink framing, warm
working light, expressive portraits, and the real application rather than a
generic centered SaaS hero, feature-card grid, or future platform diagram.
