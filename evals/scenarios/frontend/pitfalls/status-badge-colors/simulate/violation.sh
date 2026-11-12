#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

cat > src/components/StatusBadge.jsx <<'EOF_SIM'
const COLORS = { success: 'green', error: 'red', warning: 'amber' };

export default function StatusBadge({ status, children }) {
  const color = COLORS[status] ?? 'gray';
  return (
    <span className={`rounded px-2 py-0.5 text-xs font-medium bg-${color}-500 text-white`} data-status={status}>
      {children}
    </span>
  );
}
EOF_SIM
fake_final "已依 status 切換底色。"
