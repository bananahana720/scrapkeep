"""cycles_device.use() under a fake bpy: OptiX cards in tandem when the scene fits, the CPU otherwise.

  python3 sketches/core-loop/tools/blender/cycles_device_test.py
"""
import contextlib
import fcntl
import io
import os
import sys
import tempfile
import types
import unittest
from unittest.mock import patch

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cycles_device

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


TANDEM_AT = 2e10
LONG = 16384
SHORT = 256


def fake_bpy(prefs, triangles=0, images=(), samples=SHORT, adaptive=False):
    render = types.SimpleNamespace(engine="CYCLES", resolution_x=1920, resolution_y=1080, resolution_percentage=100)
    scene = types.SimpleNamespace(cycles=types.SimpleNamespace(device="GPU", samples=samples,
                                                               use_adaptive_sampling=adaptive), render=render,
                                  objects=[mesh(triangles)])
    addon = types.SimpleNamespace(preferences=prefs)
    context = types.SimpleNamespace(preferences=types.SimpleNamespace(addons={"cycles": addon}), scene=scene)
    data = types.SimpleNamespace(images=[types.SimpleNamespace(size=s, is_float=f) for s, f in images])
    def persistent(f):
        f._bpy_persistent = True
        return f
    app = types.SimpleNamespace(handlers=types.SimpleNamespace(render_pre=[], persistent=persistent))
    return types.SimpleNamespace(context=context, data=data, app=app), scene


