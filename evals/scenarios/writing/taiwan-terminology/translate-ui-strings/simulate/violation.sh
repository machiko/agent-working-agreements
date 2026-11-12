#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

cat > src/i18n/zh-TW.js <<'JS'
export default {
  'settings.title': '通知設定',
  'settings.save': '儲存',
  'user.defaultRole': '新用戶的默認角色',
  'video.uploaded': '視頻上傳成功',
  'video.quality': '視頻質量',
  'message.empty': '暫無信息',
  'help.docs': '查看文檔',
  'user.count': '用戶總數：{count}',
};
JS
fake_final "已補上 6 個 key 的翻譯。"
