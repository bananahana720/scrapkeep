import unittest

from observer import lower_sky_fraction
from PIL import Image
from policy import Policy


def frame(sky=0, targets=None):
    return dict(
        id=0, width=1280, height=900, targets=targets or [], lower_sky_fraction=sky
    )


class FramingRecoveryTests(unittest.TestCase):
    def test_upward_loss_recovers_down_with_hysteresis(self):
        policy = Policy()
        for sky, expected in ((0.9, 150), (0.5, 150), (0.2, 0)):
            policy.aim(frame(sky))
            self.assertEqual(policy.step(0.02).look[1], expected)
        self.assertGreater(policy.elapsed, 0)

    def test_reacquisition_does_not_cancel_bounded_disengagement(self):
        policy = Policy()
        policy.aim(frame(0.9))
        policy.step(3.1)
        policy.aim(frame(0.9))
        self.assertIn("KeyS", policy.motion.keys)
        target = dict(x=640, y=450, box=[630, 440, 650, 455])
        policy.aim(frame(0.9, [target]))
        self.assertFalse(policy.recovering_sky)
        self.assertIn("KeyS", policy.motion.keys)
        self.assertEqual(policy.motion.look[0], 0)
        policy.step(3)
        policy.aim(frame(0.9, [target]))
        self.assertNotIn("KeyS", policy.motion.keys)
        self.assertEqual(policy.motion.look, (0, 0))

    def test_search_backpedal_is_bounded_and_passive_never_moves(self):
        policy = Policy()
        policy.aim(frame())
        policy.step(3.1)
        policy.aim(frame())
        self.assertIn("KeyS", policy.motion.keys)
        self.assertEqual(policy.motion.look[0], 0)
        self.assertNotIn("ShiftLeft", policy.step(0.02).keys)
        policy.step(3)
        policy.aim(frame())
        self.assertNotIn("KeyS", policy.motion.keys)
        self.assertTrue(policy.motion.keys)
        passive = Policy("passive")
        passive.aim(frame(0.99))
        self.assertFalse(passive.step(20).keys)
        self.assertEqual(passive.step(0.02).look, (0, 0))

    def test_sky_measurement_does_not_mistake_ground(self):
        self.assertEqual(
            lower_sky_fraction(Image.new("RGB", (1280, 900), (181, 205, 209))), 1
        )
        self.assertEqual(
            lower_sky_fraction(Image.new("RGB", (1280, 900), (229, 230, 188))), 0
        )

    def test_targetless_search_scans_both_directions_without_jumping(self):
        policy = Policy()
        policy.aim(frame())
        policy.step(2.05)
        policy.aim(frame())
        self.assertGreater(policy.motion.look[1], 0)
        self.assertNotIn("Space", policy.step(0.02).keys)
        policy.step(1.1)
        policy.aim(frame())
        self.assertEqual(policy.recovery.phase, "back")
        policy.step(2.9)
        policy.aim(frame())
        policy.step(1.1)
        policy.aim(frame())
        self.assertLess(policy.motion.look[1], 0)
