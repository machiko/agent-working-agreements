---
source_sha256: 0c64611e5bbdd5ec66a5e6dd8e392b95c442cb0e4202d9734a307474748bd435
category: collaboration
tier: core
incidents:
  - "An attribute + middleware scheme for automatic audit logging was rejected: more complexity, no improvement"
last_reviewed: 2026-11-10
---

# Design judgment: one explicit pattern, plus a guard test

## Don't add implicit mechanism layers

If a guard test can already enforce a cross-cutting rule (auditing, permissions, logging), don't stack implicit mechanisms like middleware, attributes or decorators on top.

**Why:** A scheme was once proposed and implemented: "declare via an attribute, have middleware guess whether the request succeeded, then have a request-scoped context write the audit automatically". It was rejected because it made everything more complex without clear improvement. On re-evaluation, that was right: three mechanisms, implicit control flow, and the risk of silently writing only part of the record, all in exchange for "you can tell it's logged from the function signature". A guard test already provides that structural guarantee.

A small team values "you can see whether it's logged by reading the controller" and "there's only one way to write it". In that setting, an implicit layer is a liability.

**How:**

- Before proposing "the mature industry approach", be clear whether this needs to be "machine-checkable" or "declarative". If a test can check it, no new mechanism is needed.
- To reduce boilerplate, build a small type-safe helper first (e.g. a function that takes an enum parameter), not a new mechanism.
- If it takes 5 rules to decide which API to use, the design is wrong; go back to a single pattern.
- What actually fixes "code scattered everywhere" is a shared service or event layer. If you can't build that, say honestly that it's deferred; don't simulate it with middleware.

## Lock conventions in with guard tests <!-- 慣例 -->

Write conventions ("every write route records an audit", "every enum value has a call site", "the docs list every channel") as tests so CI catches omissions.

- State the reason for each exception-list entry, and treat the list as a "registry of known gaps", not a place to make tests go green. Never add new entries to the exception list to make a test pass.
- If a test references a doc, the doc must be version-controlled with the code and updated in the same PR.

## Don't hand-maintain lists that go stale <!-- 慣例 -->

A hand-written list that has to track hundreds of call sites will go stale. Instead, funnel entry points into a few paths, use an enum or the code itself as the list, and use tests to keep docs and code consistent.

## Use incremental analysis instead of full rescans <!-- 慣例 -->

Save analysis results for a large codebase in a baseline doc, recording the commit at the time of analysis. Next time, look only at files changed per `git diff <baseline commit>..HEAD --stat`, then update the matching sections and the baseline commit. Don't rescan the whole project every session.
