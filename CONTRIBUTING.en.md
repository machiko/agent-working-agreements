# Contributing

[繁體中文](CONTRIBUTING.md) | **English**

Every rule in this project comes from a real incident: a mistake an agent actually made, a pitfall a team actually hit. The most valuable contribution is **a real incident**; turning it into a rule PR comes second.

Rules are written in Traditional Chinese with a line-by-line English translation. Issues and PRs in English are welcome — maintainers will help with the Chinese side.

## From incident to rule

```text
incident ──▶ ① report ──▶ ② triage ──▶ ③ write the rule ──▶ ④ English version ──▶ ⑤ eval scenario ──▶ ⑥ run checks ──▶ ⑦ open a PR
```

### ① Report the incident

Either:

- **Fill in the form on GitHub**: [Incident report](https://github.com/machiko/agent-working-agreements/issues/new?template=incident_report.yml) — symptom, root cause, and what to do.
- **Use Claude Code**: run `/agreements:record` in your own project to capture the incident, then choose to prepare a draft. It builds an issue draft, scans it for identifying information, and only submits after you confirm the content.

Sanitize before submitting: remove project names, company or customer names, people's names, private IPs, internal domains, credentials and tokens. Only report what actually happened — **never invent an incident to justify a rule**.

### ② Triage (maintainers)

Issues labeled `triage` are reviewed by a maintainer, who replies on the issue with one of:

| Decision | When |
|----------|------|
| Merge into an existing rule | A rule already covers this and only lacks the scenario. Look for similar entries first with `scripts/install.sh --list --lang en` and `grep -r` |
| New entry | An existing rule file covers the area but not this pitfall |
| New rule file | A new technical area, or none of the existing categories fit |
| Declined | Only true for a single project, something agents don't get wrong anyway, or it can't be written as a verifiable action |

Be strict about core (always loaded): only pitfalls that are independent of file type and can happen in any session belong there. Everything else is optional and loads on demand via `paths`. The core rule bodies must stay within 400 lines in total.

### ③ Write the rule

Rules live in `rules/<category>/<name>.md`; the Chinese file is the source. The full standard is in [docs/rule-quality.md](docs/rule-quality.md) (Chinese). At minimum:

```markdown
---
category: database                 # same as the directory
tier: optional                     # core or optional
label: "資料庫與 ORM 地雷"          # required for optional: name in the install menu
summary: "什麼情況才選這條"          # required for optional
paths:                             # optional: load only when these files are touched
  - "**/migrations/**"
incidents:                         # at least one: a sanitized sentence or an issue number
  - "#123"
last_reviewed: 2026-11-10          # today
---

# 資料庫與 ORM 地雷

## 共用資料庫被重置

- **症狀：** The visible bad outcome, as concrete as possible.
- **根因：** Why it happens — explain the mechanism, not a moral lesson.
- **怎麼做：** A verifiable action: a command, a setting, a check.
```

- Collaboration rules use "rule → **為什麼：** (why) → **怎麼做：** (how)" instead.
- No vague wording such as 「盡量」「適當」「視情況」 ("try to", "as appropriate", "depending on the situation").
- A single entry body is at most 40 lines.
- A new rule file also needs its id in the `enforce_rules` enum of `schema/v1.json` (alphabetical order).
- If an `scripts/audit.sh` check or a runtime guard rule enforces the rule, list it under `enforced_by` in the frontmatter (section 8 of the standard).

If you can't write Chinese, write the rule in English following the same structure and say so in the PR; a maintainer will produce the Chinese source. Until then CI checks such as `scripts/check-i18n.sh` will fail — that is expected and does not block review.

### ④ English version

Write the line-aligned translation at `i18n/en/rules/<category>/<name>.md`: line N of the English file translates line N of the Chinese file, with the same heading levels, blank lines and code blocks. Section labels map as `**症狀：**` → `**Symptom:**`, `**根因：**` → `**Root cause:**`, `**怎麼做：**` → `**How:**`, `**為什麼：**` → `**Why:**`. Then run:

```bash
scripts/check-i18n.sh --stamp en <category>/<name>
```

### ⑤ Eval scenario

Show that the rule actually makes agents less likely to make the mistake. Create `evals/scenarios/<category>/<name>/<scenario>/` with:

- `prompt.md`: an ordinary development request that tends to trigger the mistake, without hinting at the rule.
- `fixture/`: files the task needs.
- `check.sh`: a deterministic verdict — exit 0 compliant, 1 violation, 2 inconclusive.
- `simulate/compliant.sh`, `simulate/violation.sh`: simulated compliant and violating behavior for the offline test.

See [`evals/README.md`](evals/README.md) for the format. Passing the offline test is enough; **you don't need to call a model** (that costs quota and is run by maintainers before releases when needed):

```bash
bash tests/eval.test.sh
```

### ⑥ Run the checks

You need bash, git and python3 on macOS or Linux. CI runs on both ubuntu and macOS, so stick to awk and sed features both support.

```bash
scripts/check-budget.sh     # required frontmatter fields, 400-line core budget
scripts/lint-rules.sh       # entry structure, vague wording, duplicate headings, entry length
scripts/check-schema.sh     # schema enum, enforced_by linkage
scripts/check-i18n.sh       # English version in sync
scripts/sanitize-check.sh   # identifying information
bash tests/install.test.sh  # the installer still works with the new files
bash tests/eval.test.sh     # offline verdicts for eval scenarios
```

If you change scripts, run the matching tests under `tests/` (e.g. `bash tests/incident-draft.test.sh` for `scripts/incident-draft.sh` or `sanitize-check.sh`); the full list is in the [README](README.en.md).

### ⑦ Open a PR

- Branch from `main`: `feature/<name>` for new rules, `fix/<name>` for fixes.
- Commit messages use `<type>: <verb> <description>`; in this repo the verb is one of 新增 (add), 更新 (update), 修復 (fix), 刪除 (remove), 重構 (refactor), 優化 (optimize). English commit messages are fine if you can't write Chinese.
- The PR template brings up a checklist; tick it and end the description with `Refs #<issue>`.
- Reviewers check what machines can't: whether the root cause explains the mechanism, and whether the "how" is actually workable.

## Other contributions

- **Fixing an existing rule**: update `last_reviewed` and the English version as well. If behavior changes, add or update the eval scenario.
- **Retiring a rule**: don't delete the file; mark it `deprecated` with `replaced_by` first (section 7 of the standard).
- **Scripts and the installer**: write the test first (`tests/*.test.sh`), then change the implementation.
- **Bug reports and feature requests**: open a regular issue.

## License

Contributions are released under the project's [MIT License](LICENSE).
