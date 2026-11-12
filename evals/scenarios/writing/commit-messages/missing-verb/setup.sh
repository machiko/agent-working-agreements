#!/usr/bin/env bash
set -euo pipefail

# 留下未提交的修正，讓 Agent 自己寫 commit 訊息
sed -i.bak 's|price \* percent;|price * percent / 100;|' src/price.js && rm src/price.js.bak
