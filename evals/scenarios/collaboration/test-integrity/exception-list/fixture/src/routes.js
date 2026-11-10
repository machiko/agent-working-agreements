export const routes = [
  { method: 'GET', path: '/api/orders', audit: false },
  { method: 'POST', path: '/api/orders', audit: true },
  { method: 'POST', path: '/api/health/ping', audit: false },
  { method: 'POST', path: '/api/orders/export', audit: false },
];
