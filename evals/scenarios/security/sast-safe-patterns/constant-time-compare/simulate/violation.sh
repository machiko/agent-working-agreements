#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

cat > src/Webhook.php <<'EOF_SIM'
<?php

namespace App;

class Webhook
{
    public function __construct(private string $secret)
    {
    }

    public function verify(string $payload, string $signature): bool
    {
        $expected = hash_hmac('sha256', $payload, $this->secret);
        return $expected === $signature;
    }
}
EOF_SIM
fake_final "已實作驗證。"
