from dataclasses import dataclass
from math import hypot, log


@dataclass
class Intent:
    keys: tuple = ()
    buttons: tuple = ()
    look: tuple = (0.0, 0.0)


@dataclass
class TargetTrack:
    number: int
    x: float
    y: float
    box: tuple
    last_seen: float
    progress_at: float
    best_width: float
    best_error: float


@dataclass
class Recovery:
    phase: str = "search"
    reason: str = "no_target"
    started: float = 0.0
    until: float = 0.0
    attempt: int = 0
    side: str = "KeyA"


class Policy:
    OCCLUSION_SECONDS = 0.8

    def __init__(self, profile="visual"):
        self.profile = profile
        self.elapsed = 0.0
        self.last_frame = None
        self.motion = Intent()
        self.target_count = 0
        self.lost_since = None
        self.framing = "level"
        self.track = None
        self.track_number = 0
        self.recovery = Recovery()
        self.next_recovery = 0.0
        self.still_since = None
        self.visual_evidence = {}

    def _select(self, targets, width, height):
        cx, cy = width / 2, height / 2
        if self.track and self.elapsed - self.track.last_seen > self.OCCLUSION_SECONDS:
            self.track = None
        previous = self.track
        if previous is not None:
            old_width = previous.box[2] - previous.box[0]
            candidates = []
            for target in targets:
                size = target["box"][2] - target["box"][0]
                ratio = size / max(1, old_width)
                distance = hypot(target["x"] - previous.x, target["y"] - previous.y)
                if 0.45 < ratio < 2.2 and distance < max(width * 0.16, old_width * 3):
                    candidates.append(
                        (distance / width + abs(log(ratio)) * 0.12, target)
                    )
            if candidates:
                return min(candidates, key=lambda item: item[0])[1], False
            if self.elapsed - previous.last_seen <= self.OCCLUSION_SECONDS:
                return None, False
        if targets:
            return min(targets, key=lambda t: hypot(t["x"] - cx, t["y"] - cy)), True
        return None, False

    def _phase(self, phase, reason, duration=0):
        self.recovery.phase = phase
        self.recovery.reason = reason
        self.recovery.started = self.elapsed
        self.recovery.until = self.elapsed + duration

    def _escape(self, reason):
        state = self.recovery
        state.attempt += 1
        state.side = "KeyA" if state.attempt % 2 else "KeyD"
        self._phase("reverse", reason, 0.8)
        self.next_recovery = self.elapsed + 6

    def aim(self, frame):
        self.last_frame = frame["id"]
        self.target_count = len(frame["targets"])
        if self.profile == "passive":
            self.motion = Intent()
            return
        width, height = frame["width"], frame["height"]
        cx, cy = width / 2, height / 2
        self.visual_evidence = dict(frame.get("scene_change", {}))
        unchanged = self.visual_evidence.get("changed_fraction")
        if unchanged is not None:
            if unchanged < 0.005:
                if self.still_since is None:
                    self.still_since = self.elapsed
            else:
                self.still_since = None
        target, new_track = self._select(frame["targets"], width, height)
        if target:
            size = target["box"][2] - target["box"][0]
            error = hypot((target["x"] - cx) / width, (target["y"] - cy) / height)
            if new_track:
                self.track_number += 1
                self.track = TargetTrack(
                    self.track_number,
                    target["x"],
                    target["y"],
                    tuple(target["box"]),
                    self.elapsed,
                    self.elapsed,
                    size,
                    error,
                )
            else:
                track = self.track
                if size > track.best_width * 1.15 or error < track.best_error - 0.06:
                    track.progress_at = self.elapsed
                    track.best_width = max(size, track.best_width)
                    track.best_error = min(error, track.best_error)
                track.x, track.y = target["x"], target["y"]
                track.box, track.last_seen = tuple(target["box"]), self.elapsed
            self.lost_since = None
            self.framing = "level"
        else:
            if self.lost_since is None:
                self.lost_since = self.elapsed
            sky = frame.get("lower_sky_fraction", 0)
            ground = frame.get("upper_ground_fraction", 0)
            if sky > 0.65:
                self.framing = "sky"
            elif ground > 0.55:
                self.framing = "ground"
            elif (self.framing == "sky" and sky < 0.35) or (
                self.framing == "ground" and ground < 0.20
            ):
                self.framing = "level"
            if (
                self.track
                and self.elapsed - self.track.last_seen > self.OCCLUSION_SECONDS
            ):
                self.track = None
        state = self.recovery
        while (
            state.phase in ("reverse", "lateral", "settle")
            and self.elapsed >= state.until
        ):
            boundary = state.until
            if state.phase == "reverse":
                self._phase("lateral", state.reason, 0.9)
            elif state.phase == "lateral":
                self._phase("settle", state.reason, 0.3)
            else:
                self._phase("track" if target else "search", "escape_complete")
                break
            duration = state.until - state.started
            state.started, state.until = boundary, boundary + duration
        escaping = state.phase in ("reverse", "lateral", "settle")
        if not escaping:
            frozen = (
                self.still_since is not None and self.elapsed - self.still_since >= 1.5
            )
            stalled_target = target and self.elapsed - self.track.progress_at >= 7
            lost = self.lost_since is not None and self.elapsed - self.lost_since >= 3
            if self.elapsed >= self.next_recovery and (
                frozen or stalled_target or lost
            ):
                self._escape(
                    "scene_unchanged"
                    if frozen
                    else "target_no_progress"
                    if stalled_target
                    else "target_lost"
                )
            else:
                phase = "track" if target else "occluded" if self.track else "search"
                if state.phase != phase:
                    self._phase(
                        phase,
                        "visible_target"
                        if target
                        else "brief_occlusion"
                        if self.track
                        else "no_target",
                    )
        correction = (
            150 if self.framing == "sky" else -150 if self.framing == "ground" else 0
        )
        if state.phase == "reverse":
            keys, look = ("KeyS",), (0, correction)
        elif state.phase == "lateral":
            keys, look = (state.side,), (0, correction)
        elif state.phase == "settle":
            keys, look = (), (0, 0)
        elif target:
            look = (
                max(-220, min(220, (target["x"] - cx) * 1.15)),
                max(-150, min(150, (target["y"] - cy) * 1.15)),
            )
            size = target["box"][2] - target["box"][0]
            scale = height / 1390
            keys = (
                ("KeyS",)
                if size > 75 * scale
                else ("KeyW",)
                if size < 25 * scale
                else ()
            )
            if 5 < self.elapsed % 9 < 7:
                keys += ("KeyA" if int(self.elapsed / 9) % 2 == 0 else "KeyD",)
        elif self.track:
            look = (max(-90, min(90, (self.track.x - cx) * 0.35)), correction)
            keys = ()
        else:
            searching = self.elapsed - self.lost_since
            vertical = (
                (70 if int(self.elapsed / 4) % 2 == 0 else -70) if searching >= 1 else 0
            )
            look = (
                110 if searching < 3 else 180,
                correction or vertical,
            )
            keys = ("KeyW",) if searching >= 0.8 and self.framing == "level" else ()
        self.motion = Intent(keys, ("left",), look)

    def diagnostics(self):
        track = self.track
        state = self.recovery
        return {
            "track": None
            if track is None
            else {
                "id": track.number,
                "x": track.x,
                "y": track.y,
                "box": track.box,
                "last_seen_age": round(self.elapsed - track.last_seen, 3),
                "no_progress_seconds": round(self.elapsed - track.progress_at, 3),
            },
            "recovery": {
                "phase": state.phase,
                "reason": state.reason,
                "phase_age": round(self.elapsed - state.started, 3),
                "remaining": round(max(0, state.until - self.elapsed), 3),
                "attempt": state.attempt,
            },
            "scene_change": self.visual_evidence,
            "framing": self.framing,
            "still_seconds": None
            if self.still_since is None
            else round(self.elapsed - self.still_since, 3),
            "progress_basis": "target_scale_or_alignment; image_change_is_not_translation",
        }

    def step(self, dt):
        self.elapsed += max(0, dt)
        if self.profile == "passive":
            return Intent()
        keys = list(self.motion.keys)
        phase = self.elapsed % 8
        for begin, end, key in (
            (2, 2.2, "Space"),
            (2.4, 2.6, "Space"),
            (3, 3.25, "ShiftLeft"),
            (4, 4.3, "KeyE"),
            (4.7, 5, "KeyQ"),
            (6, 6.2, "KeyR"),
        ):
            if begin <= phase < end:
                if key in ("Space", "ShiftLeft") and self.recovery.phase != "track":
                    continue
                keys.append(key)
        return Intent(tuple(keys), self.motion.buttons, self.motion.look)
