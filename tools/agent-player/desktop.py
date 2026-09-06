"""Adapter to the one installed native controller and its workspace ownership."""

import importlib
import os
import subprocess
import sys
import time
from contextlib import contextmanager
from pathlib import Path


class Desktop:
    def __init__(self, name, controller_root):
        self.root = Path(controller_root).expanduser().resolve()
        for path in (self.root, self.root.parent / "hypruse/src"):
            sys.path.insert(0, str(path))
        os.environ["CODEX_AGENT_WORKSPACE_NAME"] = name
        state_root = Path.home() / ".local/state/codex-native-input/agent-desktop"
        self.state = state_root / (
            "session.json" if name == "game" else f"workspaces/{name}/session.json"
        )
        os.environ["CODEX_AGENT_DESKTOP_STATE"] = str(self.state)
        self.seat = importlib.import_module("seat")
        self.ownership = importlib.import_module("ownership")
        self.semantic = importlib.import_module("semantic")
        self.NativeInput = importlib.import_module("native_input").NativeInput
        self.token = None
        self.owner = f"orchard-player-{os.getpid()}"
        self.expires = 0
        self.window = None
        self.manifest = None
        self.env = None
        self.started = False
        self.capture_phase = None

    def launch(self, url):
        # Claim before lifecycle mutation, including the first start of an empty workspace.
        self.renew(initial=True)
        with self.ownership.operation(self.state, self.token, True):
            if self.seat.status().get("compositor"):
                self.seat._stop_unlocked()
            self.manifest = self.seat._start_unlocked(url)
            self.started = True
            self.env = self.seat._session_environment(self.seat.status())
            if self.manifest["url"] != url:
                raise RuntimeError("Workspace did not launch the intended build URL")
            windows = self.seat.query(self.env, "clients")
            choices = [
                w for w in windows if w["pid"] == self.manifest["browser"]["pid"]
            ]
            if len(choices) != 1:
                raise RuntimeError(
                    "Expected one owned browser window in the playtest desktop"
                )
            self.window = choices[0]["address"]
        return self.manifest

    def renew(self, initial=False):
        validate = (
            None
            if initial
            else lambda: self.seat._session_environment(self.seat.status())
        )
        lease = self.ownership.claim(
            self.state, self.owner, 900, self.token, validate=validate
        )
        self.token, self.expires = lease["lease_token"], lease["expires_at"]

    @contextmanager
    def operation(self):
        if self.expires - time.time() < 120:
            self.renew()
        with self.ownership.operation(self.state, self.token, True):
            self.manifest = self.seat.status()
            self.env = self.seat._session_environment(self.manifest)
            yield

    @contextmanager
    def native(self):
        with self.operation():
            with self.NativeInput(
                self.manifest["wayland_socket"],
                self.manifest["hyprland_instance"],
                self.window,
                self.manifest["pause_file"],
            ) as controller:
                yield controller

    def observe(self):
        with self.operation():
            return self.semantic.observe(self.manifest, self.window, 300)

    def activate(self, observation, action):
        with self.operation():
            return self.semantic.activate(
                self.manifest,
                self.window,
                observation["observation_id"],
                action["control_id"],
                action["action_name"],
            )

    def tap(self, key):
        with self.native() as controller:
            controller.tap(key)

    def capture(self):
        self.capture_phase = "window query"
        window = next(
            (
                w
                for w in self.seat.query(self.env, "clients")
                if w["address"] == self.window
            ),
            None,
        )
        if not window or window["pid"] != self.manifest["browser"]["pid"]:
            raise RuntimeError("Owned browser window changed")
        x, y = window["at"]
        width, height = window["size"]
        started = time.monotonic()
        self.capture_phase = "grim screenshot"
        data = subprocess.run(
            ["grim", "-t", "jpeg", "-q", "85", "-g", f"{x},{y} {width}x{height}", "-"],
            env=self.env,
            capture_output=True,
            check=True,
            timeout=2,
        ).stdout
        self.capture_phase = "completed"
        return data, time.monotonic() - started

    def close(self):
        errors = []
        if self.started:
            try:
                with self.ownership.operation(self.state, self.token, False):
                    self.seat._stop_unlocked()
            except Exception as exc:
                errors.append(f"desktop cleanup: {exc}")
        if self.token:
            try:
                self.ownership.release(self.state, self.token)
            except Exception as exc:
                errors.append(f"lease cleanup: {exc}")
            self.token = None
        return errors
