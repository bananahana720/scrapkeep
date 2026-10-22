"""Check complete isolated ideal-pilot repeats without executing gameplay formulas."""

import argparse
import ast
import json
import math
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TOLERANCE = 0.0001


def constant(path, name):
    text = (ROOT / path).read_text()
    return ast.literal_eval(re.search(rf"^const {name} := (.+)$", text, re.M)[1])


def owners():
    posture = "src/combat/boss_posture.gd"
    park = (ROOT / "src/core/park_defs.gd").read_text()
    pressure = float(re.search(r'"posture_curve": ([0-9.]+)', park)[1])
    return {
        "pulse_cycle": constant("src/combat/warden.gd", "PULSE_CYCLE"),
        "sheet_seconds": constant("src/combat/warden_reactor.gd", "SHEET_SECONDS"),
        "sheet_ram_breaks": constant("src/combat/warden_reactor.gd", "MOUNTED_POSTURE")["sheet_ram_breaks"],
        "full": constant(posture, "FULL"),
        "mult_min": constant(posture, "MULT_MIN"),
        "mult_max": constant(posture, "ORDINARY_RATIO"),
        "curve": constant("src/core/park_defs.gd", "POSTURE_CURVE") * pressure,
        "hefts": constant("src/core/run_state.gd", "HEFT_CLASS_AT"),
        "core_radius": constant("src/combat/warden.gd", "FAMILY_POINT_RADIUS"),
        "ball_radius": constant("src/movement/tuning.gd", "RADIUS"),
        "hit_stop_scale": constant("src/game.gd", "HIT_STOP_SCALE"),
    }


def read_case(folder, size, seed):
    case = folder / f"{size}-{seed}"
    fight = json.loads((case / "fight.json").read_text())
    trace = [json.loads(line) for line in (case / "trace.ndjson").read_text().splitlines()]
    assert fight["broken"], f"{case}: unbroken"
    assert fight["size"] == size and fight["seed"] == seed
    assert fight["fight_resets"] == 0 and fight["setup_resets"] == 1
    assert trace and all(row["engaged"] and not row["broken"] for row in trace[:-1]), f"{case}: left the fight"
    assert trace[-1]["broken"], f"{case}: no breaking tick"
    assert len(trace) == fight["sample_count"], f"{case}: sample count differs"
    first, terminal = fight["first_frame"], fight["terminal_frame"]
    assert all(type(frame) is int for frame in (first, terminal)), f"{case}: invalid frame bounds"
    assert first == fight["engaged_frame"] + 1 and terminal == fight["breaking_frame"], f"{case}: event coverage differs"
    assert [row["frame"] for row in trace] == list(range(first, terminal + 1)), f"{case}: incomplete frame coverage"
    times = [row["t"] for row in trace]
    assert all(math.isfinite(value) for value in times + [fight["seconds"], fight["started"]]), f"{case}: nonfinite time"
    assert abs(times[0]) < TOLERANCE, f"{case}: missing engagement"
    expected = owners()
    hz = fight["physics_hz"]
    assert math.isfinite(hz) and hz > 0, f"{case}: invalid physics frequency"
    steps = (1 / hz, expected["hit_stop_scale"] / hz)
    assert all(any(abs(later - earlier - step) < TOLERANCE for step in steps)
               for earlier, later in zip(times, times[1:])), f"{case}: invalid timestamp interval"
    assert abs(times[-1] - fight["seconds"]) < TOLERANCE, f"{case}: incomplete final interval"
    rams = [row for row in fight["contacts"] if row["sheet_ram"]]
    assert rams and rams[-1]["shatter"], f"{case}: no sheet-ram break"
    assert fight["initial_heft"] == expected["hefts"][2 if size == "grown" else 0]
    for key in ("pulse_cycle", "sheet_seconds", "sheet_ram_breaks", "curve", "mult_min", "mult_max", "core_radius", "ball_radius"):
        assert fight["constants"][key] == expected[key], f"{case}: wrong {key}"
    assert len(rams) == len(fight["contacts"]), f"{case}: ideal pilot has a non-sheet contact"
    posture = trace[0]["posture"]
    assert math.isfinite(posture) and 0 <= posture < expected["full"], f"{case}: invalid initial posture"
    sampled = {row["frame"]: row for row in trace}
    frame_gain = {}
    contact_posture = {}
    previous = (first - 1, -math.inf)
    for index, ram in enumerate(rams):
        assert ram["live"] and ram["entered"] == ram["cycle"] and ram["solver_contact"], f"{case}: unqualified contact"
        frame, time = ram["frame"], ram["t"]
        assert math.isfinite(time) and (frame, time) >= previous, f"{case}: contact order differs"
        previous = (frame, time)
        assert frame in sampled, f"{case}: contact outside trace"
        sample = sampled[frame]
        assert sample["live"] and sample["cycle"] == ram["cycle"] and sample["entered"] == ram["entered"], f"{case}: contact disagrees with sampled cycle"
        assert abs(time - fight["started"] - sample["t"]) < TOLERANCE, f"{case}: contact timestamp differs"
        punch, plating, heft = ram["punch"], ram["plating"], ram["heft"]
        assert all(math.isfinite(value) for value in (punch, plating, heft, ram["requested_gain"], ram["gain"], ram["posture"])), f"{case}: nonfinite contact"
        assert punch >= 0 and heft > 0, f"{case}: invalid punch or heft"
        ratio = punch / plating if plating > 0 else expected["mult_max"]
        grown_ratio = punch / heft * expected["hefts"][2] / plating if plating > 0 else expected["mult_max"]
        clamp = lambda value: min(expected["mult_max"], max(expected["mult_min"], value))
        gain = expected["full"] / expected["sheet_ram_breaks"] * (clamp(ratio) / clamp(grown_ratio)) ** expected["curve"]
        requested = max(0.0, gain - frame_gain.get(frame, 0.0))
        assert abs(ram["requested_gain"] - requested) < TOLERANCE, f"{case}: owner-derived gain differs"
        after = min(expected["full"], posture + requested)
        assert abs(ram["gain"] - (after - posture)) < TOLERANCE, f"{case}: applied gain differs"
        assert abs(ram["posture"] - after) < TOLERANCE, f"{case}: resulting posture differs"
        full = abs(after - expected["full"]) < TOLERANCE
        assert ram["shatter"] == full and (not full or index == len(rams) - 1), f"{case}: premature or missing shatter"
        frame_gain[frame] = frame_gain.get(frame, 0.0) + requested
        posture = after
        contact_posture[frame] = posture
    posture = trace[0]["posture"]
    for row in trace:
        posture = contact_posture.get(row["frame"], posture)
        assert math.isfinite(row["posture"]) and abs(row["posture"] - posture) < TOLERANCE, f"{case}: trace posture differs at frame {row['frame']}"
    assert abs(posture - expected["full"]) < TOLERANCE, f"{case}: break below FULL"
    assert rams[-1]["frame"] == terminal, f"{case}: break frame differs"
    assert abs(rams[-1]["t"] - fight["started"] - fight["seconds"]) < TOLERANCE, f"{case}: break timestamp differs"
    cycles = sorted({row["cycle"] for row in trace if row["live"]})
    assert cycles == list(range(1, fight["cycles"] + 1)), f"{case}: missing cycle coverage"
    assert all(later["cycle"] - earlier["cycle"] in (0, 1) for earlier, later in zip(trace, trace[1:])), f"{case}: cycle discontinuity"
    assert all(any(ram["cycle"] == cycle for ram in rams) for cycle in cycles), f"{case}: missed live cycle"
    return fight, trace


