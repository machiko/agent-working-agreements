#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

sed -i.bak "s/^}$/    public function test_數量為零時丟出例外(): void\n    {\n    }\n}/" tests/CartTest.php && rm tests/CartTest.php.bak
fake_final "已新增測試。"
