// 計算折扣後價格；percent 為 0–100
export function applyDiscount(price, percent) {
  return price - price * percent;
}
