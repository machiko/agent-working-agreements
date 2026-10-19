---
category: collaboration
tier: core
---

# Git 安全：分支、暫存區、並行 session

## commit 前重新確認目前分支

每次 `git commit` 前都先跑 `git branch --show-current`（或 `git status -sb`），不要沿用 session 開頭或上一次 commit 時看到的分支。

**為什麼：** 使用者常在另一個終端切分支並 commit。agent 沿用舊資訊，就把 `feat:` commit 落在別人的 `fix/` 分支上了。

**怎麼做：**

- 分支名稱要和 commit 類型相符（`feat` 對 `feature/`、`fix` 對 `fix/`、`chore` 對 `chore/`）。不符就先 `git switch -c` 開新分支。
- 功能或重構類的 commit 不要直接落在 release／main，要開對應名稱的分支走 PR。只有該版本自己的事（例如補 CHANGELOG）可以直接 commit。
- 工作中如果 reflog 或 status 顯示分支被切換過，先停下來重新對齊。
- 落錯分支時，用 cherry-pick 搬到正確的分支，原分支用 `branch -f` 退回。不要 rebase 已經 push 的分支。

## 開分支時明寫基底

開 fix／feature 分支前，先問「這個修正要進哪條 release」，然後用 `git switch -c fix/x <目標分支>` 明確寫出基底，不要從目前的 HEAD 直接切。

**為什麼：** 有一次從當時所在的開發線切出 fix 分支，再 fast-forward 進舊版 release，結果那個 release 夾帶了另一條線獨有的功能，牽連數十個檔案，只能重設、cherry-pick，再 force-with-lease 推回。

**怎麼做：** release 線之間有「只存在某一條線」的功能時，先跑 `git diff --stat A B` 確認差異，再決定基底。

## 只 add 明確的路徑

不用 `git add -A` 或 `git add .`。commit 前逐檔看 staged 清單：`git status --short | grep -E '^[MDA] '`。

**為什麼：** squash（`reset --soft` 後重新 commit）、amend 之後，整個工作區都會在暫存區裡，這是 untracked 的資料檔最容易被一起帶進去的時候。實際發生過：含個人資料的 CSV 被一併掃進 commit。

**怎麼做：** 遇到 `.csv`、`.xlsx`、`.sql`、`.json`、`.env*`，或路徑在 `storage/`、`data/` 底下，一律停下來問使用者。個資相關規則見 [`../security/data-files.md`](../security/data-files.md)。

## 並行的 agent session 各用各的 worktree

多個自主 session（排程、loop、背景 agent）不要共用同一個 git worktree。

**為什麼：** HEAD 是 worktree 層級的單一狀態，不是每個 process 各自一份。實際發生過：session A 開 docs 分支 commit 之後，並行的 session B 把 lint 修正也 commit 上去，落到了 A 的分支。接著 B checkout 回 main，把工作區還原成舊檔，A 還以為自己的編輯被還原了。

**怎麼做：**

- 並行工作用 `git worktree add` 或 agent 的 worktree 隔離，一個分支對一個 worktree。
- 無法隔離時，開工前先跑 `git status` 和 `git branch --show-current`；commit 後立刻用 `git log --oneline <branch>` 確認 commit 落在自己的分支。

## 不可逆的操作先確認

`push --force`、`reset --hard`、刪分支、改寫已 push 的歷史，都要先取得使用者同意。同意只對當下那一件事有效，不會延伸到下一次。
