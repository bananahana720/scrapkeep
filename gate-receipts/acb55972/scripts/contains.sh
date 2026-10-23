#!/bin/bash
# contains.sh <stage-sha> <pr>...: name every other PR head that a PR head carries but the stage lacks.
st=$1; shift
for p in "$@"; do
  h=$(git rev-parse refs/prall/$p); out=""
  for r in $(git for-each-ref --format='%(refname:strip=2)' refs/prall/); do
    [ "$r" = "$p" ] && continue
    o=$(git rev-parse refs/prall/$r)
    git merge-base --is-ancestor $o $st && continue
    git merge-base --is-ancestor $o $h && out="$out #$r(${o:0:8})"
  done
  echo "#$p ${h:0:8} carries:${out:- none}"
done
