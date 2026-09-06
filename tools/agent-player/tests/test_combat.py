import sys
import unittest
from contextlib import contextmanager
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from combat import PerceptionFailure, play
from policy import Policy


class Clock:
    value = 0.0

    def now(self):
        return self.value

    def sleep(self, seconds):
        self.value += seconds


class Controller:
    def __init__(self):
        self.events = []

    def set_state(self, *args, **kwargs):
        self.events.append(("state", args, kwargs))

    def tick(self):
        self.events.append(("tick",))

    def release(self):
        self.events.append(("release",))


class Desktop:
    def __init__(self):
        self.controller = Controller()

    @contextmanager
    def native(self):
        try:
            yield self.controller
        finally:
            self.controller.release()


class Evidence:
    def __init__(self):
        self.records = []

    def event(self, *args, **kwargs):
        self.records.append((args, kwargs))

    def frame(self, frame):
        pass


def observer(frame=None, error=None):
    @contextmanager
    def factory(desktop):
        yield type("Observer", (), {"latest": frame, "error": error})()

    return factory


def frame(**changes):
    return dict(
        id=0,
        time=0,
        data=b"",
        width=1280,
        height=900,
        targets=[],
        modal=False,
        capture_ms=20,
        observe_ms=30,
        **changes,
    )


class CombatSafetyTests(unittest.TestCase):
    def run_failure(self, factory, pattern):
        clock = Clock()
        desktop = Desktop()
        evidence = Evidence()
        with self.assertRaisesRegex(PerceptionFailure, pattern):
            play(
                desktop,
                Policy(),
                4,
                evidence,
                observer_factory=factory,
                clock=clock.now,
                sleep=clock.sleep,
            )
        self.assertEqual(desktop.controller.events[-1], ("release",))
        self.assertNotIn("KeyI", str(desktop.controller.events))
        return desktop, evidence

    def test_missing_first_frame_releases_without_toggle(self):
        self.run_failure(observer(), "no first frame")

    def test_capture_exception_releases_without_toggle(self):
        self.run_failure(observer(error=RuntimeError("camera gone")), "capture failed")

    def test_repeated_frame_expires_and_cannot_renew_its_authority(self):
        desktop, evidence = self.run_failure(observer(frame()), "stale frame")
        states = [event for event in desktop.controller.events if event[0] == "state"]
        self.assertTrue(states)
        self.assertLessEqual(max(event[2]["lease_seconds"] for event in states), 0.5)
        self.assertIn("stale frame", evidence.records[-1][1]["reason"])

    def test_menu_cue_releases_before_any_gameplay(self):
        clock = Clock()
        desktop = Desktop()
        evidence = Evidence()
        item = frame()
        item["modal"] = True
        reason = play(
            desktop,
            Policy(),
            4,
            evidence,
            observer_factory=observer(item),
            clock=clock.now,
            sleep=clock.sleep,
        )
        self.assertEqual(reason, "menu_candidate")
        self.assertFalse(
            any(event[0] == "state" for event in desktop.controller.events)
        )
        self.assertEqual(desktop.controller.events[-1], ("release",))

    def test_policy_clock_survives_menu_boundary(self):
        continuous = Policy()
        split = Policy()
        for _ in range(240):
            continuous.step(0.02)
        for _ in range(100):
            split.step(0.02)
        # Menu duration deliberately makes no calls to the active-combat clock.
        for _ in range(140):
            split.step(0.02)
        self.assertEqual(continuous.step(0.02), split.step(0.02))
        self.assertIn("KeyQ", split.step(0.02).keys)

    def test_active_limit_is_reached_within_one_capture_segment(self):
        clock = Clock()
        desktop = Desktop()
        evidence = Evidence()
        policy = Policy()
        reason = play(
            desktop,
            policy,
            4,
            evidence,
            active_limit=0.1,
            observer_factory=observer(frame()),
            clock=clock.now,
            sleep=clock.sleep,
        )
        self.assertEqual(reason, "active_limit")
        self.assertGreaterEqual(policy.elapsed, 0.1)
        self.assertLess(policy.elapsed, 0.13)


class ObserverCleanupTests(unittest.TestCase):
    def test_input_releases_before_slow_observer_cleanup_on_error(self):
        clock = Clock()
        desktop = Desktop()
        evidence = Evidence()

        @contextmanager
        def factory(unused):
            class MovingObserver:
                latest = frame()

                @property
                def error(self):
                    return RuntimeError("capture gone") if clock.value > 0 else None

            try:
                yield MovingObserver()
            finally:
                self.assertEqual(desktop.controller.events[-1], ("release",))

        with self.assertRaisesRegex(PerceptionFailure, "capture gone"):
            play(
                desktop,
                Policy(),
                4,
                evidence,
                observer_factory=factory,
                clock=clock.now,
                sleep=clock.sleep,
            )
        self.assertTrue(any(event[0] == "state" for event in desktop.controller.events))
