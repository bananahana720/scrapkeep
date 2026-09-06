import unittest
from pathlib import Path

from observer import SceneChange, upper_ground_fraction
from PIL import Image, ImageDraw
from policy import Intent, Policy


def target(x=630, y=400, width=12):
    return {"x": x, "y": y, "box": [x - width / 2, y - 4, x + width / 2, y + 4]}


def feed(policy, targets=(), dt=0.1, change=None):
    policy.step(dt)
    frame = {
        "id": policy.elapsed,
        "width": 1280,
        "height": 900,
        "targets": list(targets),
        "lower_sky_fraction": 0,
    }
    if change is not None:
        frame["scene_change"] = {"changed_fraction": change}
    policy.aim(frame)
    return policy.diagnostics()


class TargetContinuityTests(unittest.TestCase):
    def test_selected_face_survives_crosshair_distractor(self):
        policy = Policy()
        feed(policy, [target(770)])
        selected = policy.track.number
        feed(policy, [target(764), target(640)])
        self.assertEqual(policy.track.number, selected)
        self.assertEqual(policy.track.x, 764)

    def test_brief_occlusion_holds_identity_without_chasing_distractor(self):
        policy = Policy()
        feed(policy, [target(900)])
        selected = policy.track.number
        feed(policy, [target(640)], dt=0.3)
        self.assertEqual(policy.recovery.phase, "occluded")
        self.assertFalse(policy.motion.keys)
        feed(policy, [target(885), target(640)], dt=0.3)
        self.assertEqual(policy.track.number, selected)
        self.assertEqual(policy.track.x, 885)

    def test_track_expiry_allows_new_selection(self):
        policy = Policy()
        feed(policy, [target(900)])
        selected = policy.track.number
        feed(policy, [target(640)], dt=0.9)
        self.assertGreater(policy.track.number, selected)
        self.assertEqual(policy.track.x, 640)

    def test_returning_geometry_after_grace_starts_a_new_track(self):
        policy = Policy()
        feed(policy, [target(800)])
        selected = policy.track.number
        feed(policy, dt=0.3)
        feed(policy, dt=0.3)
        feed(policy, [target(800)], dt=0.3)
        self.assertGreater(policy.track.number, selected)

    def test_association_prefers_similar_size_over_a_closer_different_box(self):
        policy = Policy()
        feed(policy, [target(800)])
        feed(policy, [target(810), target(801, width=20)])
        self.assertEqual(policy.track.x, 810)

    def test_distant_face_requests_forward_movement(self):
        policy = Policy()
        feed(policy, [target()])
        self.assertIn("KeyW", policy.motion.keys)

    def test_image_change_does_not_hide_stagnant_target_geometry(self):
        policy = Policy()
        for _ in range(82):
            feed(policy, [target()], change=0.8)
            if policy.recovery.phase == "reverse":
                break
        self.assertEqual(policy.recovery.reason, "target_no_progress")
        self.assertEqual(policy.recovery.phase, "reverse")

    def test_target_growth_prevents_premature_escape(self):
        policy = Policy()
        for i in range(65):
            feed(policy, [target(width=10 + i / 3)], change=0.8)
        self.assertEqual(policy.recovery.phase, "track")
        self.assertEqual(policy.recovery.attempt, 0)


