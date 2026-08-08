# Agent Office

`Agent Office` is the temporary development name for a native Mac proof of
concept: a cosy local workplace where an owner gives a small team of AI
employees an outcome, starts the day, watches their handoffs, and inspects the
work they leave behind.

![The organization home](artifacts/design/organization-home-current.png)

## Run it

Requirements: macOS 14 or newer and Xcode 16 or a compatible Swift 6.1
toolchain.

```bash
swift run AgentOffice
```

The first launch creates a fresh Willow Studio organization under:

```text
~/Library/Application Support/AgentOffice/WillowStudioPOC
```

Choose **company folder** in the app to create or reopen a different local
organization. Selecting an empty folder seeds a fresh team.

## What works

- Start and end a workday without losing progress.
- Watch Maya, Nia, and Theo research, write, review, revise, and report.
- Inspect goals, blockers, tasks, activity, and employee-authored Markdown.
- Use the deterministic **Demo team**, which needs no account or network.
- Optionally choose **Local Codex** when the authenticated Codex CLI is
  installed. Its process is ephemeral and read-only; the app stores no API key.

## POC boundaries

The organization and roles are seeded, employees run one bounded content
workflow, and tool permissions are represented but not yet grantable. There is
no background scheduling, marketplace, cloud sync, publishing integration,
human onboarding, or production permission system yet.

The future employee marketplace is tracked in
[issue #1](https://github.com/sass-maker/agent-office/issues/1).
