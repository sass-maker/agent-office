## Context

See `proposal.md` for motivation and `specs/marketing-site/spec.md` for the
observable contract. The repository is currently a dependency-free Swift
package with a real 1420-pixel application screenshot, a painterly office
background, and a character atlas. No web toolchain or hosting target exists.

The landing page extends the established golden-hour dollhouse world. It is a
Persuade surface, while the application remains an Operate surface.

## Goals / Non-Goals

**Goals:**

- Make the present Mac product and its first workday understandable immediately.
- Make one-time workplace ownership plus optional employee subscriptions feel
  natural rather than like enterprise seat pricing.
- Reuse real product evidence in a responsive, accessible, fast page.
- Keep the page runnable from ordinary static files.

**Non-Goals:**

- Payment, email capture, analytics, authentication, employee purchasing, or
  public deployment.
- A generic employee marketplace, fabricated roadmap, or unsupported product
  claims.
- Recreating the native application in the browser.

## Decisions

### Build a dependency-free static site

Use semantic HTML, authored CSS, and a small progressive JavaScript file under
`site/`. This avoids adding an unapproved production dependency and makes the
POC directly inspectable. Astro remains a reasonable later migration if the
site gains routes or content operations.

### Present the workplace as a permanent keepsake object

The selected composition treats the Mac workplace as the substantial object a
customer buys once. Employee subscriptions appear as named character folios
that can join it. This separates durable ownership from recurring labor more
clearly than a conventional pricing table.

### Combine product-object framing with a real workday

The first viewport uses the actual app in a dark spruce presentation case. The
next passage follows Nia, Theo, and Maya through a concrete workday. This keeps
the product model memorable without sacrificing proof.

### Reuse the real screenshot and character art

The current application screenshot is the hero proof. Character portraits are
cropped from the existing transparent atlas with CSS background positioning;
functional text and controls remain semantic HTML.

### Keep motion spatial and optional

One scroll-linked office reveal and restrained folio lifts provide the authored
motion moment. Content is visible by default, and `prefers-reduced-motion`
removes transitions and parallax.

## Direction Contract

**THESIS:** Own the workplace; hire the people. Refuse the standard SaaS hero
plus feature-card pricing page.

**OWN-WORLD:** A dark-spruce presentation case opens onto the real golden-hour
dollhouse, followed by walnut employee folios and pinned-paper work records.

**STORY:** See the workplace, watch one useful workday, meet the team, then
understand what is owned once and what can be subscribed to.

**FIRST VIEWPORT:** A compact promise and honest action sit above a large Mac
workplace nested in an open keepsake case; the office is the dominant proof.

**FORM:** Persuade; product-as-keepsake, combined with a vertical workday
narrative. Surface seed `02088b69`, grounded candidate 7.

## Risks / Trade-offs

- **Large raster assets can slow first paint** → use compressed responsive
  images, explicit dimensions, lazy loading below the first viewport, and no
  additional decorative raster.
- **The keepsake metaphor could feel toy-like** → keep copy direct, interaction
  restrained, and the real application visibly functional.
- **Subscription language could imply a live store** → label the model as the
  intended way to buy and keep all current calls to action demonstrative.
- **Static files lack production conveniences** → document a simple local
  server and defer framework adoption until the surface earns it.