class RecoveryBoundsTests(unittest.TestCase):
    def test_long_search_keeps_turning_through_a_full_camera_sweep(self):
        policy = Policy()
        yaw = 0
        for _ in range(450):
            feed(policy, change=0.3)
            self.assertGreaterEqual(policy.motion.look[0], 0)
            yaw += policy.motion.look[0] * 0.1
        self.assertGreater(yaw * 0.003, 6.2832)

    def test_lost_target_escape_has_bounded_straight_relocation(self):
        policy = Policy()
        for _ in range(54):
            feed(policy, change=0.3)
        self.assertEqual(policy.recovery.phase, "relocate")
        self.assertEqual(policy.motion.keys, ("KeyW",))
        self.assertEqual(policy.motion.look[0], 0)
        feed(policy, dt=3, change=0.3)
        self.assertNotEqual(policy.recovery.phase, "relocate")

    def test_fresh_target_interrupts_relocation(self):
        policy = Policy()
        for _ in range(54):
            feed(policy, change=0.3)
        self.assertEqual(policy.recovery.phase, "relocate")
        feed(policy, [target(800)], change=0.3)
        self.assertEqual(policy.recovery.phase, "track")
        self.assertGreater(policy.motion.look[0], 0)

    def test_repeated_relocation_is_capped_and_leaves_time_to_scan(self):
        policy = Policy()
        durations, scan_durations = [], []
        previous = None
        scan_start = None
        for _ in range(900):
            feed(policy, change=0.3)
            phase = policy.recovery.phase
            if phase == "relocate" and previous != phase:
                durations.append(policy.recovery.until - policy.recovery.started)
            if previous == "relocate" and phase == "search":
                scan_start = policy.elapsed
            if scan_start is not None and phase == "reverse":
                scan_durations.append(policy.elapsed - scan_start)
                scan_start = None
            previous = phase
        self.assertGreater(durations[-1], durations[0])
        self.assertLessEqual(max(durations), 5)
        self.assertGreaterEqual(len(scan_durations), 5)
        self.assertTrue(all(seconds >= 2.99 for seconds in scan_durations))

    def test_relocation_corrects_bad_framing_without_advancing(self):
        policy = Policy()
        for _ in range(54):
            feed(policy, change=0.3)
        policy.aim(
            dict(id=55, width=1280, height=900, targets=[], lower_sky_fraction=0.9)
        )
        self.assertEqual(policy.recovery.phase, "relocate")
        self.assertEqual(policy.motion.keys, ())
        self.assertGreater(policy.motion.look[1], 0)

    def test_new_target_does_not_reset_an_in_flight_escape_number(self):
        policy = Policy()
        for _ in range(17):
            feed(policy, change=0)
        self.assertEqual(policy.recovery.phase, "reverse")
        self.assertEqual(policy.recovery.attempt, 1)
        feed(policy, [target()], change=0.7)
        self.assertEqual(policy.recovery.phase, "reverse")
        self.assertEqual(policy.recovery.attempt, 1)
        for _ in range(90):
            feed(policy, [target()], change=0.7)
        self.assertEqual(policy.recovery.attempt, 2)
        self.assertEqual(policy.recovery.side, "KeyD")

    def test_search_moves_and_each_escape_phase_has_bounded_exit(self):
        policy = Policy()
        phases = set()
        seen_forward = False
        for _ in range(600):
            feed(policy, change=0.3)
            phases.add(policy.recovery.phase)
            seen_forward |= "KeyW" in policy.motion.keys
        self.assertTrue(seen_forward)
        self.assertTrue(
            {"search", "reverse", "lateral", "settle", "relocate"} <= phases
        )
        self.assertGreater(policy.recovery.attempt, 4)
        self.assertLess(policy.elapsed - policy.recovery.started, 6.1)

    def test_fresh_identical_frames_trigger_repeated_bounded_escapes(self):
        policy = Policy()
        for _ in range(30):
            feed(policy, change=0)
        self.assertEqual(policy.recovery.reason, "scene_unchanged")
        transitions = []
        for _ in range(330):
            feed(policy, change=0)
            transitions.append(policy.recovery.phase)
            self.assertLess(policy.elapsed - policy.recovery.started, 6.1)
        self.assertGreater(policy.recovery.attempt, 4)
        self.assertIn("search", transitions[-30:])

    def test_new_face_returns_long_search_to_tracking_after_escape_finishes(self):
        policy = Policy()
        for _ in range(360):
            feed(policy, change=0)
        feed(policy, [target()], change=0.7)
        feed(policy, [target()], dt=2.1, change=0.7)
        self.assertEqual(policy.recovery.phase, "track")
        self.assertIn("KeyW", policy.motion.keys)

    def test_escape_completion_does_not_report_unobserved_target_progress(self):
        policy = Policy()
        for _ in range(110):
            feed(policy, [target()], change=0.3)
        self.assertGreater(policy.diagnostics()["track"]["no_progress_seconds"], 10)

    def test_long_step_does_not_extend_escape_deadline(self):
        policy = Policy()
        feed(policy)
        feed(policy, dt=3.1)
        self.assertEqual(policy.recovery.phase, "reverse")
        feed(policy, dt=4.6)
        self.assertEqual(policy.recovery.phase, "search")

    def test_passive_has_no_tracking_or_recovery_input(self):
        policy = Policy("passive")
        for _ in range(400):
            feed(policy, [target()], change=0)
        self.assertEqual(policy.step(0.2), Intent())
        self.assertIsNone(policy.track)


class ImageEvidenceTests(unittest.TestCase):
    def test_retained_downward_views_are_separate_from_worker_view(self):
        directory = Path(__file__).parent / "fixtures"
        for name in ("ground-stall.jpg", "boundary-stall.jpg"):
            self.assertGreater(
                upper_ground_fraction(Image.open(directory / name)), 0.55
            )
        self.assertLess(
            upper_ground_fraction(Image.open(directory / "workers.jpg")), 0.20
        )

    def test_downward_recovery_looks_up_until_the_view_levels(self):
        policy = Policy()
        for ground, expected in ((0.8, -150), (0.3, -150), (0.1, 0)):
            policy.aim(
                dict(
                    id=ground,
                    width=1280,
                    height=900,
                    targets=[],
                    upper_ground_fraction=ground,
                )
            )
            self.assertEqual(policy.step(0.02).look[1], expected)

    def test_brief_detections_cannot_restart_every_vertical_sweep_downward(self):
        policy = Policy()
        search_pitch = []
        for i in range(160):
            feed(policy, [target(800, 450)] if i % 20 == 0 else [])
            if policy.recovery.phase == "search":
                search_pitch.append(policy.motion.look[1])
        self.assertTrue(any(y > 0 for y in search_pitch))
        self.assertTrue(any(y < 0 for y in search_pitch))
        self.assertLess(abs(sum(search_pitch)), 500)

    def test_repeated_real_scene_and_changed_real_scene_are_distinct(self):
        directory = Path(__file__).parent / "fixtures"
        first = Image.open(directory / "workers.jpg")
        second = Image.open(directory / "nameplate.jpg")
        evidence = SceneChange()
        self.assertIsNone(evidence.measure(first)["changed_fraction"])
        self.assertEqual(evidence.measure(first)["changed_fraction"], 0)
        self.assertGreater(evidence.measure(second)["changed_fraction"], 0.05)

    def test_avatar_and_hud_changes_do_not_count_as_background_change(self):
        first = Image.new("RGB", (1280, 960), "gray")
        second = first.copy()
        draw = ImageDraw.Draw(second)
        draw.rectangle((410, 200, 869, 700), fill="white")
        draw.rectangle((0, 0, 1279, 100), fill="white")
        evidence = SceneChange()
        evidence.measure(first)
        self.assertEqual(evidence.measure(second)["changed_fraction"], 0)
