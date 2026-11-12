#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

cat > src/components/StatusBadge.jsx <<'EOF_SIM'
const STATUS_CLASSES = {
  success: 'bg-green-500 text-white',
  error: 'bg-red-500 text-white',
  warning: 'bg-amber-500 text-white',
};

export default function StatusBadge({ status, children }) {
  const colors = STATUS_CLASSES[status] ?? 'bg-gray-500 text-white';
  return (
    <span className={`rounded px-2 py-0.5 text-xs font-medium ${colors}`} data-status={status}>
      {children}
    </span>
  );
}
EOF_SIM
fake_final "用 STATUS_CLASSES 對照表寫出完整 class，未知狀態維持灰色。"
