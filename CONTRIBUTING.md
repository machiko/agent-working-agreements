# 參與貢獻

**繁體中文** | [English](CONTRIBUTING.en.md)

本專案的守則都來自真實事故：Agent 實際犯過的錯、團隊實際踩過的坑。最有價值的貢獻是**一次真實事故**，其次才是把它寫成守則的 PR。

不熟中文也歡迎用英文開 issue 或 PR，維護者會協助翻譯。

## 從事故到守則

```text
事故 ──▶ ① 回報 issue ──▶ ② 分類判斷 ──▶ ③ 寫守則 ──▶ ④ 英文版 ──▶ ⑤ 評測情境 ──▶ ⑥ 跑檢查 ──▶ ⑦ 開 PR
```

### ① 回報事故

二選一：

- **在 GitHub 填表**：[踩坑事故回報](https://github.com/machiko/agent-working-agreements/issues/new?template=incident_report.yml)，寫出症狀、根因、怎麼做。
- **用 Claude Code**：在自己的專案執行 `/agreements:record` 記錄事故，最後選「整理草稿給我看」。它會產生 issue 草稿並做去識別化掃描，你確認內容後才會送出。

送出前務必去識別化：專案名、公司或客戶名、人名、私有 IP、內部網域、帳密與 Token 都要拿掉。只寫真的發生過的事，**不要為了湊守則編造事故**。

### ② 分類判斷（維護者）

標 `triage` 的 issue 由維護者判斷，結果會回覆在 issue 裡：

| 判斷 | 條件 |
|------|------|
| 併入既有守則 | 已有守則講同一件事，只是缺這個情境。先用 `scripts/install.sh --list` 與 `grep -r` 找相近的條目 |
| 新條目 | 現有守則檔的範圍涵蓋得到，但沒有這個坑 |
| 新守則檔 | 新的技術領域，或現有分類都放不下 |
| 不收 | 只在單一專案成立、Agent 本來就不會犯、或沒辦法寫成可驗證的動作 |

要不要放進 core（每次都載入）要特別嚴格：只有跟檔案類型無關、每個 session 都可能踩到的才放 core，其他一律 optional，並用 `paths` 設定按需載入。core 本文總共不超過 400 行。

### ③ 寫守則

守則放在 `rules/<category>/<name>.md`，中文是來源。完整標準見 [守則品質標準](docs/rule-quality.md)，最少要做到：

```markdown
---
category: database                 # 等於所在目錄
tier: optional                     # core 或 optional
label: "資料庫與 ORM 地雷"          # optional 必填：安裝選單上的名稱
summary: "什麼情況才選這條"          # optional 必填
paths:                             # 選填：只在碰到這些檔案時載入
  - "**/migrations/**"
incidents:                         # 至少一項，去識別化的一句話或 issue 編號
  - "#123"
last_reviewed: 2026-11-10          # 今天
---

# 資料庫與 ORM 地雷

## 共用資料庫被重置

- **症狀：** 看得到的壞結果，越具體越好。
- **根因：** 為什麼會發生，說明機制，不是道德勸說。
- **怎麼做：** 可以驗證的具體動作：指令、設定值、檢查方式。
```

- 協作類守則改用「規則 → **為什麼：** → **怎麼做：**」。
- 不用「盡量」「適當」「視情況」這類空泛用語。
- 單一條目本文不超過 40 行。
- 新增守則檔還要把 id 加進 `schema/v1.json` 的 `enforce_rules` enum（依字母排序）。
- 守則有對應的 `scripts/audit.sh` 檢查或執行期攔截規則時，在 frontmatter 加 `enforced_by`（見品質標準第 8 節）。

### ④ 英文版

在 `i18n/en/rules/<category>/<name>.md` 寫逐行對照的英文版：英文第 N 行就是中文第 N 行的翻譯，標題層級、空行與程式碼區塊位置都相同。規則見品質標準第 9 節。寫完執行：

```bash
scripts/check-i18n.sh --stamp en <category>/<name>
```

不熟英文的話跳過這步，在 PR 說明註明，維護者會補上。這時 CI 的 `scripts/check-i18n.sh` 會因為缺英文版而失敗，這是預期的，不影響審查。

### ⑤ 評測情境

證明「裝了這條守則，Agent 比較不會犯錯」。在 `evals/scenarios/<category>/<name>/<情境名稱>/` 建立：

- `prompt.md`：一般的開發請求，會誘發這個錯誤，不要提示守則。
- `fixture/`：任務需要的檔案。
- `check.sh`：確定性判定，exit 0 合規、1 違規、2 無法判定。
- `simulate/compliant.sh`、`simulate/violation.sh`：模擬合規與違規的行為，給離線測試用。

格式細節見 [`evals/README.md`](evals/README.md)。只要離線測試通過即可，**不需要實際呼叫模型**（那會消耗額度，由維護者在發版前視情況執行）：

```bash
bash tests/eval.test.sh
```

### ⑥ 跑檢查

需要 bash、git、python3，macOS 或 Linux。CI 會在 ubuntu 與 macOS 各跑一次，awk、sed 只用兩邊都支援的寫法。

```bash
scripts/check-budget.sh     # frontmatter 必填欄位、core 400 行預算
scripts/lint-rules.sh       # 條目結構、空泛用語、標題重複、條目長度
scripts/check-schema.sh     # schema enum、enforced_by 連動
scripts/check-i18n.sh       # 英文版同步
scripts/sanitize-check.sh   # 識別資訊
bash tests/install.test.sh  # 安裝器沒有被新檔案弄壞
bash tests/eval.test.sh     # 評測情境的離線判定
```

改到腳本的話，跑 `tests/` 底下對應的測試（例如改 `scripts/incident-draft.sh` 或 `sanitize-check.sh` 就跑 `bash tests/incident-draft.test.sh`）；全部測試的清單在 [README](README.md#-參與貢獻與品質驗證)。

### ⑦ 開 PR

- 從 `main` 開分支：新守則用 `feature/<名稱>`，修正用 `fix/<名稱>`。
- commit 訊息格式是 `<type>: <動詞> <敘述>`，動詞用「新增、更新、修復、刪除、重構、優化」之一，例如 `feat: 新增 資料庫重置前確認環境的守則`。
- PR 範本會帶出檢查清單，照著勾選；說明最後寫 `Refs #<issue 編號>`。
- 維護者審查時會看根因是否說明了機制、「怎麼做」是否真的可行，這兩點機器檢查不出來。

## 其他貢獻

- **修正既有守則**：改完一樣要更新 `last_reviewed` 與英文版。行為有改變的話，補或改評測情境。
- **淘汰守則**：不要直接刪檔，先標 `deprecated` 與 `replaced_by`，見品質標準第 7 節。
- **腳本與安裝器**：先寫測試（`tests/*.test.sh`），再改實作。
- **錯誤回報與功能建議**：直接開一般 issue。

## 授權

提交的內容以本專案的 [MIT License](LICENSE) 釋出。
