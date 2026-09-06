"""Bounded evidence writer and source provenance for one native playtest."""

import hashlib
import json
import queue
import threading
import time
from pathlib import Path


def hashes(paths, base):
    return {
        str(path.relative_to(base)): hashlib.sha256(path.read_bytes()).hexdigest()
        for path in sorted(paths)
        if path.is_file()
    }


class Evidence:
    def __init__(self, directory):
        self.directory = Path(directory)
        self.directory.mkdir(parents=True, exist_ok=True)
        self.events = (self.directory / "events.ndjson").open("w")
        self.images = queue.Queue(maxsize=4)
        self.image_error = None
        self.last_image = 0
        self.frame_count = 0
        self.worker = threading.Thread(
            target=self._write_images, daemon=True, name="evidence-writer"
        )
        self.worker.start()

    def event(self, kind, **values):
        record = dict(at=time.time(), kind=kind, **values)
        self.events.write(json.dumps(record) + "\n")
        self.events.flush()

    def save_json(self, name, value):
        (self.directory / name).write_text(json.dumps(value, indent=2))

    def frame(self, frame):
        if frame["time"] - self.last_image < 1:
            return
        self.last_image = frame["time"]
        self.frame_count += 1
        try:
            self.images.put_nowait((f"frame-{self.frame_count:05}.jpg", frame["data"]))
        except queue.Full:
            pass  # Only periodic illustrations can be dropped; outcomes/actions are retained.

    def _write_images(self):
        try:
            while True:
                item = self.images.get()
                if item is None:
                    return
                name, data = item
                (self.directory / name).write_bytes(data)
        except Exception as exc:
            self.image_error = str(exc)

    def close(self):
        self.images.put(None, timeout=3)
        self.worker.join(timeout=3)
        self.events.close()
        if self.worker.is_alive() or self.image_error:
            raise RuntimeError(self.image_error or "Evidence writer did not stop")
