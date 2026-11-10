---
source_sha256: 5dbc34fec4f228195e1102db5f5cbf9fd8b4d32f76746b8792f2e9922b18b437
category: writing
tier: optional
label: "How to write a CHANGELOG"
summary: "One entry per user-visible feature, 15-20 entries per release, deployment steps as a numbered list. Pick this only if you maintain a CHANGELOG"
incidents:
  - "CHANGELOG entries written as long noun phrases were hard to read; after switching to one feature per entry, a release ballooned to 27 entries"
  - "The date was added after merging, creating an extra docs-only commit"
last_reviewed: 2026-11-10
---

# CHANGELOG entries

## One entry equals one "user-visible feature theme"

Like commits, entries **start with a verb and fit on one line**. But the granularity of an entry is "one feature theme", not one engineering change. Keep a release to **15-20 entries**.

**Why:** The result of two rounds of feedback stacking up. First, entries written as five-line noun phrases were called hard to read, so they were split into one entry per sub-feature; a release then had 27 entries and drew "trim it down, too many". Merging same-theme entries back took it from 27 entries to 18 and from 67 lines to 46. The "one thing" in "one entry, one thing" means one thing the user can perceive.

**How:**

- Match verbs to categories, using the same vocabulary as commit messages: Added uses "新增" (add), Changed uses "更新" (update), Removed uses "刪除" (remove), Fixed uses "修復" (fix). Users can't see a commit's "重構" (refactor), so leave it out; write "優化" (optimize) as "更新" (update) instead.
- Join multiple changes to the same feature in a single entry with "；"; don't split them into several entries.
- Merge multiple fixes for the same root cause into one entry.
- Over 20 entries, first look for same-theme entries to merge; don't cut content.

## What stays out of the CHANGELOG <!-- 慣例 -->

| Leave out | Put it in |
|------|--------|
| Enum constant names, table column names | PR description |
| Threshold numbers ("10 times in 15 minutes") | PR description or spec |
| Full query syntax, endpoint lists | Technical docs |
| `.env` keys listed one by one | `.env.example`, plus a check command |

What can go in: user-visible names (pages, buttons, category names) and command names.

## Engineering / deployment section <!-- 慣例 -->

Write it as "Deploy in order:" followed by numbered steps, e.g.: open network access → check env → migrate → seeder → clear cache and rebuild containers → verify → backfill data. One step may contain several commands.

- After the steps, add at most three notes, covering only things the steps don't mention and that are needed during deployment.
- If there are no new env vars, migrations, or permission changes, don't write "no changes".

## Releasing

- Put in-progress entries under `[Unreleased]` first; on release, move them into the version section and leave `[Unreleased]` as an empty heading.
- Fill in the release date in the last PR before the release, so the merge commit can be the tag target directly. While in development, write `YYYY-MM-xx`.
- Don't add `[skip ci]` to the commit that fills in the date.

**Why:** Adding the date after merging means pushing an extra docs-only commit. If the tag must point to a commit whose image has already been built, that commit then has to go through the full gate again. Adding `[skip ci]` to skip that round doesn't work either: some CI platforms honor the marker and skip auto-deploy too, leaving you to push an empty commit to trigger it. If you've already missed the window, tag the existing commit directly.
