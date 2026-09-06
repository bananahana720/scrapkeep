"""Render recorded playtest evidence without interpreting game simulation state."""

import json
import math
from collections import Counter
from pathlib import Path


def _text(value):
    return str(value).replace("|", "\\|").replace("\n", " ")


def _seconds(value):
    return (
        f"{value:.2f}s"
        if isinstance(value, (int, float)) and math.isfinite(value)
        else "unavailable"
    )


def _distribution(values):
    values = sorted(
        value
        for value in values
        if isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(value)
        and value >= 0
    )
    if not values:
        return "0 | unavailable | unavailable | unavailable"
    percentile = lambda fraction: values[max(0, math.ceil(len(values) * fraction) - 1)]
    return f"{len(values)} | {percentile(0.5):.2f} | {percentile(0.95):.2f} | {values[-1]:.2f}"


def write_report(output, report):
    """Write report.md beside report.json and return its path."""
    output = Path(output)
    config = report.get("configuration", {})
    metrics = {
        name: []
        for name in (
            "Input tick gap",
            "Fresh-frame age",
            "Capture",
            "Total visual observation",
            "Semantic UI observation",
        )
    }
    gaps, rows, details = [], [], []
    semantic_count = native_count = reward_count = 0
    for listed in report.get("trials", []):
        index = listed["trial"]
        relative = f"trial-{index:03}"
        directory = output / relative
        try:
            result = json.loads((directory / "result.json").read_text())
            result.update(listed)
        except (OSError, ValueError) as exc:
            result = listed
            gaps.append(f"{relative}/result.json: {exc}")
        counts = Counter()
        rewards = Counter()
        try:
            with (directory / "events.ndjson").open() as source:
                for number, line in enumerate(source, 1):
                    try:
                        event = json.loads(line)
                        if not isinstance(event, dict):
                            raise ValueError("event must be an object")
                    except ValueError as exc:
                        gaps.append(f"{relative}/events.ndjson line {number}: {exc}")
                        continue
                    kind = event.get("kind")
                    if kind == "combat_segment":
                        counts["native"] += len(event.get("actions", []))
                        metrics["Input tick gap"].extend(event.get("tick_gaps_ms", []))
                        for frame in event.get("frames", []):
                            for label, key in (
                                ("Fresh-frame age", "frame_age_ms"),
                                ("Capture", "capture_ms"),
                                ("Total visual observation", "observe_ms"),
                            ):
                                metrics[label].append(frame.get(key))
                    elif kind == "observation":
                        metrics["Semantic UI observation"].append(
                            event.get("milliseconds")
                        )
                    elif kind in ("action", "resume_action", "restart_action"):
                        counts["semantic"] += 1
                        if event.get("reward_id"):
                            rewards[event["reward_id"]] += 1
        except OSError as exc:
            gaps.append(f"{relative}/events.ndjson: {exc}")
        semantic_count += counts["semantic"]
        native_count += counts["native"]
        reward_count += sum(rewards.values())
        start, end = result.get("started_at"), result.get("ended_at")
        wall = (
            end - start
            if isinstance(start, (int, float)) and isinstance(end, (int, float))
            else None
        )
        checks = []
        for key, label in (
            ("pause_check", "pause/resume"),
            ("restart_check", "defeat or victory/restart"),
        ):
            checks.append(
                f"{label}: {result.get(key) or 'not established'}"
                if config.get(key)
                else f"{label}: not requested"
            )
        rows.append(
            f"| [{index}]({relative}/result.json) | {_text(result.get('outcome', 'unavailable'))} | "
            f"{_text(result.get('terminal_outcome') or 'none recorded')} | {_seconds(wall)} | "
            f"{_seconds(result.get('active_seconds'))} | {counts['native']} / {counts['semantic']} | "
            f"{sum(rewards.values())} | {'; '.join(checks)} |"
        )
        labels = [
            name
            for name in dict.fromkeys(result.get("result_labels", []))
            if name
            in (
                "The orchard is yours.",
                "One more spark?",
                "ALL THREE WAVES CLEARED",
                "RUN ENDED",
            )
        ]
        terminal = "; ".join(labels) if labels else "no terminal label recorded"
        selection = (
            ", ".join(f"{name} × {count}" for name, count in rewards.items()) or "none"
        )
        details.append(
            f"- Trial {index}: {_text(terminal)}. Recorded reward actions: {_text(selection)}. "
            f"[Actions and frame timings]({relative}/events.ndjson); "
            f"[complete result labels]({relative}/result.json)."
        )
        for key in ("error", "evidence_error"):
            if result.get(key):
                gaps.append(f"Trial {index} {key}: {result[key]}")

    verdict = (
        "passed"
        if report.get("passed") is True
        else "did not pass"
        if report.get("passed") is False
        else "not recorded"
    )
    start, end = report.get("started_at"), report.get("ended_at")
    wall = (
        end - start
        if isinstance(start, (int, float)) and isinstance(end, (int, float))
        else None
    )
    lines = [
        "# Agent playtest evidence",
        "",
        f"Runner acceptance: **{verdict}**. "
        f"Recorded trials: {len(rows)} / {_text(config.get('trials', 'unspecified'))}. "
        f"Total run wall time: {_seconds(wall)}.",
        "",
        "Acceptance checks the configured run and requested checks. A recorded loss is a terminal outcome; "
        "a smoke pass does not establish a full clear.",
        "",
        "| Trial | Outcome | Original terminal outcome | Wall time | Active time | Native / semantic actions | Rewards | Requested checks |",
        "| --- | --- | --- | ---: | ---: | ---: | ---: | --- |",
        *rows,
        "",
        *details,
        "",
        f"Recorded action totals: {native_count} native intent changes, {semantic_count} semantic dispatches, "
        f"{reward_count} reward selections. Native intent changes exclude individual input ticks and helper key taps.",
        "",
        "## Timing",
        "",
        "All values below are milliseconds, pooled across recorded trials. "
        "Percentiles use nearest rank; missing or invalid samples are omitted, never replaced by zero.",
        "",
        "| Stage | Samples | p50 | p95 | Maximum |",
        "| --- | ---: | ---: | ---: | ---: |",
        *(f"| {name} | {_distribution(values)} |" for name, values in metrics.items()),
        "",
        "Input tick gap measures combat-loop iterations, including startup waits. Fresh-frame age is sampled "
        "when a new frame is consumed. Capture and total visual observation use those consumed frames; "
        "total observation includes capture and detection. Semantic UI observation is a separate menu-state read. "
        "These are local pipeline timings, not model API latency or complete display latency.",
        "",
        "Wall time includes setup, menu work, observation and waits. Trial active time is the combat policy's "
        "accumulated time, not a simulation clock or displayed game completion time; a separate restart probe "
        "may add wall time without advancing the original trial policy.",
        "",
        "## Provenance and limits",
        "",
        "Exact per-file SHA-256 values, configuration, desktop identity and runtime versions are retained in "
        "[report.json](report.json). Compare these identities before comparing runs.",
        "",
        f"- Game and player source: {len(report.get('source_hashes', {}))} hashed files; "
        f"unchanged at completion: {_text(report.get('source_unchanged', 'unavailable'))}.",
        f"- Installed controller: {len(report.get('controller_hashes', {}))} hashed files; "
        f"unchanged at completion: {_text(report.get('controller_unchanged', 'unavailable'))}.",
        f"- Served build: {len(report.get('build_hashes', {}))} hashed files.",
        "",
        "Combat decisions use screenshots; menu decisions use exposed accessibility names and roles. "
        "The player does not read or mutate simulation state. Saved action records and periodic screenshots "
        "support inspection and reruns, but timing and game randomness are nondeterministic. "
        "No deterministic replay, video recording, human enjoyment, or physical controller result is established.",
    ]
    if report.get("error"):
        gaps.append(str(report["error"]))
    gaps.extend(str(error) for error in report.get("cleanup_errors", []))
    if gaps:
        lines.extend(
            [
                "",
                "## Errors and evidence gaps",
                "",
                *[f"- {_text(gap)}" for gap in gaps],
            ]
        )
    destination = output / "report.md"
    destination.write_text("\n".join(lines) + "\n")
    return destination
