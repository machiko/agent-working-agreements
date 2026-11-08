#!/usr/bin/env bash
# check-schema.sh — 驗證 schema/v1.json 與規則庫、策略檔範本一致。
#
# 用法：scripts/check-schema.sh [策略檔...]
#   預設檢查：schema 的 enforce_rules enum 等於 rules/ 底下所有規則 id；templates/agreements.json 符合 schema。
#   另外帶入的策略檔（例如 doctor.sh --init-policy 的產出）也會依 schema 檢查。
#
# 比 schema 嚴格一點：不允許未定義的欄位（schema 本身 additionalProperties: true），用來抓本 repo 產出的拼字錯誤。
# 只用 python3 標準函式庫，不需要 jsonschema 套件；檢查範圍限於本 schema 用到的型別、enum 與 uniqueItems。
# 結束碼：0 通過；1 不一致；2 缺少 python3。

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
command -v python3 >/dev/null 2>&1 || { echo "✗ check-schema.sh 需要 python3" >&2; exit 2; }

python3 - "$ROOT" "$ROOT/templates/agreements.json" "$@" <<'PY'
import json
import os
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
print(f"✓ schema 與規則庫一致（{len(rule_ids)} 條規則），策略檔 {len(policy_files)} 個皆合法")
PY
