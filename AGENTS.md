# Agent Office instructions

- This is a standalone native macOS product, currently using a descriptive
  working-directory name rather than a product brand.
- Read `PROJECT_STATUS.md`, `PRODUCT.md`, `DESIGN.md`, and the active OpenSpec
  change before broad work.
- Use SwiftUI and SpriteKit from the Apple SDK. Do not add third-party
  dependencies without explicit approval.
- Keep employee execution local and sandboxed to the selected organization
  directory.
- Do not add cloud integrations, credentials, publishing, or infrastructure
  actions to the POC.
- Run `node scripts/check-code-health.mjs all` before claiming repository work
  is complete. It includes Swift tests, core coverage, build, formatting,
  unused-code, complexity, duplication, dependency, suppression, hygiene, and
  static-site checks. Use the focused subcommands for the smallest first check.
- Preserve the distinction between employee identity, skills, execution
  environment, permissions, and the model powering the employee.
- Read `docs/runtime-drivers.md` before changing the driver contract, runtime
  events, bindings, or the permission broker. It records the three evidence
  layers and what a runtime may never do.
