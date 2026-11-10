---
source_sha256: 849d366da8649ab9dc52d8b0f99fcab90faa68aa0ebe5583a7fb97317c60d886
category: security
tier: core
incidents:
  - ".gitignore blocked only a single filename, and a test CSV containing personal data was pulled into a commit during a squash"
last_reviewed: 2026-11-10
enforced_by:
  - audit:data-files-staged
  - guard:data-files
---

# Keep personal data and sensitive files out of version control

## Rule

- Only add explicit paths; don't use `git add -A` or `git add .`.
- Before committing, review the staged list file by file. For any `.csv`, `.xlsx`, `.docx`, `.sql`, `.json`, or file under `data/`, `storage/`, or `.env*`, stop and ask the user first.
- In `.gitignore`, use wildcards to block a whole family of files (`accounts*.csv`), not just a single filename.
- Block all `.env.*` by default, and use `!` to allow only files known to contain no secrets, such as `.env.example`.
- Block data files in the repo root (`/*.csv /*.xlsx /*.xls /*.docx /*.pdf`) by default.

**Why:** What actually happened:

- `.gitignore` blocked only a single filename, so another test CSV from the same series (containing personal data) was pulled into a commit during a squash.
- When auditing, check history too: database dumps, environment config files, and the like stay in history if they were ever committed, even after they're deleted.

As long as a repo can be cloned, anything in its history is effectively public.

## Before adding seed / fixture data files <!-- 參考 -->

First grep to confirm everything is fake data:

```bash
grep -nE '@[A-Za-z0-9.-]+\.(gov|edu)\.[a-z]{2}' <file>   # government/institution emails
grep -nE '09[0-9]{8}' <file>                              # Taiwan mobile numbers
grep -nE '[A-Z][12][0-9]{8}' <file>                       # Taiwan national ID numbers
grep -nE '\$2[aby]\$' <file>                              # bcrypt hashes
```

## Auditing an existing repo <!-- 參考 -->

```bash
git ls-files | grep -Ei '\.(csv|xlsx|docx|sql)$'
git log --all --diff-filter=A --name-only --format= | grep -Ei '\.(csv|xlsx|sql)$' | sort -u
```

When you find a problem, "removing it from version control" and "rewriting history" are two separate decisions. Rewriting history affects every collaborator, so let the user decide.
