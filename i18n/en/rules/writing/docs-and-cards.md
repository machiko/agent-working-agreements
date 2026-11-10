---
source_sha256: d36aff814cc704a37c4c46dfc6c3deb3a5f78eee03e4d7ef18608d9f84ddd21d
category: writing
tier: optional
label: "Writing task cards"
summary: "Open Notion/Jira cards with a TL;DR, use tables heavily, and keep PM-facing sections in plain language. Pick this if you have the agent write cards or planning docs"
incidents:
  - "The first draft of a task card was too long; asked to trim it and add a TL;DR"
last_reviewed: 2026-11-10
---

# Task cards and shared documents

For cards (Notion, Jira, issues) and planning docs read by PMs and collaborators:

- **Open with a TL;DR**: three to four lines covering the conclusion and the biggest risk.
- **Keep it brief**: inventories, decisions, and ordering always go in tables or short bullet lists, not long paragraphs.
- **Plain language for PM sections**: class names, code paths, and function names go in a "Resources" section at the end.
- **Self-check**: can a PM grasp the conclusion within thirty seconds? If not, rewrite the opening.

**Why:** First drafts of cards often run too long and get sent back to be trimmed with a TL;DR added. Cards are read by many people; put engineering details up front and non-engineering readers stop reading.

## Single-source documents <!-- 慣例 -->

If a document is the single source for "which behaviors trigger X", such as which events get sent to the logging system:

- Document the entry points and rules; don't copy every call site. Leave the long tail to the enum or the code itself.
- Lock the document and code together with a gatekeeping test, and update the document in the same PR when the code changes.
- Don't include host addresses, credentials, or per-environment config values.
