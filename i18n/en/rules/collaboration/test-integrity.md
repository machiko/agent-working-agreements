---
source_sha256: 5ad679b9814f5560f4066c2f41f0643e5f3bb351c1186b3f88f47ac7c8b4dba9
category: collaboration
tier: core
sources:
  - https://newsletter.kentbeck.com/p/augmented-coding-beyond-the-vibes
incidents:
  - "Added a new route to the guard test's exception list to turn CI green"
  - "Retries papered over intermittent failures, hiding two bugs: session garbage collection and IDs of 0"
last_reviewed: 2026-11-10
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

## Keep structural and behavioral changes separate <!-- 慣例 -->

Put refactors (no behavior change) and feature changes in separate commits. A refactor commit shouldn't need to change any test's expected results. If it does, it actually changed behavior.
