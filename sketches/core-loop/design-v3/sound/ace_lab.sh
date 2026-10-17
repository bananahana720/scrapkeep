#!/usr/bin/env bash
# Render one ace.json experiment round on the RTX 4080, so the command is one allow-listable path.
#
#     ace_lab.sh <render folder> <round> <seed> [<seed> ...]
#
# ace.py's VRAM check parses one line of nvidia-smi; with the RTX 3060 installed it gets two,
# so a shim pins nvidia-smi to GPU 0 for the duration of the run.
set -euo pipefail

if [ "$#" -lt 3 ]; then
    echo "usage: ace_lab.sh <render folder> <round> <seed> [<seed> ...]" >&2
    exit 2
fi
folder="$1"
round="$2"
shift 2

shim="$(mktemp -d)"
trap 'rm -rf "$shim"' EXIT
printf '#!/bin/sh\nexec /usr/bin/nvidia-smi -i 0 "$@"\n' > "$shim/nvidia-smi"
chmod +x "$shim/nvidia-smi"

PATH="$shim:$PATH" CUDA_DEVICE_ORDER=PCI_BUS_ID CUDA_VISIBLE_DEVICES=0 \
    python3 "$HOME/.claude/skills/song-composer/scripts/ace.py" lab "$folder" "$round" --seeds "$@"
