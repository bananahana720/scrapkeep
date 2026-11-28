#!/bin/bash
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../../.." && pwd)
B=$1
W=${BOARD_ROOT:-$REPO/artifacts/local/alpha/push/w13/concepts}
Q=$REPO/sketches/core-loop/tools/coordinator/gpu_queue.sh
V=$HOME/.local/share/genai-venv
S=$HOME/.cache/huggingface/hub/models--black-forest-labs--FLUX.1-schnell/snapshots/741f7c3ce8b383c54771c7003378a50191e9efe9
if [ -z "$B" ] || [ ! -f "$W/boards/$B.json" ]; then
  echo "usage: run_board.sh <board_name>  ($W/boards/<board_name>.json must exist)"
  exit 2
fi
mkdir -p "$W/boards/$B" "$W/logs"
start=$(date +%s)
"$Q" --gpu 0 --need 11000 --name "board-$B" --timeout 3600 -- \
  nice -n 10 env PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True "$V/bin/python" -I "$HERE/gen_board.py" "$S" "$W/boards/$B.json" "$W/boards/$B" \
  > "$W/logs/board-$B.log" 2>&1
code=$?
echo "board $B exit=$code seconds=$(( $(date +%s) - start ))" | tee -a "$W/logs/board-$B.log"
exit $code
