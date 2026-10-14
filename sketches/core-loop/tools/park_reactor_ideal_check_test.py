"""Planted record defects must fail through the real evaluator's main entry point."""

import argparse
import contextlib
import copy
import io
import json
import sys
from pathlib import Path
from unittest.mock import patch

import park_reactor_ideal_check as evaluator


def check(first, second, mutate=None):
    read_text = Path.read_text

    def planted(path, *args, **kwargs):
        text = read_text(path, *args, **kwargs)
        if mutate and path.name == "trace.ndjson":
            rows = [json.loads(line) for line in text.splitlines()]
            rows = mutate(copy.deepcopy(rows))
            return "\n".join(json.dumps(row) for row in rows) + "\n"
        return text

    output = io.StringIO()
    with patch.object(Path, "read_text", planted), patch.object(sys, "argv", ["check", str(first), str(second)]), contextlib.redirect_stdout(output):
        result = evaluator.main()
    return result, output.getvalue()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("first", type=Path)
    parser.add_argument("second", type=Path)
    args = parser.parse_args()
    mutations = {
        "omitted interior sample": lambda rows: rows[:len(rows)//2] + rows[len(rows)//2+1:],
        "removed cycle": lambda rows: [row for row in rows if row["cycle"] != 1],
        "truncated beginning": lambda rows: rows[1:],
        "truncated end": lambda rows: rows[:-1],
        "reversed timestamps": lambda rows: [dict(row, t=rows[-1-index]["t"]) for index, row in enumerate(rows)],
        "gate truncated trace": lambda rows: list({row["cycle"]: next(r for r in rows if r["cycle"] == row["cycle"]) for row in rows}.values()),
    }
    failures = 0
    result, output = check(args.first, args.second)
    print("valid complete batches:", "PASS" if result == 0 else "FAIL")
    if result != 0:
        print(output)
        failures += 1
    for name, mutate in mutations.items():
        result, output = check(args.first, args.second, mutate)
        print(name + ": " + ("PASS rejected" if result == 1 else "FAIL accepted"))
        print(output.strip())
        failures += result != 1
    print(f"park_reactor_ideal_check_test: {'FAIL' if failures else 'PASS'} ({len(mutations)+1} controls)")
    return int(bool(failures))


if __name__ == "__main__":
    raise SystemExit(main())
