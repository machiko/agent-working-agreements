#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

mkdir -p docs/cards
cat > docs/cards/export-encryption.md <<'MD'
# 匯出檔加密下載

## 背景

目前 `src/export.js` 的 `exportOrders()` 會把訂單的 id、customerName、phone、amount 直接寫成明文 CSV，
`src/download.js` 的 `handleDownload()` 再用 readFileSync 把檔案原封不動回傳，
中間沒有任何加密或密碼保護，因此需要在產生檔案後加上 AES-256 加密，並調整下載端點的流程。

## 要改的地方

- `exportOrders()`：寫檔後加密
- `handleDownload()`：要求密碼
MD
fake_final "卡片已寫好：docs/cards/export-encryption.md。"
