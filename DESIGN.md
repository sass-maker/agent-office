# Design

## Direction contract

**THESIS:** A tiny company should feel inhabited, legible, and cared for—not
like enterprise software with avatars added. The workplace is the product's
primary truth; boards support it.

**OWN WORLD:** A handcrafted dollhouse office at golden hour: ink outlines,
muted spruce, apricot, butter yellow, dusty blue, warm wood, paper labels, small
plants, and expressive employees. Native Mac chrome frames the world quietly.

**STORY:** The owner sees who is here, what they are doing, what is blocked,
and what needs attention; they start the day, watch handoffs, inspect artifacts,
and end the day.

**FIRST VIEWPORT:** Slim native sidebar, expansive cutaway office in the
center, compact goals/blockers/tasks rail on the right, Start/End Day anchored
top-right.

**FORM:** Operate mode; spatial dollhouse workplace. AI Town supplies the
quality and spatial-legibility reference, Spiritfarer the warmth and character
care, and Things the Mac restraint. Mission-control dashboards and HR suites
are anti-references.

## Principles

- The scene is largest, but no critical state exists only inside it.
- Every character movement or pose corresponds to a task, handoff, review,
  blocker, or rest state.
- Depth comes from architectural layers, shadows, furniture, texture, and
  foreground overlap—not glass cards or decorative gradients.
- Supporting panels read like pinned notes and a studio ledger, not KPI cards.
- Controls use native semantics, focus, shortcuts, tooltips, and contrast.

## Palette

- Night spruce: `#173B3A`
- Deep ink: `#263238`
- Warm plaster: `#F4E6C9`
- Apricot: `#E78B5B`
- Butter: `#F2C96D`
- Dusty blue: `#7395A8`
- Moss: `#6E8B62`
- Walnut: `#76513A`
- Paper: `#FFF8E8`

## Typography

Use the macOS system rounded face for employee names and welcoming labels, and
the standard system face for dense work state. Preserve Dynamic Type behavior;
do not use pixel fonts for functional text.

## Components

- Employee avatars have unique silhouette, clothing color, nameplate, status
  dot, and task-derived workstation position.
- Goals are one compact progress ledger, blockers are high-contrast pinned
  notes, and tasks use three columns: Ready, Doing, Review/Done.
- Artifact links use a document icon, filename, author, and native Reveal action.
- Start Day is optimistic spruce; End Day is a calm apricot control, never an
  alarming destructive red.

## Motion

- Characters ease between meaningful stations and use restrained idle motion.
- Handoffs briefly connect two employees with a paper/document cue.
- Reduced Motion removes idle movement and cross-room travel while preserving
  immediate position and status changes.

## Accessibility

- The native task board and employee list mirror the full scene state.
- Provide keyboard focus, labels, tooltips, sufficient contrast, and no
  information encoded by color alone.
- The workplace remains useful at narrower window sizes by collapsing the right
  rail into a native inspector rather than shrinking functional text.

## Marketing surface

The landing page is a Persuade surface inside the same world. It presents the
Mac workplace as a substantial keepsake object the owner buys once, not a
generic SaaS shell. Named employee folios sit beside that permanent workplace
and explain optional subscriptions without resembling a pricing table.

The first viewport must make the real application the dominant proof. A
visitor then follows one actual workday before meeting Maya, Nia, and Theo.
Use dark spruce as the presentation-case field, walnut as structural material,
paper for work records, and the golden office as the light source. Avoid the
standard centered SaaS hero, feature-card grids, fake social proof, and future
platform diagrams.

Marketing motion is one spatial reveal: the presentation case opens into the
workplace and the workday advances as the visitor scrolls. Reduced Motion keeps
the complete composition visible and removes travel.
