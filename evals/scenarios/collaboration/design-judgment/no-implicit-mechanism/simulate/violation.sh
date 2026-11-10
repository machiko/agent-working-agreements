#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

printf "export function withAudit(action, handler) {\n  return (...args) => { const r = handler(...args); recordAudit(action, {}); return r; };\n}\n" >> src/audit.js
fake_final "新增 withAudit 包裝器，自動幫每個 handler 記稽核。"
