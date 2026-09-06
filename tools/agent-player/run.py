#!/usr/bin/env python3
"""Build, run and record bounded native orchard playtests in a dedicated workspace."""

import argparse
import hashlib
import http.server
import json
import re
import signal
import subprocess
import sys
import threading
import time
import unittest
import uuid
from functools import partial
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTROLLER_ROOT = Path.home() / ".local/share/codex-native-input/agent-desktop"
CONTROLLER_MANIFEST = Path(__file__).resolve().parent / "controller-manifest.json"


def controller_files(root):
    return sorted(
        path
        for path in Path(root).rglob("*.py")
        if path.is_file() and "__pycache__" not in path.parts
    )


def controller_entries(root):
    return {
        str(path.relative_to(root)): {
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "size": path.stat().st_size,
        }
        for path in controller_files(root)
    }


def first_controller_mismatch(expected, actual):
    """Name the first file whose hash or size differs, is missing or is unexpected."""
    for name in sorted(set(expected) | set(actual)):
        if expected.get(name) != actual.get(name):
            return name
    return None


def portable_label(root):
    root, home = Path(root), Path.home()
    return "~/" + str(root.relative_to(home)) if root.is_relative_to(home) else str(root)


def write_controller_manifest(root, manifest):
    manifest.write_text(
        json.dumps(
            {
                "controller_root": portable_label(root),
                "generated_at": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
                "files": controller_entries(root),
            },
            indent=2,
        )
        + "\n"
    )


def check_controller(root, manifest, allow_drift):
    expected = json.loads(manifest.read_text())["files"]
    actual = controller_entries(root)
    mismatch = first_controller_mismatch(expected, actual)
    if mismatch and not allow_drift:
        raise SystemExit(
            f"Controller drift: {mismatch} under {root} does not match {manifest}. "
            "Regenerate the manifest with --write-controller-manifest after reviewing "
            "the controller, or pass --allow-controller-drift to run against it anyway."
        )
    return {
        "manifest": str(manifest),
        "matched": mismatch is None,
        "first_mismatch": mismatch,
        "drift_allowed": allow_drift,
        "hashes": actual,
    }


def prepare_output(requested, workspace):
    output = requested or ROOT / "artifacts/local/agent-playtests" / (
        time.strftime("%Y%m%dT%H%M%S") + f"-{workspace}-{uuid.uuid4().hex[:8]}"
    )
    output = output.resolve()
    if output.exists() and any(output.iterdir()):
        raise ValueError("Output directory must be new or empty")
    output.mkdir(parents=True, exist_ok=True)
    # Exclusive creation also refuses two callers racing over an empty directory.
    with (output / "run-owner.json").open("x") as owner:
        json.dump({"workspace": workspace, "started_at": time.time()}, owner)
    return output


