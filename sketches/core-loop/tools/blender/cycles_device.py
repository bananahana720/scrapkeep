"""Cycles render device for headless recipes.

`blender -b --factory-startup` ignores the user's preferences, so Cycles renders on the CPU
unless the recipe turns a GPU on itself. `use(scene)` puts the scene on OptiX when an OptiX
device exists and leaves it on the CPU otherwise (cloud containers have no GPU). Call it after
any read_factory_settings or open_mainfile, since both reset the device choice.

SCRAPKEEP_CYCLES picks the mode:
  gpu (default)  one OptiX device: the first whose name holds SCRAPKEEP_CYCLES_GPU
                 (default "4080"), else the first OptiX device. A two-GPU render must fit the
                 3060's 12 GB and competes with model jobs routed to it.
  all            every OptiX device (about 19% faster on small scenes).
  cpu            the CPU, whatever is installed.
Samples, materials and outputs are the recipe's own; only the device changes.
"""
import os

MODE_ENV = "SCRAPKEEP_CYCLES"
NAME_ENV = "SCRAPKEEP_CYCLES_GPU"
NVIDIA_DRIVER = "/proc/driver/nvidia/version"


def optix_devices(prefs):
    try:
        prefs.compute_device_type = "OPTIX"
        prefs.refresh_devices()
    except (AttributeError, TypeError, ValueError):
        return []
    return [d for d in prefs.devices if d.type == "OPTIX"]


def pick(devices, mode, name):
    if mode == "all":
        return list(devices)
    named = [d for d in devices if name and name.lower() in d.name.lower()]
    return (named or list(devices))[:1]


def use(scene):
    """Set scene.cycles.device to GPU or CPU and return which one it got."""
    mode = os.environ.get(MODE_ENV, "gpu").strip().lower()
    scene.cycles.device = "CPU"
    if mode == "cpu" or not os.path.exists(NVIDIA_DRIVER):
        return "CPU"
    import bpy

    prefs = bpy.context.preferences.addons["cycles"].preferences
    devices = optix_devices(prefs)
    chosen = pick(devices, mode, os.environ.get(NAME_ENV, "4080"))
    if not chosen:
        prefs.compute_device_type = "NONE"
        return "CPU"
    ids = {d.id for d in chosen}
    for d in prefs.devices:
        d.use = d.id in ids
    scene.cycles.device = "GPU"
    return "GPU"
