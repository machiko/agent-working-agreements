---
category: security
tier: optional
label: "SAST 安全寫法"
summary: "寫程式時就避開 Checkmarx 類掃描器常抓的 8 種寫法。專案有接 SAST 掃描才選；只在編輯程式碼時載入"
paths:
  - "**/*.{php,js,mjs,ts,tsx,jsx,vue}"
---

# 預先避開 SAST 告警的寫法

> 從多次處理商用 SAST 掃描器（Checkmarx 類）告警的修復 PR 整理而來。這類掃描器多半依「形式」判斷，語意正確的程式碼也會被抓。事後修一輪通常還會留下殘留的落點，要修第二、第三次。所以寫新程式時就直接套用以下寫法。
>
> 範例以 PHP／Laravel 和瀏覽器端 JS 為主，原則適用於其他語言。

## 1. 前端 fetch：Missing HSTS Header

- 所有 `fetch()` 都經過專案自己的 wrapper，不要直接用裸 `fetch()`。
- 需要 Response 物件時（streaming、檢查 `ok`），用 `JSON.parse(await resp.text())` 解析，**不要呼叫 `resp.json()`**。掃描器把 `.json()` 認定為污點 sink，連 `.json().catch(() => ({}))` 也會被抓。
- 後端在 HTTPS 下一律送 HSTS header（用 middleware）。

## 2. 雜湊、HMAC、token 比對：Observable Time Discrepancy

- 一律用常數時間比較（`hash_equals($expected, $actual)`），並先用 `is_string()` 檢查型別。
- 掃描器會追蹤雜湊函式回傳值的污點，**任何碰到這個值的比較運算子都會被抓**：
  - null 的退路不要寫 `$a === $b`，改成 `is_null($a) && is_null($b)`
  - 裝著雜湊值的陣列判斷是否為空，不要寫 `$arr === []`，改用 `empty($arr)`
- 只在內部執行的維護指令也會被掃，不能用「沒有外部時序可觀察」當理由跳過。

## 3. 加密金鑰：Use of Hard-coded Cryptographic Key

- 金鑰欄位的型別用 `?string`，缺少時回傳 `null`，**不要用 `''`、`str_repeat()` 之類的字面值當退路**。用到金鑰前先判斷 null，是 null 就直接失敗。
- 如果掃描器還是把 `config('x.key')` 的字面值預設一路追到解密函式，就改讀 `$_ENV['KEY'] ?? $_SERVER['KEY'] ?? null`，並在 docblock 註明這個寫法的前提（例如沒有使用 config cache）。
- 測試用的金鑰在 setUp 裡用 `random_bytes(32)` 產生，IV 也用隨機產生。不要寫 `str_repeat('a', 32)` 或 `"\x00"`。

## 4. 迴圈條件受輸入控制：Unchecked Input for Loop Condition

解析外部串流或使用者輸入的 `while (buf.indexOf(...) !== -1)` 這類迴圈，要兩層防護：

1. 改成 `for (let i = 0; i < MAX_ITERATIONS; i++)`，找不到就 `break`。
2. 累積 buffer 之前先檢查長度上限（例如 SSE 設 1 MB），超過就取消讀取並拋出錯誤。

## 5. 檔案系統：Path Traversal

- 刪除目錄用框架提供的 API（例如 `File::deleteDirectory()`），不要自己用 `scandir`、`unlink`、`rmdir` 寫遞迴。
- 路徑拼接優先透過 storage 抽象層（例如 `Storage::disk()->path()`）。

## 6. 弱雜湊：Use of Weak Hash

cache key、指紋這類用途也一律用 `sha256`，不要用 `md5`、`sha1`，即使不是安全用途也一樣。

## 7. 例外處理：Improper Exception Handling

CLI 指令的進入點外層包 `try { … } catch (Throwable $e) { log; return FAILURE; }`：

- 要 catch `Throwable`，不只是 `Exception`。
- try 包在 transaction 外面，不要把 try 寫在 transaction 的 closure 裡面。

## 8. 硬編碼密碼：Use of Hardcoded Password

這條規則看的是**識別字、陣列 key、物件屬性名稱裡有沒有 `password`、`pwd`，而且被指派了字串字面值**，不管那個值像不像密碼。測試檔、header 名稱、日誌遮罩、範例值都會被抓。

- 測試夾具的密碼在執行期產生（`crypto.randomUUID()`、`Str::password()`），存成變數共用。
- 協定常數（例如密碼傳遞用的 header 名稱）的識別字不要含 password 字眼。前端不寫字面值，改由後端常數透過 `<meta>` 或 `data-*` 帶入。
- 日誌遮罩直接把那個 key 剔除（`Arr::except()`），不要填 `'***'`。
- **字面值透過參數物件流進 `opts.password` 也會被抓**：e2e 的 `loginAs(page, 'admin')` 裡的 `'admin'` 會被當成密碼。登入 helper 的密碼只從環境變數取，不開放呼叫端傳入。
