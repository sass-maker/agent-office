# Agent Office — PROJECT STATUS

Last updated: 2026-08-09

## Why / What

This is a standalone proof of concept for a native Mac workplace where an
owner hires basic AI employees, assigns an organizational outcome, and watches
employees coordinate through goals, blockers, tasks, reviews, and local
artifacts. `Agent Office` is a descriptive development name, not the product
brand.

The first slice is a small content team. It is not HR software, a coding-agent
product, or a generic automation platform.

## Dependencies

- macOS, SwiftUI, SpriteKit, and Foundation from the Apple SDK.
- The locally installed and authenticated Codex CLI for optional employee work
  cycles. The app must remain inspectable when Codex is unavailable.
- A user-selected local organization folder for state and artifacts.

## Timeline

- 2026-08-08 — Standalone POC project initialized.
- 2026-08-09 — First local workday slice implemented and verified.

## Products

- Native macOS POC runnable locally through Swift Package Manager.

## Features (shipped)

- A native SwiftUI and SpriteKit organization home with a cosy, authored
  dollhouse office and three named AI employees.
- A bounded content-team workday: research, drafting, manager review, one
  revision, approval, and an end-of-day report.
- Start Day and End Day controls with resumable local state, visible goals,
  tasks, blockers, activity, and attributable Markdown artifacts.
- Deterministic demo execution and optional use of the locally authenticated
  Codex CLI without storing an API key in the app.
- Local organization folders containing inspectable JSON state and ordinary
  employee files.

## Work queue

[GitHub Issues](https://github.com/sass-maker/agent-office/issues)
