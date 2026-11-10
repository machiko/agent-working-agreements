# prepare.sh — 建立情境的工作目錄。由 run.sh 與 tests/eval.test.sh 以 source 載入。

# eval_prepare <情境目錄> <工作目錄> <lib 目錄>：
# 複製 fixture、建立 git repo 並提交初始版本、執行 setup.sh，最後把 HEAD 標記為 eval-base（判定時的比較基準）
eval_prepare() {
  local scenario="$1" work="$2" lib="$3"
  if [ -d "$scenario/fixture" ]; then cp -R "$scenario/fixture/." "$work/"; fi
  (
    cd "$work"
    git init -q -b main
    git config user.email "eval@example.com"
    git config user.name "eval"
    git config commit.gpgsign false
    git add -A
    git commit -q --allow-empty -m "init"
    if [ -f "$scenario/setup.sh" ]; then EVAL_LIB="$lib" bash "$scenario/setup.sh"; fi
    git tag -f eval-base HEAD >/dev/null
  )
}
