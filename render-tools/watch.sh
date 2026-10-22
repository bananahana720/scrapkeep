#!/bin/bash
# exits when an unseen gpu-render request appears; logs gh failures to watch.err
seen=~/scratch/w18/render/seen.txt
touch "$seen"
while true; do
  if ids=$(gh issue view 241 --repo bananahana720/scrapkeep --json comments --jq '.comments[] | select(.body|test("(^|\n)[*>\\s]*NEEDS:[ `*]*gpu-render";"i")) | .id' 2>>~/scratch/w18/render/watch.err); then
    for i in $ids; do
      if ! grep -qx "$i" "$seen"; then
        echo "NEW $i"; exit 0
      fi
    done
  else
    echo "$(date -Is) gh failed" >> ~/scratch/w18/render/watch.err
  fi
  sleep 120
done
