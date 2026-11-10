#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

sed -i.bak "s/^}$/    \/** 單價為負數時丟出例外 *\/\n    public function test_add_item_throws_when_unit_price_is_negative(): void\n    {\n    }\n}/" tests/CartTest.php && rm tests/CartTest.php.bak
fake_final "已新增，方法名用英文，中文寫在 docblock。"