def arguments():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace", default="playtest")
    parser.add_argument("--trials", type=int, default=1)
    parser.add_argument("--max-seconds", type=float, default=300)
    parser.add_argument("--profile", choices=["visual", "passive"], default="visual")
    parser.add_argument(
        "--rewards", default="ground-loop,echo,brace-package,shear-package"
    )
    parser.add_argument("--smoke-seconds", type=float, default=0)
    parser.add_argument("--pause-check", action="store_true")
    parser.add_argument("--restart-check", action="store_true")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--controller-root", type=Path, default=CONTROLLER_ROOT)
    parser.add_argument(
        "--controller-manifest", type=Path, default=CONTROLLER_MANIFEST
    )
    parser.add_argument("--allow-controller-drift", action="store_true")
    parser.add_argument("--write-controller-manifest", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if not re.fullmatch(r"[a-z][a-z0-9_-]{0,31}", args.workspace) or args.workspace in (
        "game",
        "studio",
    ):
        parser.error(
            "Choose a dedicated workspace name; game and studio are reserved interactive areas"
        )
    if not 1 <= args.trials <= 10 or not 5 <= args.max_seconds <= 900:
        parser.error("Trials must be 1–10 and each trial 5–900 seconds")
    if not 0 <= args.smoke_seconds <= args.max_seconds:
        parser.error("Smoke duration must fit the trial limit")
    if args.restart_check and args.smoke_seconds:
        parser.error("Restart verification requires an actual terminal result")
    return args


class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass


def observe(desktop, evidence, number):
    from flow import classify

    start = time.monotonic()
    ui = desktop.observe()
    state = classify(ui)
    evidence.save_json(f"ui-{number:04}-{state}.json", ui)
    evidence.event(
        "observation",
        state=state,
        milliseconds=(time.monotonic() - start) * 1000,
        truncated=ui["truncated"],
        bus_calls=ui["bus_calls"],
    )
    return ui, state


def capture(desktop, evidence, name):
    with desktop.operation():
        data, _ = desktop.capture()
    (evidence.directory / f"{name}.jpg").write_bytes(data)


def trial(desktop, args, directory, index):
    from combat import PerceptionFailure, play
    from evidence import Evidence
    from flow import choose_action, select_button
    from policy import Policy

    evidence = Evidence(directory)
    policy = Policy(args.profile)
    result = {
        "trial": index,
        "profile": args.profile,
        "started_at": time.time(),
        "outcome": None,
        "rewards": [],
        "pause_check": None,
        "restart_check": None,
    }
    deadline = time.monotonic() + args.max_seconds
    observations = retries = 0
    did_pause = False
    observed_play = False
    pause_after = min(5, args.smoke_seconds / 2) if args.smoke_seconds else 5
    try:
        ui, state = observe(desktop, evidence, observations)
        if state in ("won", "lost"):
            action = select_button(ui, "Start a fresh run")
            if not action:
                raise RuntimeError("Fresh-run button is missing or ambiguous")
            desktop.activate(ui, action)
            evidence.event("action", **action)
            time.sleep(1.2)
            observations += 1
            ui, state = observe(desktop, evidence, observations)
            if state in ("won", "lost"):
                raise RuntimeError(
                    "Fresh-run action did not leave the previous terminal result"
                )
        while time.monotonic() < deadline:
            if state in ("won", "lost"):
                if not observed_play:
                    raise RuntimeError(
                        "Terminal result arrived before fresh play was confirmed"
                    )
                result["outcome"] = state
                result["terminal_outcome"] = state
                result["result_labels"] = [
                    n.get("name") for n in ui["nodes"] if n.get("name")
                ]
                capture(desktop, evidence, "terminal")
                if args.restart_check:
                    action = select_button(ui, "Start a fresh run")
                    if not action:
                        raise RuntimeError("Restart button is missing or ambiguous")
                    desktop.activate(ui, action)
                    evidence.event("restart_action", **action)
                    time.sleep(1.2)
                    observations += 1
                    ui, state = observe(desktop, evidence, observations)
                    if state != "playing":
                        raise RuntimeError(f"Restart did not return to play: {state}")
                    play(desktop, Policy("passive"), 2, evidence)
                    desktop.tap("KeyI")
                    time.sleep(0.15)
                    observations += 1
                    ui, state = observe(desktop, evidence, observations)
                    if state != "paused":
                        raise RuntimeError("Restarted run did not pause normally")
                    result["restart_check"] = "passed"
                    capture(desktop, evidence, "restarted-paused")
                break
            if state == "playing":
                observed_play = True
                retries = 0
                if args.pause_check and not did_pause and policy.elapsed >= pause_after:
                    desktop.tap("KeyI")
                    time.sleep(0.15)
                    observations += 1
                    ui, state = observe(desktop, evidence, observations)
                    if state != "paused":
                        raise RuntimeError("Pause verification did not reach dashboard")
                    capture(desktop, evidence, "pause-check")
                    action = select_button(ui, "Resume play")
                    if not action:
                        raise RuntimeError("Resume button is missing or ambiguous")
                    desktop.activate(ui, action)
                    evidence.event("resume_action", **action)
                    time.sleep(1.2)
                    observations += 1
                    ui, state = observe(desktop, evidence, observations)
                    if state != "playing":
                        raise RuntimeError(f"Resume did not return to play: {state}")
                    did_pause = True
                    result["pause_check"] = "passed"
                if args.smoke_seconds and policy.elapsed >= args.smoke_seconds:
                    desktop.tap("KeyI")
                    time.sleep(0.15)
                    observations += 1
                    ui, state = observe(desktop, evidence, observations)
                    if state != "paused":
                        raise RuntimeError("Smoke completion did not pause")
                    result["outcome"] = "smoke_passed"
                    capture(desktop, evidence, "smoke-paused")
                    break
                if state == "playing":
                    seconds = min(30, deadline - time.monotonic())
                    limits = []
                    if args.pause_check and not did_pause:
                        limits.append(pause_after)
                    if args.smoke_seconds:
                        limits.append(args.smoke_seconds)
                    play(
                        desktop,
                        policy,
                        seconds,
                        evidence,
                        active_limit=min(limits) if limits else None,
                    )
            elif state in ("welcome", "capture", "paused", "rewards"):
                action = choose_action(ui, args.rewards.split(","))
                if action is None:
                    raise RuntimeError(f"No unique supported action for {state}")
                desktop.activate(ui, action)
                evidence.event("action", state=state, **action)
                if action.get("reward_id"):
                    result["rewards"].append(action["reward_id"])
                retries += 1
                if retries > 12:
                    raise RuntimeError(
                        "Menu or pointer-capture recovery did not converge"
                    )
                time.sleep(
                    1.2
                    if state in ("welcome", "capture", "paused")
                    or action["name"].startswith("Continue")
                    else 0.15
                )
            elif state == "startup_error":
                raise RuntimeError("Game exposed its startup failure screen")
            else:
                retries += 1
                if retries > 3:
                    raise PerceptionFailure("Visible game state remained unknown")
                time.sleep(0.2)
            observations += 1
            ui, state = observe(desktop, evidence, observations)
            evidence.event("progress", state=state, active_seconds=policy.elapsed)
            print(
                json.dumps(
                    {
                        "trial": index,
                        "state": state,
                        "active_seconds": round(policy.elapsed, 1),
                    }
                ),
                flush=True,
            )
        if result["outcome"] is None:
            result["outcome"] = "timeout"
            capture(desktop, evidence, "timeout")
    except BaseException as exc:
        result["outcome"] = (
            "interrupted"
            if isinstance(exc, KeyboardInterrupt)
            else "infrastructure_error"
        )
        if type(exc).__name__ == "PerceptionFailure":
            result["outcome"] = "perception_failure"
        if "lost focus" in str(exc):
            result["outcome"] = "focus_loss"
        if "Emergency stop" in str(exc):
            result["outcome"] = "emergency_stop"
        result["error"] = f"{type(exc).__name__}: {exc}"
    finally:
        result["ended_at"] = time.time()
        result["active_seconds"] = policy.elapsed
        result["observations"] = observations + 1
        try:
            evidence.close()
        except Exception as exc:
            result["evidence_error"] = str(exc)
        evidence.save_json("result.json", result)
    return result


def main():
    args = arguments()
    if args.self_test:
        suite = unittest.defaultTestLoader.discover(
            str(Path(__file__).parent / "tests")
        )
        return (
            0 if unittest.TextTestRunner(verbosity=2).run(suite).wasSuccessful() else 1
        )
    if args.write_controller_manifest:
        write_controller_manifest(args.controller_root, args.controller_manifest)
        print(json.dumps({"manifest": str(args.controller_manifest)}), flush=True)
        return 0
    controller = check_controller(
        args.controller_root, args.controller_manifest, args.allow_controller_drift
    )
    from desktop import Desktop
    from evidence import hashes
    from flow import REWARD_NAMES
    from report import write_report

    if any(name not in REWARD_NAMES for name in args.rewards.split(",")):
        raise ValueError("Unknown reward preference")
    # Import dependencies before building or starting a desktop.
    import numpy
    import PIL

    output = prepare_output(args.output, args.workspace)

    def source_files():
        return [
            ROOT / "package.json",
            ROOT / "package-lock.json",
            ROOT / "orchard.html",
            *sorted((ROOT / "src").rglob("*")),
            *sorted((ROOT / "tools/agent-player").rglob("*.py")),
            *sorted((ROOT / "tools/agent-player/tests/fixtures").glob("*.jpg")),
            ROOT / "scripts/agent-playtest.mjs",
        ]

    report = {
        "started_at": time.time(),
        "configuration": {
            k: str(v) if isinstance(v, Path) else v for k, v in vars(args).items()
        },
        "method": "normal game build; screenshot combat; exposed semantic menus; native input",
        "source_hashes": hashes(source_files(), ROOT),
        "trials": [],
        "cleanup_errors": [],
    }
    report["controller"] = controller
    report["controller_hashes"] = controller["hashes"]
    report["runtime"] = {
        "python": sys.version,
        "numpy": numpy.__version__,
        "Pillow": PIL.__version__,
    }
    desktop = httpd = None
    try:
        with (output / "build.log").open("w") as log:
            subprocess.run(
                ["npm", "run", "build", "--", "--outDir", str(output / "build")],
                cwd=ROOT,
                stdout=log,
                stderr=log,
                check=True,
                timeout=120,
            )
        report["build_hashes"] = hashes((output / "build").rglob("*"), output / "build")
        httpd = http.server.ThreadingHTTPServer(
            ("127.0.0.1", 0), partial(QuietHandler, directory=str(output / "build"))
        )
        httpd.daemon_threads = True
        serving = threading.Thread(target=httpd.serve_forever, daemon=True)
        serving.start()
        url = f"http://127.0.0.1:{httpd.server_port}/orchard.html"
        report["url"] = url
        desktop = Desktop(args.workspace, args.controller_root)
        report["desktop"] = desktop.launch(url)
        for index in range(1, args.trials + 1):
            result = trial(desktop, args, output / f"trial-{index:03}", index)
            report["trials"].append(result)
            (output / "report.json").write_text(json.dumps(report, indent=2))
            if result["outcome"] not in ("won", "lost", "smoke_passed") or result.get(
                "evidence_error"
            ):
                break
    except BaseException as exc:
        report["error"] = f"{type(exc).__name__}: {exc}"
    finally:
        if desktop:
            report["cleanup_errors"] = desktop.close()
        if httpd:
            httpd.shutdown()
            httpd.server_close()
        report["source_unchanged"] = report["source_hashes"] == hashes(
            source_files(), ROOT
        )
        report["controller_unchanged"] = report[
            "controller_hashes"
        ] == controller_entries(args.controller_root)
        report["ended_at"] = time.time()
        report["passed"] = (
            len(report["trials"]) == args.trials
            and not report.get("error")
            and not report["cleanup_errors"]
            and report["source_unchanged"]
            and report["controller_unchanged"]
            and all(
                r["outcome"] in ("won", "lost", "smoke_passed")
                and not r.get("evidence_error")
                and (not args.pause_check or r["pause_check"] == "passed")
                and (not args.restart_check or r["restart_check"] == "passed")
                for r in report["trials"]
            )
        )
        (output / "report.json").write_text(json.dumps(report, indent=2))
        write_report(output, report)
        print(
            json.dumps(
                {
                    "report": str(output / "report.json"),
                    "passed": report["passed"],
                    "outcomes": [r["outcome"] for r in report["trials"]],
                    "cleanup_errors": report["cleanup_errors"],
                }
            ),
            flush=True,
        )
    return 0 if report["passed"] else 1


if __name__ == "__main__":

    def interrupt(signum, frame):
        raise KeyboardInterrupt(f"signal {signum}")

    signal.signal(signal.SIGTERM, interrupt)
    raise SystemExit(main())
