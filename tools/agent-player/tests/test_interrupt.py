import signal
import subprocess
import sys
import time
import unittest
from pathlib import Path

import run as runner

CHILD = """
import signal, sys, time
sys.path.insert(0, {player!r})
import run
run.install_interrupt_handler()
interrupts = 0
print("ready", flush=True)
try:
    while True:
        time.sleep(0.05)
except KeyboardInterrupt:
    interrupts += 1
    time.sleep(1.0)
print("interrupts", interrupts, flush=True)
print("sigint", signal.getsignal(signal.SIGINT) is signal.SIG_IGN, flush=True)
print("sigterm", signal.getsignal(signal.SIGTERM) is signal.SIG_IGN, flush=True)
"""


class InterruptHandlerTests(unittest.TestCase):
    def setUp(self):
        self.previous = {s: signal.getsignal(s) for s in (signal.SIGINT, signal.SIGTERM)}

    def tearDown(self):
        for signum, handler in self.previous.items():
            signal.signal(signum, handler)

    def test_handler_ignores_further_signals_before_raising(self):
        runner.install_interrupt_handler()
        self.assertIs(signal.getsignal(signal.SIGINT), runner.interrupt)
        self.assertIs(signal.getsignal(signal.SIGTERM), runner.interrupt)
        with self.assertRaises(KeyboardInterrupt) as raised:
            runner.interrupt(signal.SIGTERM, None)
        self.assertEqual(str(raised.exception), f"signal {int(signal.SIGTERM)}")
        self.assertIs(signal.getsignal(signal.SIGINT), signal.SIG_IGN)
        self.assertIs(signal.getsignal(signal.SIGTERM), signal.SIG_IGN)

    def test_second_sigint_does_not_interrupt_cleanup(self):
        player = str(Path(runner.__file__).resolve().parent)
        child = subprocess.Popen(
            [sys.executable, "-c", CHILD.format(player=player)],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        try:
            self.assertEqual(child.stdout.readline().strip(), "ready")
            child.send_signal(signal.SIGINT)
            time.sleep(0.3)
            child.send_signal(signal.SIGINT)
            stdout, stderr = child.communicate(timeout=10)
        finally:
            if child.poll() is None:
                child.kill()
        self.assertEqual(child.returncode, 0, stderr)
        self.assertEqual(
            stdout.split(), ["interrupts", "1", "sigint", "True", "sigterm", "True"]
        )
