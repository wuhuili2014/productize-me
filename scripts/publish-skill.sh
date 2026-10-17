#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if [[ "$(git branch --show-current)" != "main" ]]; then
  echo "发布已停止：当前分支不是 main。" >&2
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "发布已停止：请先提交或处理工作区改动。" >&2
  exit 1
fi

git fetch origin main

local_commit="$(git rev-parse HEAD)"
remote_commit="$(git rev-parse origin/main)"

if ! git merge-base --is-ancestor "$remote_commit" "$local_commit"; then
  echo "发布已停止：GitHub main 不在当前提交历史中。请先用 fast-forward 方式同步，禁止强制推送或合并无关历史。" >&2
  exit 1
fi

"$repo_root/scripts/verify-release.sh" HEAD
git push origin main

released=""
for _ in {1..12}; do
  sleep 5
  git fetch origin main --quiet
  source_commit="$(git show origin/main:VERSION.md 2>/dev/null | sed -n 's/^- Source commit: //p')"
  if [[ "$source_commit" == "$local_commit" ]]; then
    released="yes"
    break
  fi
done

if [[ -z "$released" ]]; then
  echo "发布未确认：GitHub 自动版本在 60 秒内没有指向本次提交。" >&2
  exit 1
fi

"$repo_root/scripts/verify-release.sh" origin/main
version="$(git show origin/main:VERSION.md | sed -n 's/^- Version: //p')"
echo "发布并校验完成：${version}"
