---
category: security
tier: core
---

# 個資與機敏檔案不進版控

## 規則

- 只 add 明確的路徑，不要用 `git add -A` 或 `git add .`。
- commit 前逐檔看 staged 清單。遇到 `.csv`、`.xlsx`、`.docx`、`.sql`、`.json`，或路徑在 `data/`、`storage/`、`.env*` 底下的檔案，先停下來問使用者。
- `.gitignore` 用萬用字元擋整個檔案家族（`accounts*.csv`），不要只擋單一檔名。
- `.env.*` 預設全部擋掉，只用 `!` 放行 `.env.example` 這類確定不含祕密的檔案。
- 根目錄的資料型檔案（`/*.csv /*.xlsx /*.xls /*.docx /*.pdf`）預設擋掉。

**為什麼：** 實際發生過的事：

- `.gitignore` 只擋了單一檔名，結果同系列的另一個測試用 CSV（含個人資料）在 squash 後被一併帶進 commit。
- 清查時也要檢查歷史：資料庫 dump、環境設定檔這類檔案如果曾經被提交，即使之後刪掉，仍然留在歷史裡。

repo 只要能被 clone，歷史裡的東西就等於公開了。

## 新增 seed／fixture 資料檔之前

先 grep 確認全是假資料：

```bash
grep -nE '@[A-Za-z0-9.-]+\.(gov|edu)\.[a-z]{2}' <file>   # 機關信箱
grep -nE '09[0-9]{8}' <file>                              # 台灣手機號碼
grep -nE '[A-Z][12][0-9]{8}' <file>                       # 台灣身分證字號
grep -nE '\$2[aby]\$' <file>                              # bcrypt 雜湊
```

## 清查現有 repo

```bash
git ls-files | grep -Ei '\.(csv|xlsx|docx|sql)$'
git log --all --diff-filter=A --name-only --format= | grep -Ei '\.(csv|xlsx|sql)$' | sort -u
```

發現問題時，「移出版控」和「改寫歷史」是兩個不同的決定。改寫歷史會影響所有協作者，要讓使用者自己決定。
