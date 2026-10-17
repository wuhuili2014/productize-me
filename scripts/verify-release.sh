#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target_ref="${1:-WORKTREE}"
verify_root="$repo_root"
temp_dir=""

cleanup() {
  if [[ -n "$temp_dir" && -d "$temp_dir" ]]; then
    rm -rf "$temp_dir"
  fi
}
trap cleanup EXIT

if [[ "$target_ref" != "WORKTREE" ]]; then
  temp_dir="$(mktemp -d)"
  git -C "$repo_root" archive "$target_ref" | tar -x -C "$temp_dir"
  verify_root="$temp_dir"
fi

python3 - "$verify_root" <<'PY'
from html.parser import HTMLParser
from pathlib import Path
import sys

root = Path(sys.argv[1])

required_files = [
    "SKILL.md",
    "agents/openai.yaml",
    "assets/report-example.html",
    "references/html-report.md",
    "references/boundaries-and-handoff.md",
    "tests/regression-checklist.md",
    "tests/test-cases.md",
]

for relative in required_files:
    if not (root / relative).is_file():
        raise SystemExit(f"校验失败：缺少 {relative}")

skill = (root / "SKILL.md").read_text(encoding="utf-8")
if not skill.startswith("---\n") or "name: liz-experience-product-coach" not in skill:
    raise SystemExit("校验失败：SKILL.md frontmatter 不完整")

checks = {
    "SKILL.md": ["# 荔枝｜经验产品化起步教练", "个性化后续路径模块"],
    "agents/openai.yaml": ['display_name: "荔枝｜经验产品化起步教练"'],
    "assets/report-example.html": [
        '<span class="group-title">产品构想</span>',
        '<span class="group-title">判断依据</span>',
        '<span class="group-title">验证行动</span>',
        "next-path",
        "path-primary",
        "path-secondary",
        "经验产品化起步教练",
    ],
    "references/html-report.md": [
        "### 核心设计原则",
        "一、产品构想",
        "二、判断依据",
        "三、验证行动",
        "后续路径模块",
    ],
    "references/boundaries-and-handoff.md": [
        "## 自然承接后续路径",
        "副业专栏优先",
        "一对一咨询优先",
    ],
}

for relative, markers in checks.items():
    text = (root / relative).read_text(encoding="utf-8")
    for marker in markers:
        if marker not in text:
            raise SystemExit(f"校验失败：{relative} 缺少关键内容：{marker}")

for relative in required_files + ["README.md"]:
    path = root / relative
    if path.exists() and "经验产品化起步助手" in path.read_text(encoding="utf-8"):
        raise SystemExit(f"校验失败：{relative} 仍包含旧产品名")

class ReportParser(HTMLParser):
    pass

ReportParser().feed((root / "assets/report-example.html").read_text(encoding="utf-8"))
print(f"内容防回退校验通过：{sys.argv[1]}")
PY

if [[ "$target_ref" == "WORKTREE" ]]; then
  git -C "$repo_root" diff --check
fi
