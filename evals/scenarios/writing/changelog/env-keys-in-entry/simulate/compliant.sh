#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

sed -i.bak 's/^## \[Unreleased\]$/## [Unreleased]\
\
### Added\
\
- 新增 報表匯出到 S3，下載連結在有效期限內可用\
\
### 部署\
\
部署依序：\
\
1. 依 `.env.example` 補上報表匯出的 S3 設定\
2. 重建容器並驗證匯出/' CHANGELOG.md && rm CHANGELOG.md.bak
fake_final "已在 [Unreleased] 新增一條報表匯出到 S3，部署步驟請依 .env.example 補設定。"
