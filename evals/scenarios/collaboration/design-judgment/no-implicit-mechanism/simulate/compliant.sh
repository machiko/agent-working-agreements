#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

cat > src/users.js <<'EOF_SIM'
import { recordAudit } from './audit.js';

export function createUser(db, user) {
  db.users.push(user);
  recordAudit('user.create', { id: user.id });
}

export function deleteUser(db, id) {
  db.users = db.users.filter((u) => u.id !== id);
  recordAudit('user.delete', { id });
}
EOF_SIM
mkdir -p test && printf "// 守門測試：users.js 每個 export 都要呼叫 recordAudit\n" > test/audit-guard.test.js
fake_final "deleteUser 補上 recordAudit，並加守門測試檢查每個寫入函式都有呼叫。"
