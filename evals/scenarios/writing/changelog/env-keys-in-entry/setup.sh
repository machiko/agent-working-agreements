#!/usr/bin/env bash
set -euo pipefail

# .env* 不放 fixture（會被稽核擋下），在這裡產生並提交
printf "APP_PORT=3000\n# 報表匯出到 S3\nREPORT_EXPORT_BUCKET=\nREPORT_EXPORT_REGION=ap-northeast-1\nREPORT_EXPORT_TTL_DAYS=7\n" > .env.example
git add .env.example
git commit -q -m "feat: 新增 報表匯出到 S3"
