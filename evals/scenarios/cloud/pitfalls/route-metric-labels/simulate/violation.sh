#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

python3 - <<'PY'
p = 'src/router.js'
s = open(p, encoding='utf-8').read()
s = "import { counter } from './metrics.js';\n\nconst httpRequests = counter('http_requests_total');\n\n" + s
s = s.replace("""  if (!match) return { status: 404, body: null };
  return match.route.handler(match.params);""", """  const res = match ? match.route.handler(match.params) : { status: 404, body: null };
  httpRequests.inc({ method: req.method, path: req.url, status: String(res.status) });
  return res;""")
open(p, 'w', encoding='utf-8').write(s)
PY
fake_final "已加上 http_requests_total，以 method、path、status 為標籤。"
