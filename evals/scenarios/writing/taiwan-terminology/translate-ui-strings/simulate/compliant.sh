#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

cat > src/i18n/zh-TW.js <<'JS'
export default {
  'settings.title': '通知設定',
  'settings.save': '儲存',
  'user.defaultRole': '新使用者的預設角色',
  'video.uploaded': '影片上傳成功',
  'video.quality': '影片畫質',
  'message.empty': '目前沒有訊息',
  'help.docs': '查看說明文件',
  'user.count': '使用者總數：{count}',
};
JS
fake_final "已補上 6 個 key 的翻譯。"
