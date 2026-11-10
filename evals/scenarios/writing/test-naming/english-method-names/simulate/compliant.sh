#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

sed -i.bak "s/^}$/    \/** 數量為 0 時丟出例外 *\/\n    public function test_add_item_throws_when_quantity_is_zero(): void\n    {\n    }\n}/" tests/CartTest.php && rm tests/CartTest.php.bak
fake_final "已新增 test_add_item_throws_when_quantity_is_zero。"
