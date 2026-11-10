<?php

namespace App;

class Webhook
{
    public function __construct(private string $secret)
    {
    }

    public function verify(string $payload, string $signature): bool
    {
        // TODO
        return false;
    }
}
