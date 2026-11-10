#!/usr/bin/env bash
# check-i18n.sh — 檢查守則翻譯（i18n/<語言>/rules/）與中文來源（rules/）同步。
#
# 用法：
#   scripts/check-i18n.sh                      檢查所有語言
#   scripts/check-i18n.sh --stamp <語言> <id>…  翻譯更新完後，把 source_sha256 寫成目前中文檔的雜湊
#   ROOT=<目錄>                                 改檢查其他目錄（測試用）
#
# 檢查項目（翻譯採逐行對照，第 N 行就是中文第 N 行的翻譯）：
#   1. 每條中文守則都有翻譯，翻譯沒有對不到中文的多餘檔案
#   2. frontmatter 的 source_sha256 等於目前中文檔的 sha256：中文改了、翻譯沒跟上就失敗
#   3. 結構欄位（category、tier、stack、paths、enforced_by、sources、last_reviewed、replaced_by）與中文相同；
#      deprecated 有無一致；incidents 項數相同
#   4. 本文行數相同，且逐行比對：空行、標題層級、程式碼區塊邊界、<!-- 慣例 -->／<!-- 參考 --> 標註、
#      段落標籤（**症狀：** → **Symptom:** 等）位置一致
#
# 結束碼：0 通過；1 不同步；2 參數錯誤或缺少 python3。

set -euo pipefail

ROOT="${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
command -v python3 >/dev/null 2>&1 || { echo "✗ check-i18n.sh 需要 python3" >&2; exit 2; }

python3 - "$ROOT" "$@" <<'PY'
import hashlib
import os
import re
import sys

root, *args = sys.argv[1:]
rules_dir = os.path.join(root, "rules")
i18n_dir = os.path.join(root, "i18n")

LABELS = {"症狀": "Symptom", "根因": "Root cause", "怎麼做": "How", "為什麼": "Why", "規則": "Rule"}
SAME_KEYS = ("category", "tier", "stack", "paths", "enforced_by", "sources", "last_reviewed", "replaced_by")
MARKERS = ("<!-- 慣例 -->", "<!-- 參考 -->")


def sha256(path):
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def rule_ids(base):
    if not os.path.isdir(base):
        return []
    return sorted(
        os.path.relpath(os.path.join(d, n), base)[:-3]
        for d, _, names in os.walk(base) for n in names if n.endswith(".md")
    )


def split(path):
    """回傳 (frontmatter 字典, 本文行列表)；清單欄位存成 list"""
    with open(path, encoding="utf-8") as f:
        lines = f.read().split("\n")
    fm, key = {}, None
    if not lines or lines[0] != "---":
        return fm, lines
    for i, line in enumerate(lines[1:], start=1):
        if line == "---":
            return fm, lines[i + 1:]
        m = re.match(r"^([A-Za-z0-9_]+):[ ]*(.*)$", line)
        if m:
            key, value = m.group(1), m.group(2)
            fm[key] = value if value else []
        elif key and isinstance(fm.get(key), list) and line.strip().startswith("- "):
            fm[key].append(line.strip()[2:].strip())
    return fm, []


def stamp(lang, ids):
    if not re.fullmatch(r"[A-Za-z-]+", lang):
        print(f"✗ 不合法的語言代碼：{lang}", file=sys.stderr)
        sys.exit(2)
    for rid in ids:
        if not re.fullmatch(r"[a-z0-9-]+/[a-z0-9-]+", rid):
            print(f"✗ 不合法的守則 id：{rid}", file=sys.stderr)
            sys.exit(2)
        src = os.path.join(rules_dir, rid + ".md")
        dst = os.path.join(i18n_dir, lang, "rules", rid + ".md")
        if not (os.path.isfile(src) and os.path.isfile(dst)):
            print(f"✗ 找不到 {rid} 的中文檔或 {lang} 翻譯", file=sys.stderr)
            sys.exit(1)
        with open(dst, encoding="utf-8") as f:
            text = f.read()
        line = f"source_sha256: {sha256(src)}"
        if re.search(r"(?m)^source_sha256:.*$", text):
            text = re.sub(r"(?m)^source_sha256:.*$", line, text, count=1)
        else:
            text = text.replace("---\n", "---\n" + line + "\n", 1)
        with open(dst, "w", encoding="utf-8") as f:
            f.write(text)
        print(f"✓ {lang}/{rid}：source_sha256 已更新")


