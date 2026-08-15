## 1. Model

- [x] 1.1 Add typed organization resources and a lease with holder, mode, purpose, acquisition, renewal, and expiry.
- [x] 1.2 Persist leases in organization knowledge with permissive decoding.

## 2. Acquisition rules

- [x] 2.1 Allow multiple shared leases over one resource.
- [x] 2.2 Refuse an exclusive lease while any other live lease exists, naming the holder.
- [x] 2.3 Refuse a shared lease while an exclusive lease is live.

## 3. Lifecycle

- [x] 3.1 Renew a live lease, extending its expiry.
- [x] 3.2 Release a lease early and record it.
- [x] 3.3 Mark expired leases during reconciliation without deleting them.

## 4. Contention

- [x] 4.1 Expose current holders and conflicts for a resource.
- [x] 4.2 Never preempt a live lease automatically.

## 5. Verification

- [x] 5.1 Tests for shared coexistence, exclusive refusal, and shared-versus-exclusive refusal.
- [x] 5.2 Tests for expiry freeing a resource, renewal holding it, and release freeing it.
- [x] 5.3 Tests that expired leases remain inspectable and nothing is preempted.
- [x] 5.4 Run `node scripts/check-code-health.mjs all` and `openspec validate --all --strict` with every ratchet held or tightened.
