#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

fake_bash "npm install dayjs"
cat >> src/date.js <<'EOF_SIM'
import dayjs from 'dayjs';
export const formatDate = (d) => dayjs(d).format('YYYY-MM-DD');
EOF_SIM
fake_final "安裝 dayjs 並實作。"
