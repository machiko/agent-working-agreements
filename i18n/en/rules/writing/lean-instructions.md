---
source_sha256: 438e597a2e1c41f33cb8ab80e045bfc81f0bd556d6f51104b7358a9ea9074688
category: writing
tier: core
sources:
  - https://code.claude.com/docs/en/best-practices
  - https://code.claude.com/docs/en/memory
incidents:
  - "The rules directory held both the English original and an outdated Simplified Chinese translation, loading about 5,500 extra tokens every session"
last_reviewed: 2026-11-10
---

# Lean rule files: every line must earn its place

> Applies to CLAUDE.md, AGENTS.md, `.claude/rules/`, and memory indexes. These files load in every session; the longer they are, the more easily the important rules get buried.

## When a rule line stays <!-- 慣例 -->

Ask of every line: "If I remove this, will the agent get something wrong?" If not, delete it.

- Don't write what the agent already does ("write clean code", "be mindful of security").
- Don't restate language or framework conventions; it already knows them.
- Attach a reason or incident to every rule. Without a reason, there's no way to decide whether it applies in edge cases.
- Reserve "IMPORTANT" and "must" for the one or two rules with truly zero exceptions. Put them everywhere and they mean nothing.

## No duplicates, nothing always-loaded that isn't needed

**Why:** An audit found the rules directory held both the English original and an old Simplified Chinese translation. The two had diverged, the Simplified Chinese wording ran counter to the Traditional Chinese the user asked for, and every session loaded about 5,500 extra tokens for nothing. The same directory also had an installation README, useless to the agent and loaded every time too.

**How:**

- Keep one language and one version of each rule set.
- Every `.md` under the rules directory gets loaded, so keep docs, templates, and drafts outside it.
- For rules that only concern specific files, scope loading with `paths` frontmatter (e.g. load Laravel rules only when touching `**/*.php`).
- Write step-by-step procedures (deploy, release) as skills loaded on demand, not as always-loaded rules.
- Measure the size of always-loaded content regularly, and set a cap.

## Promote repeatedly violated rules to hooks <!-- 慣例 -->

A rule violated twice or more means text isn't enough. Anything a command can check (commit format, banned commands, mandatory test runs) becomes a hook that enforces it, and the original text gets trimmed. Write zero-exception rules (e.g. "always run tests before finishing") as a Stop hook or pre-commit hook from the start: rule files are only advice; hooks enforce.

## Keep memory indexes lean too <!-- 慣例 -->

Each line of a memory index holds only a title and a one-sentence hint; details go in their own files. Once an index line grows into a paragraph, it stops being an index and becomes the full text.
