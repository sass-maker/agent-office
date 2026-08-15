## 1. Request model

- [x] 1.1 Add `RuntimeAccessRequest` with stable id, origin, capability or question, sanitized input summary, risk context, requested scope, and expiry.
- [x] 1.2 Redact secret-shaped content when a request is built, and carry connection handles rather than credentials.
- [x] 1.3 Add `RuntimeAccessResolution` covering deny, answer, allow once, allow for occurrence, allow for commitment, and contract-revision request.

## 2. Authority evaluation

- [x] 2.1 Evaluate runtime support, package boundaries, contract scope, organization grant, commitment scope, and review policy in a fixed order.
- [x] 2.2 Deny with a reason naming the layer that refused.
- [x] 2.3 Treat unrecognized capabilities and malformed requests as denials.

## 3. Broker

- [x] 3.1 Add the broker with submit, resolve, and pending-request inspection.
- [x] 3.2 Contain the runtime until a valid resolution is recorded.
- [x] 3.3 Record receipts through the organization command boundary and deny when recording fails.
- [x] 3.4 Make resolution idempotent and reject resolutions for a different session, commitment, or occurrence.
- [x] 3.5 Ignore provider "always allow" suggestions as policy.

## 4. Scoped approvals and revocation

- [x] 4.1 Store approvals scoped to one use, an occurrence, or a commitment, with expiry.
- [x] 4.2 Expose the currently authorized capability set for injection into a session.
- [x] 4.3 Revoke access so later use is rejected and affected active work is interrupted.

## 5. Verification

- [x] 5.1 Deterministic policy tests for each authority layer and denial reason.
- [x] 5.2 Fake-driver integration test covering request, denial, scoped approval, expiry, revocation, and broker failure.
- [x] 5.3 Tests for idempotent resolution, stale-session resolution, provider suggestion, and secret redaction.
- [x] 5.4 Run `node scripts/check-code-health.mjs all` and `openspec validate --all --strict` with every ratchet held or tightened.
