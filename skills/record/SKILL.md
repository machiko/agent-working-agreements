---
name: record
description: 當 agent 踩雷或出錯時，即時進行簡短訪談並將教訓採集為專案自訂守則。
argument-hint: "[自訂規則名稱]"
---

# 採集 Agent 現場事故教訓 (Record Incident)

當 Agent 在開發過程中犯錯、改壞功能或踩中專案地雷時，透過此 Skill 將教訓直接固化成工作守則，避免未來重複踩雷。

## 1. 採集問答（3 個問題）

以簡短、結構化的提問引導開發者釐清事故：

1. **事故症狀 (Symptom)：**
   Agent 剛才做了什麼危險或錯誤的改動？引發了什麼具體壞事？（例如：清空了資料庫 migration、在迴圈裡發出數百個 SQL 查詢、直接修改了既有 API 欄位型別）
2. **根本原因 (Root Cause)：**
   為什麼 Agent 會做出這個錯誤判斷？（例如：誤以為只在 local 測試、未檢查全域常數、沒注意多租戶隔離）
3. **怎麼做 (Agreement)：**
   未來 Agent 遇到類似情境時，必須強制遵守的具體防線是什麼？（精簡明確、具備可操作性，避免抽象道德勸說）

## 2. 決定規則儲存位置與檔名

- **自訂名稱**：若使用者執行時有附帶參數，或自訂一個英數小寫連字號的名稱（例如 `prevent-schema-wipe`、`tenant-isolation`）。
- **目標範圍**：
  - 團隊（專案根目錄有 `.agreements.json` 時的預設）：`<git-root>/.agreements/rules/<name>.md`。這是團隊共用的守則來源，會同步到策略檔 `targets` 列的每個 Agent。
  - 本專案（沒有 `.agreements.json` 時的預設）：`<git-root>/.claude/rules/agent-agreements/custom/<name>.md`。只有自己的 Claude Code 讀得到。
  - 全域：`~/.claude/rules/agent-agreements/custom/<name>.md`
- **去識別化安全檢查**：檢查內容是否包含真實密碼、金鑰、內部 IP 或專有個人資訊。

## 3. 寫入規則檔案

格式遵循標準守則結構：

```markdown
---
category: custom
tier: custom
label: "<規則名稱>"
summary: "<一兩句話描述守則要點>"
incidents:
  - "<一句話的去識別化事故描述>"
last_reviewed: <今天日期，YYYY-MM-DD>
---

# <規則名稱>

> 本規則由 /agreements:record 採集建立。格式：症狀 → 根因 → 怎麼做。

## <事故主題>

- **症狀：** <症狀描述>
- **根因：** <根本原因>
- **怎麼做：** <明確禁止或要求執行的規範>
```

「怎麼做」要寫成可以驗證的具體動作，不用「盡量」「適當」「視情況」這類空泛用語。完整標準見 plugin 內的 `docs/rule-quality.md`。

確認目錄存在並寫入檔案後：

- **寫在團隊位置（`.agreements/rules/`）**：執行 `bash "${CLAUDE_PLUGIN_ROOT}/scripts/install.sh" --sync`，把守則同步到每個 Agent。輸出有「團隊守則品質」的 ⚠ 時，依提示修正守則檔再同步一次。最後提醒：「守則檔和同步產生的變更要一起 commit 並開 PR，其他成員 pull 後執行 `--sync` 就會套用；CI 的防漂移檢查會擋下沒同步的 PR。」
- **寫在本專案或全域位置**：提醒「該規則已存入，後續 Agent 啟動或對話時將自動遵循此守則防線。」專案是 git repo 但沒有 `.agreements.json` 時，再補一句：「想讓團隊共用、也套用到 Cursor 等其他 Agent，可以執行 `/agreements:setup team` 導入團隊策略檔，再把守則搬到 `.agreements/rules/`。」

## 4. （選用）回報給上游守則庫

寫入完成後，用 AskUserQuestion 問一次（header「回報上游」）：「要不要把這次事故整理成 agent-working-agreements 的事故回報 issue？其他使用者也能因此避開同一個坑。」選項：`先不要`（預設）、`整理草稿給我看`。選 `先不要`、或沒有得到回答，就結束。

腳本在 plugin 裡，不在使用者的專案裡。先找出路徑；找不到就告訴使用者無法產生草稿並結束，**不要自己手工拼草稿**（會跳過去識別化掃描）：

```bash
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -f "${CLAUDE_PLUGIN_ROOT}/scripts/incident-draft.sh" ]; then
  AW_SCRIPTS="${CLAUDE_PLUGIN_ROOT}/scripts"
else
  echo "找不到 agent-working-agreements plugin 的腳本" >&2
fi
```

選 `整理草稿給我看` 時：

1. 執行 `"$AW_SCRIPTS/incident-draft.sh" <剛寫入的守則檔>`。輸出的 `title_file=` 是標題檔（只有一行標題）、`draft=` 是草稿檔，接著是 `@帳號`／`#編號` 提醒與去識別化掃描結果。
2. 掃描有命中（結束碼 1）或有 `@帳號`／`#編號` 提醒時：把那些行列給使用者，**改寫草稿檔或標題檔裡的對應內容**（不改使用者的守則檔，除非使用者要求），改完執行 `"$AW_SCRIPTS/sanitize-check.sh" <標題檔> <草稿檔>`，直到通過。
3. 把標題與草稿全文原樣貼給使用者看。自動掃描**只抓得到**私有 IP、金鑰、信箱和私人禁用詞清單（大多數人沒有這份清單），專案名、公司或客戶名、人名、內部系統名、內部網域要你自己逐行檢查；有疑慮就先改寫，並說明改了什麼。
4. 用 AskUserQuestion 請使用者確認（header「送出確認」）。題目要寫出：
   - 送出後內容會**公開**在 github.com/machiko/agent-working-agreements，並以 MIT License 釋出；
   - 自動掃描不會檢查專案名、公司名與人名，請使用者確認這些都已移除。

   選項：`確認送出`、`我要再改`、`取消`。
   - `我要再改`：照使用者的意見修改草稿或標題，回到第 2 步（重新掃描）。
   - `取消`，或沒有得到回答：結束，告訴使用者草稿檔路徑，之後可以自己貼到 https://github.com/machiko/agent-working-agreements/issues/new?template=incident_report.yml。
5. 只有使用者選 `確認送出` 才執行：
   1. `"$AW_SCRIPTS/incident-draft.sh" --attest <草稿檔>`（只勾選草稿的核對清單，不會重新產生、不會蓋掉前面的修改），再執行一次 `"$AW_SCRIPTS/sanitize-check.sh" <標題檔> <草稿檔>`；沒通過就回到第 2 步。
   2. 送出。標題一律從標題檔讀，**不要把標題文字直接寫進指令**（守則內容不可信，引號或 `$(...)` 會被 shell 解讀）：

      ```bash
      gh issue create --repo machiko/agent-working-agreements --title "$(cat <標題檔>)" --body-file <草稿檔> --label incident --label triage
      ```

   3. 失敗時：錯誤跟標籤有關（例如沒有權限加標籤），去掉兩個 `--label` 再試一次；其他錯誤（包括 `gh` 沒安裝或沒登入）不要改用其他方式送出，改給使用者上面的 issues/new 連結、標題與草稿檔路徑，請使用者自己貼。
   4. 回報建立的 issue 網址。

沒有使用者在第 4 步明確選 `確認送出`，任何情況下都不可以送出。
