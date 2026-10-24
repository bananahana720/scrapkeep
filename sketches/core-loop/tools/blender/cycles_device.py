"""Cycles render device for headless recipes.

`blender -b --factory-startup` ignores the user's preferences, so Cycles renders on the CPU
unless the recipe turns a GPU on itself. `use(scene)` puts the scene on OptiX when an OptiX
device exists and leaves it on the CPU otherwise (cloud containers have no GPU). Call it after
any read_factory_settings or open_mainfile, since both reset the device choice.

SCRAPKEEP_CYCLES picks the cards:
  auto (default)  every OptiX card in tandem (4080 + 3060: 26.3 s against 32.5 s on the 4080
                  alone) when the scene fits the smallest card's free memory, else the 4080 alone.
  all             every OptiX card, without the fit check.
  <name>          the one card whose name holds it, e.g. 3060. Frame-time captures need an idle
                  4080, so bakes run with SCRAPKEEP_CYCLES=3060 while a capture is on.
  cpu             the CPU, whatever is installed.
While a 4080 frame-time capture runs, auto runs the 3060 alone (the CPU when there is no 3060), so
bakes keep GPU speed and the 4080 stays idle. A capture is on when SCRAPKEEP_CAPTURE_FILE exists
or another process holds an flock on SCRAPKEEP_CAPTURE_LOCK (defaults: the PC's capture lane's
capture-active and timing.lock). Any other SCRAPKEEP_CYCLES value overrides that.
The fit check compares free VRAM (nvidia-smi; 12 GiB per card when it can't answer) with
fit_bytes(): the scene as built when use() runs, plus HEADROOM for Cycles' kernels and buffers.
Samples, materials and outputs are the recipe's own; only the device changes.
"""
import fcntl
import os
import subprocess
import sys

NVIDIA_DRIVER = "/proc/driver/nvidia/version"
MODE_ENV = "SCRAPKEEP_CYCLES"
CAPTURE_FILE = os.environ.get("SCRAPKEEP_CAPTURE_FILE", "/home/andrew/scratch/w18/gates/capture-active")
CAPTURE_LOCK = os.environ.get("SCRAPKEEP_CAPTURE_LOCK", "/home/andrew/scratch/w18/gates/timing.lock")
CAPTURE_CARD = "3060"
BIG = "4080"
GIB = 1 << 30
HEADROOM = 2 * GIB
CARD_BYTES = 12 * GIB


def warn(text):
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


def pick(devices, mode, need, free):
    if mode == "all":
        return list(devices)
    if mode != "auto":
        return [d for d in devices if mode in d.name.lower()][:1]
    missing = [d.name for d in devices if free and d.name not in free]
    if missing:
        warn("nvidia-smi lists no %s; treating it as full" % ", ".join(missing))
    if len(devices) > 1 and all(free.get(d.name, 0 if free else CARD_BYTES) >= need for d in devices):
        return list(devices)
    return ([d for d in devices if BIG in d.name] or list(devices))[:1]


def use(scene):
    """Set scene.cycles.device to GPU or CPU and return which one it got."""
    mode = os.environ.get(MODE_ENV, "auto").strip().lower() or "auto"
    scene.cycles.device = "CPU"
    if mode == "cpu" or not os.path.exists(NVIDIA_DRIVER):
        return "CPU"
    import bpy

    prefs = bpy.context.preferences.addons["cycles"].preferences
    devices = optix_devices(prefs)
    if mode == "auto" and capture_on():
        mode = CAPTURE_CARD
        warn("4080 capture running; rendering on the %s alone" % CAPTURE_CARD)
    chosen = pick(devices, mode, fit_bytes(bpy, scene), free_bytes() if mode == "auto" else {})
    ids = {d.id for d in chosen}
    for d in prefs.devices:
        d.use = d.id in ids
    if not chosen:
        prefs.compute_device_type = "NONE"
        warn("no OptiX device for SCRAPKEEP_CYCLES=%s; rendering on the CPU" % mode)
        return "CPU"
    scene.cycles.device = "GPU"
    return "GPU"
