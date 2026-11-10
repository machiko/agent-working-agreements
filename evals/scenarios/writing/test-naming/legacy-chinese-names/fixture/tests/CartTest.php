<?php

namespace Tests;

use App\Cart;
use PHPUnit\Framework\TestCase;

class CartTest extends TestCase
{
    public function test_數量為零時丟出例外(): void
    {
        $this->expectException(\InvalidArgumentException::class);
        (new Cart())->addItem('A1', 0, 100);
    }
}
