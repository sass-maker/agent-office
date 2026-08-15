## 1. Journalled decisions

- [x] 1.1 Add a sanitized runtime-decision receipt type.
- [x] 1.2 Add a command payload that records a decision through the organization boundary.
- [x] 1.3 Reference the employee and commitment on the resulting event.

## 2. Authorized capability injection

- [x] 2.1 Let the outcome engine accept an authorized capability set, unchanged when none is given.
- [x] 2.2 Pass the broker's authorized set from the app model when dispatching work.

## 3. Owner-facing state

- [x] 3.1 Expose pending runtime requests on the app model.
- [x] 3.2 Expose allow-once, allow-for-commitment, deny, and answer resolutions.
- [x] 3.3 Expire pending requests rather than leaving them open.

## 4. Verification

- [x] 4.1 Test that a grant outside the commitment's authority does not reach the work request.
- [x] 4.2 Test that decisions journal with actor, entities, and sanitized detail.
- [x] 4.3 Test that a failing journal denies the request and retains no approval.
- [x] 4.4 Run `node scripts/check-code-health.mjs all` and `openspec validate --all --strict` with every ratchet held or tightened.
