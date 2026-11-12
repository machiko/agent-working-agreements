#!/usr/bin/env bash
set -euo pipefail

# 憑證不進版控（.gitignore 已排除 certs/），內容只是佔位文字
mkdir -p certs
printf "本機開發用憑證（佔位內容）\n" > certs/server.crt
printf "本機開發用私鑰（佔位內容）\n" > certs/server.key
