"""Run ACE-Step 1.5 jobs. Copied from music-video/ace/run.py for the Scrapkeep cover audition.

One or more job files in one process (models stay loaded between files):
    systemd-run --user --scope -p MemoryMax=28G nice -n 10 \
        ~/.local/share/ACE-Step-1.5/.venv/bin/python ace/run.py ace/jobs/a.json [b.json ...]

Warm worker (same prefix), then queue job files from any shell:
    ... ace/run.py --serve [IDLE_SECONDS]      # default 300; queue: renders/ace/queue
    ~/.local/share/ACE-Step-1.5/.venv/bin/python ace/run.py --submit ace/jobs/a.json ...

Loads the planner LM once and each DiT model once, runs that model's jobs, and
writes audio plus manifest.json into the job file's out_dir. VRAM is hard-capped
(MAX_CUDA_VRAM, enforced by ACE-Step through set_per_process_memory_fraction)
so the desktop and the live wallpaper keep their share of the GPU. Run it under
`systemd-run --user --scope -p MemoryMax=...` so RAM is capped as well.

Per-phase wall times and nvidia-smi peaks go to timings.json beside the manifest.
"""

import dataclasses
import gc
import json
import os
import subprocess
import sys
import threading
import time
import traceback
from collections import defaultdict
from contextlib import contextmanager
from pathlib import Path

ACE = Path.home() / ".local/share/ACE-Step-1.5"
os.environ.setdefault("MAX_CUDA_VRAM", "12.5")
os.environ.setdefault("PYTORCH_CUDA_ALLOC_CONF", "expandable_segments:True")
sys.path.insert(0, str(ACE))

VRAM_CEILING_GB = 12.5  # never raise: the desktop, wallpaper and browsers need the rest
YIELD_GRACE = 10  # seconds a worker waits for more tickets before yielding the GPU
QUEUE = Path(__file__).resolve().parents[4] / "artifacts/local/ace-audition/queue"
LYRIC_TRACK = "Generate the vocals track based on the audio context:"
STARTED = time.perf_counter()


def gpu_state():
    out = subprocess.run(["nvidia-smi", "--query-gpu=memory.used,memory.total",
                          "--format=csv,noheader,nounits"], capture_output=True, text=True)
    used, total = (int(v) for v in out.stdout.strip().split(","))
    return used, total


GPU_LOCK = Path("/tmp/claude-1000/ace-gpu.lock")


def gpu_lock():
    """One GPU job at a time across every session and agent using this runner."""
    import fcntl

    GPU_LOCK.parent.mkdir(parents=True, exist_ok=True)
    handle = open(GPU_LOCK, "w")
    try:
        fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        print(f"waiting for the GPU lock ({GPU_LOCK}) held by another ACE-Step job...")
        fcntl.flock(handle, fcntl.LOCK_EX)
    return handle


class GpuPeak(threading.Thread):
    """Samples nvidia-smi twice a second: whole-device and this process's MiB."""

    def __init__(self):
        super().__init__(daemon=True)
        self.device_peak = self.process_peak = 0
        self.pid = str(os.getpid())

    def reset(self):
        self.device_peak = self.process_peak = 0

    def run(self):
        while True:
            try:
                self.device_peak = max(self.device_peak, gpu_state()[0])
                out = subprocess.run(["nvidia-smi", "--query-compute-apps=pid,used_memory",
                                      "--format=csv,noheader,nounits"],
                                     capture_output=True, text=True).stdout
                for line in out.splitlines():
                    pid, mib = (v.strip() for v in line.split(","))
                    if pid == self.pid:
                        self.process_peak = max(self.process_peak, int(mib))
            except (ValueError, OSError):
                pass
            time.sleep(0.5)


class Timings:
    """Wall time per phase, written to timings.json next to the manifest."""

    def __init__(self, path, sampler):
        self.path, self.sampler, self.rows = path, sampler, []

    @contextmanager
    def phase(self, name, **tags):
        started = time.perf_counter()
        try:
            yield
        finally:
            self.add(name, time.perf_counter() - started, **tags)

    def add(self, name, seconds, **tags):
        self.rows.append(dict(phase=name, seconds=round(seconds, 2), **tags))

    def write(self, **extra):
        import torch
        from torch._dynamo.utils import calculate_time_spent
        self.path.write_text(json.dumps(dict(
            rows=self.rows, process_seconds=round(time.perf_counter() - STARTED, 1),
            compile_seconds={k: round(v, 1) for k, v in calculate_time_spent().items()},
            gpu_peak_device_mib=self.sampler.device_peak,
            gpu_peak_process_mib=self.sampler.process_peak,
            torch_peak_reserved_mib=round(torch.cuda.max_memory_reserved() / 2**20),
            max_cuda_vram_gb=float(os.environ["MAX_CUDA_VRAM"]), **extra), indent=1))


