---
category: container
tier: optional
label: "容器與本機虛擬化環境地雷"
summary: "容器與本機環境通用事故：切分支單檔 bind mount inode 斷線、終端殺掉 client 容器程序仍殘留、Xdebug/Profiler 拖慢測試、macOS 虛擬化檔案系統事件丟失、反向代理路由白名單。只在碰到容器設定時載入"
stack: container
paths:
  - "**/Dockerfile*"
  - "**/Containerfile*"
  - "**/*compose*.yml"
  - "**/*compose*.yaml"
  - "**/nginx/**"
  - "**/.dockerignore"
incidents:
  - "切換分支後容器內設定退回預設值，queue worker 消失"
  - "Host 端改了程式碼，容器內的開發伺服器沒有熱重載"
  - "憑證與私鑰被打包進映像，推送到共享 Registry"
last_reviewed: 2026-11-10
---

# 容器與本機虛擬化環境地雷

> 適用於 Docker、Podman、Compose、本機虛擬化與反向代理開發環境。格式：症狀 → 根因 → 怎麼做。

## 切換分支後單檔 Bind Mount Inode 斷線

- **症狀：** `git switch` 切完分支後，容器內部的設定檔（如 php.ini、nginx.conf、custom.cnf）退回預設值，或是 queue worker 程序消失、任務卡住，甚至容器健康檢查顯示 healthy 但對外連線全數拒絕。
- **根因：** Git 切換分支或文字編輯器寫入時會建立新檔案並取代原檔案，導致 Host 端檔案的 inode 發生變化。Docker 單檔 bind mount 是以底層 inode 進行綁定，當 inode 變更後，容器內部的檔案便指向已被銷毀的舊 inode，失去同步或變成空檔案。
- **怎麼做：**
  - 重啟時不要只使用 `docker compose restart`（這不會重新計算 mount）。必須使用 `docker compose up -d --force-recreate <service>` 強制重建容器掛載。
  - 從工作流程根本預防：一個分支對應一個獨立的 git worktree，避免在同一個掛載目錄中反覆切換分支跑測試。

## 終端殺掉 Client 容器內部程序仍繼續佔用資源

- **症狀：** 在終端按下 Ctrl+C 結束 `docker compose exec` 或 `docker run` 後，本機 CPU 依然飆高、連接埠依然被佔用、或資料庫被未終止的測試程序鎖定。
- **根因：** 終端中斷信號只終止了 host 端的 client 連線程序，若容器內沒有配置 init 程序（如 dumb-init、tini）將 SIGINT/SIGTERM 正確轉發給子程序，容器內的程序會被 PID 1 收養變成孤兒程序繼續在背景執行。
- **怎麼做：**
  - 殺掉終端連線後，必須明確進容器以 `pkill` 終止程序，或執行 `docker kill <container_id>`。
  - Dockerfile 應配置 `init: true` 或引入 `tini` 作為 entrypoint，確保信號能正確轉發至子程序。

## macOS / Windows 虛擬化檔案系統事件丟失 (Inotify Drop)

- **症狀：** 在 Host 端修改了前端代碼、CSS 或樣板，但容器內部的開發伺服器（Vite、Webpack、Next.js）完全沒有觸發熱重載（HMR），必須重啟容器才有反應。
- **根因：** macOS（VirtioFS / gRPC-FUSE）與 Windows（WSL2 跨檔案系統）的跨宿主檔案共享層，常常無法將底層 inotify 檔案變更事件即時傳遞進虛擬機容器內。
- **怎麼做：**
  - 開發伺服器配置啟用輪詢模式（Polling Fallback，例如 Vite `server.watch.usePolling: true`、Webpack `watchOptions: { poll: 1000 }`）。
  - 或者手動在容器內部執行 `touch` 目標入口檔案強制觸發更新。

## Profiler / Debugger 常駐拖慢整套測試

- **症狀：** 整套測試從一兩分鐘暴增至 30 分鐘以上，甚至在 CI 或多並發測試時主機直接凍結。
- **根因：** 容器內啟用了偵錯或覆蓋率工具（如 Xdebug、Python py-spy、Node --inspect），並且預設在每個請求或 CLI 執行時都全面啟動，產生巨大效能開銷。
- **怎麼做：**
  - 本地開發預設將 debugger 設為手動觸發（Trigger 模式），只在 HTTP Header 帶有指定 Trigger key 或命令列傳入環境變數時才啟用。
  - 運行批次測試或平行測試時，一律透過環境變數明確關閉 debug 模式。

## 同源反向代理路由白名單同步遺漏

- **症狀：** 前端呼叫同源的新增 API 端點（如 `/api/v2/items`）時，偶發回傳 404、405 或直接返回 SPA 的 index.html。
- **根因：** 本機環境通常透過 Nginx、Traefik 或 Caddy 轉發 `/api/*` 避開 CORS。新增端點若路徑模式不符既有 proxy rule，請求會直接穿透落入前端靜態服務路由。
- **怎麼做：** 調整反向代理規則時，優先採用泛型路由轉發（如 `location /api/ { proxy_pass ... }`），避免針對每個子路徑逐一手動條列；每次修改 proxy 設定檔後先跑語法測試（如 `nginx -t`）再 reload。

## 憑證與私鑰禁止打包進容器映像 (No Certificates in Images)

- **症狀：** 專案更換 HTTPS 憑證或輪換金鑰後，發布新容器仍出示舊憑證，或容器映像檔推送至公開/共享 Registry 後造成私鑰永久外洩。
- **根因：** 在 Dockerfile 建構階段使用 `COPY ./ssl /etc/ssl` 將憑證與私鑰烤入映像檔中。即使在後續指令中刪除或覆蓋，私鑰仍殘留在 Docker 映像檔的唯讀歷史 Layer 中，拉取歷史層即可輕易還原。
- **怎麼做：**
  - 憑證與私鑰一律在執行期（Runtime）以唯讀 Volume 掛載（例如 Compose 的 `./ssl:/etc/ssl/private:ro`），或透過 K8s Secrets / AWS Secrets Manager 於啟動時動態注入。
  - 確保 `.dockerignore` 與 `.gitignore` 包含 `*.pem`、`*.crt`、`*.key`，防止意外建構或提交進映像歷史。
