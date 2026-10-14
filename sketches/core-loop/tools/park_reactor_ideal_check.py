"""Check complete isolated ideal-pilot repeats without executing gameplay formulas."""

import argparse
import json
from pathlib import Path


def read_case(folder, size, seed):
    case = folder / f"{size}-{seed}"
    fight = json.loads((case / "fight.json").read_text())
    trace = [json.loads(line) for line in (case / "trace.ndjson").read_text().splitlines()]
    assert fight["broken"], f"{case}: unbroken"
    assert fight["size"] == size and fight["seed"] == seed
    assert fight["fight_resets"] == 0 and fight["setup_resets"] == 1
    assert trace and all(row["engaged"] for row in trace), f"{case}: left the fight"
    rams = [row for row in fight["contacts"] if row["sheet_ram"]]
    assert rams and rams[-1]["shatter"], f"{case}: no sheet-ram break"
    cycles = sorted({row["cycle"] for row in trace if row["live"]})
    assert all(any(ram["cycle"] == cycle for ram in rams) for cycle in cycles), f"{case}: missed live cycle"
    return fight, trace


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("first", type=Path)
    parser.add_argument("second", type=Path)
    args = parser.parse_args()
    failures = []
    for size in ("grown", "small"):
        for seed in range(1, 5):
            try:
                first = read_case(args.first, size, seed)
                second = read_case(args.second, size, seed)
                assert first == second, f"{size}-{seed}: duplicate differs"
            except (OSError, ValueError, KeyError, AssertionError) as error:
                failures.append(str(error))
    for failure in failures:
        print(failure)
    print(f"park_reactor_ideal_check: {'FAIL' if failures else 'PASS'} ({8-len(failures)}/8 complete identical cases)")
    return int(bool(failures))


if __name__ == "__main__":
    raise SystemExit(main())
