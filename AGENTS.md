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
- Run `swift test` before claiming behavior is complete and `swift build`
  before claiming the app builds.
- Preserve the distinction between employee identity, skills, execution
  environment, permissions, and the model powering the employee.

