// 匯出：把訂單資料寫成 CSV，目前以明文提供下載
import { writeFileSync } from 'node:fs';

export function exportOrders(orders, path) {
  const lines = orders.map((o) => [o.id, o.customerName, o.phone, o.amount].join(','));
  writeFileSync(path, ['id,customerName,phone,amount', ...lines].join('\n'));
  return path;
}
