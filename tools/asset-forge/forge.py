#!/usr/bin/env python3
"""Asset forge: a headless Claude Code agent writes a Blender recipe, the forge builds and
validates it. See README.md. Stdlib only."""
import argparse
import contextlib
import datetime
import fcntl
import json
import os
import re
import shlex
import shutil
import signal
import subprocess
import sys
import time
import tomllib
import uuid
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import forgecore as fc  # noqa: E402

FORGE_PY = Path(__file__).resolve()
NAME_RE = re.compile(r"^[a-z][a-z0-9_]{1,40}$")


def die(msg, code=2):
    print("forge: " + msg, file=sys.stderr)
    sys.exit(code)


def now():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


# --- params and version setup ---------------------------------------------------------
def budget_classes(pack, kind):
    """The sketch's per-class triangle/vertex/draw caps (assets/asset_budgets.json), when the
    checkout has them; the registry test measures promoted models against these."""
    rel = pack.get("budgets")
    if kind["bands_key"] != "model" or not rel:
        return {}
    path = Path(pack["repo_root"]) / rel
    return json.loads(path.read_text())["classes"] if path.is_file() else {}


def build_params(pack, kind, asset, category, preview=True):
    key = kind["bands_key"]
    refused = pack.get("refuse", {}).get(key, {})
    if category in refused:
        die("category %r: %s" % (category, refused[category]))
    bands, sizes, draws = pack["bands"][key], pack["sizes"][key], pack["draw_calls"][key]
    classes = budget_classes(pack, kind)
    max_verts = None
    if classes:
        if category not in classes:
            die("category %r is not a budget class in %s: %s" % (category, pack["budgets"], ", ".join(sorted(classes))))
        cap = classes[category]
        low = bands[category][0] if category in bands else cap["tris"] // 10
        band = [min(low, cap["tris"] // 2), cap["tris"]]
        max_draws, max_verts = cap["draws"], cap["verts"]
    elif category in bands:
        band, max_draws = bands[category], draws[category]
    else:
        die("category %r not in pack %s bands: %s" % (category, pack["name"], ", ".join(bands)))
    specs = fc.slot_specs(pack)
    return {
        "kind": kind["name"], "pack": pack["name"], "asset": asset, "category": category,
        "band": band,
        "size_range": sizes.get(category, sizes.get("default", [0.05, 40.0])),
        "max_draw_calls": max_draws,
        "max_vertices": max_verts,
        "budget_class": category if classes else None,
        "profile": pack.get("profiles", {}).get(key, {}).get(category, {}),
        "slots": list(specs), "slot_specs": specs,
        "palette": fc.pack_palette(pack),
        "helper_dir": str(pack["helper_dir_path"]),
        "inspect_script": str(pack["inspect_path"]),
        "preview": preview,
    }


def style_excerpt(pack):
    text = Path(pack["repo_root"], pack["style"]["brief"]).read_text()
    parts = []
    for sec in pack["style"]["sections"]:
        m = re.search(r"^## %s\. .*?(?=^## |\Z)" % re.escape(sec), text, re.M | re.S)
        if m:
            parts.append(m.group(0).rstrip())
    return "\n\n".join(parts)


def system_prompt(pack, kind, params):
    system = (fc.FORGE_DIR / "system.md").read_text().replace("{forge}", str(FORGE_PY))
    brief = (kind["dir"] / kind["brief"]).read_text()
    extra = params["profile"].get("brief")
    if extra:
        brief += "\n\n" + (kind["dir"] / extra).read_text()
    return "%s\n\n%s\n\n# Style rules from the project (%s)\n\n%s\n" % (system, brief, pack["style"]["brief"], style_excerpt(pack))


def prepare_version(pack, kind, asset, category, prompt, parent=None, reference=None, preview=True):
    vdir = fc.alloc_version(pack["name"], asset)
    (vdir / "reference").mkdir()
    (vdir / "prompt.md").write_text(prompt.rstrip() + "\n")
    params = build_params(pack, kind, asset, category, preview)
    params["parent_version"] = parent.name if parent else None
    fc.write_json(vdir / "params.json", params)
    for rel in pack["style"]["examples"]:
        src = Path(pack["repo_root"], rel)
        if src.is_file():
            shutil.copyfile(src, vdir / "reference" / src.name)
    if parent:
        fc.sweep(parent)
        shutil.copyfile(parent / "recipe.py", vdir / "recipe.py")
        prev = parent / "preview" / "sheet.png"
        if prev.is_file():
            shutil.copyfile(prev, vdir / "reference" / "previous.png")
    if reference:
        shutil.copyfile(reference, vdir / "reference" / ("source.glb" if reference.suffix == ".glb" else "concept.png"))
    (vdir / "system_prompt.md").write_text(system_prompt(pack, kind, params))
    return vdir, params


# --- forge run: the only place recipe code executes --------------------------------------
def sandbox_prefix(vdir, extra_ro, unit, mem="20G", swap="2G"):
    """Recipe code sees /usr, /etc and /sys read-only, the GPU render nodes, its helper dirs
    read-only and its version dir writable. Not /run (the user bus and agent sockets live
    there), not $HOME, not the caller's environment. Without bwrap there is no confinement,
    so the forge refuses to run rather than fall back."""
    if not shutil.which("bwrap"):
        return None, ["bwrap is not installed; forge run refuses to execute recipe code unconfined"]
    scope = ["systemd-run", "--user", "--scope", "-q", "--unit", unit, "-p", "MemoryMax=" + mem, "-p", "MemorySwapMax=" + swap]
    home = str(Path.home())
    bw = ["bwrap", "--die-with-parent", "--new-session", "--unshare-all", "--clearenv",
          "--setenv", "PATH", "/usr/bin", "--setenv", "HOME", home, "--setenv", "LANG", "C.UTF-8",
          "--ro-bind", "/usr", "/usr", "--ro-bind", "/etc", "/etc", "--ro-bind", "/sys", "/sys",
          "--symlink", "usr/bin", "/bin", "--symlink", "usr/bin", "/sbin",
          "--symlink", "usr/lib", "/lib", "--symlink", "usr/lib", "/lib64",
          "--dev", "/dev", "--dev-bind-try", "/dev/dri", "/dev/dri", "--proc", "/proc",
          "--tmpfs", "/tmp", "--tmpfs", home]
    for p in extra_ro:
        bw += ["--ro-bind", str(p), str(p)]
    bw += ["--bind", str(vdir), str(vdir)]
    notes = ["bwrap: no network or sockets, cleared env, /usr /etc /sys read-only, only the version dir writable"]
    return scope + bw, notes


def run_blender(vdir, kind, params, timeout):
    unit = "forge-%s.scope" % uuid.uuid4().hex[:10]
    exe = os.path.realpath(shutil.which("blender") or "blender")
    ro = [params["helper_dir"], kind["dir"], fc.FORGE_DIR, os.path.dirname(exe)]
    prefix, notes = sandbox_prefix(vdir, ro, unit)
    if prefix is None:
        return {"rc": None, "timed_out": False, "harness": notes[0], "cmd": [], "notes": notes}
    cmd = prefix + [exe, "-b", "--factory-startup", "--python-exit-code", "1", "-P",
                    str(kind["dir"] / kind["entry"]), "--", str(vdir)]
    log = os.fdopen(os.open(vdir / "run.log", os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o644), "w")
    t0 = time.time()
    try:
        proc = subprocess.Popen(cmd, cwd=vdir, stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT,
                                start_new_session=True)
    except FileNotFoundError as exc:
        log.close()
        return {"rc": None, "timed_out": False, "harness": "cannot start: %s" % exc, "cmd": cmd, "notes": notes}
    timed_out = False
    try:
        proc.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        timed_out = True
        subprocess.run(["systemctl", "--user", "kill", "--signal=SIGKILL", unit], capture_output=True)
        subprocess.run(["systemctl", "--user", "stop", unit], capture_output=True)
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        proc.wait()
    # Nothing recipe-spawned may outlive the run: the outer steps below trust the tree.
    subprocess.run(["systemctl", "--user", "stop", unit], capture_output=True)
    log.close()
    return {"rc": proc.returncode, "timed_out": timed_out, "seconds": round(time.time() - t0, 1), "cmd": cmd, "notes": notes}


def load_ctx(vdir):
    vdir = Path(vdir).resolve()
    fc.sweep(vdir)
    params = fc.read_json(vdir / "params.json")
    if not params:
        die("%s has no params.json; not a version directory" % vdir)
    return vdir, params, fc.load_pack(params["pack"]), fc.load_kind(params["kind"])


@contextlib.contextmanager
def version_lock(vdir):
    """One forge step per version dir at a time: a sweep assumes no sandboxed recipe is
    alive while the outer steps read and write the tree. The lock sits on the directory
    itself, which the sandbox cannot replace (it is the bind-mount root)."""
    vdir = Path(vdir).resolve()
    if not vdir.is_dir():
        die("%s is not a version directory" % vdir)
    fd = os.open(vdir, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX)
        yield
    finally:
        os.close(fd)


def do_run(vdir, timeout=600, quiet=False):
    with version_lock(vdir):
        return locked_run(vdir, timeout, quiet)


def locked_run(vdir, timeout, quiet):
    vdir, params, pack, kind = load_ctx(vdir)
    for d in ("out", "preview"):
        shutil.rmtree(vdir / d, ignore_errors=True)
    for f in ("result.json", "validate.json"):
        (vdir / f).unlink(missing_ok=True)
    if not (vdir / "recipe.py").is_file():
        res = {"schema_version": 1, "status": "recipe_error", "error": "recipe.py does not exist", "warnings": []}
        run = {"rc": None, "timed_out": False, "notes": []}
    else:
        run = run_blender(vdir, kind, params, timeout)
        swept = fc.sweep(vdir)
        res = fc.read_json(vdir / "result.json")
        if swept and res is not None:
            res["status"] = "recipe_error"
            res["error"] = "the recipe left links or special files, which were deleted: %s" % ", ".join(swept)
        if run.get("harness"):
            res = {"schema_version": 1, "status": "harness_error", "error": run["harness"], "warnings": []}
        elif run["timed_out"]:
            res = {"schema_version": 1, "status": "recipe_error", "warnings": [],
                   "error": "timed out after %ds (the recipe is too slow or loops); simplify it" % timeout}
        elif res is None:
            res = {"schema_version": 1, "status": "harness_error", "warnings": [],
                   "error": "Blender exited %s without writing result.json; see run.log" % run["rc"]}
    fc.write_json(vdir / "result.json", res)
    validator = fc.load_module(kind["dir"] / kind["validator"], "forge_kind_validator")
    if res["status"] == "harness_error":
        checks = [fc.check("harness", "fail", None, "HARNESS FAULT, not your script: " + res.get("error", "")[-600:])]
    else:
        checks = validator.validate(vdir, params, res, pack)
    verdict = {**fc.score(checks), "checks": checks, "generated": now()}
    fc.write_json(vdir / "validate.json", verdict)
    write_manifest(vdir, params, pack, kind, run)
    if not quiet:
        print_report(vdir, params, res, verdict, run)
    if res["status"] == "harness_error":
        return 2
    return 0 if verdict["passed"] else 1


def print_report(vdir, params, res, verdict, run):
    print("forge run %s/%s/%s" % (params["pack"], params["asset"], vdir.name))
    if res["status"] == "harness_error":
        print("HARNESS FAULT (not your script):", res.get("error", "")[-800:])
    elif res["status"] == "recipe_error":
        print("RECIPE FAULT:\n" + res.get("error", "")[-1800:])
    for c in verdict["checks"]:
        print("  %-5s %-16s %s" % (c["state"].upper(), c["id"], c["detail"]))
    print("score %d/10 (%s)" % (verdict["score"], verdict["state"]))
    if res["status"] == "ok":
        print("sheet: " + str(vdir / "preview" / "sheet.png"))


# --- manifest -------------------------------------------------------------------------
def claude_version():
    try:
        return subprocess.run([os.environ.get("FORGE_CLAUDE", "claude"), "--version"], capture_output=True, text=True, timeout=20).stdout.strip()
    except Exception:  # noqa: BLE001
        return None


def write_manifest(vdir, params, pack, kind, run=None):
    old = fc.read_json(vdir / "manifest.json", {})
    agent = fc.read_json(vdir / "agent.json") or {}
    res = fc.read_json(vdir / "result.json", {})
    val = fc.read_json(vdir / "validate.json", {})
    sources = {}
    for name in ("prompt.md", "params.json", "recipe.py", "system_prompt.md", "reference/concept.png", "reference/source.glb"):
        if (vdir / name).is_file():
            sources[name] = fc.sha256_file(vdir / name)
    for p in (kind["dir"] / kind["entry"], kind["dir"] / kind["validator"], kind["dir"] / kind["brief"], FORGE_PY):
        sources["forge:" + p.name] = fc.sha256_file(p)
    files = {}
    for sub in ("out", "preview"):
        for p in sorted((vdir / sub).glob("*")) if (vdir / sub).is_dir() else []:
            if p.is_file():
                files["%s/%s" % (sub, p.name)] = fc.sha256_file(p)
    m = {
        "schema_version": 1,
        "tool": "asset-forge",
        "kind": params["kind"], "pack": params["pack"], "asset": params["asset"], "version": vdir.name,
        "category": params["category"],
        "parent_version": params.get("parent_version"),
        "prompt_sha256": fc.sha256_file(vdir / "prompt.md") if (vdir / "prompt.md").is_file() else None,
        "concept_sha256": sources.get("reference/concept.png"),
        "model_requested": old.get("model_requested"),
        "model_used": sorted((agent.get("modelUsage") or {}).keys()) or old.get("model_used"),
        "claude_cli_version": old.get("claude_cli_version"),
        "agent_command": old.get("agent_command"),
        "blender": res.get("blender"),
        "units": "metres; Blender Z up, front -Y; glTF Y up",
        "sandbox": (run or {}).get("cmd") or old.get("sandbox"),
        "validate_score": val.get("score"),
        "validate_state": val.get("state"),
        "triangles": (res.get("measure") or {}).get("triangles"),
        "provenance": "Original procedural geometry written by a model-driven Blender recipe for Scrapkeep. No external assets or paid generation. No public license grant.",
        "limits": {"engine_import": "not_run", "human_acceptance": "not_measured", "performance": "not_measured"},
        "sources": sources,
        "files": files,
        "generated": now(),
    }
    fc.write_json(vdir / "manifest.json", m)
    return m


def merge_manifest(vdir, **fields):
    m = fc.read_json(vdir / "manifest.json", {})
    m.update(fields)
    fc.write_json(vdir / "manifest.json", m)


# --- the agent ---------------------------------------------------------------------------
def agent_command(vdir, model, max_turns, budget):
    run_cmd = "python3 %s run ." % FORGE_PY
    gate = {"hooks": {"PreToolUse": [{"matcher": "Bash", "hooks": [{
        "type": "command", "command": "python3 %s %s" % (fc.FORGE_DIR / "bash_gate.py", shlex.quote(run_cmd))}]}]}}
    cmd = [os.environ.get("FORGE_CLAUDE", "claude"), "-p", "--model", model,
           "--restricted", "--strict-mcp-config", "--setting-sources", "", "--settings", json.dumps(gate),
           "--tools", "Read,Write,Edit,Bash",
           "--allowedTools", "Read", "Write", "Edit", "Bash(%s)" % run_cmd,
           "--disallowedTools", "Write(params.json)", "Edit(params.json)",
           "--permission-mode", "dontAsk", "--permission-prompts", "none",
           "--no-session-persistence", "--output-format", "json",
           "--max-turns", str(max_turns), "--max-budget-usd", str(budget),
           "--append-system-prompt-file", "system_prompt.md"]
    return cmd


def agent_task(vdir, params, revising):
    label = fc.load_kind(params["kind"]).get("band_label", "triangle band")
    lines = ["Build the asset described in prompt.md in this directory (asset %r, category %r, %s %s to %s)."
             % (params["asset"], params["category"], label, params["band"][0], params["band"][1])]
    if revising:
        lines.append("This is a revision. recipe.py is the previous version and reference/previous.png is its sheet. Change it as the prompt asks and keep what already works.")
    if (vdir / "reference" / "concept.png").is_file():
        lines.append("reference/concept.png is the concept picture. Read it first and match it.")
    if (vdir / "reference" / "source.glb").is_file():
        lines.append("reference/source.glb is the source model (a GLB). A sprite recipe can call load_reference() to use it.")
    lines.append("Follow the system brief. The prompt:\n\n" + (vdir / "prompt.md").read_text())
    return "\n".join(lines)


def run_agent(vdir, params, model, max_turns, budget, timeout, revising):
    cmd = agent_command(vdir, model, max_turns, budget)
    merge_manifest(vdir, model_requested=model, claude_cli_version=claude_version(),
                   agent_command=cmd + ["<task prompt on stdin>"], agent_started=now())
    env = {**os.environ, "CLAUDE_CODE_DISABLE_CLAUDE_MDS": "1"}
    proc = subprocess.Popen(cmd, cwd=vdir, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            text=True, env=env, start_new_session=True)
    try:
        stdout, stderr = proc.communicate(agent_task(vdir, params, revising), timeout=timeout)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        stdout, stderr = proc.communicate()
        stdout, stderr = "", (stderr or "") + "\nagent timed out after %ds" % timeout
    # An inner `forge run` the agent started may outlive it; it holds the version lock,
    # so waiting for the lock here means its recipe has exited before we sweep.
    with version_lock(vdir):
        fc.sweep(vdir)
        fc.write_text(vdir / "agent.stderr", stderr)
        try:
            out = json.loads(stdout)
        except json.JSONDecodeError:
            out = {"is_error": True, "result": stdout[-2000:] or stderr[-2000:], "rc": proc.returncode}
        fc.write_json(vdir / "agent.json", out)
        fc.write_text(vdir / "notes.md", (out.get("result") or "").strip() + "\n")
    return out


def make_or_revise(args, revising):
    pack = fc.load_pack(args.pack)
    kind = fc.load_kind(args.kind)
    asset = args.name
    if not NAME_RE.match(asset):
        die("asset name %r must match %s" % (asset, NAME_RE.pattern))
    parent = None
    if revising:
        have = fc.versions(pack["name"], asset)
        if not have:
            die("no versions of %s/%s to revise" % (pack["name"], asset))
        parent = fc.version_dir(pack["name"], asset, args.base or "v%d" % have[-1])
        if not (parent / "recipe.py").is_file():
            die("%s has no recipe.py" % parent)
    reference = Path(args.reference).resolve() if args.reference else None
    if reference and not reference.is_file():
        die("reference %s not found" % reference)
    category = args.category or pack["default_category"]
    vdir, params = prepare_version(pack, kind, asset, category, args.prompt, parent, reference)
    print("forge: %s %s/%s/%s (model %s)" % ("revise" if revising else "make", pack["name"], asset, vdir.name, args.model))
    if args.dry_agent:
        print("forge: --dry-agent, version prepared at", vdir)
        return 0
    out = run_agent(vdir, params, args.model, args.max_turns, args.budget, args.agent_timeout, revising)
    # The agent cannot be trusted to have left an honest result: restore the read-only
    # inputs and run the authoritative build and validation once more.
    fc.write_json(vdir / "params.json", params)
    rc = do_run(vdir, args.timeout, quiet=False)
    merge_manifest(vdir, agent_cost_usd=out.get("total_cost_usd"), agent_turns=out.get("num_turns"),
                   agent_error=bool(out.get("is_error")))
    print("forge: notes:", (vdir / "notes.md").read_text().strip() if (vdir / "notes.md").exists() else "(none)")
    print("forge: version dir", vdir)
    return rc


# --- list / compare / promote / pack ----------------------------------------------------
def cmd_list(args):
    root = fc.scratch_root()
    print("packs:", ", ".join(fc.pack_names()), "| kinds:", ", ".join(fc.kind_names()))
    for pdir in sorted(p for p in root.glob("*") if p.is_dir()) if root.is_dir() else []:
        if args.pack and pdir.name != args.pack:
            continue
        for adir in sorted(p for p in pdir.glob("*") if p.is_dir() and not p.name.startswith("_")):
            for v in fc.versions(pdir.name, adir.name):
                vd = adir / ("v%03d" % v)
                val = fc.read_json(vd / "validate.json", {})
                man = fc.read_json(vd / "manifest.json", {})
                print("%-10s %-20s v%03d  score %-4s %-5s tris %-6s parent %s" % (
                    pdir.name, adir.name, v, val.get("score", "-"), val.get("state", "-"), man.get("triangles", "-"), man.get("parent_version") or "-"))
    return 0


def cmd_compare(args):
    pack = args.pack
    a, b = (fc.version_dir(pack, args.asset, v) for v in (args.a, args.b))
    for d in (a, b):
        fc.sweep(d)
    sheets = [d / "preview" / "sheet.png" for d in (a, b)]
    for s in sheets:
        if not s.is_file():
            die("missing %s" % s)
    out = fc.asset_dir(pack, args.asset) / ("compare_%s_%s.png" % (a.name, b.name))
    subprocess.run(["montage", "-label", a.name, str(sheets[0]), "-label", b.name, str(sheets[1]), "-tile", "1x",
                    "-geometry", "+4+4", "-background", "#242a28", "-fill", "white", str(out)], check=True)
    print(out)
    return 0


IMAGE_EXT = (".png", ".webp", ".jpg", ".jpeg", ".hdr")


def write_registry(pack, params, vdir, written):
    """One fragment per asset in the sketch's registry.d/, listing every model and image the
    promote put under assets/, so the registry test finds them. Rows start unshipped: the
    budget test counts a model once someone wires it in and sets ships to true."""
    rel = pack.get("registry")
    reg = Path(pack["repo_root"]) / rel if rel else None
    if not reg or not reg.is_dir():
        print("forge: no registry directory in this checkout; skipped the registry fragment")
        return None
    sketch = Path(pack["sketch_path"])
    assets = (sketch / "assets").resolve()
    recipe = next((p for p in written if p.suffix == ".py"), None)
    side = next((p for p in written if p.name.endswith(".forge.json")), None)
    concept = vdir / "reference" / "concept.png"
    provenance = {"recipe": recipe.relative_to(sketch).as_posix() if recipe else None,
                  "notes": side.relative_to(sketch).as_posix() if side else None}
    if concept.is_file():
        provenance["concept_reference"] = str(concept)
    rows = []
    for p in written:
        ext = p.suffix.lower()
        if ext != ".glb" and ext not in IMAGE_EXT or not p.resolve().is_relative_to(assets):
            continue
        rows.append({"id": p.stem, "path": "res://" + p.relative_to(sketch).as_posix(),
                     "class": (params.get("budget_class") or params["category"]) if ext == ".glb" else "texture",
                     "ships": False,
                     "loader": "none (forge promote %s/%s; wire it in and set ships true)" % (params["asset"], vdir.name),
                     "provenance": provenance})
    if not rows:
        return None
    dst = reg / (params["asset"] + ".json")
    fc.write_json(dst, {"assets": rows})
    return dst


def cmd_promote(args):
    vdir = fc.version_dir(args.pack, args.asset, args.version)
    vdir, params, pack, kind = load_ctx(vdir)
    val = fc.read_json(vdir / "validate.json")
    if not val or not val.get("passed"):
        die("%s did not validate (run `forge run` first); refusing to promote" % vdir.name, 1)
    mod = fc.load_module(kind["dir"] / kind["promoter"], "forge_kind_promote")
    written = mod.promote(vdir, params, pack, fc.read_json(vdir / "manifest.json", {}), args.force)
    fragment = write_registry(pack, params, vdir, written)
    if fragment:
        written.append(fragment)
    for p in written:
        print("promoted", p)
    merge_manifest(vdir, promoted=[str(p) for p in written], promoted_at=now())
    return 0


def cmd_pack(args):
    plan = tomllib.loads(Path(args.plan).read_text())
    pack_name = plan.get("pack", "core-loop")
    style = plan.get("style", "")
    sheets, rcs = [], {}
    for item in plan["asset"]:
        ns = argparse.Namespace(
            pack=pack_name, kind=item.get("kind", plan.get("kind", "model")), name=item["name"],
            category=item.get("category"), reference=item.get("reference"), base=None,
            prompt=(style + "\n\n" if style else "") + item["prompt"], model=args.model, max_turns=args.max_turns,
            budget=args.budget, agent_timeout=args.agent_timeout, timeout=args.timeout, dry_agent=args.dry_agent)
        rcs[item["name"]] = make_or_revise(ns, False)
        last = fc.versions(pack_name, item["name"])[-1]
        s = fc.version_dir(pack_name, item["name"], "v%d" % last) / "preview" / "sheet.png"
        if s.is_file():
            sheets.append((item["name"], s))
    if sheets:
        out = fc.scratch_root() / pack_name / "_packs" / (Path(args.plan).stem + ".png")
        out.parent.mkdir(parents=True, exist_ok=True)
        cmd = ["montage"]
        for n, s in sheets:
            cmd += ["-label", n, str(s)]
        subprocess.run(cmd + ["-tile", "1x", "-geometry", "+4+4", "-background", "#242a28", "-fill", "white", str(out)], check=True)
        print("contact sheet", out)
    print("results:", json.dumps(rcs))
    return 0 if all(v == 0 for v in rcs.values()) else 1


def add_agent_flags(p):
    p.add_argument("--pack", default="core-loop")
    p.add_argument("--kind", default="model")
    p.add_argument("--category", help="band category (default: the pack's default)")
    p.add_argument("--reference", help="concept picture (png) the recipe should match")
    p.add_argument("--model", default="sonnet")
    p.add_argument("--max-turns", type=int, default=40)
    p.add_argument("--budget", type=float, default=3.0, help="max USD for the agent")
    p.add_argument("--agent-timeout", type=int, default=1800)
    p.add_argument("--timeout", type=int, default=600, help="wall-clock seconds per Blender run")
    p.add_argument("--dry-agent", action="store_true", help="prepare the version dir and stop (no model call)")


def main(argv=None):
    ap = argparse.ArgumentParser(prog="forge", description=__doc__)
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("make", help="new asset: agent writes, forge builds and validates")
    p.add_argument("what", choices=fc.kind_names(), metavar="KIND")
    add_agent_flags(p)
    p.add_argument("--name", required=True)
    p.add_argument("prompt")
    p = sub.add_parser("revise", help="new version of an asset from its latest (or --base) version")
    add_agent_flags(p)
    p.add_argument("--name", required=True)
    p.add_argument("--base", help="version to revise, e.g. v002 (default latest)")
    p.add_argument("prompt")
    p = sub.add_parser("run", help="build and validate one version dir (the only place recipe code runs)")
    p.add_argument("version_dir")
    p.add_argument("--timeout", type=int, default=600)
    p = sub.add_parser("list")
    p.add_argument("--pack")
    p = sub.add_parser("compare")
    p.add_argument("asset"); p.add_argument("a"); p.add_argument("b"); p.add_argument("--pack", default="core-loop")
    p = sub.add_parser("promote")
    p.add_argument("asset"); p.add_argument("version"); p.add_argument("--pack", default="core-loop"); p.add_argument("--force", action="store_true")
    p = sub.add_parser("pack", help="sequential makes from a plan.toml, then a contact sheet")
    p.add_argument("plan")
    add_agent_flags(p)
    args = ap.parse_args(argv)
    if args.cmd == "make":
        args.kind = args.what
        return make_or_revise(args, False)
    if args.cmd == "revise":
        return make_or_revise(args, True)
    if args.cmd == "run":
        return do_run(args.version_dir, args.timeout)
    return {"list": cmd_list, "compare": cmd_compare, "promote": cmd_promote, "pack": cmd_pack}[args.cmd](args)


if __name__ == "__main__":
    sys.exit(main())
