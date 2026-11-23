#!/usr/bin/env bash
# Release notes limited to the commits that touched one subfolder, in the format of GitHub's generated notes.
# usage: scoped-notes.sh <previous-tag> <target-ref> <new-tag> <path>
# <previous-tag> may be '' for the first release of the package.
set -euo pipefail

if [ $# -ne 4 ]; then
  echo "usage: $0 <previous-tag> <target-ref> <new-tag> <path>" >&2
  exit 2
fi
prev=$1 target=$2 new=$3 path=$4
repo=$(gh repo view --json nameWithOwner -q .nameWithOwner)
range=${prev:+$prev..}$target

entries=()
seen=" "
while IFS=$'\t' read -r sha subject; do
  # version bumps committed by the publish workflows
  case "$subject" in *'[skip ci]'*) continue ;; esac
  pr=$(gh api "repos/$repo/commits/$sha/pulls" -q '.[0] // empty | "\(.number)\t\(.user.login)\t\(.html_url)\t\(.title)"' 2>/dev/null || true)
  if [ -n "$pr" ]; then
    IFS=$'\t' read -r num login url title <<<"$pr"
    case "$seen" in *" $num "*) continue ;; esac
    seen="$seen$num "
    entries+=("* $title by @$login in $url")
  else
    login=$(gh api "repos/$repo/commits/$sha" -q '.author.login // empty' 2>/dev/null || true)
    entries+=("* $subject${login:+ by @$login} in https://github.com/$repo/commit/$sha")
  fi
done < <(git log --reverse --no-merges --format='%H%x09%s' "$range" -- "$path")

if [ ${#entries[@]} -eq 0 ]; then
  echo "no changes under $path in $range" >&2
  exit 1
fi

echo "## What's Changed"
printf '%s\n' "${entries[@]}"
echo
if [ -n "$prev" ]; then
  echo "**Full Changelog**: https://github.com/$repo/compare/$prev...$new"
else
  echo "**Full Changelog**: https://github.com/$repo/commits/$new"
fi
