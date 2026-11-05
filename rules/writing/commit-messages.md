---
category: writing
tier: optional
label: "Commit 格式"
summary: "commit 訊息用「type: 動詞 敘述」格式，動詞固定用繁中。團隊已有自己的格式就不要選，或裝完再改"
---

# Commit 訊息

> 以下是一套已實際使用的格式（繁中動詞版）。如果你的團隊有自己的規範，直接改這份檔案。agent 只會照這裡寫的做。

## 格式

```
<type>: <動詞> <敘述>

- 細節（選填，第二行要空白）
```

| type | 用途 |
|------|------|
| `feat` | 新功能 |
| `fix` | 修 bug |
| `docs` | 文件 |
| `style` | 格式化，不影響行為 |
| `refactor` | 重構，功能不變 |
| `perf` | 效能 |
| `test` | 測試 |
| `chore` | 依賴、設定、雜項 |
| `ui` | 介面與 UX |

動詞固定用這六個，動詞後空一格：**新增、更新、修復、刪除、重構、優化**。

```
✅ fix: 修復 快取 key 在主鍵非 id 時無法區分使用者
✅ feat: 新增 匯出檔 AES-256 加密
❌ fix: 驗證碼快取 key 問題          ← 少了動詞
❌ feat: 改進                         ← 沒有敘述
❌ chore: update packages             ← 不符合語言規範
```

**為什麼要特別寫「不能漏動詞」：** 規範本身寫得很清楚，失誤發生在執行時沒有逐字對照。agent 最常漏的就是動詞。

## 資安修補用中性措辭

資安修補的分支名、commit 訊息、changelog 條目、任務卡名，不用「個資外洩」「leak」「漏洞」這類字眼，改寫成中性的描述，例如「收斂頁面輸出的資料欄位」「加密明文欄位」。

**為什麼：** 這些文字會留存下來，交給 PM、客戶或稽核單位看。merge commit 也會保留分支名。用語太重會被讀成事故通報。

**怎麼做：** 對話裡分析問題時照實描述沒關係。要寫進會留存或交付的文字時，再換成中性詞。

## 檢查清單

- [ ] 第一行符合 `<type>: <動詞> <敘述>`
- [ ] 目前分支和 type 相符（見 [`../collaboration/git-safety.md`](../collaboration/git-safety.md)）
- [ ] AI attribution trailer（`Co-Authored-By` 等）是否附加依團隊政策決定。如果禁止，在你的 CLAUDE.md 明寫，否則 agent 會依自己的預設附上
- [ ] 不 force push 到 main／develop
