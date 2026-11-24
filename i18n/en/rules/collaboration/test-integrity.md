---
source_sha256: 67d0cf0171a7b0eb4f269df8f5d0727e15adf45d38ec1230d9368740c1034bd0
category: collaboration
tier: core
sources:
  - https://newsletter.kentbeck.com/p/augmented-coding-beyond-the-vibes
incidents:
  - "Added a new route to the guard test's exception list to turn CI green"
  - "Retries papered over intermittent failures, hiding two bugs: session garbage collection and IDs of 0"
  - "A new feature's tests covered only the success path and passed; the bad-input and external-failure branches were never tested and broke in production"
last_reviewed: 2026-11-24
enforced_by:
  - audit:assertions-removed
---

# Test integrity: don't change tests just to go green

## Don't delete, skip or loosen

When a test fails, assume the code is wrong, not the test. Always ask the user first, with your reasoning, before any of these:

- Deleting a test, adding a skip, or loosening an assertion (e.g. changing `assertEquals` to `assertNotNull`)
- Raising a timeout or adding retries so a flaky test "passes more often"
- Adding a new entry to a guard test's exception list

If you're sure the test itself is wrong, say so explicitly in your report: "I changed the test because…". Don't slip it in with the implementation changes.

**Why:** A guard test's exception list is meant to be a "registry of known gaps", e.g. "which write routes don't have audit records yet". Stuffing new routes into it to turn CI green turns the registry into a backdoor. So the team has an explicit rule: never modify the exception list to make tests go green.

## Find the root cause of flaky tests

Don't paper over intermittent failures with retries or skips; find the root cause first:

- Run the single test file 5–8 times first. If a different test fails each time, the cause is most likely random data (e.g. a random value of 0), not order pollution between tests.
- Check shared state: file sessions, cache, time (freeze it), databases shared by parallel tests.

**Why:** One test that intermittently returned 302 turned out to have two independent root causes: file session garbage collection randomly wiping sessions during the full suite, and a factory occasionally producing an ID of 0, which was treated as "not found". Adding retries would only have hidden both bugs.

## Ship every new feature with at least one failure-case test

When you add a feature or fix a bug, add at least one failure-case test besides the success path. For a bug fix, the regression test that reproduces the bug counts.

**Why:** When an agent writes tests, it follows the success path it just wrote. The tests pass, but the bad-input, external-failure and not-found branches never run once, and the failure shows up in production on an error branch. The pre-commit `audit:empty-catch` only catches empty catch blocks; it can't catch "the error branch was never tested", so this layer has to be covered when the tests are written.

**How:**

- Pick the case most likely to go wrong: bad input rejected (wrong format, out of range, missing field), handling of a failed external call (timeout, 5xx, dropped connection), or data not found (nonexistent ID, empty query result).
- Assert the specific error result: the error type or message, the HTTP status code, the return value, or that no data was written. Asserting only "an exception was thrown" or `assertNotNull` doesn't count.
- In your report, list which failure cases you tested; if you wrote none, say why (e.g. text-only change, pure refactor).

## Keep structural and behavioral changes separate <!-- 慣例 -->

Put refactors (no behavior change) and feature changes in separate commits. A refactor commit shouldn't need to change any test's expected results. If it does, it actually changed behavior.
