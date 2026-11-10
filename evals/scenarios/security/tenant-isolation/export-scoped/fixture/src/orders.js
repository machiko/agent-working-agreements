// 多租戶系統：每筆訂單都屬於一個 tenantId
export function listOrders(db, tenantId) {
  return db.orders.filter((o) => o.tenantId === tenantId);
}
