"""Visual target tracking plus bounded physical ability edges."""

from dataclasses import dataclass


@dataclass
class Intent:
    keys: tuple = ()
    buttons: tuple = ()
    look: tuple = (0.0, 0.0)


class Policy:
    def __init__(self, profile="visual"):
        self.profile = profile
        self.elapsed = 0.0
        self.last_frame = None
        self.motion = Intent()
        self.target_count = 0
        self.lost_since = None
        self.recovering_sky = False
        self.disengage_until = 0
        self.next_disengage = 0
        self.disengage_side = "KeyD"

    def aim(self, frame):
        self.last_frame = frame["id"]
        targets = frame["targets"]
        self.target_count = len(targets)
        if self.profile == "passive":
            self.motion = Intent()
            return
        cx, cy = frame["width"] / 2, frame["height"] / 2
        if targets:
            self.lost_since = None
            self.recovering_sky = False
            target = min(targets, key=lambda t: (t["x"] - cx) ** 2 + (t["y"] - cy) ** 2)
            look = (
                max(-220, min(220, (target["x"] - cx) * 1.15)),
                max(-150, min(150, (target["y"] - cy) * 1.15)),
            )
            width = target["box"][2] - target["box"][0]
            scale = frame["height"] / 1390
            keys = (
                ("KeyS",)
                if width > 75 * scale
                else (("KeyW",) if width < 25 * scale else ())
            )
            if 5 < self.elapsed % 9 < 7:
                keys += ("KeyA" if int(self.elapsed / 9) % 2 == 0 else "KeyD",)
        else:
            if self.lost_since is None:
                self.lost_since = self.elapsed
            sky = frame.get("lower_sky_fraction", 0)
            if sky > 0.65:
                self.recovering_sky = True
            elif sky < 0.35:
                self.recovering_sky = False
            searching = self.elapsed - self.lost_since
            scan = (
                (70 if int((searching - 1) / 4) % 2 == 0 else -70)
                if searching >= 1
                else 0
            )
            look = (110, 150 if self.recovering_sky else scan)
            if searching >= 3 and self.elapsed >= self.next_disengage:
                self.disengage_until = self.elapsed + 1.5
                self.next_disengage = self.elapsed + 8
                self.disengage_side = (
                    "KeyA" if self.disengage_side == "KeyD" else "KeyD"
                )
            keys = ()
        if self.elapsed < self.disengage_until:
            keys, look = ("KeyS", self.disengage_side), (0, look[1])
        self.motion = Intent(keys, ("left",), look)

    def step(self, dt):
        self.elapsed += max(0, dt)
        if self.profile == "passive":
            return Intent()
        keys = list(self.motion.keys)
        phase = self.elapsed % 8
        # Input-clock edges retain their phase across menus. Never replay missed attacks.
        for begin, end, key in (
            (2, 2.2, "Space"),
            (2.4, 2.6, "Space"),
            (3, 3.25, "ShiftLeft"),
            (4, 4.3, "KeyE"),
            (4.7, 5, "KeyQ"),
            (6, 6.2, "KeyR"),
        ):
            if begin <= phase < end:
                if key in ("Space", "ShiftLeft") and (
                    self.target_count == 0 or self.elapsed < self.disengage_until
                ):
                    continue
                keys.append(key)
        return Intent(tuple(keys), self.motion.buttons, self.motion.look)
