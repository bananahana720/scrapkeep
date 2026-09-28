#!/usr/bin/env bash
# Exits 0 once the GPU has room for one audition job: device use at most 4000 MiB and no
# process above 3000 MiB. Retries every 120 s, ten times, then exits 1. Never kills anything.
set -u
MAX_USED=4000
MAX_PROC=3000
for try in 1 2 3 4 5 6 7 8 9 10; do
	used=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | head -1 | tr -d ' ')
	top=$(nvidia-smi --query-compute-apps=used_memory --format=csv,noheader,nounits | tr -d ' ' | sort -n | tail -1)
	if [ -z "$top" ]; then
		top=0
	fi
	echo "$(date -Is) try $try: device ${used} MiB, largest process ${top} MiB"
	nvidia-smi --query-compute-apps=pid,used_memory --format=csv,noheader
	if [ "$used" -le "$MAX_USED" ] && [ "$top" -le "$MAX_PROC" ]; then
		echo "GPU clear"
		exit 0
	fi
	if [ "$try" -lt 10 ]; then
		sleep 120
	fi
done
echo "GPU BUSY after 10 tries"
exit 1
