"""cycles_device.use() under a fake bpy: OptiX when present, the CPU otherwise.

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


def fake_bpy(prefs):
    scene = types.SimpleNamespace(cycles=types.SimpleNamespace(device="GPU"))
    addon = types.SimpleNamespace(preferences=prefs)
    context = types.SimpleNamespace(preferences=types.SimpleNamespace(addons={"cycles": addon}), scene=scene)
    return types.SimpleNamespace(context=context), scene


BOTH = ["NVIDIA GeForce RTX 3060", "NVIDIA GeForce RTX 4080"]


class UseTest(unittest.TestCase):
    def setUp(self):
        self.driver = tempfile.NamedTemporaryFile()
        self.addCleanup(self.driver.close)

    def run_use(self, gpus, env=None, driver=True, refuse=False):
        prefs = Prefs(gpus, refuse)
        bpy, scene = fake_bpy(prefs)
        path = self.driver.name if driver else self.driver.name + ".missing"
        with patch.dict(sys.modules, {"bpy": bpy}), patch.dict(os.environ, env or {}, clear=True), \
                patch.object(cycles_device, "NVIDIA_DRIVER", path):
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

    def test_default_is_the_4080_alone(self):
        got, prefs, used = self.run_use(BOTH)
        self.assertEqual((got, prefs.compute_device_type, used), ("GPU", "OPTIX", ["NVIDIA GeForce RTX 4080"]))
        self.assertFalse(prefs.devices[0].use)

    def test_all_uses_every_optix_device(self):
        got, _, used = self.run_use(BOTH, {"SCRAPKEEP_CYCLES": "all"})
        self.assertEqual((got, used), ("GPU", BOTH))

    def test_name_match_picks_another_card(self):
        got, _, used = self.run_use(BOTH, {"SCRAPKEEP_CYCLES_GPU": "3060"})
        self.assertEqual((got, used), ("GPU", ["NVIDIA GeForce RTX 3060"]))

    def test_no_name_match_takes_the_first_optix_device(self):
        got, _, used = self.run_use(["NVIDIA RTX A4000"])
        self.assertEqual((got, used), ("GPU", ["NVIDIA RTX A4000"]))

    def test_cpu_mode_forces_cpu(self):
        got, prefs, used = self.run_use(BOTH, {"SCRAPKEEP_CYCLES": "cpu"})
        self.assertEqual((got, prefs.compute_device_type, used), ("CPU", "NONE", []))


if __name__ == "__main__":
    unittest.main()
