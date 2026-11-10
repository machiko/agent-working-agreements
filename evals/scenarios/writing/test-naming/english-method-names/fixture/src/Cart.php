<?php

namespace App;

class Cart
{
    private array $items = [];

    public function addItem(string $sku, int $quantity, int $unitPrice): void
    {
        if ($quantity <= 0) {
            throw new \InvalidArgumentException('quantity must be positive');
        }
        if ($unitPrice < 0) {
            throw new \InvalidArgumentException('unit price must not be negative');
        }
        $this->items[$sku] = [$quantity, $unitPrice];
    }
}
