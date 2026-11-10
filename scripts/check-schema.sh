#!/usr/bin/env bash
# check-schema.sh — 驗證 schema/v1.json 與規則庫、策略檔範本一致。
#
# 用法：scripts/check-schema.sh [策略檔...]
#   預設檢查：schema 的 enforce_rules enum 等於 rules/ 底下所有規則 id；templates/agreements.json 符合 schema。
#   另外帶入的策略檔（例如 doctor.sh --init-policy 的產出）也會依 schema 檢查。
#   守則與機器檢查連動：守則 frontmatter 的 enforced_by 列出的 audit:<ID>／guard:<名稱> 必須存在；
#   反過來，audit.sh 每個「# @check audit:<ID> <守則 id>」都要被該守則列入，guard-rules.tsv 每個名稱都要被同名守則列入。
#
# 比 schema 嚴格一點：不允許未定義的欄位（schema 本身 additionalProperties: true），用來抓本 repo 產出的拼字錯誤。
# 只用 python3 標準函式庫，不需要 jsonschema 套件；檢查範圍限於本 schema 用到的型別、enum 與 uniqueItems。
# 結束碼：0 通過；1 不一致；2 缺少 python3。

set -euo pipefail

ROOT="${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
command -v python3 >/dev/null 2>&1 || { echo "✗ check-schema.sh 需要 python3" >&2; exit 2; }

python3 - "$ROOT" "$ROOT/templates/agreements.json" "$@" <<'PY'
import json
import os
import re
import sys

root, *policy_files = sys.argv[1:]
errors = []

with open(os.path.join(root, "schema", "v1.json"), encoding="utf-8") as f:
    schema = json.load(f)
props = schema["properties"]

rules_dir = os.path.join(root, "rules")
rule_ids = sorted(
    os.path.relpath(os.path.join(d, n), rules_dir)[:-3]
    for d, _, names in os.walk(rules_dir) for n in names if n.endswith(".md")
)
enum_ids = props["enforce_rules"]["items"]["enum"]

missing = sorted(set(rule_ids) - set(enum_ids))
extra = sorted(set(enum_ids) - set(rule_ids))
if missing:
    errors.append(f"schema enum 缺少規則：{', '.join(missing)}")
if extra:
    errors.append(f"schema enum 有不存在的規則：{', '.join(extra)}")
if enum_ids != sorted(enum_ids):
    errors.append("schema enum 沒有依字母排序")



def enforced_by(path):
    """讀 frontmatter 的 enforced_by 區塊清單"""
    items, on = [], False
    with open(path, encoding="utf-8") as f:
        lines = f.read().split("\n")
    if not lines or lines[0] != "---":
        return items
    for line in lines[1:]:
        if line == "---":
            break
        if line == "enforced_by:":
            on = True
            continue
        if line.startswith("enforced_by:"):
            errors.append(f"{os.path.relpath(path, root)}：enforced_by 要用區塊清單（每行「  - <ID>」）")
        if on and line.startswith(" ") and line.strip().startswith("- "):
            items.append(line.strip()[2:].strip().strip('"'))
            continue
        on = False
    return items


audit_checks = {}  # audit:<ID> -> 守則 id
with open(os.path.join(root, "scripts", "audit.sh"), encoding="utf-8") as f:
    audit_lines = f.read().split("\n")
for i, line in enumerate(audit_lines):
    # 每個「# N. 檢查名稱」的檢查都要緊接在 @check 標記之後
    if re.match(r"# [0-9]+\. ", line) and (i == 0 or not audit_lines[i - 1].startswith("# @check ")):
        errors.append(f"audit.sh 的檢查「{line[2:]}」前面缺少「# @check audit:<ID> <守則 id>」標記")
for line in audit_lines:
    if line.startswith("# @check "):
        parts = line.split()
        if len(parts) != 4 or not parts[2].startswith("audit:"):
            errors.append(f"audit.sh 的 @check 標記格式應為「# @check audit:<ID> <守則 id>」：{line.strip()}")
            continue
        if parts[2] in audit_checks:
            errors.append(f"audit.sh 的檢查 ID 重複：{parts[2]}")
        audit_checks[parts[2]] = parts[3]
guards = set()
with open(os.path.join(root, "scripts", "lib", "guard-rules.tsv"), encoding="utf-8") as f:
    for line in f:
        if line.strip() and not line.startswith("#"):
            guards.add("guard:" + line.split("\t", 1)[0])

claims = {rid: enforced_by(os.path.join(rules_dir, rid + ".md")) for rid in rule_ids}
for rid, ids in claims.items():
    for cid in ids:
        if cid not in audit_checks and cid not in guards:
            errors.append(f"rules/{rid}.md：enforced_by 的「{cid}」不存在於 audit.sh 或 guard-rules.tsv")
        elif cid in audit_checks and audit_checks[cid] != rid:
            errors.append(f"rules/{rid}.md：「{cid}」在 audit.sh 標示屬於 {audit_checks[cid]}")
        elif cid in guards and cid.split(":", 1)[1] != os.path.basename(rid):
            errors.append(f"rules/{rid}.md：「{cid}」只能由同名守則列入")
for cid, rid in sorted(audit_checks.items()):
    if rid not in claims:
        errors.append(f"audit.sh 的 {cid} 指向不存在的守則 {rid}")
    elif cid not in claims[rid]:
        errors.append(f"rules/{rid}.md：缺少 enforced_by「{cid}」（audit.sh 有對應檢查）")
for cid in sorted(guards):
    if not any(cid in ids for ids in claims.values()):
        errors.append(f"guard-rules.tsv 的 {cid} 沒有守則在 enforced_by 列入")

TYPES = {"string": str, "array": list, "boolean": bool, "object": dict}


def validate(path):
    rel = os.path.relpath(path, root) if path.startswith(root) else path
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, ValueError) as e:
        errors.append(f"{rel}：無法解析 JSON（{e}）")
        return
    if not isinstance(data, dict):
        errors.append(f"{rel}：最外層必須是物件")
        return
    for key, value in data.items():
        spec = props.get(key)
        if spec is None:
            errors.append(f"{rel}：未定義的欄位「{key}」")
            continue
        if not isinstance(value, TYPES[spec["type"]]):
            errors.append(f"{rel}：「{key}」型別應為 {spec['type']}")
            continue
        if "enum" in spec and value not in spec["enum"]:
            errors.append(f"{rel}：「{key}」的值「{value}」不在允許清單內")
        if spec["type"] == "array":
            bad = [v for v in value if v not in spec["items"]["enum"]]
            if bad:
                errors.append(f"{rel}：「{key}」含未知規則：{', '.join(map(str, bad))}")
            if spec.get("uniqueItems") and len(value) != len(set(map(str, value))):
                errors.append(f"{rel}：「{key}」有重複項目")


for p in policy_files:
    validate(p)

if errors:
    for e in errors:
        print(f"✗ {e}", file=sys.stderr)
    sys.exit(1)
print(f"✓ schema 與規則庫一致（{len(rule_ids)} 條規則），策略檔 {len(policy_files)} 個皆合法，"
      f"機器檢查 {len(audit_checks) + len(guards)} 項皆與守則連動")
PY
