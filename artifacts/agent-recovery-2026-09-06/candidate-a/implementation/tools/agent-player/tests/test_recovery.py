import json
import unittest
from pathlib import Path

from PIL import Image, ImageDraw
from observer import scene_sample, scene_change
from policy import Policy


def target(x=640, y=450, width=12):
    return dict(x=x, y=y, box=(x - width / 2, y - 4, x + width / 2, y + 4))


def observe(policy, targets=(), change=None, dt=0.1):
    policy.step(dt)
    policy.aim(dict(id=policy.elapsed, width=1280, height=900, targets=list(targets), scene_change=change))


class TargetContinuityTests(unittest.TestCase):
    def test_distractor_nearer_crosshair_does_not_replace_selected_target(self):
        p = Policy()
        observe(p, [target(800)])
        selected_at = p.track.selected_at
        observe(p, [target(795), target(642)])
        self.assertEqual(p.track.x, 795)
        self.assertEqual(p.track.selected_at, selected_at)

    def test_short_occlusion_retains_track_then_reacquires(self):
        p = Policy()
        observe(p, [target(800)])
        selected_at = p.track.selected_at
        observe(p, [target(640)], dt=0.3)
        self.assertEqual(p.recovery.phase, "occluded")
        self.assertEqual(p.track.x, 800)
        observe(p, [target(780), target(640)], dt=0.3)
        self.assertEqual(p.track.selected_at, selected_at)
        self.assertEqual(p.track.x, 780)
        self.assertEqual(p.recovery.phase, "track")

    def test_expired_track_is_discarded_despite_unrelated_detection(self):
        p = Policy()
        observe(p, [target(850)])
        observe(p, [target(400)], dt=0.8)
        self.assertEqual(p.track.x, 400)
        self.assertEqual(p.track.last_seen, p.elapsed)

    def test_persistent_face_recovers_even_when_pixels_change(self):
        p = Policy()
        for _ in range(49):
            observe(p, [target()], dict(changed_fraction=0.8, mean_luma_delta=60))
        self.assertEqual(p.recovery.reason, "no_apparent_approach")
        self.assertIn(p.recovery.phase, ("back", "side"))

    def test_apparent_approach_delays_no_progress_without_claiming_translation(self):
        p = Policy()
        for i in range(30):
            observe(p, [target(width=8 + i * 0.2)], dt=0.15)
        self.assertEqual(p.recovery.phase, "track")
        self.assertEqual(p.diagnostics()["progress_evidence"]["world_translation"], "unverified")

    def test_search_and_escape_move_and_each_escape_exits_on_time(self):
        p = Policy()
        phases = []
        starts = []
        for _ in range(200):
            observe(p)
            self.assertTrue(p.motion.keys)
            self.assertNotIn("Space", p.step(0).keys)
            phases.append(p.recovery.phase)
            if p.recovery.phase == "back" and (len(phases) == 1 or phases[-2] != "back"):
                starts.append((p.elapsed, p.recovery.side))
            self.assertLess(p.elapsed - p.recovery.started, 3.11)
        self.assertTrue({"search", "back", "side", "advance"}.issubset(phases))
        self.assertGreaterEqual(len(starts), 3)
        self.assertNotEqual(starts[0][1], starts[1][1])

    def test_reacquisition_cannot_cancel_escape_but_escape_ends(self):
        p = Policy()
        observe(p)
        observe(p, dt=3.1)
        self.assertEqual(p.recovery.phase, "back")
        for _ in range(27):
            observe(p, [target()])
            self.assertNotEqual(p.recovery.phase, "track")
        observe(p, [target()], dt=0.2)
        self.assertEqual(p.recovery.phase, "track")

    def test_diagnostics_are_small_json(self):
        p = Policy()
        observe(p, [target()])
        data = json.dumps(p.diagnostics())
        self.assertLess(len(data), 1000)
        self.assertIn("selected_track", data)


class SceneEvidenceTests(unittest.TestCase):
    def test_retained_identical_frame_is_frozen_and_different_view_changes(self):
        fixtures = Path(__file__).parent / "fixtures"
        a = scene_sample(Image.open(fixtures / "workers.jpg"))
        b = scene_sample(Image.open(fixtures / "nameplate.jpg"))
        frozen = scene_change(a, a)
        changed = scene_change(a, b)
        self.assertEqual(frozen["changed_fraction"], 0)
        self.assertGreater(changed["changed_fraction"], 0.015)
        p = Policy()
        for _ in range(23):
            observe(p, [target()], frozen)
        self.assertEqual(p.recovery.reason, "unchanged_scene")
        p = Policy()
        for _ in range(23):
            observe(p, [target()], changed)
        self.assertEqual(p.recovery.phase, "track")

    def test_center_avatar_and_hud_motion_cannot_claim_scene_change(self):
        im = Image.new("RGB", (1280, 900), (150, 180, 120))
        before = scene_sample(im)
        d = ImageDraw.Draw(im)
        d.rectangle((400, 250, 880, 700), fill="red")
        d.rectangle((0, 0, 1280, 190), fill="white")
        d.rectangle((0, 730, 1280, 899), fill="black")
        self.assertEqual(scene_change(before, scene_sample(im))["changed_fraction"], 0)

    def test_signed_luma_difference_handles_both_directions(self):
        dark = scene_sample(Image.new("RGB", (1280, 900), "black"))
        light = scene_sample(Image.new("RGB", (1280, 900), "white"))
        self.assertEqual(scene_change(dark, light), scene_change(light, dark))
        self.assertEqual(scene_change(dark, light)["mean_luma_delta"], 255)
