---
category: docker
tier: optional
label: "Docker 地雷"
summary: "切分支後 bind mount 斷線、Xdebug 拖慢測試、CI 快取等。用 compose 開發才選；只在碰到 Dockerfile、compose 時載入"
stack: docker
paths:
  - "**/Dockerfile*"
  - "**/*compose*.yml"
  - "**/*compose*.yaml"
  - "**/nginx/**"
  - "**/*.ini"
  - "**/bitbucket-pipelines.yml"
  - "**/.gitlab-ci.yml"
  - "**/.github/workflows/*.yml"
---

# Docker 與本機開發環境地雷

> 以 macOS 搭配 Docker Desktop、compose 開發環境為主。格式：症狀 → 根因 → 怎麼做。

## 切分支後，單檔 bind mount 斷掉

- **症狀：** 切完分支，PHP 的 `memory_limit` 退回 128M，整套測試 OOM；或者 supervisord 管的某個 queue worker 消失、任務卡在 queued；或者某個服務退回預設設定、只聽 127.0.0.1，healthcheck 仍然顯示 healthy，其他容器卻連不上。
- **根因：** git 切分支（或 `sed -i`、`perl -pi`）會改寫 host 端的檔案，inode 跟著換掉。單檔的 bind mount 綁的是舊 inode，容器內的路徑會變成不可讀或直接不存在。目錄級的 mount 在目錄被刪掉又重建時也會斷。
- **怎麼做：**
  - 判斷方式：在容器內讀設定值，例如 `php -r 'echo ini_get("memory_limit");'`，或 `ls -l` 看掛載點。
  - `docker compose restart` 不會重新掛載。要用 `docker compose up -d --force-recreate <service>`，named volume 的資料會保留。
  - 一般的 `up -d` 也沒用，因為 compose 的 config hash 沒有變。
  - 從根本避免：一個分支一個 worktree，主工作區不要為了跑測試而切分支。

## 從 host 端殺掉 `docker compose exec`，容器內的程序還在跑

殺掉 exec 的 client 不會帶走容器裡的程序（例如 phpunit），要自己進容器 `pkill`。`docker run` 也一樣：砍掉 client 之後要 `docker kill`。

## Xdebug 拖慢整套測試

- **症狀：** 整套測試從幾分鐘變成 30 分鐘以上，看起來像當掉。
- **怎麼做：** 設定成 `xdebug.mode=debug` 搭配 `xdebug.start_with_request=trigger`。要除錯時，request 帶 `XDEBUG_TRIGGER`，或 CLI 前面加 `XDEBUG_TRIGGER=1`；要算覆蓋率時再臨時設定 `XDEBUG_MODE=coverage`。另外開的 `docker run` 容器如果沒有掛載 xdebug.ini，就要加 `-e XDEBUG_MODE=off`，否則平行測試會把主機塞爆。

## 容器內的 Vite 沒有偵測到新的 Tailwind class

- **症狀：** 樣板的 HMR 看起來有更新，但新加的 class 沒有樣式。
- **根因：** macOS 的 bind mount 不會把檔案事件傳進容器，Tailwind 不會重新掃描 class。
- **怎麼做：** `touch` 一下主 CSS 入口檔，幾秒後就會重建。驗證版面前先做這一步，否則會誤以為 class 寫錯了。

## 同源反向代理的白名單

前端打同源的 `/api/*`，由 nginx `proxy_pass` 轉發到另一個後端，藉此避開 CORS 和 mixed content。這種架構下，**每新增一個後端端點，都要同步在 nginx 加上 `location`**，否則請求會落到主框架的路由，回 404 或 405。改完設定先 `nginx -t`，再 reload。

## 平行測試與共用資源

- 多個測試程序共用同一個測試資料庫時，不要同時從兩個工作區跑整套測試，用 `flock` 之類的鎖排隊。
- 背景執行整套測試時，腳本最後要 `exit $rc` 把結束碼傳出去，不要在最後接 `| tail`，否則結束碼會被吃掉。
- zsh 不會切割沒加引號的變數：`RUN="docker run …"; $RUN php …` 會被當成一個檔名。要用 function 包起來：`run() { docker run … "$@"; }`。

## CI 快取

- 要快取的是套件管理器的**下載快取**（`~/.composer/cache`、`~/.npm`），不是安裝結果（`vendor/`、`node_modules/`）。後者會被 `npm ci` 或 setup 腳本清掉，等於每次完整重裝，還多付一次上傳下載的時間。
- 第一次冷快取會比沒有快取還慢，從第二次開始才省時間。
- 改了快取路徑時要一併改快取名稱，否則舊的封存會被還原到新路徑。
- Bitbucket Pipelines 的快取名稱只接受小寫英數字和連字號，有底線會讓整份設定解析失敗。
