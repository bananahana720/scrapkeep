#!/usr/bin/env bash
# Starts, checks and stops the two local web servers a web proof drives, on ports of their own.
# Usage: .agents/skills/scrapkeep-verify-web/scripts/web.sh start|doctor|stop
#   start   Vite (the yard at / and the orchard at /orchard.html) and the Sitting Kit server, each in the
#           background with a pid file; waits until both answer
#   doctor  read-only: are the two servers ours, up, and serving this checkout?
#   stop    stops only the servers whose pid files this script wrote; evidence stays
# Env: VERIFY_WEB_VITE_PORT (default 5199), VERIFY_WEB_KIT_PORT (default 8799).
# Run state (pid files, logs, the kit's scratch verdicts file) is artifacts/local/verify-web/run/;
# proofs are artifacts/local/verify-web/<name>/.
set -uo pipefail
skill_dir="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
repo="$(git -C "$skill_dir" rev-parse --show-toplevel)"
run="$repo/artifacts/local/verify-web/run"
vite_port="${VERIFY_WEB_VITE_PORT:-5199}"
kit_port="${VERIFY_WEB_KIT_PORT:-8799}"
verdicts="$run/verdicts.json"

alive() { [ -f "$run/$1.pid" ] && kill -0 "$(cat "$run/$1.pid")" 2>/dev/null; }
answers() { curl -fs --noproxy '*' -o /dev/null --max-time 3 "$1"; }
wait_for() { for _ in $(seq 1 60); do answers "$1" && return 0; sleep 0.5; done; return 1; }

case "${1:-}" in
  start)
    mkdir -p "$run"
    [ -d "$repo/node_modules/vite" ] || { echo "web: no node_modules; run npm ci" >&2; exit 2; }
    for name in vite kit; do alive "$name" && { echo "web: $name already running (pid $(cat "$run/$name.pid")); run stop first" >&2; exit 2; }; done
    (cd "$repo" && exec node node_modules/vite/bin/vite.js --host 127.0.0.1 --port "$vite_port" --strictPort) > "$run/vite.log" 2>&1 &
    echo $! > "$run/vite.pid"
    (cd "$repo" && exec node project-guide/handoff/sitting-kit/serve.mjs --port "$kit_port" --verdicts "$verdicts") > "$run/kit.log" 2>&1 &
    echo $! > "$run/kit.pid"
    wait_for "http://127.0.0.1:$vite_port/" || { echo "web: Vite did not answer on $vite_port; see $run/vite.log" >&2; exit 1; }
    wait_for "http://127.0.0.1:$kit_port/api/build" || { echo "web: the Sitting Kit did not answer on $kit_port; see $run/kit.log" >&2; exit 1; }
    echo "web: yard http://127.0.0.1:$vite_port/  orchard http://127.0.0.1:$vite_port/orchard.html  sitting kit http://127.0.0.1:$kit_port/"
    ;;
  doctor)
    bad=0
    say() { printf '%-5s %s\n' "$1" "$2"; [ "$1" = FAIL ] && bad=1; return 0; }
    head="$(git -C "$repo" rev-parse HEAD)"
    say INFO "checkout $repo at ${head:0:8} on $(git -C "$repo" rev-parse --abbrev-ref HEAD)"
    for name in vite kit; do
      if alive "$name"; then say OK "$name is ours and running (pid $(cat "$run/$name.pid"))"; else say FAIL "$name is not running from this checkout: run web.sh start"; fi
    done
    if answers "http://127.0.0.1:$vite_port/orchard.html" && answers "http://127.0.0.1:$vite_port/"; then say OK "Vite serves / and /orchard.html on $vite_port"; else say FAIL "Vite does not answer on $vite_port"; fi
    served="$(curl -fsS --noproxy '*' --max-time 3 "http://127.0.0.1:$kit_port/api/build" 2>/dev/null | sed -n 's/.*"sha":"\([0-9a-f]*\)".*/\1/p')"
    if [ "$served" = "$head" ]; then say OK "the Sitting Kit on $kit_port names this checkout's commit"; else say FAIL "the Sitting Kit on $kit_port names '${served:0:8}', not ${head:0:8}"; fi
    say INFO "the kit writes verdicts to $verdicts, never artifacts/local/sitting-kit/verdicts.json (Andrew's)"
    if command -v chromium >/dev/null || [ -x /opt/pw-browsers/chromium ] || [ -n "${CHROMIUM_PATH:-}" ]; then say OK "a Chromium is present"; else say FAIL "no Chromium: set CHROMIUM_PATH"; fi
    exit $bad
    ;;
  stop)
    for name in vite kit; do
      if alive "$name"; then kill -TERM "$(cat "$run/$name.pid")" && echo "web: stopped $name (pid $(cat "$run/$name.pid"))"; fi
      rm -f "$run/$name.pid"
    done
    rm -f "$verdicts" "$verdicts.tmp"
    echo "web: evidence kept under $repo/artifacts/local/verify-web/"
    ;;
  *) sed -n 2,10p "${BASH_SOURCE[0]}"; exit 2 ;;
esac
