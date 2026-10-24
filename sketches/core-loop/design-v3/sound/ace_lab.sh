#!/usr/bin/env bash
# Render one ace.json experiment round on one GPU, so the command is one allow-listable path.
#
#     [ACE_GPU=1] ace_lab.sh <render folder> <round> <seed> [<seed> ...]
#
# ACE_GPU is the PCI-order card: 0 is the RTX 4080 (the default), 1 the RTX 3060, the music card
# while the 4080 times frames. ace.py's VRAM check parses one line of nvidia-smi; with two cards
# it gets two, so a shim pins nvidia-smi to the chosen card. ace.py starts a render worker that
# outlives this script and keeps its PATH, so each card's shim lives in a fixed folder that is
# never deleted.
set -euo pipefail

if [ "$#" -lt 3 ]; then
    echo "usage: ace_lab.sh <render folder> <round> <seed> [<seed> ...]" >&2
    exit 2
fi
folder="$1"
round="$2"
shift 2
gpu="${ACE_GPU:-0}"

if [ "$gpu" = "0" ]; then
    shim="$HOME/.local/share/scrapkeep-ace-shim"
else
    shim="$HOME/.local/share/scrapkeep-ace-shim-$gpu"
fi
mkdir -p "$shim"
printf '#!/bin/sh\nexec /usr/bin/nvidia-smi -i %s "$@"\n' "$gpu" > "$shim/nvidia-smi"
chmod +x "$shim/nvidia-smi"

PATH="$shim:$PATH" CUDA_DEVICE_ORDER=PCI_BUS_ID CUDA_VISIBLE_DEVICES="$gpu" \
    python3 "$HOME/.claude/skills/song-composer/scripts/ace.py" lab "$folder" "$round" --seeds "$@"
