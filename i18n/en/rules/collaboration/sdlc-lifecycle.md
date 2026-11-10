---
source_sha256: fe99de00ecb3461c95dde5ed43597e2b4bb97973d3d7f093641dbf85a6f963c6
category: collaboration
tier: optional
label: "Software lifecycle standard"
summary: "Defines the delivery standards and quality gates for the 6 stages (spec, implementation, testing, acceptance, merge, release) of medium-to-large feature work"
incidents:
  - "Edited a dozen-plus files after reading only a vague requirement, drifting away from what the user meant"
  - "Deleted failing assertions to look finished, or claimed a manual check that was never done"
last_reviewed: 2026-11-10
---

# Software development lifecycle: 6-stage delivery standards and quality gates

When taking on medium-to-large feature work or a complex refactor, follow the 6-stage delivery standard so skipped steps don't distort requirements, let quality slip, or cause production incidents. Small single-file tweaks, debugging, or one-off lookups can use a lighter version.

## 1. Spec stage (Spec & Alignment): agree on boundaries before touching code

Before starting, define explicitly "what to do" and "what not to do (non-goals)". If the change is expected to touch more than 3 files, produce a plan and acceptance criteria first.

**Why:** Requirements are often misunderstood. Agents frequently read two lines of vague description and then edit a dozen-plus files in one go, only to find the result has drifted completely from the user's original intent or broken the existing architecture.

**How:**
- List the feature goals, scope of impact (files and APIs), schema changes, and non-goals.
- Propose concrete acceptance criteria (Given / When / Then, or expected behavior).
- Don't modify core business code until the user confirms the direction.

## 2. Implementation stage (Implementation): atomic commits and architectural guardrails

Keep code changes atomic: don't mix unrelated refactors or formatting changes into the feature work, and follow the project's pitfall rules strictly.

**Why:** Unrelated changes mixed in make code review painful; worse, taking shortcuts often means swallowing errors (empty catch), hard-coding secrets, or missing tenant data isolation.

**How:**
- Hold the guardrail baseline: never silently swallow errors, never put plaintext secrets in code, and strictly scope data queries to the tenant.
- One commit does one thing; use conventional prefixes in messages (e.g. `feat:`, `fix:`, `refactor:`).

## 3. Testing stage (Testing & Verification): let real green lights do the talking

After implementing, create or run the corresponding automated tests. Never skip or fake verification.

**Why:** To "look finished", agents most often delete failing assertions, loosen comparisons arbitrarily, or claim "checked it manually, looks fine" without ever running anything.

**How:**
- Run the relevant unit and integration tests and confirm every assertion genuinely passes.
- Never delete or weaken existing tests to get a green light; when a test fails, hunt down the code defect instead of changing the expected value.
- Avoid testing pitfalls: clean up mocks in `afterEach`, and never use a static `sleep` to wait on async work.

## 4. Acceptance stage (Review & Acceptance): proactively provide a self-review and evidence

Before submitting for acceptance, check the diff against the rules yourself and provide verification steps a human can reproduce.

**Why:** "I'm done" alone doesn't build trust; the user ends up spending several times longer checking line by line for missed edge cases.

**How:**
- Run a self-review (e.g. `/agreements:review` or `scripts/review.sh`) and confirm no leftover TODOs or trivial mistakes.
- List in the conversation or card: a summary of test results, and reproduction steps or sample API requests.
- Mark items that need a human decision (trade-offs, copy approval) clearly in a visible place.

## 5. Merge stage (Merge & Integration): check the base and the gatekeeping checks

When preparing to merge, confirm the target branch, resolve conflicts, and pass the proactive guard audit.

**Why:** Agents often carry over stale terminal state and commit a feature straight onto someone else's fix branch, or push directly to the main branch, polluting deployments or overwriting others' work.

**How:**
- Re-check the current branch (`git branch --show-current`) and the target base branch.
- Run `scripts/audit.sh` to make sure no `.env*` files, personal data, or wide-open permissions (`chmod 777`) were staged by mistake.
- Go through a Pull Request / Merge Request and merge only after the CI gatekeeping workflow is all green.

## 6. Release stage (Release & Hygiene): clean up test leftovers and maintain versions

When publishing or deploying, make sure environment variables are in place, clear out test leftovers, and leave a clear version trail.

**Why:** The most common release failures: mock tokens or fake data from testing get carried into production, and new environment variables aren't configured in production, so the service fails to restart.

**How:**
- Make sure every new environment variable has a default or a secure-configuration notice in production.
- Clean up all temporary fake data, test dumps, and temporary credentials on local machines and in containers.
- Update the CHANGELOG and the semantic version (SemVer) so changes are traceable.
