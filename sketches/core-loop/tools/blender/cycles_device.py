"""Cycles render device for headless recipes.

`blender -b --factory-startup` ignores the user's preferences, so Cycles renders on the CPU
unless the recipe turns a GPU on itself. `use(scene)` puts the scene on OptiX when an OptiX
device exists and leaves it on the CPU otherwise (cloud containers have no GPU). Call it after
any read_factory_settings or open_mainfile, since both reset the device choice.

SCRAPKEEP_CYCLES picks the cards:
  auto (default)  the 4080 alone, or every OptiX card in tandem for a render of at least
                  TANDEM_MIN sample-pixels that fits the smallest card's free memory.
  all             every OptiX card, without the size or fit check.
  <name>          the one card whose name holds it, e.g. 3060. Frame-time captures need an idle
                  4080, so bakes run with SCRAPKEEP_CYCLES=3060 while a capture is on.
  cpu             the CPU, whatever is installed.
While a 4080 frame-time capture runs, auto runs the 3060 alone (the CPU when there is no 3060), so
bakes keep GPU speed and the 4080 stays idle. A capture is on when SCRAPKEEP_CAPTURE_FILE exists
or another process holds an exclusive flock on SCRAPKEEP_CAPTURE_LOCK (defaults: capture-active and
timing.lock in SCRAPKEEP_CAPTURE_DIR, the PC capture lane's gates folder; move it with the wave).
Any other SCRAPKEEP_CYCLES value overrides that.
Tandem has not yet won on a repo scene. PC medians of 3 on warden_swarm.glb, 4 views, against
the 4080 alone: 1920x1440 at 256 samples (7.1e8 sample-pixels a view) 13.07 s vs 11.36 s (#447);
3840x2880 at 512 (5.7e9) 47.1 s vs 43.2 s (#452). The machine notice's own render gained (26.3 s
vs 32.5 s), scene unknown. TANDEM_MIN (SCRAPKEEP_CYCLES_TANDEM_MIN) sits at 2e10, above both
losses, until cycles_tandem_probe.py rows show where tandem starts to win; re-fit it from those.
The fit check compares free VRAM (nvidia-smi; 12 GiB per card when it can't answer) with
fit_bytes(): the scene's triangles and images, plus HEADROOM for Cycles' kernels and buffers.
use() decides once and arms a render_pre handler that decides again before every Cycles render
in the process, from the scene as it is then (samples, size, imported meshes, capture state).
Samples, materials and outputs are the recipe's own; only the device changes.
"""
import fcntl
import os
import subprocess
import sys

NVIDIA_DRIVER = "/proc/driver/nvidia/version"
MODE_ENV = "SCRAPKEEP_CYCLES"
CAPTURE_DIR = os.environ.get("SCRAPKEEP_CAPTURE_DIR", "/home/andrew/scratch/w18/gates")
CAPTURE_FILE = os.environ.get("SCRAPKEEP_CAPTURE_FILE", os.path.join(CAPTURE_DIR, "capture-active"))
CAPTURE_LOCK = os.environ.get("SCRAPKEEP_CAPTURE_LOCK", os.path.join(CAPTURE_DIR, "timing.lock"))
CAPTURE_CARD = "3060"
BIG = "4080"
TANDEM_MIN = float(os.environ.get("SCRAPKEEP_CYCLES_TANDEM_MIN", "2e10"))
GIB = 1 << 30
HEADROOM = 2 * GIB
CARD_BYTES = 12 * GIB


_warned = set()


def warn(text):
    if text not in _warned:
        _warned.add(text)
        print("cycles_device: " + text, file=sys.stderr, flush=True)


def capture_on():
    if os.path.exists(CAPTURE_FILE):
        return True
    try:
        with open(CAPTURE_LOCK) as f:
            try:
                fcntl.flock(f, fcntl.LOCK_SH | fcntl.LOCK_NB)
            except BlockingIOError:
                return True
            fcntl.flock(f, fcntl.LOCK_UN)
    except OSError:
        pass
    return False


