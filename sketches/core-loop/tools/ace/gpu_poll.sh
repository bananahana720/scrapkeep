#!/usr/bin/env bash
# Appends a timestamped nvidia-smi reading every 5 s to $1 until killed.
set -u
while true; do
	used=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | head -1 | tr -d ' ')
	apps=$(nvidia-smi --query-compute-apps=pid,used_memory --format=csv,noheader,nounits | tr -d ' ' | tr '\n' ';')
	echo "$(date +%s) $used $apps" >> "$1"
	sleep 5
done
