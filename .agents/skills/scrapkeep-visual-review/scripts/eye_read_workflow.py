"""Blind two-stage Gemini player's-eye film reader and judge for scripts/redteam/eye.mjs output."""

import glob
import json
import os
import shutil
import time

eye_dir = os.path.abspath(args["eye_dir"])
reader_dir = os.path.join(eye_dir, "reader")
judge_sheet_path = os.path.join(eye_dir, "judge", "SHEET.md")
brief_path = os.path.join(reader_dir, "BRIEF.md")
chunk_size = int(args.get("chunk_size", 50))

frames = sorted(glob.glob(os.path.join(reader_dir, "*.jpg")))
if not frames:
    raise FileNotFoundError(f"No .jpg frames found in {reader_dir}")
if not os.path.isfile(brief_path):
    raise FileNotFoundError(f"Missing reader brief: {brief_path}")
if not os.path.isfile(judge_sheet_path):
    raise FileNotFoundError(f"Missing judge sheet: {judge_sheet_path}")

# Stage a clean reader-only view under artifacts/local/eye-reader-staging/ so paths
# passed to the blind Reader never expose `eye_dir` directory flags (such as --plant)
# or reuse stale frames from an earlier run.
run_slug = os.path.basename(eye_dir).split("-plant")[0]
stage_dir = os.path.abspath(os.path.join("artifacts/local/eye-reader-staging", f"{run_slug}-{int(time.time() * 1000)}"))
os.makedirs(stage_dir, exist_ok=True)
staged_brief = os.path.join(stage_dir, "BRIEF.md")
shutil.copyfile(brief_path, staged_brief)
staged_frames = []
for f in frames:
    dst = os.path.join(stage_dir, os.path.basename(f))
    shutil.copyfile(f, dst)
    staged_frames.append(dst)

chunks = [staged_frames[i : i + chunk_size] for i in range(0, len(staged_frames), chunk_size)]

phase("Blind Reader")
reader_schema = {
    "type": "object",
    "properties": {
        "overall_impression": {"type": "string"},
        "frame_notes": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "frame": {"type": "string"},
                    "what_is_happening": {"type": "string"},
                    "unclear_or_missing": {"type": "string"},
                },
                "required": ["frame", "what_is_happening", "unclear_or_missing"],
            },
        },
        "control_check": {"type": "string"},
    },
    "required": ["overall_impression", "frame_notes", "control_check"],
}


def build_reader_prompt(chunk_idx, chunk_frames):
    frame_list = "\n".join(f"- {p}" for p in chunk_frames)
    return (
        "You are a cold player's-eye Reader who has never seen this game.\n"
        f"Read ONLY {staged_brief} and inspect chunk {chunk_idx + 1}/{len(chunks)} of the frame images below via `read_file`.\n"
        "Do NOT open any other directory, log, or file in the repository.\n"
        "Describe what you actually see in each frame, what the HUD/telegraphs/objective appear to tell you, "
        "and anything confusing or invisible.\n\n"
        f"Frames:\n{frame_list}\n"
    )


chunk_reports = await parallel(
    list(enumerate(chunks)),
    lambda pair: agent(
        build_reader_prompt(pair[0], pair[1]),
        schema=reader_schema,
        role=f"Blind Film Reader {pair[0] + 1}/{len(chunks)}",
        type_name="scrapkeep-explorer",
        workspace="inherit",
        model=args.get("reader_model") or "inherit",
    ),
)

phase("Judge Comparison")
judge_schema = {
    "type": "object",
    "properties": {
        "verdict": {"type": "string", "enum": ["PASS", "PASS+NOTES", "FAIL"]},
        "discrepancies": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "frame": {"type": "string"},
                    "severity": {"type": "string", "enum": ["blocker", "major", "minor", "watch"]},
                    "reader_saw": {"type": "string"},
                    "game_knew": {"type": "string"},
                },
                "required": ["frame", "severity", "reader_saw", "game_knew"],
            },
        },
        "summary": {"type": "string"},
    },
    "required": ["verdict", "discrepancies", "summary"],
}

judge_prompt = (
    f"Read {judge_sheet_path} (the game's ground-truth state per frame) and compare it against the blind Reader reports.\n"
    "Flag every moment where the game knew a critical fact (objective, danger, hit, prompt) that the cold Reader missed or misread.\n\n"
    f"Blind Reader Reports:\n{json.dumps(chunk_reports, indent=2)}\n"
)

judge_report = await agent(
    judge_prompt,
    schema=judge_schema,
    role="Film Judge",
    type_name="scrapkeep-reviewer-medium",
    workspace="inherit",
    model=args.get("judge_model") or "inherit",
)

result = {"eye_dir": eye_dir, "frames": len(frames), "chunks": len(chunks), "reader_chunks": chunk_reports, "judge": judge_report}
log(json.dumps(result, indent=2))
print(json.dumps(result, indent=2))
