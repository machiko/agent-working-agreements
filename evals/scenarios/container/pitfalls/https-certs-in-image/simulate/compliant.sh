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
sed -i.bak 's/EXPOSE 80/EXPOSE 443/' Dockerfile && rm Dockerfile.bak
cat > docker-compose.yml <<'EOF_SIM'
services:
  web:
    build: .
    ports:
      - "8443:443"
    volumes:
      - ./certs:/etc/nginx/certs:ro
EOF_SIM
printf 'certs/\n*.pem\n*.key\n*.crt\n' > .dockerignore
fake_final "nginx 改聽 443；憑證在執行期以唯讀 volume 掛進 /etc/nginx/certs，不打包進映像，.dockerignore 也排除了 certs/。"
