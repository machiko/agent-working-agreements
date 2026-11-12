#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

python3 - <<'PY'
p = 'src/router.js'
s = open(p, encoding='utf-8').read()
s = "import { counter } from './metrics.js';\n\nconst httpRequests = counter('http_requests_total');\n\n" + s
s = s.replace("""  if (!match) return { status: 404, body: null };
  return match.route.handler(match.params);""", """  if (!match) {
    httpRequests.inc({ method: req.method, route: 'unmatched', status: '4xx' });
    return { status: 404, body: null };
  }
  const res = match.route.handler(match.params);
  httpRequests.inc({ method: req.method, route: match.route.pattern, status: `${String(res.status)[0]}xx` });
  return res;""")
open(p, 'w', encoding='utf-8').write(s)
PY
fake_final "已加上 http_requests_total，標籤用路由樣板（如 /users/:id）、method 與狀態碼區間。"