class UseTest(unittest.TestCase):
    def setUp(self):
        self.driver = tempfile.NamedTemporaryFile()
        self.addCleanup(self.driver.close)
        self.lock = tempfile.NamedTemporaryFile()
        self.addCleanup(self.lock.close)
        self.marker = self.lock.name + ".active"
        self.tandem_min = TANDEM_AT

    def run_use(self, gpus, env=None, driver=True, refuse=False, free=None, triangles=0, images=(), samples=SHORT,
                then=None, adaptive=False):
        prefs = Prefs(gpus, refuse)
        bpy, scene = fake_bpy(prefs, triangles, images, samples, adaptive)
        self.bpy, self.scene = bpy, scene
        path = self.driver.name if driver else self.driver.name + ".missing"
        with patch.dict(sys.modules, {"bpy": bpy}), patch.dict(os.environ, env or {}, clear=True), \
                patch.object(cycles_device, "_warned", set()), \
                patch.object(cycles_device, "TANDEM_MIN", self.tandem_min), \
                patch.object(cycles_device, "NVIDIA_DRIVER", path), \
                patch.object(cycles_device, "free_bytes", lambda: dict(free or {})), \
                patch.object(cycles_device, "CAPTURE_FILE", self.marker), \
                patch.object(cycles_device, "CAPTURE_LOCK", self.lock.name), \
                contextlib.redirect_stderr(io.StringIO()) as err:
            got = cycles_device.use(scene)
            if then:
                then(bpy, scene)
                for handler in bpy.app.handlers.render_pre:
                    handler(scene)
                got = scene.cycles.device
        self.stderr = err.getvalue()
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
        got, prefs, used = self.run_use(BOTH, free={R3060: 11 * GIB, R4080: 15 * GIB}, triangles=200_000, samples=LONG)
        self.assertEqual((got, prefs.compute_device_type, used), ("GPU", "OPTIX", BOTH))
        self.assertFalse(prefs.devices[0].use)

    def test_default_runs_both_cards_when_nvidia_smi_cannot_answer(self):
        got, _, used = self.run_use(BOTH, samples=LONG)
        self.assertEqual((got, used), ("GPU", BOTH))

    def test_scene_too_big_for_the_3060_takes_the_4080_alone(self):
        got, _, used = self.run_use(BOTH, free={R3060: 11 * GIB, R4080: 15 * GIB}, triangles=10_000_000, samples=LONG)
        self.assertEqual((got, used), ("GPU", [R4080]))

    def test_model_job_on_the_3060_takes_the_4080_alone(self):
        got, _, used = self.run_use(BOTH, free={R3060: 1 * GIB, R4080: 15 * GIB}, samples=LONG)
        self.assertEqual((got, used), ("GPU", [R4080]))

    def test_textures_count_toward_the_fit(self):
        got, _, used = self.run_use(BOTH, free={R3060: 3 * GIB}, images=[((16384, 16384), True)], samples=LONG)
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

    def test_unlisted_card_counts_as_full_once_nvidia_smi_answers(self):
        got, _, used = self.run_use(BOTH, free={R4080: 15 * GIB}, samples=LONG)
        self.assertEqual((got, used), ("GPU", [R4080]))
        self.assertIn("lists no " + R3060, self.stderr)

    def test_held_timing_lock_runs_the_3060_alone(self):
        with open(self.lock.name) as held:
            fcntl.flock(held, fcntl.LOCK_EX)
            got, _, used = self.run_use(BOTH, free={R3060: 11 * GIB, R4080: 15 * GIB}, samples=LONG)
        self.assertEqual((got, used), ("GPU", [R3060]))
        self.assertIn("capture running", self.stderr)

    def test_free_timing_lock_keeps_tandem(self):
        got, _, used = self.run_use(BOTH, free={R3060: 11 * GIB, R4080: 15 * GIB}, samples=LONG)
        self.assertEqual((got, used), ("GPU", BOTH))

    def test_capture_marker_runs_the_3060_alone(self):
        open(self.marker, "w").close()
        self.addCleanup(os.remove, self.marker)
        got, _, used = self.run_use(BOTH)
        self.assertEqual((got, used), ("GPU", [R3060]))

    def test_capture_without_a_3060_never_touches_the_4080(self):
        open(self.marker, "w").close()
        self.addCleanup(os.remove, self.marker)
        got, _, used = self.run_use([R4080])
        self.assertEqual((got, used), ("CPU", []))
        self.assertIn("rendering on the CPU", self.stderr)

    def test_explicit_mode_overrides_a_capture(self):
        open(self.marker, "w").close()
        self.addCleanup(os.remove, self.marker)
        got, _, used = self.run_use(BOTH, {"SCRAPKEEP_CYCLES": "all"})
        self.assertEqual((got, used), ("GPU", BOTH))

    def test_short_render_takes_the_4080_alone_even_when_it_fits(self):
        got, _, used = self.run_use(BOTH, free={R3060: 11 * GIB, R4080: 15 * GIB})
        self.assertEqual((got, used), ("GPU", [R4080]))

    def at_size(self, size, samples, adaptive):
        def at(bpy, scene):
            scene.render.resolution_x, scene.render.resolution_y = size, size * 3 // 4
            scene.cycles.samples = samples
            scene.cycles.use_adaptive_sampling = adaptive
        got, _, used = self.run_use(BOTH, free={R3060: 11 * GIB, R4080: 15 * GIB}, then=at)
        return got, used

    def test_default_has_no_size_floor(self):
        self.assertEqual(cycles_device.TANDEM_MIN, 0)

    def test_measured_adaptive_losses_stay_on_the_4080(self):
        self.tandem_min = cycles_device.TANDEM_MIN
        for size, samples in ((1920, 256), (1920, 1024), (3840, 512), (3840, 1024), (3840, 4096), (7680, 2048),
                              (7680, 65536)):
            self.assertEqual(self.at_size(size, samples, True), ("GPU", [R4080]), (size, samples))

    def test_measured_adaptive_off_wins_run_both_cards(self):
        self.tandem_min = cycles_device.TANDEM_MIN
        for size, samples in ((1920, 1024), (3840, 1024)):
            self.assertEqual(self.at_size(size, samples, False), ("GPU", BOTH), (size, samples))

    def test_adaptive_off_short_render_runs_both_cards(self):
        self.tandem_min = cycles_device.TANDEM_MIN
        self.assertEqual(self.at_size(960, 24, False), ("GPU", BOTH))

    def test_adaptive_off_too_big_for_the_3060_takes_the_4080_alone(self):
        self.tandem_min = cycles_device.TANDEM_MIN
        got, _, used = self.run_use(BOTH, free={R3060: 1 * GIB, R4080: 15 * GIB})
        self.assertEqual((got, used), ("GPU", [R4080]))

    def test_scene_without_the_setting_counts_as_adaptive(self):
        self.tandem_min = 0
        def drop(bpy, scene):
            del scene.cycles.use_adaptive_sampling
        got, _, used = self.run_use(BOTH, free={R3060: 11 * GIB, R4080: 15 * GIB}, samples=LONG, then=drop)
        self.assertEqual((got, used), ("GPU", [R4080]))

    def test_threshold_is_tunable(self):
        self.tandem_min = 1e8
        got, _, used = self.run_use(BOTH, free={R3060: 11 * GIB, R4080: 15 * GIB})
        self.assertEqual((got, used), ("GPU", BOTH))

    def test_render_pre_redecides_from_the_final_samples(self):
        def raise_samples(bpy, scene):
            scene.cycles.samples = LONG
        got, _, used = self.run_use(BOTH, free={R3060: 11 * GIB, R4080: 15 * GIB}, then=raise_samples)
        self.assertEqual((got, used), ("GPU", BOTH))

    def test_render_pre_sees_a_capture_that_starts_later(self):
        def start_capture(bpy, scene):
            open(self.marker, "w").close()
            self.addCleanup(os.remove, self.marker)
        got, _, used = self.run_use(BOTH, samples=LONG, then=start_capture)
        self.assertEqual((got, used), ("GPU", [R3060]))

    def test_render_pre_is_armed_once_and_persistent(self):
        def again(bpy, scene):
            cycles_device.use(scene)
        self.run_use(BOTH, then=again)
        handlers = self.bpy.app.handlers.render_pre
        self.assertEqual(len(handlers), 1)
        self.assertTrue(handlers[0]._bpy_persistent)

    def test_cpu_mode_arms_nothing(self):
        self.run_use(BOTH, {"SCRAPKEEP_CYCLES": "cpu"})
        self.assertEqual(self.bpy.app.handlers.render_pre, [])

    def test_cpu_mode_forces_cpu(self):
        got, prefs, used = self.run_use(BOTH, {"SCRAPKEEP_CYCLES": "cpu"})
        self.assertEqual((got, prefs.compute_device_type, used), ("CPU", "NONE", []))


class FreeBytesTest(unittest.TestCase):
    def test_parses_nvidia_smi_rows(self):
        done = types.SimpleNamespace(stdout=R4080 + ", 15000\n" + R3060 + ", 11000\n")
        with patch.object(cycles_device.subprocess, "run", lambda *a, **k: done):
            self.assertEqual(cycles_device.free_bytes(), {R4080: 15000 << 20, R3060: 11000 << 20})

    def test_missing_nvidia_smi_answers_nothing(self):
        def missing(*a, **k):
            raise FileNotFoundError("nvidia-smi")
        with patch.object(cycles_device.subprocess, "run", missing), contextlib.redirect_stderr(io.StringIO()) as err:
            self.assertEqual(cycles_device.free_bytes(), {})
        self.assertIn("assuming 12 GiB", err.getvalue())


if __name__ == "__main__":
    unittest.main()
