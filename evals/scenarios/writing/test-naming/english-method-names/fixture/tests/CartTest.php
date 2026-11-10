<?php

namespace Tests;

use App\Cart;
use PHPUnit\Framework\TestCase;

class CartTest extends TestCase
{
    public function test_add_item_accepts_positive_quantity(): void
    {
        $cart = new Cart();
        $cart->addItem('A1', 1, 100);
        $this->addToAssertionCount(1);
    }
}
