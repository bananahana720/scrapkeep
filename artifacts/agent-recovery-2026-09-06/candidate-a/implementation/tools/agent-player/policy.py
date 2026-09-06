"""Visual target continuity and bounded recovery through one input owner."""

from dataclasses import dataclass
from math import hypot


@dataclass
class Intent:
    keys: tuple = ()
    buttons: tuple = ()
    look: tuple = (0.0, 0.0)


@dataclass
class TargetTrack:
    x: float
    y: float
    box: tuple
    last_seen: float
    selected_at: float
    reference_width: float
    progress_at: float

    @property
    def width(self):
        return self.box[2] - self.box[0]


@dataclass
class RecoveryState:
    phase: str = "search"
    reason: str = "no_target"
    started: float = 0.0
    side: str = "KeyA"


ESCAPE_PHASES = {"back": 0.8, "side": 0.8, "advance": 1.2}


class Policy:
    def __init__(self, profile="visual"):
        self.profile = profile
        self.elapsed = 0.0
        self.last_frame = None
        self.motion = Intent()
        self.target_count = 0
        self.track = None
        self.recovery = RecoveryState()
        self.recovering_sky = False
        self.still_since = None
        self.scene_change = None
        self.approach_evidence = "unobserved"

    def _select(self, frame):
        targets = frame["targets"]
        current = self.track
        if current is not None:
            gate = max(frame["width"] * 0.12, current.width * 3)
            matches = [
                t for t in targets
                if hypot(t["x"] - current.x, t["y"] - current.y) <= gate
                and 0.4 <= (t["box"][2] - t["box"][0]) / max(1, current.width) <= 2.5
            ]
            if matches:
                target = min(matches, key=lambda t: hypot(t["x"] - current.x, t["y"] - current.y))
                current.x, current.y = target["x"], target["y"]
                current.box = tuple(target["box"])
                current.last_seen = self.elapsed
                if current.width > current.reference_width * 1.15:
                    current.reference_width = current.width
                    current.progress_at = self.elapsed
                    self.approach_evidence = "apparent_size_increase"
                return True
            if self.elapsed - current.last_seen <= 0.7:
                return False
            self.track = None
        if targets:
            cx, cy = frame["width"] / 2, frame["height"] / 2
            target = min(targets, key=lambda t: hypot(t["x"] - cx, t["y"] - cy))
            self.track = TargetTrack(
                target["x"], target["y"], tuple(target["box"]),
                self.elapsed, self.elapsed, target["box"][2] - target["box"][0], self.elapsed,
            )
            self.approach_evidence = "new_track"
            return True
        return False

    def _escape(self, reason):
        side = "KeyD" if self.recovery.side == "KeyA" else "KeyA"
        self.recovery = RecoveryState("back", reason, self.elapsed, side)
        self.still_since = None

    def aim(self, frame):
        self.last_frame = frame["id"]
        self.target_count = len(frame["targets"])
        if self.profile == "passive":
            self.motion = Intent()
            return
        visible = self._select(frame)
        self.scene_change = frame.get("scene_change")
        if self.scene_change is not None and self.scene_change["changed_fraction"] < 0.015:
            if self.still_since is None:
                self.still_since = self.elapsed
        else:
            self.still_since = None
        if visible:
            self.recovering_sky = False
        else:
            sky = frame.get("lower_sky_fraction", 0)
            if sky > 0.65:
                self.recovering_sky = True
            elif sky < 0.35:
                self.recovering_sky = False

        state = self.recovery
        while state.phase in ESCAPE_PHASES and self.elapsed - state.started >= ESCAPE_PHASES[state.phase]:
            next_phase = {"back": "side", "side": "advance", "advance": "search"}[state.phase]
            self.recovery = state = RecoveryState(next_phase, state.reason, state.started + ESCAPE_PHASES[state.phase], state.side)
            if next_phase == "search":
                if self.track:
                    self.track.progress_at = self.elapsed
                    self.track.reference_width = self.track.width
                self.still_since = None
        if state.phase not in ESCAPE_PHASES:
            if visible:
                if state.phase != "track":
                    self.recovery = state = RecoveryState("track", "visible_target", self.elapsed, state.side)
                width = self.track.width
                distant = width < 25 * frame["height"] / 1390
                waiting = self.elapsed - self.track.progress_at
                if waiting >= (4.5 if distant else 7):
                    self._escape("no_apparent_approach" if distant else "persistent_target")
                elif self.still_since is not None and self.elapsed - self.still_since >= 2:
                    self._escape("unchanged_scene")
            elif self.track is not None:
                if state.phase != "occluded":
                    self.recovery = RecoveryState("occluded", "brief_occlusion", self.elapsed, state.side)
            else:
                if state.phase != "search":
                    self.recovery = state = RecoveryState("search", "target_lost", self.elapsed, state.side)
                if self.elapsed - state.started >= 3:
                    self._escape("search_timeout")
                elif self.still_since is not None and self.elapsed - self.still_since >= 2:
                    self._escape("unchanged_scene")

        state = self.recovery
        vertical = 150 if self.recovering_sky else 0
        side_sign = -1 if state.side == "KeyA" else 1
        if state.phase == "back":
            keys, look = ("KeyS", state.side), (0, vertical)
        elif state.phase == "side":
            keys, look = (state.side,), (side_sign * 55, vertical)
        elif state.phase == "advance":
            keys, look = ("KeyW", state.side), (0, vertical)
        elif state.phase == "occluded":
            keys, look = (state.side,), (0, vertical)
        elif state.phase == "track":
            target = self.track
            cx, cy = frame["width"] / 2, frame["height"] / 2
            look = (max(-220, min(220, (target.x - cx) * 1.15)), max(-150, min(150, (target.y - cy) * 1.15)))
            scale = frame["height"] / 1390
            keys = ("KeyS",) if target.width > 75 * scale else (("KeyW",) if target.width < 25 * scale else ())
        else:
            searching = self.elapsed - state.started
            scan = (70 if int(self.elapsed / 4) % 2 == 0 else -70) if searching >= 1 else 0
            keys, look = (state.side,), (side_sign * 100, vertical or scan)
        self.motion = Intent(keys, ("left",), look)

    def diagnostics(self):
        track = self.track
        return {
            "selected_track": None if track is None else {
                "x": track.x, "y": track.y, "box": track.box,
                "last_seen_age": round(self.elapsed - track.last_seen, 3),
                "selected_at": track.selected_at,
                "no_approach_seconds": round(self.elapsed - track.progress_at, 3),
            },
            "recovery": {
                "phase": self.recovery.phase, "reason": self.recovery.reason,
                "phase_age": round(self.elapsed - self.recovery.started, 3),
                "side": self.recovery.side,
            },
            "progress_evidence": {
                "scene_change": self.scene_change,
                "still_seconds": None if self.still_since is None else round(self.elapsed - self.still_since, 3),
                "approach": self.approach_evidence,
                "world_translation": "unverified",
            },
        }

    def step(self, dt):
        self.elapsed += max(0, dt)
        if self.profile == "passive":
            return Intent()
        keys = list(self.motion.keys)
        phase = self.elapsed % 8
        for begin, end, key in (
            (2, 2.2, "Space"), (2.4, 2.6, "Space"),
            (3, 3.25, "ShiftLeft"), (4, 4.3, "KeyE"),
            (4.7, 5, "KeyQ"), (6, 6.2, "KeyR"),
        ):
            if begin <= phase < end:
                if key in ("Space", "ShiftLeft") and self.recovery.phase != "track":
                    continue
                keys.append(key)
        return Intent(tuple(keys), self.motion.buttons, self.motion.look)
