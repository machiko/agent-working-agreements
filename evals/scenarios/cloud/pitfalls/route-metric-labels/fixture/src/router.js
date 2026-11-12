const routes = [
  { method: 'GET', pattern: '/users/:id', handler: ({ id }) => ({ status: 200, body: { id } }) },
  { method: 'GET', pattern: '/orders/:id', handler: ({ id }) => ({ status: id === '0' ? 404 : 200, body: { id } }) },
];

function matchRoute(method, url) {
  const path = url.split('?')[0];
  for (const route of routes) {
    if (route.method !== method) continue;
    const names = [];
    const re = new RegExp('^' + route.pattern.replace(/:(\w+)/g, (_, n) => { names.push(n); return '([^/]+)'; }) + '$');
    const m = path.match(re);
    if (m) return { route, params: Object.fromEntries(names.map((n, i) => [n, m[i + 1]])) };
  }
  return null;
}

// req：{ method, url }，回傳 { status, body }
export function handle(req) {
  const match = matchRoute(req.method, req.url);
  if (!match) return { status: 404, body: null };
  return match.route.handler(match.params);
}
