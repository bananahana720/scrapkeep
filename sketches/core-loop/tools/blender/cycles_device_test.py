"""cycles_device.use() under a fake bpy: OptiX cards in tandem when the scene fits, the CPU otherwise.

  python3 sketches/core-loop/tools/blender/cycles_device_test.py
"""
import os
import sys
import tempfile
import types
import unittest
from unittest.mock import patch

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cycles_device  # noqa: E402

GIB = cycles_device.GIB
R3060, R4080 = "NVIDIA GeForce RTX 3060", "NVIDIA GeForce RTX 4080"
BOTH = [R3060, R4080]


class Device:
    def __init__(self, name, type_):
        self.name, self.type, self.id, self.use = name, type_, type_ + ":" + name, True


class Prefs:
    def __init__(self, gpus, refuse=False):
        self.gpus, self.refuse = gpus, refuse
        self._type, self.devices = "NONE", []

    @property
    def compute_device_type(self):
        return self._type

    @compute_device_type.setter
    def compute_device_type(self, value):
        if self.refuse and value == "OPTIX":
            raise TypeError("enum \"OPTIX\" not found")
        self._type = value

    def refresh_devices(self):
        self.devices = [Device("Intel Xeon", "CPU")]
        if self._type == "OPTIX":
            self.devices += [Device(n, "OPTIX") for n in self.gpus]


def mesh(triangles):
    return types.SimpleNamespace(type="MESH", data=types.SimpleNamespace(loops=[0] * (3 * triangles),
                                                                         polygons=[0] * triangles))


def fake_bpy(prefs, triangles=0, images=()):
    scene = types.SimpleNamespace(cycles=types.SimpleNamespace(device="GPU"), objects=[mesh(triangles)])
    addon = types.SimpleNamespace(preferences=prefs)
    context = types.SimpleNamespace(preferences=types.SimpleNamespace(addons={"cycles": addon}), scene=scene)
    data = types.SimpleNamespace(images=[types.SimpleNamespace(size=s, is_float=f) for s, f in images])
    return types.SimpleNamespace(context=context, data=data), scene


class UseTest(unittest.TestCase):
    def setUp(self):
        self.driver = tempfile.NamedTemporaryFile()
        self.addCleanup(self.driver.close)

    def run_use(self, gpus, env=None, driver=True, refuse=False, free=None, triangles=0, images=()):
        prefs = Prefs(gpus, refuse)
        bpy, scene = fake_bpy(prefs, triangles, images)
        path = self.driver.name if driver else self.driver.name + ".missing"
        with patch.dict(sys.modules, {"bpy": bpy}), patch.dict(os.environ, env or {}, clear=True), \
                patch.object(cycles_device, "NVIDIA_DRIVER", path), \
                patch.object(cycles_device, "free_bytes", lambda: dict(free or {})):
            got = cycles_device.use(scene)
        self.assertEqual(got, scene.cycles.device)
        return got, prefs, [d.name for d in prefs.devices if d.use and d.type == "OPTIX"]

    def test_no_driver_stays_on_cpu_without_touching_prefs(self):
        got, prefs, used = self.run_use(BOTH, driver=False)
        self.assertEqual((got, prefs.compute_device_type, used), ("CPU", "NONE", []))

    def test_driver_but_no_optix_device_falls_back_to_cpu(self):
        got, prefs, used = self.run_use([])
        self.assertEqual((got, prefs.compute_device_type, used), ("CPU", "NONE", []))

    def test_build_without_optix_falls_back_to_cpu(self):
        got, prefs, used = self.run_use(BOTH, refuse=True)
        self.assertEqual((got, prefs.compute_device_type, used), ("CPU", "NONE", []))

    def test_default_runs_both_cards_when_the_scene_fits(self):
        got, prefs, used = self.run_use(BOTH, free={R3060: 11 * GIB, R4080: 15 * GIB}, triangles=200_000)
        self.assertEqual((got, prefs.compute_device_type, used), ("GPU", "OPTIX", BOTH))
        self.assertFalse(prefs.devices[0].use)

    def test_default_runs_both_cards_when_nvidia_smi_cannot_answer(self):
        got, _, used = self.run_use(BOTH)
        self.assertEqual((got, used), ("GPU", BOTH))

    def test_scene_too_big_for_the_3060_takes_the_4080_alone(self):
        got, _, used = self.run_use(BOTH, free={R3060: 11 * GIB, R4080: 15 * GIB}, triangles=10_000_000)
        self.assertEqual((got, used), ("GPU", [R4080]))

    def test_model_job_on_the_3060_takes_the_4080_alone(self):
        got, _, used = self.run_use(BOTH, free={R3060: 1 * GIB, R4080: 15 * GIB})
        self.assertEqual((got, used), ("GPU", [R4080]))

    def test_textures_count_toward_the_fit(self):
        got, _, used = self.run_use(BOTH, free={R3060: 3 * GIB}, images=[((16384, 16384), True)])
        self.assertEqual((got, used), ("GPU", [R4080]))

    def test_all_skips_the_fit_check(self):
        got, _, used = self.run_use(BOTH, {"SCRAPKEEP_CYCLES": "all"}, free={R3060: 0}, triangles=10_000_000)
        self.assertEqual((got, used), ("GPU", BOTH))

    def test_capture_rule_3060_leaves_the_4080_idle(self):
        got, prefs, used = self.run_use(BOTH, {"SCRAPKEEP_CYCLES": "3060"})
        self.assertEqual((got, used), ("GPU", [R3060]))
        self.assertFalse(next(d for d in prefs.devices if d.name == R4080).use)

    def test_named_card_missing_falls_back_to_cpu(self):
        got, _, used = self.run_use([R4080], {"SCRAPKEEP_CYCLES": "3060"})
        self.assertEqual((got, used), ("CPU", []))

    def test_single_card_runs_alone(self):
        got, _, used = self.run_use(["NVIDIA RTX A4000"])
        self.assertEqual((got, used), ("GPU", ["NVIDIA RTX A4000"]))

    def test_cpu_mode_forces_cpu(self):
        got, prefs, used = self.run_use(BOTH, {"SCRAPKEEP_CYCLES": "cpu"})
        self.assertEqual((got, prefs.compute_device_type, used), ("CPU", "NONE", []))


if __name__ == "__main__":
    unittest.main()
