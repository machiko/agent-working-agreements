---
name: harvest
description: 維護者用：把 Claude Code 私人 memory 裡新累積的教訓，去識別化後整理成規則。必須在 agent-working-agreements 的 clone 或 fork 裡執行。
disable-model-invocation: true
---

# 從私人 memory 整理規則（harvest）

目標：一條教訓從 memory 進到 `rules/`，使用者花的時間不超過 5 分鐘。所有寫入都要使用者確認；不 commit、不 push，除非使用者另外要求。

## 0. 前置檢查

**先確認在 repo 的工作副本裡**，不符合任何一項就停下來，不做後續步驟：

```bash
root="$(git rev-parse --show-toplevel 2>/dev/null)" \
  && [ -d "$root/rules" ] \
  && grep -q '"name": *"agreements"' "$root/.claude-plugin/plugin.json" \
  && case "$root" in */plugins/cache/*|*/plugins/marketplaces/*) false ;; esac \
  && echo "OK: $root"
```

- 沒有印出 `OK`：告訴使用者這個指令要在 agent-working-agreements 的 clone 或 fork 裡執行（`git clone` 自己的 fork 後，在該目錄開 Claude Code），然後結束。**不要寫入 plugin 的安裝目錄**，那裡的檔案會在 plugin 更新時被覆蓋。
- 印出 `OK`：之後的指令都在 `$root` 執行，使用工作副本裡的 `scripts/`，不要用 plugin 安裝目錄裡的版本。

其他前置條件：

- 私人禁用詞清單 `~/.claude/agreements-harvest/denylist.txt` 必須存在（可用 `AGREEMENTS_DENYLIST` 改路徑）。不存在時，先請使用者列出專案名、組織、同事、主機、只在原專案出現的產品用語與類別名稱，寫進這份清單。**這份清單絕不可放進 repo。**
- 目前分支與工作區要乾淨：`git status --short`。

## 1. 盤點

執行 `scripts/harvest-scan.sh`（第一次或要全部重看時加 `--all`）。輸出以 tab 分隔：修改日期、type、name、檔案路徑、description。

## 2. 分類

讀每個候選 memory 檔，再讀現有規則（`scripts/install.sh --list` 與相關規則全文），把每條分成三類：

| 分類 | 條件 |
|------|------|
| 新增規則 | 跨專案適用、有事故或明確理由、現有規則沒有涵蓋 |
| 補強既有規則 | 現有規則已有這個主題，但這條提供新的事故、新的做法或反例。寫明要補哪個檔案的哪一段 |
| 略過 | 只適用原專案（特定類別、流程、部署）、只是進度狀態、或是通用常識（違反 `writing/lean-instructions`） |

用一張表列給使用者看：編號、memory name、分類、要寫進哪個檔案、一句理由。請使用者回覆要處理的編號。略過的項目也列出來，讓使用者可以推翻。

## 3. 草擬

對使用者選定的每一條：

- 照「規則 → **為什麼** → **怎麼做**」寫，繁體中文，風格比照同目錄的規則。
- **去識別化**：
  - 拿掉專案名、組織、人名、主機、內部類別名、只在原專案出現的產品用語。
  - 事故改寫成通用情境，不直接引用使用者原話，不留可以反推的細節數字（檔案數、筆數、分支數）。
  - 角色層級、資料欄位等原專案結構，換成通用說法。
- 新檔案要有 frontmatter：`category`（等於目錄名）、`tier`。`optional` 必須有 `label` 與 `summary`（做什麼、什麼情況才選）。只跟特定檔案有關的加 `paths`。改寫自外部資料的加 `sources`，而且只能改寫 MIT／Apache-2.0／CC0／CC BY 授權的文字。
- 預設 `tier: optional`。只有「任何專案、任何人都該遵守」的才提議 `core`，並說明理由。

## 4. 檢查

依序執行，全部通過才進下一步：

```bash
scripts/sanitize-check.sh     # 識別資訊（含私人禁用詞）
scripts/check-budget.sh       # frontmatter 與 core 400 行上限
bash tests/install.test.sh    # 安裝器沒有被新檔案弄壞
```

core 超出預算時，不要硬塞：提議改成 optional、合併到既有規則，或精簡現有內容，讓使用者選。

## 5. 確認與收尾

1. 用 `git diff` 與新檔清單給使用者看完整的改動。
2. 使用者確認後，執行 `scripts/harvest-scan.sh --mark`，記錄這次 harvest 的時間。
3. 回報：新增幾條、補強幾條、略過幾條，以及 core／optional 行數。
