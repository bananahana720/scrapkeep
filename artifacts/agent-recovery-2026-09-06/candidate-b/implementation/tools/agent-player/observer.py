"""Screenshot capture/detection runs independently of the input owner."""

import io
import threading
import time

import numpy as np
from PIL import Image
from vision import detect


class SceneChange:
    def __init__(self):
        self.previous = None

    def measure(self, image):
        small = np.asarray(
            image.convert("L").resize((64, 48), Image.Resampling.BOX)
        ).astype(np.int16)
        sample = np.concatenate(
            (small[12:35, 3:20].ravel(), small[12:35, 44:61].ravel())
        )
        result = {
            "changed_fraction": None,
            "mean_luma_delta": None,
            "basis": "side_bands_excluding_hud_and_avatar",
        }
        if self.previous is not None:
            delta = np.abs(sample - self.previous)
            result.update(
                changed_fraction=round(float((delta > 6).mean()), 4),
                mean_luma_delta=round(float(delta.mean()), 3),
            )
        self.previous = sample
        return result


def lower_sky_fraction(image):
    """Recognize lost upward framing from visible sky below the crosshair."""
    a = np.asarray(image.convert("RGB"))
    h, w = a.shape[:2]
    band = a[int(h * 0.58) : int(h * 0.72), int(w * 0.15) : int(w * 0.85)].astype(
        np.int16
    )
    r, g, b = band.transpose(2, 0, 1)
    return float(((r > 90) & (g - r > 10) & (b - r > 10) & (abs(g - b) < 25)).mean())


def modal_candidate(image):
    """A conservative input-stop cue, never an outcome classification."""
    a = np.asarray(image.convert("RGB")).astype(np.int16)
    h, w = a.shape[:2]
    area = a[int(h * 0.35) : int(h * 0.65), int(w * 0.3) : int(w * 0.7)]
    r, g, b = area.transpose(2, 0, 1)
    dark = (
        float(((g - r > 20) & (g - b > 0) & (g < 100) & (r < 55) & (b > 25)).mean())
        > 0.75
    )
    if not dark:
        return False
    radius = min(420, int(w * 0.46))
    for x in (w // 2 - radius, w // 2 + radius - 1):
        edge = a[max(0, h // 2 - 80) : h // 2 + 80, max(0, x - 2) : x + 3]
        if edge.size == 0:
            return False
        r, g, b = edge.transpose(2, 0, 1)
        border = (
            (r > 70)
            & (g > 100)
            & (b > 70)
            & (g - r > 6)
            & (g - r < 60)
            & (g >= b)
            & (g - b < 60)
        ) | ((r > 215) & (g > 215) & (b > 215))
        # Chromium's focused dialog adds a white outer outline one pixel away.
        if float(border.mean(axis=0).max()) <= 0.65:
            return False
    return True


class Observer:
    def __init__(self, desktop):
        self.desktop = desktop
        self.stop = threading.Event()
        self.latest = None
        self.error = None
        self.phase = "starting"
        self.thread = threading.Thread(
            target=self._run, daemon=True, name="player-observer"
        )

    def _run(self):
        number = 0
        scene_change = SceneChange()
        try:
            while not self.stop.is_set():
                started = time.monotonic()
                self.phase = "capture"
                data, capture_seconds = self.desktop.capture()
                self.phase = "decode"
                image = Image.open(io.BytesIO(data))
                image.load()
                self.phase = "detect"
                modal = modal_candidate(image)
                targets = [] if modal else detect(image)
                self.latest = {
                    "id": number,
                    "time": started,
                    "data": data,
                    "width": image.width,
                    "height": image.height,
                    "targets": targets,
                    "modal": modal,
                    "lower_sky_fraction": lower_sky_fraction(image),
                    "scene_change": scene_change.measure(image),
                    "capture_ms": capture_seconds * 1000,
                    "observe_ms": (time.monotonic() - started) * 1000,
                }
                number += 1
                self.phase = "waiting"
                self.stop.wait(max(0, 0.12 - (time.monotonic() - started)))
        except Exception as exc:
            self.error = exc

    def __enter__(self):
        self.thread.start()
        return self

    def __exit__(self, *exc):
        self.stop.set()
        self.thread.join(timeout=3)
        if self.thread.is_alive():
            raise RuntimeError(
                "Capture worker did not terminate within its bounded I/O timeout"
            )
