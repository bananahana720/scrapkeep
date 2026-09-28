#!/usr/bin/env python3
"""Impulse fixtures for the ACE runtime proof of concept (ACE-MUSIC-REVIEW section 3).

No ACE audio: every file is silence with single-sample clicks at known samples, so the
sequencer test can assert exact sample positions after Vorbis decode. Rerun to
reproduce; ffmpeg's bitexact flags keep the Ogg serial and headers stable.

    python3 sketches/core-loop/tools/ace/make_poc_fixtures.py

Layout (44.1 kHz stereo, 172 BPM on the engine grid: STEP 3846, BEAT 15384, BAR 61536):
  L: a beat click (0.8) on every beat, and a bar-ID click at bar + 4096 + 256 * id,
     where id is the file's first bar id plus the bar index.
  R: a file-ID click on every beat at beat + 64 * (file_id + 1).
  R: a last-frame click at exit - 1, so a join that drops the final frames shows.
  Looping stems end at their exit and carry a tail click at exit - 32 in L. The landing
  and the lift are one-shots with POST_ROLL frames past the exit and a post-roll click
  at exit + 16 in L that a correct join never plays: the decoder's 2-frame lead-in
  means the last frames before the exit only come out if the file runs past it.
"""
import json
import pathlib
import subprocess

import numpy as np

RATE = 44100
BEAT = 15384
BAR = BEAT * 4
CLICK = 0.8
POST_ROLL = 1024
HERE = pathlib.Path(__file__).resolve().parent
OUT = HERE / "poc_fixtures"

# id, file_id, bars, key (semitones from D), first bar id, loop
FILES = [
    ("stem_drums", 0, 16, 0, 0, True),
    ("stem_bass", 1, 16, 0, 0, True),
    ("stem_other", 2, 16, 0, 0, True),
    ("landing", 3, 4, 0, 16, False),
    ("lift", 4, 1, 1, 20, False),
]


def render(file_id: int, bars: int, first_bar_id: int, loop: bool) -> np.ndarray:
    exit_at = bars * BAR
    n = exit_at if loop else exit_at + POST_ROLL
    pcm = np.zeros((n, 2), dtype=np.float32)
    for beat in range(bars * 4):
        at = beat * BEAT
        pcm[at, 0] = CLICK
        pcm[at + 64 * (file_id + 1), 1] = CLICK
    for bar in range(bars):
        pcm[bar * BAR + 4096 + 256 * (first_bar_id + bar), 0] = CLICK
    pcm[exit_at - 1, 1] = CLICK
    if loop:
        pcm[exit_at - 32, 0] = CLICK
    else:
        pcm[exit_at + 16, 0] = CLICK
    return pcm


def encode(pcm: np.ndarray, ogg: pathlib.Path) -> None:
    """Pipes 16-bit PCM to ffmpeg's libvorbis; no temporary files."""
    ints = np.clip(np.round(pcm * 32767.0), -32768, 32767).astype("<i2")
    cmd = [
        "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
        "-f", "s16le", "-ar", str(RATE), "-ac", "2", "-i", "pipe:0",
        "-c:a", "libvorbis", "-q:a", "6",
        "-fflags", "+bitexact", "-flags:a", "+bitexact", "-map_metadata", "-1",
        str(ogg),
    ]
    subprocess.run(cmd, input=ints.tobytes(), check=True)


def main() -> None:
    OUT.mkdir(exist_ok=True)
    manifest = {"rate": RATE, "beat_samples": BEAT, "bar_samples": BAR, "files": []}
    for name, file_id, bars, key, first_bar_id, loop in FILES:
        pcm = render(file_id, bars, first_bar_id, loop)
        encode(pcm, OUT / (name + ".ogg"))
        manifest["files"].append({
            "id": name,
            "file_id": file_id,
            "sample_count": int(pcm.shape[0]),
            "bars": bars,
            "key_offset": key,
            "first_bar_id": first_bar_id,
            "loop": loop,
            "loop_offset": 0,
            "entry": 0,
            "exit": bars * BAR,
        })
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=1) + "\n")


if __name__ == "__main__":
    main()
