# 團隊導入指南

**繁體中文** | [English](team.en.md)

讓整個團隊的 AI Agent 遵守同一套守則：一份策略檔 `.agreements.json` 決定裝哪些守則、裝到哪些 Agent、用哪個版本；團隊自己的規範放在 `.agreements/rules/`。兩者都放進 repo，改動一律走 PR，CI 擋下沒同步的變更。

## 三步

| 誰 | 做什麼 | 指令 |
|----|--------|------|
| 負責人 | 導入一次，開 PR | `install.sh --team-init`（Claude Code：`/agreements:setup team`） |
| 成員 | clone 或 pull 之後同步 | `install.sh --sync`（Claude Code：`/agreements:setup sync`） |
| 任何人 | 改規範 | 改 `.agreements/rules/` 或 `.agreements.json` → `--sync` → 開 PR |

不想 clone 本專案的話，`install.sh` 換成遠端指令：

```bash
curl -fsSL https://raw.githubusercontent.com/machiko/agent-working-agreements/main/scripts/remote-install.sh | bash -s -- --sync
```

遠端執行 `--sync` 會讀策略檔的 `agreements_version`，下載團隊鎖定的那一版，不會因為每個人下載的時間不同而裝到不同版本。

## 1. 負責人：導入

在專案根目錄執行：

```bash
scripts/install.sh --team-init --targets claude,cursor,agents-md
```

- `--targets`：團隊用的 Agent。可用 `claude`、`cursor`、`agents-md`、`copilot`、`windsurf`。不給時依專案現有設定偵測（有 `.cursor/` 就加 cursor，以此類推），都沒有就用 `claude,agents-md`。
- `--preset`：`smart`（預設，依技術棧推薦）、`full`、`core`。
- `--lang en`：裝英文版守則。
- `--no-ci`：不安裝 CI 工作流。
- `--dry-run`：只列出會做的事。

它會依序：

1. 產生 `.agreements.json`，鎖定目前版本，強制 `security/dangerous-operations` 與 `collaboration/git-safety`
2. 建立 `.agreements/rules/README.md`（團隊守則的格式說明）
3. 執行 `--sync`：安裝每個目標，並安裝 Git pre-commit 與 pre-push
4. 安裝 CI 守門（`agent-audit.yml`）與防漂移檢查（`agent-agreements-drift.yml`）
5. 列出要 commit 的檔案，以及要轉告成員的指令

檢查後 commit、開 PR。

### 產生的策略檔

```json
{
  "preset": "smart",
  "enforce_rules": ["security/dangerous-operations", "collaboration/git-safety"],
  "targets": ["claude", "cursor", "agents-md"],
  "agreements_version": "1.6.0",
  "git_hooks": true,
  "lang": "zh-TW"
}
```

| 欄位 | 作用 |
|------|------|
| `targets` | `--sync` 裝好或更新每一個；`--check-drift` 逐一檢查 |
| `agreements_version` | 跟這個版本不同時 `--sync` 會停下，不悄悄升級或降級 |
| `git_hooks` | `true` 時 `--sync` 會安裝 Git hooks（hooks 不進版控，所以每個成員都要同步一次） |
| `enforce_rules` | 一定要裝的守則；團隊守則寫 `custom/<name>` |

完整欄位見 [`schema/v1.json`](../schema/v1.json)。

## 2. 成員：同步

```bash
scripts/install.sh --sync
```

- 第一次會安裝每個目標與 Git hooks。
- 之後每次 pull 到策略檔或團隊守則的變更，再執行一次。沒有變更時只會顯示「已同步，沒有變更」。
- 團隊守則有格式問題時會列出 ⚠，只提示、不擋同步。
- 每次都依策略檔重新決定要裝哪些守則：策略檔改了 `preset` 或 `enforce_rules`，同步後就生效；個人用 `--select` 加裝的守則會被移除。
- `git_hooks` 為 `true` 而專案沒有 `scripts/audit.sh` 時，會複製一份進來給 pre-commit 稽核用，要一起 commit。

## 3. 新增團隊守則

1. 在 `.agreements/rules/` 新增 `<name>.md`，檔名只用小寫英數與連字號，格式見目錄裡的 `README.md`。用 Claude Code 的話，`/agreements:record` 會訪談並寫到這裡。
2. 執行 `--sync`。守則會以 `custom/<name>` 裝到每個目標。
3. 守則檔與同步產生的變更一起 commit，開 PR。

要讓某條守則不能被拿掉，把 `custom/<name>` 加進 `enforce_rules`。

以前 `/agreements:record` 寫在 `.claude/rules/agent-agreements/custom/` 的守則只有自己的 Claude Code 讀得到。搬到 `.agreements/rules/` 後執行 `--sync`，就能跟團隊共用，也會套用到其他 Agent；`doctor.sh` 會提示還有幾條沒搬。

## 4. 升級版本

1. 用新版工具，把 `.agreements.json` 的 `agreements_version` 改成新版本號。
2. 執行 `--sync`，守則會升到新版。
3. 一起 commit、開 PR。成員 pull 後執行 `--sync`。

## 被 CI 擋下時

防漂移檢查（`doctor.sh --check-drift`）在這些情況會失敗：

| 訊息 | 原因 | 處理 |
|------|------|------|
| 缺少團隊守則 | 新增了 `.agreements/rules/` 的守則但沒同步 | 執行 `--sync`，commit 變更 |
| 團隊守則與 .agreements/rules 不一致 | 改了守則但沒同步，或手動改了安裝出來的檔案 | 執行 `--sync`；手動改過的檔案要加 `--force` 才會覆蓋 |
| 已從 .agreements/rules 移除但仍安裝著 | 刪了守則但沒同步 | 執行 `--sync` |
| 安裝版本應為 X | 策略檔改了版本但守則沒重裝 | 用該版本執行 `--sync` |
| 強制守則尚未安裝／狀態異常 | `enforce_rules` 的守則沒裝或被改 | 執行 `--sync` |
| 尚未安裝守則 | `targets` 裡的目標沒安裝 | 執行 `--sync` |

GitLab、Bitbucket 等平台不會自動加防漂移工作流，在 CI 加這一步：

```bash
curl -fsSL https://raw.githubusercontent.com/machiko/agent-working-agreements/main/scripts/remote-install.sh | bash -s -- --check-drift .
```