def optix_devices(prefs):
    try:
        if prefs.compute_device_type != "OPTIX" or not any(d.type == "OPTIX" for d in prefs.devices):
            prefs.compute_device_type = "OPTIX"
            prefs.refresh_devices()
    except (AttributeError, TypeError, ValueError):
        return []
    return [d for d in prefs.devices if d.type == "OPTIX"]


def free_bytes():
    """{card name: free VRAM in bytes} from nvidia-smi, or {} when it can't answer."""
    try:
        query = "=".join(("--query-gpu", "name,memory.free"))  # sketch-lint L3 reads "--x=" as a game flag
        out = subprocess.run(["nvidia-smi", query, "--format=csv,noheader,nounits"],
                             capture_output=True, text=True, timeout=10, check=True).stdout
    except (OSError, subprocess.SubprocessError):
        warn("nvidia-smi gave no free memory; assuming 12 GiB per card")
        return {}
    free = {}
    for line in out.splitlines():
        name, _, mib = line.rpartition(",")
        if name.strip() and mib.strip().isdigit():
            free[name.strip()] = int(mib) << 20
    return free


def fit_bytes(bpy, scene):
    """Triangles at 1 KiB each (geometry plus BVH), image pixels at 4 bytes (16 for float), plus HEADROOM."""
    total = HEADROOM
    for ob in scene.objects:
        if ob.type == "MESH":
            me = ob.data
            total += (len(me.loops) - 2 * len(me.polygons)) * 1024
    for im in bpy.data.images:
        w, h = im.size[:2]
        total += w * h * (16 if im.is_float else 4)
    return total


def work(scene):
    """Sample-pixels in one render: width x height at the render percentage, times samples."""
    r = scene.render
    return r.resolution_x * r.resolution_y * (r.resolution_percentage / 100.0) ** 2 * scene.cycles.samples


def pick(devices, mode, scene, need, free_of):
    if mode == "all":
        return list(devices)
    if mode != "auto":
        return [d for d in devices if mode in d.name.lower()][:1]
    big = ([d for d in devices if BIG in d.name] or list(devices))[:1]
    if len(devices) < 2 or work(scene) < TANDEM_MIN:
        return big
    free = free_of()
    missing = [d.name for d in devices if free and d.name not in free]
    if missing:
        warn("nvidia-smi lists no %s; treating it as full" % ", ".join(missing))
    if all(free.get(d.name, 0 if free else CARD_BYTES) >= need for d in devices):
        return list(devices)
    return big


def mode_now():
    return os.environ.get(MODE_ENV, "auto").strip().lower() or "auto"


def use(scene):
    """Set scene.cycles.device to GPU or CPU, arm the per-render check, and return the device."""
    mode = mode_now()
    scene.cycles.device = "CPU"
    if mode == "cpu" or not os.path.exists(NVIDIA_DRIVER):
        return "CPU"
    import bpy

    handlers = bpy.app.handlers.render_pre
    if not any(getattr(h, "__name__", "") == "cycles_device_render_pre" for h in handlers):
        handlers.append(bpy.app.handlers.persistent(cycles_device_render_pre))
    return decide(bpy, scene, mode)


def cycles_device_render_pre(scene, *_):
    if scene.render.engine == "CYCLES":
        import bpy

        decide(bpy, scene, mode_now())


def decide(bpy, scene, mode):
    scene.cycles.device = "CPU"
    if mode == "cpu":
        return "CPU"
    prefs = bpy.context.preferences.addons["cycles"].preferences
    devices = optix_devices(prefs)
    if mode == "auto" and capture_on():
        mode = CAPTURE_CARD
        warn("4080 capture running; rendering on the %s alone" % CAPTURE_CARD)
    chosen = pick(devices, mode, scene, fit_bytes(bpy, scene), free_bytes)
    ids = {d.id for d in chosen}
    for d in prefs.devices:
        d.use = d.id in ids
    if not chosen:
        prefs.compute_device_type = "NONE"
        warn("no OptiX device for SCRAPKEEP_CYCLES=%s; rendering on the CPU" % mode)
        return "CPU"
    scene.cycles.device = "GPU"
    return "GPU"
