#!/usr/bin/env bash
# Rerun all fifteen retained check-script rows of the HF-10 rerun table from the
# retained copies under artifacts/local/tasks/HF-10/rerun/, into one consolidated
# log. Usage: rerun-all.sh <repo-root> <log-path>
set -uo pipefail
ROOT=$(cd "$1" && pwd); LOG=$2
D="$ROOT/artifacts/local/tasks/HF-10"; R="$D/rerun"
: > "$LOG"
run() { # run <label> <cwd> <cmd...>
  local label=$1 cwd=$2; shift 2
  { echo "=== $label ==="; echo "CMD: (cwd=$cwd) $*"; } >> "$LOG"
  ( cd "$cwd" && "$@" ) >> "$LOG" 2>&1
  echo "EXIT=$?" >> "$LOG"
}
SHADOW="$D/shadow-root"
bash "$D/make-shadow-root.sh" "$ROOT" "$SHADOW" >> "$LOG" 2>&1
run "HF-01 check-coverage" "$SHADOW" python3 "$R/HF-01/check-coverage.py"
cp "$SHADOW/artifacts/local/tasks/HF-01/coverage.json" "$R/HF-01/coverage.json"
echo "RETAINED: $R/HF-01/coverage.json" >> "$LOG"
run "HF-02 check-register" "$SHADOW" python3 "$R/HF-02/check-register.py"
cp "$SHADOW/artifacts/local/tasks/HF-02/focused-check.json" "$R/HF-02/focused-check.json"
echo "RETAINED: $R/HF-02/focused-check.json" >> "$LOG"
rm -rf "$SHADOW"
run "HF-03a check_contract" "$ROOT" python3 "$R/HF-03a/check_contract.py" "$ROOT"
run "HF-03a run_checks" "$ROOT" python3 "$R/HF-03a/run_checks.py" "$ROOT"
run "HF-04a check_contract" "$ROOT" python3 "$R/HF-04a/check_contract.py" "$ROOT"
run "HF-04a run_checks" "$ROOT" python3 "$R/HF-04a/run_checks.py" "$ROOT"
run "HF-05 check_contract" "$ROOT" python3 "$R/HF-05/check_contract.py" "$ROOT"
run "HF-03b check_graph" "$ROOT" python3 "$R/HF-03b/check_graph.py" "$ROOT" --out "$R/HF-03b"
run "HF-04b check_patterns" "$ROOT" python3 "$R/HF-04b/check_patterns.py" "$ROOT"
run "HF-06a check_matrix" "$ROOT" python3 "$R/HF-06a/check_matrix.py" "$ROOT" --out "$R/HF-06a"
run "HF-06b check_projection" "$ROOT" python3 "$R/HF-06b/check_projection.py" "$ROOT" --out "$R/HF-06b"
run "HF-07a check_envelope" "$ROOT" python3 "$R/HF-07a/check_envelope.py" "$ROOT" --out "$R/HF-07a"
run "HF-07b check_boundaries" "$ROOT" python3 "$R/HF-07b/check_boundaries.py" "$ROOT" --out "$R/HF-07b"
run "HF-08 check_recovery" "$ROOT" python3 "$R/HF-08/check_recovery.py" "$ROOT" --out "$R/HF-08"
run "HF-09 check_migration" "$ROOT" python3 "$R/HF-09/check_migration.py" "$ROOT" --out "$R/HF-09"
{ echo "=== Derived counts for the report's rerun table (from the receipts written above) ==="; } >> "$LOG"
python3 - "$R" >> "$LOG" 2>&1 <<'PYEOF'
import json, sys, pathlib
R = pathlib.Path(sys.argv[1])
g = json.loads((R / "HF-03b/graph-check.json").read_text())
steps = g["walkthrough_steps"]
proof_hashes = sum(1 for r in g["results"] if r["name"].startswith("s0-04-hash-"))
forbidden = sum(1 for r in g["results"] if r["name"].startswith("forbidden-") and r["name"] != "forbidden-pair-count")
print("HF-03b check_graph: %d checks, %d failures, walkthrough steps W1=%d W2=%d W3=%d total=%d, %d forbidden pairs, %d HF-04a arrows, %d S0-04 proof hashes"
      % (g["checks"], g["failures"], steps["W1"], steps["W2"], steps["W3"], sum(steps.values()), forbidden, g["hf04a_arrows_checked"], proof_hashes))
b = json.loads((R / "HF-07b/paper-check.json").read_text())
nc = b["negative_controls"]
print("HF-07b check_boundaries: %d checks, %d failed, %d model runs, %d/%d negative controls detected"
      % (b["checks"], b["failed"], b["model_runs"], sum(1 for c in nc if c["detected"]), len(nc)))
c1 = json.loads((R / "HF-01/coverage.json").read_text())
print("HF-01 check-coverage: result=%s, %d rows, %d columns, %d S0-01 native files, %d support files, %d current native files, %d representative paths"
      % (c1["result"], c1["rowCount"], c1["tableColumnCount"], len(c1["s0Native"]), len(c1["s0SupportAccounting"]), c1["currentNativeFileCount"], len(c1["representatives"])))
c2 = json.loads((R / "HF-02/focused-check.json").read_text())
print("HF-02 check-register: result=%s, %d register rows, %d negative probes"
      % (c2["result"], c2["rowCount"], len(c2["negativeProbes"])))
PYEOF
grep -c '^EXIT=' "$LOG"
