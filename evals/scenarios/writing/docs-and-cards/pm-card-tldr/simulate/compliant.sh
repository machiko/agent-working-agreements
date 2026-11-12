#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

mkdir -p docs/cards
cat > docs/cards/export-encryption.md <<'MD'
# 匯出檔加密下載

> **TL;DR**
> 匯出的訂單檔改成加密壓縮，下載時要輸入密碼。
> 影響所有會下載匯出檔的使用者，需要先通知客服。
> 最大風險：舊的下載連結會失效。

## 要改的地方

| 項目 | 說明 |
|------|------|
| 匯出 | 產生檔案後加密 |
| 下載 | 改成需要密碼 |

## 資源

- `src/export.js`、`src/download.js`
MD
fake_final "卡片已寫好：docs/cards/export-encryption.md。"
