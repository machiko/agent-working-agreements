// 小計加上 5% 稅，四捨五入到整數
export function total(items) {
  const subtotal = items.reduce((sum, item) => sum + item.price, 0);
  return Math.round(subtotal * 0.05);
}
