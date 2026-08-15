## 1. Driver contract

- [x] 1.1 Add `RuntimeDriverKind`, `RuntimeDriverVersion`, and `RuntimeCapability` with declared-capability negotiation.
- [x] 1.2 Add `RuntimeConfiguration` over literal values and secret references, with driver-declared secret fields and validation that rejects embedded secret values.
- [x] 1.3 Add the `RuntimeDriver` protocol: kind, version, declared capabilities, configuration validation, availability, session creation, and dispose.
- [x] 1.4 Add `RuntimeSession` with turn execution, interrupt, stop, and an opaque resume cursor.

## 2. Bindings and provenance

- [x] 2.1 Add `RuntimeBinding` recording employee, driver kind, driver version, configuration version, and provenance, separate from employee identity.
- [x] 2.2 Persist bindings in organization knowledge with permissive decoding for organizations written before this change.
- [x] 2.3 Derive a default binding from the existing execution provider without changing employee identity or history.
- [x] 2.4 Retain prior driver provenance when a binding is replaced.

## 3. Normalized runtime events

- [x] 3.1 Add the `RuntimeEvent` envelope with kind, event/employee/binding/session/commitment/correlation identifiers, and timestamp.
- [x] 3.2 Reject events whose declared binding or session does not match the emitting session.
- [x] 3.3 Let a session propose an organization command without letting it mutate organization state.
- [x] 3.4 Keep raw diagnostics, normalized events, and organization events separately identifiable.

## 4. Registry and failure isolation

- [x] 4.1 Add a driver registry that resolves a binding to a driver or a named unavailable shadow.
- [x] 4.2 Report missing, incompatible, misconfigured, and unhealthy drivers with human-readable reasons.
- [x] 4.3 Keep one driver's failure from affecting employees bound to other drivers.
- [x] 4.4 Discard stale resume cursors recoverably and start a fresh session without identity loss.

## 5. Move the built-in runtimes behind the seam

- [x] 5.1 Add a demo driver wrapping the deterministic runner.
- [x] 5.2 Add a local Codex driver wrapping the Codex runner, reporting unavailable instead of silently falling back.
- [x] 5.3 Replace the call-site provider branch with a registry lookup.
- [x] 5.4 Add a deterministic fake driver for contract tests.

## 6. Verification

- [x] 6.1 Add contract tests covering both built-in drivers and the fake driver against the same expectations.
- [x] 6.2 Add tests for secret-value rejection, unavailable shadows, cross-driver isolation, event origin validation, and stale cursors.
- [x] 6.3 Confirm an organization written before this change loads, gains a default binding, and keeps its employees and history.
- [x] 6.4 Run `node scripts/check-code-health.mjs all` and `openspec validate --strict` with every ratchet held or tightened.
