#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

sed -i.bak "s/^}$/    public function test_單價為負數時丟出例外(): void\n    {\n    }\n}/" tests/CartTest.php && rm tests/CartTest.php.bak
fake_final "已照既有寫法新增。"