def summarize(fight, trace):
    cycles = {}
    for index, row in enumerate(trace):
        stop = trace[index + 1]["t"] if index + 1 < len(trace) else fight["seconds"]
        seconds = stop - row["t"]
        cycle = cycles.setdefault(row["cycle"], {"cycle": row["cycle"], "waiting_s": 0.0,
            "riding_s": 0.0, "ram_approach_s": 0.0, "return_live_s": 0.0, "rams": []})
        phase = "waiting_s" if not row["live"] else (
            "return_live_s" if row["rammed"] else "riding_s" if row["riding"] else "ram_approach_s")
        cycle[phase] += seconds
        if row["live"]:
            cycle.setdefault("live_at", row["t"])
    for ram in fight["contacts"]:
        if ram["sheet_ram"]:
            cycles[ram["cycle"]]["rams"].append(ram["t"] - fight["started"])
    return {"size": fight["size"], "seed": fight["seed"], "seconds": fight["seconds"],
        "rams": sum(len(row["rams"]) for row in cycles.values()), "cycles": list(cycles.values()),
        "max_signal_position_distance": max(math.dist(row["position"], row["core"]) for row in fight["contacts"]),
        "split": {key: sum(row[key] for row in cycles.values()) for key in
                  ("waiting_s", "riding_s", "ram_approach_s", "return_live_s")}}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("first", type=Path)
    parser.add_argument("second", type=Path)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    failures = []
    rows = []
    for size in ("grown", "small"):
        for seed in range(1, 5):
            try:
                first = read_case(args.first, size, seed)
                second = read_case(args.second, size, seed)
                assert first == second, f"{size}-{seed}: duplicate differs"
                rows.append(summarize(*first))
            except (OSError, ValueError, KeyError, AssertionError) as error:
                failures.append(str(error))
    for failure in failures:
        print(failure)
    if args.report:
        args.report.write_text(json.dumps({"failures": failures, "owners": owners(), "rows": rows}, indent=2) + "\n")
    print(f"park_reactor_ideal_check: {'FAIL' if failures else 'PASS'} ({8-len(failures)}/8 complete identical cases)")
    return int(bool(failures))


if __name__ == "__main__":
    raise SystemExit(main())
