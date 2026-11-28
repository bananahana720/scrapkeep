#!/bin/sh
# Start the merge of one reviewed unit into the integration checkout, after checking the unit's own CI.
#
# Run from the root of the integration checkout (branch entropy/gate):
#
#     sh <this file> <pull request number> <unit branch> <full SHA the review passed>
#
# It refuses when: the checkout has uncommitted changes; the branch's pushed head is not the SHA the
# review passed (the writer pushed after the review); any check of the pull request failed or is still
# running; or the merge conflicts. One kind of failed check is carried: a Linux Godot job whose only
# red tests are listed as red on main, as known-reds-ci.py beside this file reads it from the job's
# log (the run still failed; the tool only shows the red is an old one). Otherwise it leaves the merge staged and uncommitted, so review notes
# can be applied before the commit. It commits nothing and pushes nothing, and is safe to run again
# after `git merge --abort`.
#
# Why it exists: two units were merged here before their Linux CI had been read. The Mac Studio runs
# arm64 and CI runs x86-64 Linux, and each time CI held a red the Mac never showed.
set -eu
[ "$#" -eq 3 ] || { echo "usage: merge-unit.sh <pull request> <branch> <reviewed SHA>" >&2; exit 2; }
pr="$1"; branch="$2"; reviewed="$3"
[ "${#reviewed}" -eq 40 ] || { echo "merge-unit: give the full 40-character SHA the review passed" >&2; exit 2; }
[ -z "$(git status --porcelain --untracked-files=no)" ] || { echo "merge-unit: the checkout has uncommitted changes" >&2; exit 1; }
git fetch -q origin
head="$(git rev-parse "origin/$branch")"
[ "$head" = "$reviewed" ] || { echo "merge-unit: origin/$branch is at $head, the review passed $reviewed" >&2; exit 1; }
checks="$(gh pr checks "$pr" 2>&1 || true)"
[ -n "$checks" ] || { echo "merge-unit: gh pr checks $pr printed nothing" >&2; exit 1; }
state="$(printf '%s\n' "$checks" | cut -f1,2)"
bad="$(printf '%s\n' "$state" | awk -F'\t' '$2 != "pass" && $2 != "skipping"')"
if [ -n "$bad" ]; then
  echo "merge-unit: pull request $pr has checks that did not pass:" >&2
  printf '%s\n' "$bad" >&2
  python3 -I "$(dirname "$0")/known-reds-ci.py" "$pr" "$head" || exit 1
fi
passed="$(printf '%s\n' "$state" | awk -F'\t' '$2 == "pass"' | wc -l | tr -d ' ')"
[ "$passed" -gt 0 ] || { echo "merge-unit: pull request $pr shows no passed check" >&2; exit 1; }
echo "merge-unit: $passed checks passed on pull request $pr at $head"
git merge --no-ff --no-commit "origin/$branch"
