#!/usr/bin/env bash
set -uo pipefail
gpu=""
need=0
name=""
want_display=0
shared=0
timeout_s=2700
while [ $# -gt 0 ]; do
	case "$1" in
		--gpu) gpu=$2; shift 2 ;;
		--need) need=$2; shift 2 ;;
		--name) name=$2; shift 2 ;;
		--display) want_display=1; shift ;;
		--shared) shared=1; shift ;;
		--timeout) timeout_s=$2; shift 2 ;;
		--) shift; break ;;
		*) echo "gpu_queue: unknown flag $1" >&2; exit 2 ;;
	esac
done
if [ -z "$gpu" ] || [ -z "$name" ] || [ $# -eq 0 ]; then
	echo "usage: gpu_queue.sh --gpu N --need MIB --name NAME [--display] [--shared] [--timeout S] -- cmd args..." >&2
	exit 2
fi

log_line() {
	local line=$1
	mkdir -p /tmp/claude-1000
	echo "$line" >> /tmp/claude-1000/scrapkeep-gpu-queue.log
	if [ -n "${SCRAPKEEP_GPU_LOG:-}" ]; then
		echo "$line" >> "$SCRAPKEEP_GPU_LOG"
	fi
}

if [ "$shared" -eq 0 ]; then
	exec 9>"/tmp/scrapkeep-gpu${gpu}.lock"
	flock 9
fi

start=$(date +%s)
waited=0
while true; do
	row=$(nvidia-smi -i "$gpu" --query-gpu memory.used,memory.total --format csv,noheader,nounits 2>/dev/null | tr -d ' ')
	used=${row%%,*}
	total=${row##*,}
	if [ -n "$row" ] && [ "$(( total - used ))" -ge "$need" ]; then
		break
	fi
	if [ "$waited" -ge "$timeout_s" ]; then
		echo "BLOCKED: gpu $gpu has under ${need} MiB free after ${timeout_s}s (row: ${row:-none})"
		log_line "$(date -Is) gpu=$gpu name=$name need=$need pid=- rc=3 wall=$(( $(date +%s) - start )) display=-"
		exit 3
	fi
	sleep 15
	waited=$(( waited + 15 ))
done

xvnc_pid=""
display="-"
if [ "$want_display" -eq 1 ]; then
	exec 8>/tmp/scrapkeep-display.lock
	flock 8
	n=93
	while [ "$n" -le 100 ]; do
		if [ ! -e "/tmp/.X11-unix/X$n" ]; then
			break
		fi
		n=$(( n + 1 ))
	done
	if [ "$n" -gt 100 ]; then
		echo "BLOCKED: no free display in :93-:100"
		log_line "$(date -Is) gpu=$gpu name=$name need=$need pid=- rc=3 wall=$(( $(date +%s) - start )) display=-"
		exit 3
	fi
	Xvnc ":$n" -geometry 1920x1080 -depth 24 -SecurityTypes None -localhost -rfbport "59$n" -desktop "gpuq-$name" -nolisten tcp 8>&- 9>&- >/dev/null 2>&1 &
	xvnc_pid=$!
	t=0
	while [ ! -S "/tmp/.X11-unix/X$n" ]; do
		if [ "$t" -ge 20 ]; then
			echo "BLOCKED: Xvnc :$n gave no socket in 10 s"
			kill "$xvnc_pid"
			log_line "$(date -Is) gpu=$gpu name=$name need=$need pid=- rc=3 wall=$(( $(date +%s) - start )) display=:$n"
			exit 3
		fi
		sleep 0.5
		t=$(( t + 1 ))
	done
	exec 8>&-
	display=":$n"
	export DISPLAY=":$n"
	unset WAYLAND_DISPLAY
	if ! pactl list short sinks | grep -q claude_silent; then
		pactl load-module module-null-sink sink_name=claude_silent sink_properties=device.description=claude_silent >/dev/null
	fi
	export PULSE_SINK=claude_silent
	export __NV_PRIME_RENDER_OFFLOAD=1
	export __VK_LAYER_NV_optimus=NVIDIA_only
fi

export CUDA_VISIBLE_DEVICES=$gpu
export SCRAPKEEP_GPU_INDEX=$gpu
run_start=$(date +%s)
"$@" 8>&- &
cmd_pid=$!
wait "$cmd_pid"
rc=$?
if [ -n "$xvnc_pid" ]; then
	kill "$xvnc_pid"
	wait "$xvnc_pid" 2>/dev/null
fi
log_line "$(date -Is) gpu=$gpu name=$name need=$need pid=$cmd_pid rc=$rc wall=$(( $(date +%s) - run_start )) display=$display"
exit "$rc"
