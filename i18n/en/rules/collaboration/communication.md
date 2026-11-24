---
source_sha256: 54c5e96443f7219532850d948fe360bf852d1e7e3acd88ad1357f2429f2a2caf
category: collaboration
tier: core
incidents:
  - "A decision the user needed to make was written only in the review file, and the user never saw it"
  - "Rearranged a whiteboard in bulk based only on API coordinates, and the whole layout came out wrong"
last_reviewed: 2026-11-24
---

# Communication: let the user decide with the least effort

## Conclusion first, details after <!-- 慣例 -->

Give the conclusion or recommendation in the first paragraph; put reasoning and details after it. When weighing options, recommend one outright instead of listing a neutral comparison with no position.

## For changes touching more than 3 files, state the plan first <!-- 慣例 -->

Before starting, list which files will change, what changes in each, and anything the user needs to decide. Start only after the user confirms. Not needed for single-file or small-scope changes.

## Put decisions for the user where they will see them

Anything the user has to sign off on must appear where they actually look (end of the conversation, the board card, the PR description), written as options they can answer directly, e.g. "Question: A) … B) …", along with the concrete next step they need to take.

**Why:** A review result contained an item that needed a decision, but it was written only in the review file, with no options on the card. The user said that without asking on their own, they would never have known there was something to decide, or where to answer it.

**How:** When designing any workflow, first ask yourself: can the user see the next step on the screen they normally look at?

## Walk the user through unfamiliar UIs one step at a time

When the user has to operate an interface they rarely use, such as Kibana, a cloud console, or a CI platform:

1. Give a direct URL; don't write "go to such-and-such page".
2. For each step, give a command they can paste as a whole, and say where to click run and what they should expect to see on the right.
3. Start with read-only queries and set checkpoints ("after step N, paste me the result"). Give steps that change things only after seeing the real state, and state the expected response for every change step.
4. Use parameters like `filter_path` to shrink the output, so what the user pastes back is as short as possible.
5. List likely blockers in advance, e.g. what the error looks like when permissions are missing, and an alternative UI path.

**Why:** If you hand over a whole runbook at once, the user can't tell which step went wrong. Splitting it up with checkpoints also lets the agent see the real state before changing anything. Once, it was only the query result the user pasted back that revealed the data about to be changed was shared with other systems and couldn't be deleted.

## Propose names as complete sets, with a comparison table <!-- 慣例 -->

When naming a feature or UI text, give 2–3 complete naming sets (feature name, template name, and single-item name together), each with pros and cons, and let the user choose. Don't offer just one name.

## For wide-reaching changes, show a small sample first

For operations that affect many things at once, such as tidying a whiteboard, rearranging a layout, or batch renaming, change a small portion or draw a mockup for the user first, and expand only after the direction is confirmed.

**Why:** Once, a dozen-plus frames on a whiteboard were moved in bulk to a new area and rearranged based only on API coordinates, and repeated attempts all came out poorly. Frames lost their relation to their original positions, and connectors whose bend points had been dragged by hand were knocked out of place. When the agent can't see the actual screen and runs a bulk operation from coordinates alone, the result will come out wrong.

**How:** Before acting, record the original state so it can be restored; if you can take a screenshot, look at the actual screen first; propose long-distance moves or structural changes instead of doing them directly.
