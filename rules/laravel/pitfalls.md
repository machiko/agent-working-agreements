---
category: laravel
tier: optional
label: "Laravel 地雷"
summary: "10 條 Laravel 正式環境與測試的事故，例如 fake() 未定義、空的 env 蓋掉預設值。只在碰到 PHP 檔時載入"
stack: laravel
paths:
  - "**/*.php"
  - "composer.json"
  - "phpunit.xml"
  - ".env.example"
---

# Laravel 地雷

> 每一條都是實際發生過的事故，大多「單獨跑會過、CI 也抓不到」。格式：症狀 → 根因 → 怎麼做。

## 正式環境：`fake()` 未定義

- **症狀：** 正式環境噴出 `Call to undefined function fake()`。
- **根因：** Faker 屬於 `require-dev`，正式環境用 `--no-dev` 安裝時沒有它。`app/` 裡某個 `match` 的 `default` 分支會退回去產生假資料，CI 有裝 Faker 所以抓不到。就算正式環境真的裝了 Faker，使用者也會看到假資料。
- **怎麼做：** 會產生假資料或 mock 的分支一律用 `app()->isLocal()` 守住，`default` 分支不可以退回假資料，要明確拋出錯誤。測試非 local 的行為時，設定 `$this->app['env'] = 'production'`。注意這樣會重新啟用 CSRF，HTTP 測試要加上 `withoutMiddleware(ValidateCsrfToken::class)`。

## 主鍵不叫 `id` 時，`$model->id` 會靜默回傳 null

- **症狀：** 多位使用者的驗證碼互相覆蓋，單人測試無法重現。
- **根因：** legacy 資料表的主鍵是自訂名稱（例如 `pk_id`），表上沒有 `id` 欄位。Eloquent 存取不存在的屬性不會報錯，只會回傳 `null`。結果 `'code_' . $model->id` 讓所有使用者共用同一個 cache key。
- **怎麼做：** 組 cache key、log context、任何需要識別身分的地方，一律用 `getKey()` 或明確的欄位名稱。code review 時看到非標準主鍵的 model 被存取 `->id`，就當作紅旗。可以考慮開啟 `Model::preventAccessingMissingAttributes()`。

## `env('X', 'default')` 遇到空值不會回傳預設值

- **症狀：** 限額歸零、端點變成空字串、某個功能悄悄被關掉。
- **根因：** `.env` 裡有 `X=`（空值）時，`env()` 回傳的是空字串，不是預設值。用腳本「幫 `.env` 補上缺少的 key 並給空值」，等於把所有預設值蓋掉。
- **怎麼做：** 會被留空的設定在 config 裡寫成 `env('X') ?: 'default'`。`.env.example` 盡量寫上真實的預設值。同步 env 的工具預設帶入範例值，而不是補空值。

## faker `randomNumber()` 可能產生 0

- **症狀：** 間歇性出現 302 或 404，大約 1% 的機率，每次失敗的測試都不一樣。
- **根因：** 不帶參數的 `randomNumber()` 會產生 0 到 8 位數的數字，包含 0。下游用 `if (! $id)` 判斷時，0 會被當成不存在。
- **怎麼做：** 當 ID 用時寫 `randomNumber(8, true)`（固定位數）。排查 flaky 測試時，先把單一 class 重複跑 5 到 8 次，排除隨機資料造成的問題，不要先假設是測試之間的順序污染。

## 測試的 session／cache driver 要用 `array`

`phpunit.xml` 要設定 `SESSION_DRIVER=array` 和 `CACHE_STORE=array`。file driver 的 GC 抽籤（`session.lottery`）會在跑整套測試時隨機弄丟 session。時間相關的斷言要搭配 `$this->freezeTime()`。

## 匯出測試在整套測試時 OOM

- **症狀：** 單獨跑那個測試檔會過，整套 Feature suite 跑到一半就 OOM。
- **根因：** 真的跑 PhpSpreadsheet 很吃記憶體；`Excel::fake()` 回傳的 response 也還要再配置記憶體。前面的測試已經累積了不少 heap。
- **怎麼做：** 用 `Excel::shouldReceive('download')->once()->andReturnUsing(fn ($export, $name) => response('ok'))` 攔截 export 物件，再直接呼叫它的 `collection()`、`map()` 斷言。

## Docker build 時 `package:discover` 失敗

- **症狀：** production 映像 build 時，`composer dump-autoload` 失敗，exit 1。
- **根因：** Artisan 註冊指令時會透過 container 把**每個 command 實例化**，所以會觸發建構子注入。build 階段沒有密鑰，在建構子裡注入「缺密鑰就丟例外」的 service，build 就會失敗。
- **怎麼做：** 需要密鑰或連線的 service，不要在 command 的建構子注入，改在 `handle()` 裡用 `app(Service::class)` 延遲解析。驗證方式：把密鑰清空後跑 `package:discover`，要能通過。

## 切分支後 artisan 全部失敗：`Target class [cache] does not exist`

- **根因：** `bootstrap/cache/packages.php` 是別條分支留下的舊快取，記載了目前 lock 檔裡沒有的套件。真正的錯誤被錯誤回報層蓋掉了。
- **怎麼做：** composer install／update 之後一定要跑 `php artisan package:discover`（或不要加 `--no-scripts`）。要看原始錯誤時：
  ```bash
  php -r 'require "vendor/autoload.php"; $app = require "bootstrap/app.php"; $app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();'
  ```
  然後刪掉 `bootstrap/cache/packages.php` 和 `services.php` 重建。如果 `vendor/composer/autoload_static.php` 裡還留著已刪除 worktree 的絕對路徑，執行 `composer dump-autoload` 即可。

## 用 root 跑 artisan 留下 root 擁有的檔案

- **症狀：** 正式環境的某個 log channel 整天寫不進去，事件全部靜默遺失。
- **根因：** 部署時 `docker compose exec app php artisan …` 預設以 root 執行，當天第一筆 log 用 root 建出了檔案。php-fpm 和 worker 是以一般使用者執行的。
- **怎麼做：** 部署手冊裡的 artisan 指令一律加 `exec -u <app user>`。容器的 entrypoint 以 root 啟動時，先 `chown` 好 `storage/logs`、`storage/framework`、`bootstrap/cache`，再 exec 主程序。

## 跨環境不要寫死自動產生的 ID

seeder 或程式要找角色、權限時，用穩定的 `code` 查詢（`Role::where('code', 'ADMIN')->first()`）。各環境的資料是各自匯入的，自動產生的 ID 不一樣。比對既有帳號時，用唯一的帳號名稱。
