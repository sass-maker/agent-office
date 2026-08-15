## 1. Projection

- [x] 1.1 Project occurrences into days with their employee, subject, status, planned window, actual run, and receipt headline.
- [x] 1.2 Return nothing where no policy produced an occurrence.

## 2. Catch-up policy

- [x] 2.1 Add a per-policy catch-up decision: leave missed, or reschedule into the next window.
- [x] 2.2 Apply it during reconciliation without executing anything late.
- [x] 2.3 Record which occurrence a replacement replaces, and never create a second replacement.

## 3. Calendar surface

- [x] 3.1 Add a Calendar destination beside Office, Mission, and Company.
- [x] 3.2 Show day and week views with expected and actual work distinct.
- [x] 3.3 Convey status in text rather than colour alone, and keep keyboard access.
- [x] 3.4 Let the owner skip an upcoming occurrence.

## 4. Verification

- [x] 4.1 Tests for the day/week projection including the empty case.
- [x] 4.2 Tests for both catch-up policies and for repeated reconciliation.
- [x] 4.3 Run `node scripts/check-code-health.mjs all` and `openspec validate --all --strict` with every ratchet held or tightened.
