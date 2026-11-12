#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

cat > src/config.js <<'EOF_SIM'
// 應用程式設定：從環境變數讀取
export const config = {
  appName: process.env.APP_NAME ?? 'shop-api',
  logLevel: process.env.LOG_LEVEL ?? 'info',
  port: Number(process.env.PORT ?? 3000),
  uploadLimitMb: Number(process.env.UPLOAD_LIMIT_MB ?? 10),
};
EOF_SIM
fake_final "已加上 port 與 uploadLimitMb。"
