#!/usr/bin/env python3
"""report.py — 把 run.sh 產出的 results.jsonl 彙整成 Markdown 報表。

用法：report.py <results.jsonl> [--threshold 0.2]

每行結果：{"rule", "scenario", "condition": "with"|"without", "run", "verdict": "compliant"|"violation"|"inconclusive", "cost_usd"}

判讀（每條守則，不計無法判定的結果）：
  ✅ 有效              無守則違規率 − 有守則違規率 ≥ 門檻
  ⚠️ 無效              差異小於門檻，且無守則時確實會違規：守則需要改寫或刪除
  ➖ 情境沒有誘發錯誤   兩組都沒有違規：情境太簡單，無法判斷守則有沒有用
  （樣本少）          任一組判定次數少於 MIN_SAMPLES，結論僅供參考
"""

import argparse
import json
import sys
from collections import defaultdict
from dataclasses import dataclass
from typing import Dict, Iterable, List, Tuple

DEFAULT_THRESHOLD = 0.2
# 每種條件判定次數少於這個數，判讀加註「樣本少」：一次翻轉就可能跨過門檻
MIN_SAMPLES = 6


@dataclass(frozen=True)
class Tally:
    violations: int
    judged: int
    inconclusive: int

    @property
    def rate(self) -> float:
        return self.violations / self.judged if self.judged else 0.0

    def cell(self) -> str:
        if not self.judged:
            return "—"
        return f"{self.rate:.0%}（{self.violations}/{self.judged}）"


def load(path: str) -> List[dict]:
    rows = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                rows.append(json.loads(line))
    return rows


def tally(rows: Iterable[dict]) -> Tally:
    rows = list(rows)
    violations = sum(1 for r in rows if r["verdict"] == "violation")
    inconclusive = sum(1 for r in rows if r["verdict"] == "inconclusive")
    return Tally(violations, len(rows) - inconclusive, inconclusive)


def verdict(without: Tally, with_: Tally, threshold: float) -> str:
    if not without.judged or not with_.judged:
        return "❔ 資料不足"
    if without.violations == 0 and with_.violations == 0:
        return "➖ 情境沒有誘發錯誤"
    label = "✅ 有效" if without.rate - with_.rate >= threshold else "⚠️ 無效"
    if min(without.judged, with_.judged) < MIN_SAMPLES:
        label += "（樣本少）"
    return label


def group(rows: List[dict], key: str) -> Dict[str, List[dict]]:
    out: Dict[str, List[dict]] = defaultdict(list)
    for r in rows:
        out[r[key]].append(r)
    return dict(sorted(out.items()))


def split(rows: List[dict]) -> Tuple[Tally, Tally]:
    return (tally(r for r in rows if r["condition"] == "without"),
            tally(r for r in rows if r["condition"] == "with"))


def render(rows: List[dict], threshold: float) -> str:
    lines = ["# 守則效果評測報表", ""]
    total_cost = sum(float(r.get("cost_usd") or 0) for r in rows)
    inconclusive = sum(1 for r in rows if r["verdict"] == "inconclusive")
    lines += [f"共 {len(rows)} 次執行，無法判定 {inconclusive} 次，花費 ${total_cost:.2f}。"
              f"判讀門檻：違規率差異 ≥ {threshold:.0%}。", ""]

    lines += ["## 各守則", "", "| 守則 | 無守則違規率 | 有守則違規率 | 判讀 |", "|------|------|------|------|"]
    for rule, rs in group(rows, "rule").items():
        without, with_ = split(rs)
        lines.append(f"| `{rule}` | {without.cell()} | {with_.cell()} | {verdict(without, with_, threshold)} |")

    lines += ["", "## 各情境", "", "| 守則 | 情境 | 無守則 | 有守則 | 無法判定 |", "|------|------|------|------|------|"]
    for key, rs in group([dict(r, key=f"{r['rule']}\t{r['scenario']}") for r in rows], "key").items():
        rule, scenario = key.split("\t")
        without, with_ = split(rs)
        lines.append(f"| `{rule}` | {scenario} | {without.cell()} | {with_.cell()} | "
                     f"{without.inconclusive + with_.inconclusive} |")
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description="彙整守則評測結果")
    parser.add_argument("results")
    parser.add_argument("--threshold", type=float, default=DEFAULT_THRESHOLD)
    args = parser.parse_args()
    rows = load(args.results)
    if not rows:
        print("✗ 沒有任何結果", file=sys.stderr)
        return 1
    sys.stdout.write(render(rows, args.threshold))
    return 0


if __name__ == "__main__":
    sys.exit(main())