def mib(n):
    return round(n / 2**20)


def stray_cuda_tensors(*models):
    """Live CUDA tensors that are not model weights: (MiB, count, biggest, holders)."""
    owned = {id(t) for m in models if m is not None
             for t in list(m.parameters()) + list(m.buffers())}
    stray = [o for o in gc.get_objects()
             if isinstance(o, torch.Tensor) and o.is_cuda and id(o) not in owned]
    stray.sort(key=lambda t: -t.numel() * t.element_size())
    holders = sorted({type(r).__name__ for t in stray[:3] for r in gc.get_referrers(t)
                      if r is not stray})
    return (mib(sum(t.numel() * t.element_size() for t in stray)), len(stray),
            [tuple(t.shape) for t in stray[:3]], holders)


def plain(value):
    """Timestamp dataclasses (SentenceTimestamp, TokenTimestamp) as JSON objects."""
    if dataclasses.is_dataclass(value) and not isinstance(value, type):
        return dataclasses.asdict(value)
    if isinstance(value, dict):
        return {k: plain(v) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [plain(v) for v in value]
    return value


def json_default(value):
    return value.item() if hasattr(value, "item") else str(value)


def score_and_time(dit, llm, extra, audios, params, entry, timings, job_name):
    """Per take: lyric timing and ACE-Step's own scores.

    - <name>.lyrics.json: token and line timestamps from the DiT's cross-attention
      (the video's karaoke clock)
    - lyric alignment (lm_score, dit_score): how well the sung audio follows the lyrics
    - PMI global quality (text2music only): the planner's reward for how well the
      song's codes fit the caption, lyrics and metadata
    """
    from acestep.core.scoring.lm_score import calculate_pmi_score_per_condition

    keys = ("pred_latents", "encoder_hidden_states", "encoder_attention_mask",
            "context_latents", "lyric_token_idss")
    aligned = all(extra.get(k) is not None for k in keys)
    steps = int(params.get("inference_steps", 8))
    lang = params.get("vocal_language", "en")
    scores = []
    for i, audio in enumerate(audios):
        s = dict(path=audio["path"], seed=audio["params"].get("seed"))
        if aligned:
            sl = dict(pred_latent=extra["pred_latents"][i:i + 1],
                      encoder_hidden_states=extra["encoder_hidden_states"][i:i + 1],
                      encoder_attention_mask=extra["encoder_attention_mask"][i:i + 1],
                      context_latents=extra["context_latents"][i:i + 1],
                      lyric_token_ids=extra["lyric_token_idss"][i:i + 1],
                      vocal_language=lang, inference_steps=steps, seed=42)
            with timings.phase("timestamps", job=job_name, take=i):
                ts = dit.get_lyric_timestamp(
                    total_duration_seconds=float(sl["pred_latent"].shape[1] / 25.0), **sl)
            Path(audio["path"]).with_suffix(".lyrics.json").write_text(
                json.dumps(plain(ts), indent=1, default=json_default))
            s["lines_timed"] = len(ts.get("sentence_timestamps") or [])
            with timings.phase("lyric_score", job=job_name, take=i):
                al = dit.get_lyric_score(**sl)
            if al.get("success"):
                s["align_lm"] = round(float(al.get("lm_score", 0.0)), 4)
                s["align_dit"] = round(float(al.get("dit_score", 0.0)), 4)
        codes = audio["params"].get("audio_codes")
        if codes and llm.llm_initialized:
            meta = dict(bpm=params.get("bpm"), caption=params.get("caption"),
                        duration=int(params.get("duration") or 0) or None,
                        keyscale=params.get("keyscale"), language=lang,
                        timesignature=params.get("timesignature"))
            with timings.phase("pmi", job=job_name, take=i):
                per, glob, status = calculate_pmi_score_per_condition(
                    llm, codes, caption=params.get("caption", ""), lyrics=params.get("lyrics", ""),
                    metadata={k: v for k, v in meta.items() if v})
            if per:
                s["pmi_global"] = round(float(glob), 4)
                s["pmi"] = {k: round(float(v), 4) for k, v in per.items()}
        scores.append(s)
        print(f"  seed {s['seed']}: align dit {s.get('align_dit')} lm {s.get('align_lm')}  "
              f"pmi {s.get('pmi_global')}  lines {s.get('lines_timed')}")
    entry["scores"] = scores


SKIP_LM_TASKS = {"cover", "cover-nofsq", "repaint", "extract"}  # ACE-Step's own list


def uses_planner(model, params, planner_live):
    """Whether generate_music will run the planner for this job (its use_lm rule)."""
    wants = params.get("thinking", True) or any(
        params.get(k) for k in ("use_cot_caption", "use_cot_language", "use_cot_metas"))
    return planner_live and wants and params.get("task_type", "text2music") not in SKIP_LM_TASKS


RESIDENT_MAX_SECONDS = 120  # a 56 s take fits beside a resident XL DiT; 212 s does not


def job_seconds(params):
    """Audio length: the source's for cover, lego and repaint, else the requested duration."""
    if params.get("src_audio") and params.get("task_type", "text2music") != "text2music":
        import soundfile
        return soundfile.info(params["src_audio"]).duration
    return float(params.get("duration") or 0)


def offload_dit(model, planner, seconds):
    """XL (~9.5 GB on the GPU) stays resident only when nothing else needs the room:
    it leaves while the planner runs (ACE-Step's own XL-on-16GB recipe), and for
    long takes, whose source encode and decode need the rest of the 12 GiB cap."""
    return "-xl-" in model and (planner or seconds > RESIDENT_MAX_SECONDS)


def check_caps():
    """Refuse to run outside the limits this machine's other GPU and RAM users rely on."""
    cap_gb = float(os.environ["MAX_CUDA_VRAM"])
    if cap_gb > VRAM_CEILING_GB:
        sys.exit(f"MAX_CUDA_VRAM={cap_gb} is above the {VRAM_CEILING_GB} GB ceiling: the desktop, "
                 f"the live wallpaper and browsers need the rest of the 16 GB.")
    cgroup = Path("/proc/self/cgroup").read_text().strip().split(":", 2)[2]
    limit = Path(f"/sys/fs/cgroup{cgroup}/memory.max")
    if not limit.exists() or limit.read_text().strip() == "max":
        sys.exit("No RAM cap on this process. Run it under "
                 "`systemd-run --user --scope -p MemoryMax=28G ...` (oomd kills every session "
                 "on this machine if RAM runs away).")
    return cap_gb * 1024


class Session:
    """Holds the GPU lock and keeps the DiT and planner loaded across job files."""

    def __init__(self):
        cap = check_caps()
        self.lock = gpu_lock()  # held until the session ends
        # The previous holder releases the lock as it exits, a moment before
        # the driver frees its VRAM: give that up to a minute.
        for _ in range(30):
            used, total = gpu_state()
            if used + cap <= total - 512:
                break
            time.sleep(2)
        if used + cap > total - 512:
            sys.exit(f"GPU busy: {used} MiB used of {total}; a {cap:.0f} MiB cap would leave "
                     f"under 512 MiB. Lower MAX_CUDA_VRAM or free the GPU.")
        print(f"GPU before: {used}/{total} MiB, ACE-Step capped at {cap:.0f} MiB")
        self.sampler = GpuPeak()
        self.sampler.start()
        started = time.perf_counter()
        global torch, AceStepHandler, GenerationConfig, GenerationParams, generate_music
        import torch
        from acestep.handler import AceStepHandler
        from acestep.inference import GenerationConfig, GenerationParams, generate_music
        from acestep.llm_inference import LLMHandler
        self.new_llm = LLMHandler
        self.import_seconds = time.perf_counter() - started
        self.dit = self.dit_model = self.llm = self.llm_key = None
        self.idle_llm = LLMHandler()  # never initialized: generate_music then skips the planner

    def load_dit(self, model, timings):
        if self.dit_model == model:
            return self.dit, None
        if self.dit is not None:
            self.place_dit(self.dit, True)
        self.dit = self.dit_model = None
        gc.collect()
        torch.cuda.empty_cache()
        dit = AceStepHandler()
        with timings.phase("load_dit", model=model):
            msg, ok = dit.initialize_service(project_root=str(ACE), config_path=model,
                                             device="cuda", compile_model=True,
                                             offload_to_cpu=True,
                                             offload_dit_to_cpu="-xl-" in model,
                                             quantization="int8_weight_only")
        print(f"DiT {model}: {ok} {msg[:120]}")
        if ok:
            self.dit, self.dit_model = dit, model
        return self.dit, msg

    def ensure_llm(self, spec, timings):
        # The planner loads after the DiT: loading it first, on vLLM, reserved
        # ~6.5 GB and left the XL DiT no room to load and quantize.
        key = (spec.get("lm", "acestep-5Hz-lm-1.7B"), spec.get("lm_backend", "pt"))
        if self.llm_key == key:
            return
        if self.llm is not None:
            self.llm.unload()
        self.llm, self.llm_key = self.new_llm(), key
        with timings.phase("load_lm"):
            msg, ok = self.llm.initialize(checkpoint_dir=str(ACE / "checkpoints"),
                                          lm_model_path=key[0], backend=key[1], device="cuda",
                                          offload_to_cpu=True)
        print(f"LM: {ok} {msg[:120]}")

    def place_dit(self, dit, offload):
        """Apply the offload choice now, so the planner never loads beside a resident DiT."""
        dit.offload_dit_to_cpu = offload
        # any(), not the first weight: an OOM mid-move (ACE-Step moves before its
        # try/finally) leaves a model split across CPU and GPU.
        if offload and any(p.is_cuda for p in dit.model.parameters()):
            dit._recursive_to_device(dit.model, "cpu")
            dit.silence_latent = dit.silence_latent.to("cpu")
            gc.collect()
            torch.cuda.empty_cache()

    def release_job(self, dit, name, resident):
        """Free what a job left on the GPU and report it against the resident models.

        A CUDA OOM that ACE-Step catches and logs (timestamps on a full-length
        take) leaves traceback frames in reference cycles that still hold their
        GPU tensors; only a full gc pass frees them.
        """
        models = (dit.model, dit.vae, dit.text_encoder, getattr(self.llm, "llm", None))
        before, stray = torch.cuda.memory_allocated(), stray_cuda_tensors(*models)
        if dit.offload_dit_to_cpu:
            self.place_dit(dit, True)
        planner = getattr(self.llm, "llm", None)
        if (planner is not None and self.llm_key[1] == "pt"
                and any(p.is_cuda for p in planner.parameters())):
            planner.to("cpu")  # ACE-Step keeps the pt planner on the CPU between calls
        # The VAE's old-style weight_norm keeps each computed `weight` as a plain
        # tensor, which stays on the GPU (~320 MiB) when ACE-Step offloads the VAE.
        if next(dit.vae.parameters()).device.type == "cpu":
            for module in dit.vae.modules():
                weight = module.__dict__.get("weight")
                if isinstance(weight, torch.Tensor) and weight.is_cuda:
                    module.__dict__["weight"] = weight.to("cpu")
        gc.collect()
        torch.cuda.empty_cache()
        after, left = torch.cuda.memory_allocated(), stray_cuda_tensors(*models)
        print(f"{name}: allocated {mib(before)} MiB after the job ({stray[0]} MiB in {stray[1]} "
              f"stray tensors, biggest {stray[2]}, held by {stray[3]}); {mib(after)} MiB after gc "
              f"({left[0]} MiB stray); {mib(resident)} MiB before the job", flush=True)
        return dict(before=mib(before), after=mib(after), before_job=mib(resident),
                    stray_mib=stray[0], stray_count=stray[1], stray_biggest=stray[2],
                    stray_holders=stray[3], stray_after_gc_mib=left[0])

    def run_file(self, job_file):
        spec = json.loads(Path(job_file).read_text())
        base = Path(job_file).resolve().parent
        out_dir = (base / spec["out_dir"]).resolve()
        out_dir.mkdir(parents=True, exist_ok=True)
        torch.cuda.reset_peak_memory_stats()
        self.sampler.reset()
        timings = Timings(out_dir / "timings.json", self.sampler)
        if self.import_seconds:
            timings.add("import", self.import_seconds)
            self.import_seconds = 0

        def resolve(value):
            if isinstance(value, str) and value.startswith("@"):  # @file: read text from a file
                return (base / value[1:]).read_text().strip()
            if isinstance(value, str) and value.startswith("path:"):
                return str((base / value[5:]).resolve())
            return value

        # As in a one-file run, the planner joins at this file's first thinking
        # text2music job and stays for the rest of the file (lego included,
        # since ACE-Step only skips it for cover, repaint and extract).
        planner_live = False
        file_peak = 0
        groups = defaultdict(list)
        for job in spec["jobs"]:
            groups[job["model"]].append(job)
        manifest = []
        for model, jobs in groups.items():
            dit = None
            dit, msg = self.load_dit(model, timings)
            if dit is None:
                manifest.append(dict(model=model, error=msg))
                continue
            for job in jobs:
                params = {k: resolve(v) for k, v in {**spec.get("defaults", {}),
                                                      **job["params"]}.items()}
                scoring = params.pop("scoring", True)  # false: no timestamps, lyric score or PMI
                if params.get("task_type") == "lego" and "instruction" not in params:
                    params["instruction"] = LYRIC_TRACK
                if (params.get("task_type", "text2music") == "text2music"
                        and params.get("thinking", True)):
                    self.ensure_llm(spec, timings)
                    planner_live = True
                llm = self.llm if planner_live else self.idle_llm
                self.place_dit(dit, offload_dit(model, uses_planner(model, params, planner_live),
                                                job_seconds(params)))
                seeds = job.get("seeds")
                config = GenerationConfig(batch_size=len(seeds) if seeds else job.get("batch", 1),
                                          seeds=seeds, use_random_seed=seeds is None,
                                          audio_format="wav")
                dit.current_offload_cost = 0.0
                resident = torch.cuda.memory_allocated()
                file_peak = max(file_peak, torch.cuda.max_memory_allocated())
                torch.cuda.reset_peak_memory_stats()
                started = time.time()
                result = generate_music(dit, llm, GenerationParams(**params), config,
                                        save_dir=str(out_dir / job["name"]))
                took = time.time() - started
                timings.add("generate", took, job=job["name"])
                costs = (result.extra_outputs or {}).get("time_costs") or {}
                for key in ("lm_phase1_time", "lm_phase2_time", "dit_diffusion_time_cost",
                            "dit_vae_decode_time_cost", "dit_offload_time_cost"):
                    if key in costs:
                        timings.add(key, costs[key], job=job["name"], source="ace-step")
                job_peak = torch.cuda.max_memory_allocated()
                peak = max(file_peak, job_peak) / 2**20  # the manifest keeps the running peak
                entry = dict(name=job["name"], model=model, seconds=round(took, 1),
                             peak_vram_mib=round(peak), success=result.success,
                             error=result.error,
                             audios=[dict(path=a["path"], seed=a["params"].get("seed"))
                                     for a in (result.audios or [])])
                extra = result.extra_outputs or {}
                meta = extra.get("lm_metadata")
                if meta:
                    entry["lm_metadata"] = meta if isinstance(meta, (dict, list, str)) else str(meta)
                if (scoring and result.success and params.get("lyrics")
                        and "[Instrumental]" not in params["lyrics"]):
                    with timings.phase("scoring", job=job["name"]):
                        score_and_time(dit, llm, extra, result.audios, params, entry,
                                       timings, job["name"])
                manifest.append(entry)
                job_peak = torch.cuda.max_memory_allocated()
                print(f"{job['name']}: {'ok' if result.success else 'FAILED ' + str(result.error)} "
                      f"in {took:.0f}s, job peak {mib(job_peak)} MiB, GPU now {gpu_state()[0]} MiB")
                del result, extra
                memory = self.release_job(dit, job["name"], resident)
                timings.add("memory", 0, job=job["name"], peak_mib=mib(job_peak), **memory)
                (out_dir / "manifest.json").write_text(json.dumps(manifest, indent=1, default=str))
                timings.write()
        timings.write()
        print(f"manifest: {out_dir / 'manifest.json'}\ntimings: {timings.path} "
              f"(GPU peak {self.sampler.device_peak} MiB device, "
              f"{self.sampler.process_peak} MiB this process)", flush=True)
        return dict(manifest=str(out_dir / "manifest.json"), timings=str(timings.path),
                    failed=sum(1 for e in manifest if not e.get("success")))


def lock_waiters(handle):
    """True when another process is blocked on the GPU lock (/proc/locks '->' entries)."""
    inode = f":{os.fstat(handle.fileno()).st_ino}"
    return any("->" in line.split() and any(f.endswith(inode) for f in line.split())
               for line in Path("/proc/locks").read_text().splitlines())


def worker_pid(queue):
    try:
        pid = int((queue / "worker.pid").read_text())
        if "run.py" in Path(f"/proc/{pid}/cmdline").read_text():
            return pid
    except (OSError, ValueError):
        pass
    return None


def serve(queue, idle):
    """Warm worker: runs job tickets dropped into `queue`, oldest first.

    It holds the GPU lock and its VRAM only while it has work: it exits after
    `idle` seconds with an empty queue, or at once when the queue is empty and
    another GPU job is waiting on the lock (after a short grace, so a batch
    submitted a few seconds apart stays together).
    """
    queue.mkdir(parents=True, exist_ok=True)
    if worker_pid(queue):
        sys.exit(f"a worker (pid {worker_pid(queue)}) already serves {queue}")
    session = Session()
    (queue / "worker.pid").write_text(str(os.getpid()))
    print(f"worker {os.getpid()} serving {queue} (idle exit after {idle:.0f}s)", flush=True)
    last = time.monotonic()
    try:
        while True:
            tickets = sorted(queue.glob("*.ticket"))
            if tickets:
                running = tickets[0].with_suffix(".running")
                tickets[0].rename(running)
                job = json.loads(running.read_text())["job"]
                started = time.monotonic()
                try:
                    done = dict(ok=True, **session.run_file(job))
                except Exception:
                    done = dict(ok=False, error=traceback.format_exc())
                    gc.collect()
                    torch.cuda.empty_cache()
                done.update(job=job, seconds=round(time.monotonic() - started, 1))
                partial = running.with_suffix(".partial")
                partial.write_text(json.dumps(done, indent=1))
                partial.rename(running.with_suffix(".done"))
                running.unlink()
                last = time.monotonic()
            elif time.monotonic() - last > idle:
                print(f"idle for {idle:.0f}s: releasing the GPU", flush=True)
                break
            elif time.monotonic() - last > YIELD_GRACE and lock_waiters(session.lock):
                print("another GPU job is waiting on the lock: releasing the GPU", flush=True)
                break
            else:
                time.sleep(0.5)
    finally:
        (queue / "worker.pid").unlink(missing_ok=True)


def submit(queue, job_files):
    """Queue job files for the warm worker and wait for their results."""
    if not worker_pid(queue):
        sys.exit(f"no worker is serving {queue}. Start one with:\n  systemd-run --user --scope "
                 f"-p MemoryMax=28G nice -n 10 {ACE}/.venv/bin/python ace/run.py --serve")
    queue.mkdir(parents=True, exist_ok=True)
    pending = []
    for job in job_files:
        ticket = queue / f"{time.time_ns()}-{Path(job).stem}"
        ticket.with_suffix(".partial").write_text(json.dumps(dict(job=str(Path(job).resolve()))))
        ticket.with_suffix(".partial").rename(ticket.with_suffix(".ticket"))
        pending.append(ticket.with_suffix(".done"))
    failed = 0
    while pending:
        for done in [d for d in pending if d.exists()]:
            result = json.loads(done.read_text())
            failed += (not result["ok"]) or result.get("failed", 0)
            print(json.dumps(result, indent=1))
            pending.remove(done)
        if pending and not worker_pid(queue):
            sys.exit(f"the worker exited with {len(pending)} job(s) unfinished; their tickets "
                     f"are still in {queue}")
        time.sleep(0.5)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    args = sys.argv[1:]
    queue = QUEUE
    if args and args[0] == "--queue":
        queue, args = Path(args[1]).resolve(), args[2:]
    if args and args[0] == "--serve":
        serve(queue, float(args[1]) if len(args) > 1 else 300)
    elif args and args[0] == "--submit":
        submit(queue, args[1:])
    elif args:
        session = Session()
        failed = sum(session.run_file(job)["failed"] for job in args)
        sys.exit(1 if failed else 0)
    else:
        sys.exit(__doc__)
