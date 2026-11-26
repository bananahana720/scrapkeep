"""Plan and optionally execute eligible BACKLOG.md cards in isolated Antigravity workspaces."""

import json
import shlex
import subprocess

cards_arg = args.get("cards")
section_arg = args.get("section")
limit = int(args.get("limit", 2))
dry_run = bool(args.get("dry_run", True))
taken_path = args.get("taken_file")

cmd_parts = ["node", "scripts/card-runner.mjs", "--json", "--limit", str(limit)]
if cards_arg:
    joined = ",".join(cards_arg) if isinstance(cards_arg, list) else str(cards_arg)
    cmd_parts.extend(["--cards", joined])
elif section_arg:
    cmd_parts.extend(["--section", str(section_arg)])
else:
    raise ValueError("Provide args['cards'] or args['section'].")

if taken_path:
    cmd_parts.extend(["--taken", str(taken_path)])

phase("Plan eligible cards")
plan_proc = subprocess.run(cmd_parts, capture_output=True, text=True)
if plan_proc.returncode != 0:
    raise RuntimeError(f"card-runner failed (exit {plan_proc.returncode}): {plan_proc.stderr or plan_proc.stdout}")

plan_data = json.loads(plan_proc.stdout)
eligible = [c for c in plan_data.get("cards", []) if not c.get("skip")][:limit]
log(f"Stage={plan_data.get('stage')} Board=#{plan_data.get('board')} Eligible={len(eligible)}")

if dry_run or not eligible:
    output = {
        "dry_run": dry_run,
        "stage": plan_data.get("stage"),
        "board": plan_data.get("board"),
        "cards": plan_data.get("cards", []),
    }
    print(json.dumps(output, indent=2))
else:
    stage = plan_data.get("stage") or "main"
    writer_schema = {
        "type": "object",
        "properties": {
            "card_id": {"type": "string"},
            "status": {"type": "string", "enum": ["COMMITTED", "BLOCKED", "FAILED"]},
            "worktree_path": {"type": "string"},
            "branch": {"type": "string"},
            "base_sha": {"type": "string"},
            "head_sha": {"type": "string"},
            "changed_files": {"type": "array", "items": {"type": "string"}},
            "notes": {"type": "string"},
        },
        "required": ["card_id", "status", "worktree_path", "branch", "base_sha", "head_sha", "changed_files", "notes"],
    }
    review_schema = {
        "type": "object",
        "properties": {
            "card_id": {"type": "string"},
            "verdict": {"type": "string", "enum": ["PASS", "PASS+NOTES", "FAIL", "BLOCKED", "INCONCLUSIVE"]},
            "findings": {"type": "array", "items": {"type": "string"}},
            "summary": {"type": "string"},
        },
        "required": ["card_id", "verdict", "findings", "summary"],
    }

    async def process_card(card):
        cid = card["id"]
        phase(f"Card {cid}: Write in isolated workspace")
        write_res = await agent(
            (
                f"Implement BACKLOG.md card {cid} inside your isolated share workspace.\n"
                f"First run `pwd`, `git rev-parse HEAD`, and `git branch --show-current`.\n"
                f"Check `git rev-parse origin/{shlex.quote(stage)}` matches your starting HEAD; if not, stop and return status BLOCKED with details instead of rewriting or switching branches.\n"
                f"Read AGENTS.md, GEMINI.md, and card {cid} in BACKLOG.md.\n"
                f"Edit only the card's named files and tests, run focused tests, and commit locally on your share workspace branch (never push or touch main).\n"
                f"Return worktree_path (`pwd`), branch, base_sha, head_sha, changed_files, and status."
            ),
            schema=writer_schema,
            role=f"Writer {cid}",
            type_name="scrapkeep-writer",
            workspace="share",
            model=args.get("writer_model") or "inherit",
        )

        if write_res.get("status") != "COMMITTED":
            return {"card_id": cid, "writer": write_res, "checks": None, "review": None}

        wt = write_res["worktree_path"]
        base_sha = write_res["base_sha"]
        head_sha = write_res["head_sha"]

        phase(f"Card {cid}: Coordinator Checks & Diff")
        diff_stat = subprocess.run(
            ["git", "-C", wt, "diff", "--stat", f"{base_sha}..{head_sha}"],
            capture_output=True,
            text=True,
        ).stdout
        diff_body = subprocess.run(
            ["git", "-C", wt, "diff", f"{base_sha}..{head_sha}"],
            capture_output=True,
            text=True,
        ).stdout
        if len(diff_body) > 90000:
            diff_body = diff_body[:90000] + "\n[diff truncated at 90000 characters]"

        subprocess.run(["node", "scripts/ensure-node-modules.mjs"], cwd=wt, check=True)
        gate_proc = subprocess.run(
            ["npm", "run", "sketch:fast", "--", "--base", base_sha, "--budget", "600"],
            cwd=wt,
            capture_output=True,
            text=True,
        )
        gate_ok = gate_proc.returncode == 0
        gate_out = (gate_proc.stdout + "\n" + gate_proc.stderr)[-4000:]

        phase(f"Card {cid}: Independent Review")
        # AGENTS.md Rules 4 & 11 (ruling ej): admission reviews require Gemini 4 Neon at high;
        # default to "inherit" so a Neon-high coordinator session stays compliant.
        rev_res = await agent(
            (
                f"Independently review candidate for BACKLOG.md card {cid}.\n"
                f"Read the card definition for {cid} in BACKLOG.md directly; judge strictly from the card, diff, and coordinator receipts below (do not trust writer claims).\n\n"
                f"Branch: {write_res['branch']} ({base_sha}..{head_sha})\n"
                f"Fast-lane exit={gate_proc.returncode} ok={gate_ok}:\n{gate_out}\n\n"
                f"Diff stat:\n{diff_stat}\n\n"
                f"Diff:\n{diff_body}\n"
            ),
            schema=review_schema,
            role=f"Reviewer {cid}",
            type_name="scrapkeep-reviewer-medium",
            workspace="inherit",
            model=args.get("reviewer_model") or "inherit",
        )
        return {
            "card_id": cid,
            "branch": write_res["branch"],
            "head_sha": head_sha,
            "gate_ok": gate_ok,
            "review": rev_res,
        }

    results = await pipeline(eligible, process_card)
    print(json.dumps({"dry_run": False, "results": results}, indent=2))
