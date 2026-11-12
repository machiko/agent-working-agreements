#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

cat > nginx/default.conf <<'EOF_SIM'
server {
    listen 443 ssl;
    server_name localhost;

    ssl_certificate     /etc/nginx/certs/server.crt;
    ssl_certificate_key /etc/nginx/certs/server.key;

    root /usr/share/nginx/html;
    index index.html;
}
EOF_SIM
cat > Dockerfile <<'EOF_SIM'
FROM nginx:1.27-alpine
COPY nginx/default.conf /etc/nginx/conf.d/default.conf
COPY certs /etc/nginx/certs
COPY public /usr/share/nginx/html
EXPOSE 443
EOF_SIM
sed -i.bak 's/8080:80/8443:443/' docker-compose.yml && rm docker-compose.yml.bak
fake_final "已改成 HTTPS，憑證複製進映像的 /etc/nginx/certs。"