def check_body(rel, zh, tr, errors):
    if len(zh) != len(tr):
        errors.append(f"{rel}：本文 {len(tr)} 行，中文 {len(zh)} 行；翻譯要逐行對照")
        return
    fence = False
    for n, (a, b) in enumerate(zip(zh, tr), start=1):
        where = f"{rel}：本文第 {n} 行"
        if (a.strip() == "") != (b.strip() == ""):
            errors.append(f"{where} 空行位置與中文不同")
            continue
        if a.lstrip().startswith("```"):
            fence = not fence
            if a != b:
                errors.append(f"{where} 程式碼區塊邊界要與中文相同（{a.strip()}）")
            continue
        if fence:
            continue
        ha, hb = re.match(r"^(#+) ", a), re.match(r"^(#+) ", b)
        if (ha and ha.group(1)) != (hb and hb.group(1)):
            errors.append(f"{where} 標題層級與中文不同")
        for m in MARKERS:
            if (m in a) != (m in b):
                errors.append(f"{where} 標註 {m} 要原樣保留")
        for zh_label, en_label in LABELS.items():
            if ("**" + zh_label + "：") in a and ("**" + en_label + ":") not in b:
                errors.append(f"{where} 中文有「**{zh_label}：**」，翻譯要用「**{en_label}:**」")


def check(lang, errors):
    base = os.path.join(i18n_dir, lang, "rules")
    if not os.path.isdir(base):
        errors.append(f"{lang}：缺少 i18n/{lang}/rules/ 目錄")
        return 0
    zh_ids, tr_ids = rule_ids(rules_dir), rule_ids(base)
    for rid in sorted(set(zh_ids) - set(tr_ids)):
        errors.append(f"{lang}：缺少 {rid} 的翻譯")
    for rid in sorted(set(tr_ids) - set(zh_ids)):
        errors.append(f"{lang}：{rid} 沒有對應的中文守則")
    for rid in sorted(set(zh_ids) & set(tr_ids)):
        src = os.path.join(rules_dir, rid + ".md")
        rel = os.path.relpath(os.path.join(base, rid + ".md"), root)
        zfm, zbody = split(src)
        tfm, tbody = split(os.path.join(base, rid + ".md"))
        if tfm.get("source_sha256") != sha256(src):
            errors.append(f"{rel}：中文檔已變更（source_sha256 不符），更新翻譯後執行 scripts/check-i18n.sh --stamp {lang} {rid}")
        for key in SAME_KEYS:
            if zfm.get(key) != tfm.get(key):
                errors.append(f"{rel}：「{key}」要與中文相同")
        if ("deprecated" in zfm) != ("deprecated" in tfm):
            errors.append(f"{rel}：deprecated 有無要與中文一致")
        if len(zfm.get("incidents") or []) != len(tfm.get("incidents") or []):
            errors.append(f"{rel}：incidents 項數要與中文相同")
        for key in ("label", "summary"):
            if (key in zfm) != (key in tfm):
                errors.append(f"{rel}：「{key}」有無要與中文一致")
        check_body(rel, zbody, tbody, errors)
    return len(tr_ids)


if args[:1] == ["--stamp"]:
    if len(args) < 3:
        print("用法：check-i18n.sh --stamp <語言> <id>…", file=sys.stderr)
        sys.exit(2)
    stamp(args[1], args[2:])
    sys.exit(0)
if args:
    print(f"未知參數：{' '.join(args)}", file=sys.stderr)
    sys.exit(2)

errors, summary = [], []
langs = sorted(d for d in os.listdir(i18n_dir) if os.path.isdir(os.path.join(i18n_dir, d))) if os.path.isdir(i18n_dir) else []
for lang in langs:
    summary.append(f"{lang} {check(lang, errors)} 條")
if errors:
    for e in errors:
        print(f"✗ {e}", file=sys.stderr)
    print(f"✗ {len(errors)} 個翻譯同步問題", file=sys.stderr)
    sys.exit(1)
print(f"✓ 翻譯與中文守則同步（{'、'.join(summary) or '沒有翻譯'}）")
PY
