#!/usr/bin/env bash
# install-ci.sh — install.sh --ci：安裝 CI/CD 守門工作流（github、gitlab、bitbucket、pre-commit）。
#
# 工作流內容一律取自 templates/workflows/ 與 templates/ci/，這裡不另存一份。
# 依賴呼叫端的 ROOT、dry_run 與 die。這支只定義函式，用 source 載入。

# ci_detect_platform <目錄>：依既有設定檔猜平台，都沒有就用 github
ci_detect_platform() {
  if [ -f "$1/.gitlab-ci.yml" ]; then
    echo "gitlab"
  elif [ -f "$1/bitbucket-pipelines.yml" ]; then
    echo "bitbucket"
  elif [ -f "$1/.pre-commit-config.yaml" ]; then
    echo "pre-commit"
  else
    echo "github"
  fi
}

# ci_dry_run <說明> <工作流檔> <scripts 目錄>：列出會新增的檔案後結束
ci_dry_run() {
  echo "＋ $1 $2"
  [ ! -f "$3/audit.sh" ] && echo "＋ 新增 $3/audit.sh"
  exit 0
}

# ci_copy_audit <scripts 目錄>：目標還沒有 audit.sh 時複製一份
ci_copy_audit() {
  if [ ! -f "$1/audit.sh" ] && [ -f "$ROOT/scripts/audit.sh" ]; then
    cp "$ROOT/scripts/audit.sh" "$1/audit.sh"
    chmod +x "$1/audit.sh"
  fi
}

# ci_merge_template <工作流檔> <已安裝標記> <範本>：沒有檔案就複製範本；有檔案但沒有標記就空一行後附加
ci_merge_template() {
  if [ -f "$1" ] && ! grep -q "$2" "$1"; then
    printf '\n' >> "$1"
    cat "$3" >> "$1"
  elif [ ! -f "$1" ]; then
    cp "$3" "$1"
  fi
}

# install_ci <目錄> <平台，空字串代表自動偵測>：安裝後以結束碼 0 結束；平台不支援時 die
install_ci() {
  local dir="$1" platform="$2" scripts_dir wf_dir wf_file
  case "$dir" in "~"/*) dir="$HOME/${dir#\~/}" ;; esac
  [ -d "$dir" ] || die "目錄不存在：$dir"
  scripts_dir="$dir/scripts"
  [ -z "$platform" ] && platform="$(ci_detect_platform "$dir")"

  case "$platform" in
    github)
      wf_dir="$dir/.github/workflows"
      wf_file="$wf_dir/agent-audit.yml"
      [ "$dry_run" -eq 1 ] && ci_dry_run "新增" "$wf_file" "$scripts_dir"
      mkdir -p "$wf_dir" "$scripts_dir"
      # 用 cat 而不是 cp：範本唯讀（例如唯讀的 plugin 快取）時 cp 會連權限一起複製
      cat "$ROOT/templates/workflows/agent-audit.yml" > "$wf_file"
      ci_copy_audit "$scripts_dir"
      echo "✓ 已成功安裝 GitHub Actions CI 守門工作流：$wf_file"
      echo "  提示：若專案託管於 GitHub，發 PR 與 Push 將自動觸發；若為 GitLab/Bitbucket 或本地開發，可改用 scripts/audit.sh --install-hook"
      ;;
    gitlab)
      wf_file="$dir/.gitlab-ci.yml"
      [ "$dry_run" -eq 1 ] && ci_dry_run "新增/配置" "$wf_file" "$scripts_dir"
      mkdir -p "$scripts_dir"
      ci_merge_template "$wf_file" "agent-audit" "$ROOT/templates/ci/gitlab-ci.yml"
      ci_copy_audit "$scripts_dir"
      echo "✓ 已成功安裝 GitLab CI 守門工作流：$wf_file"
      ;;
    bitbucket)
      wf_file="$dir/bitbucket-pipelines.yml"
      [ "$dry_run" -eq 1 ] && ci_dry_run "新增/配置" "$wf_file" "$scripts_dir"
      mkdir -p "$scripts_dir"
      ci_merge_template "$wf_file" "Agent Agreements Guardrail Audit" "$ROOT/templates/ci/bitbucket-pipelines.yml"
      ci_copy_audit "$scripts_dir"
      echo "✓ 已成功安裝 Bitbucket Pipelines 守門工作流：$wf_file"
      ;;
    pre-commit)
      wf_file="$dir/.pre-commit-config.yaml"
      [ "$dry_run" -eq 1 ] && ci_dry_run "新增/配置" "$wf_file" "$scripts_dir"
      mkdir -p "$scripts_dir"
      ci_merge_template "$wf_file" "agent-agreements-audit" "$ROOT/templates/ci/pre-commit-config.yaml"
      ci_copy_audit "$scripts_dir"
      echo "✓ 已成功安裝 pre-commit 守門配置：$wf_file"
      ;;
    *)
      die "不支援的 CI 平台：$platform（支援 github、gitlab、bitbucket、pre-commit）"
      ;;
  esac
  exit 0
}
