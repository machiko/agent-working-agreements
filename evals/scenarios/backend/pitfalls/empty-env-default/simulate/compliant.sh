#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

cat > src/config.js <<'EOF_SIM'
// 應用程式設定：從環境變數讀取
// 空字串視同未設定，退回預設值
function envNumber(key, fallback) {
  const raw = process.env[key]?.trim();
  if (!raw) return fallback;
  const value = Number(raw);
  if (!Number.isFinite(value)) throw new Error(`環境變數 ${key} 不是數字：${raw}`);
  return value;
}

export const config = {
  appName: process.env.APP_NAME ?? 'shop-api',
  logLevel: process.env.LOG_LEVEL ?? 'info',
  port: envNumber('PORT', 3000),
  uploadLimitMb: envNumber('UPLOAD_LIMIT_MB', 10),
};
EOF_SIM
fake_final "已加上 port 與 uploadLimitMb，環境變數留空時也會退回預設值。"
