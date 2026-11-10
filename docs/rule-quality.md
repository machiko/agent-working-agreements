# 守則品質標準

`rules/` 底下每一條守則都要符合這份標準。能用機器檢查的部分由 CI 把關：

| 檢查 | 指令 | 對應條文 |
|------|------|---------|
| frontmatter 欄位、core 行數預算 | `scripts/check-budget.sh` | 1、6 |
| 條目結構、空泛用語、標題重複、條目長度 | `scripts/lint-rules.sh` | 2、3、4、5 |
| 淘汰欄位 | `scripts/check-budget.sh` | 7 |
| 守則與機器檢查連動 | `scripts/check-schema.sh` | 8 |
| 翻譯同步 | `scripts/check-i18n.sh` | 9 |

其餘（根因是否說明機制、「怎麼做」是否真的可行）靠審查判斷。

## 1. frontmatter 要記錄事故來源與審查日期

```yaml
---
category: database          # 與所在目錄一致
tier: optional              # core 或 optional
incidents:                  # 至少一項
  - "migration 中途失敗後重跑報錯，部署流程卡死"
last_reviewed: 2026-11-10   # YYYY-MM-DD
---
```

- `incidents`：一句話的去識別化事故描述、issue 編號或公開事故的出處。只寫真的發生過的事，**不可為了填欄位編造事故**。整份守則都沒有事故依據時，寫成 `"慣例：<採用的理由>（沒有單一事故）"`。
- `last_reviewed`：最後一次依本標準審查的日期。改寫內容時一併更新。

## 2. 每個條目要有依據

條目＝每個 `##` 標題；檔案沒有 `##` 時改用 `###`。

| 條目類型 | 必要段落 | 用在 |
|---------|---------|-----|
| 地雷 | `**症狀：**`、`**根因：**`、`**怎麼做：**` 三段齊全 | `*/pitfalls.md` 這類技術事故 |
| 協作守則 | 規則本文＋`**為什麼：**`（可再加 `**怎麼做：**`） | 協作、安全、寫作守則 |
| 慣例 | 標題加 `<!-- 慣例 -->` | 團隊明確採用、但沒有單一事故的做法 |
| 參考 | 標題加 `<!-- 參考 -->` | 對照表、格式範本、檢查指令清單 |

- **為什麼／根因要說明機制**，不是道德勸說。「因為這樣比較好」不算；「HEAD 是 worktree 層級的單一狀態，並行 session 會互相覆蓋」才算。
- **不要硬補理由**：沒有事故依據就標成慣例，不要寫一段聽起來合理、但沒發生過的「為什麼」。

合格：

```markdown
## commit 前重新確認目前分支

每次 `git commit` 前都先跑 `git branch --show-current`。

**為什麼：** 使用者常在另一個終端切分支。agent 沿用舊資訊，把 `feat:` commit 落在別人的 `fix/` 分支上。
```

不合格（沒有依據、動作無法驗證）：

```markdown
## 注意分支

commit 前要注意分支是否正確，盡量避免提交到錯誤的分支。
```

## 3. 「怎麼做」要能驗證

寫成看得出「有沒有做到」的具體動作：指令、設定值、檢查方式。

- 不用 `盡量`、`儘量`、`盡可能`、`儘可能`、`適當`、`視情況`、`多加注意`。lint 會擋；寫在「」引號、行內程式碼或程式碼區塊裡的不算（例如引用反例）。
- 不寫 agent 本來就會做的事（「寫乾淨的程式碼」）。

## 4. 不重複

- 條目標題不可跨檔重複（lint 會忽略編號與標註後比對）。
- 內容重複但標題不同時，lint 抓不到，審查時要合併：保留比較完整的一處，另一處改成一行指向它。兩條都是 core 時尤其要合併，因為兩份都會常駐載入。

## 5. 條目長度

單一條目本文（不含空行）不超過 40 行（`MAX_ENTRY_LINES`）。超過就拆成多個條目，或把細節移到 skill。

## 6. 常駐預算

`tier: core` 的本文總行數不超過 400 行。新增 core 條目前，先確認它是不是每個 session 都需要；只跟特定檔案有關的，改成 optional 並設 `paths`。

## 7. 淘汰守則

守則過時或被其他守則取代時，不直接刪檔，先標淘汰，下一個 major 版再移除：

```yaml
deprecated: "已併入 database/pitfalls"
replaced_by: database/pitfalls
```

`deprecated` 寫淘汰原因，不可空白；`replaced_by` 選填，必須是另一條存在且未淘汰的守則，而且只能跟 `deprecated` 一起寫。兩個欄位都不要加行內 `#` 註解，會被當成值的一部分。

- `tier: core` 不可直接淘汰：先改成 optional 並在 CHANGELOG 的 Changed 說明，下一版再淘汰。core 一律安裝，直接淘汰會讓所有安裝者同時失去它。
- 淘汰後的行為：`install.sh --list` 第 8 欄標 `deprecated`、第 9 欄是替代守則；`--detect` 不推薦、策略檔 `preset: full` 不安裝；`--select` 明確指定時照裝並警告；`doctor.sh` 對已安裝的淘汰守則扣分並提示替代守則。
- CHANGELOG：標淘汰時寫在 `### Deprecated`，實際刪檔時寫在 `### Removed`，兩者都寫出替代守則。
- `last_reviewed` 超過 1 年時 `doctor.sh` 會提示（`AGREEMENTS_REVIEW_MAX_YEARS` 可調整年數），提醒依本標準重新審查。

## 8. 守則與機器檢查連動

守則有對應的自動檢查時，在 frontmatter 用 `enforced_by` 列出，讓「文字守則」和「自動攔截」改動時不會脫節：

```yaml
enforced_by:
  - audit:empty-catch
  - guard:git-safety
```

`audit:<ID>` 對應 `scripts/audit.sh` 裡的 `# @check audit:<ID> <守則 id>`；`guard:<名稱>` 對應 `scripts/lib/guard-rules.tsv` 第 1 欄。只接受區塊清單寫法（每行 `  - `），項目後面不要加註解。

`scripts/check-schema.sh` 雙向驗證：`enforced_by` 列的 ID 必須存在；`audit.sh` 每個 `@check` 都要被標示的守則列入；`guard-rules.tsv` 的每個名稱都要被同名守則列入。新增、改名或刪除檢查時，守則要一起改。

## 9. 翻譯

中文（`rules/`）是來源，英文版放在 `i18n/en/rules/`，同一個 id 一一對應。翻譯採**逐行對照**：英文第 N 行就是中文第 N 行的翻譯，方便左右比對與審查。

- 結構欄位（`category`、`tier`、`stack`、`paths`、`enforced_by`、`sources`、`last_reviewed`、`replaced_by`）原樣複製；`label`、`summary`、`incidents`、`deprecated` 翻譯。
- 標題層級、空行位置、程式碼區塊邊界與 `<!-- 慣例 -->`／`<!-- 參考 -->` 標註要與中文相同；段落標籤對應 `**症狀：**` → `**Symptom:**`、`**根因：**` → `**Root cause:**`、`**怎麼做：**` → `**How:**`、`**為什麼：**` → `**Why:**`、`**規則：**` → `**Rule:**`。
- Agent 要照著輸出的字串（例如命中守則的標註格式）要翻成英文；示範中文寫法的範例（commit 動詞、台灣用語對照）保留中文。
- 改了中文就要同步改英文，改完執行 `scripts/check-i18n.sh --stamp en <id>`，把 `source_sha256` 更新成目前中文檔的雜湊。CI 的 `scripts/check-i18n.sh` 會擋下雜湊不符、結構不一致或行數不同的翻譯。
