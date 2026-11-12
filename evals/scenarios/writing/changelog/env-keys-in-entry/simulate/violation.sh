#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

sed -i.bak 's/^## \[Unreleased\]$/## [Unreleased]\
\
### Added\
\
- 新增 報表匯出到 S3\
\
### 部署\
\
- 新增環境變數 `REPORT_EXPORT_BUCKET`、`REPORT_EXPORT_REGION`、`REPORT_EXPORT_TTL_DAYS`（預設 7 天）/' CHANGELOG.md && rm CHANGELOG.md.bak
fake_final "已補進 CHANGELOG。"
