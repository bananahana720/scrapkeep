"""Scrapkeep's combat feedback sounds: percussion, not notes.

    python feedback_set.py <out_dir> [<onbeat_out_dir>]

Andrew, 13 November 2026: the hit-scan sound and the other critical feedback sounded like jazz
instruments and fought the melody. These cues are the moment-to-moment facts of a fight (a shot,
a hit, a crit, a kill, a deflect, a weak point, being hurt), heard a dozen times a second, so they
follow the shooter conventions a player's ear already knows and carry no note the band could clash
with. Each one lives in two lanes the melody leaves free, measured against the recorded world 1 and
Brindle fight stems (the melody stem is loudest from 200 Hz to 4 kHz):

- body: a short punch between 120 and 300 Hz, above the kick's fundamental and below the melody,
  and loud enough on laptop speakers, which lose most of what sits under 150 Hz;
- crack: a transient or an inharmonic ring above 3 kHz.

What crosses the melody's band is noise shorter than 15 ms, which the ear hears as a click, never a
pitch. Rings are inharmonic (no partial is a whole multiple of another), so they read as metal.

| Cue | Convention it follows | What you hear |
| --- | --- | --- |
| weapon_zap | Gunfire: a punchy transient with a body, no tone | A tight "tuk": a 240-to-110 Hz punch under a 3 to 7 kHz crack |
| hit_thwack | The hit marker: a crisp high tick, unlike the shot | A dry tick and a 30 ms ring of struck scrap above 3 kHz |
| crit_ping | The crit ding: the hit marker with a brighter, longer metal ring | The tick, then a 90 ms inharmonic "tink" from 3.3 to 9 kHz |
| kill_pop | The kill confirm: heavier than a hit, a break and a pop | A low punch, a crunch and a snap, then scrap skittering |
| kill_chain_tier_N | The multi-kill: each step heavier, not higher | N quick ratchet clicks and a rising air sweep; from 3 a low boom |
| hurt | Taking damage: dull, heavy, distorted, from below | A body blow, an overdriven crunch and a static tear |
| clank | The deflect: a ricochet | A hard click and a high metal zing |
| boss_weak_hit | The weak-point hit: the hit marker made huge | The tick, a heavy crunch and a deep punch |
| ui_tick | The interface click | Two dry clicks, 4 ms apart |
| onbeat_clap | A hit that lands on the beat joins the drums | A clap: three short noise bursts, like the band's own |

Writes 48 kHz mono 16-bit WAVs, peak -1 dBFS, like event_set.py. Its own seed, so its files never
move when another generator changes.
"""

import sys
from pathlib import Path

import numpy as np
import soundfile as sf

SR = 48000
RNG = np.random.default_rng(1113)

# The cues this file owns in assets/audio/event_set/ (event_set.py skips writing them).
EVENT_OWNED = ["weapon_zap", "hit_thwack", "crit_ping", "kill_pop", "hurt", "clank", "boss_weak_hit", "ui_tick",
               *[f"kill_chain_tier_{n}" for n in range(1, 6)]]
# Rendered sounds this file owns in assets/audio/sfx/.
SFX_OWNED = ["onbeat_clap"]


def t_of(seconds):
    return np.arange(int(seconds * SR)) / SR


def place(buf, sound, at):
    i = int(at * SR)
    buf[i:i + len(sound)] += sound[:max(len(buf) - i, 0)]


def mix(seconds, *parts):
    out = np.zeros(int(seconds * SR))
    for sound, at in parts:
        place(out, sound, at)
    return out


def decay_env(seconds, decay, attack=0.0004):
    t = t_of(seconds)
    return np.minimum(t / attack, 1.0) * np.exp(-t / decay)


def band_noise(seconds, lo, hi, decay, level=1.0, attack=0.0004):
    """White noise kept between lo and hi Hz (brick-wall in the spectrum, then shaped), with a fast decay."""
    n = int(seconds * SR)
    spec = np.fft.rfft(RNG.standard_normal(n))
    f = np.fft.rfftfreq(n, 1 / SR)
    spec[(f < lo) | (f > hi)] = 0
    x = np.fft.irfft(spec, n)
    x /= np.max(np.abs(x)) + 1e-12
    return level * x * decay_env(seconds, decay, attack)


def punch(seconds, f_start, f_end, drop, decay, level=1.0):
    """A sine whose pitch falls from f_start to f_end in about `drop` seconds: a drum's body, heard as weight."""
    t = t_of(seconds)
    f = f_end + (f_start - f_end) * np.exp(-t / drop)
    return level * np.sin(2 * np.pi * np.cumsum(f) / SR) * decay_env(seconds, decay, 0.0008)


def ring(seconds, partials, decay, level=1.0):
    """Struck metal: inharmonic partials (Hz) with random phases, the higher ones dying faster."""
    t = t_of(seconds)
    out = np.zeros_like(t)
    for i, f in enumerate(partials):
        out += np.sin(2 * np.pi * f * t + RNG.uniform(0, 2 * np.pi)) * np.exp(-t / (decay / (1 + 0.35 * i))) / (1 + 0.3 * i)
    out *= np.minimum(t / 0.0003, 1.0)
    return level * out / (np.max(np.abs(out)) + 1e-12)


def drive(x, amount):
    return np.tanh(amount * x) / np.tanh(amount)


def sweep_noise(seconds, f0, f1, level=1.0, peak_at=0.7):
    """Band noise whose centre glides from f0 to f1 with a swell to peak_at of its length: an air rush."""
    n = int(seconds * SR)
    noise = RNG.standard_normal(n)
    out, y1, y2 = np.empty(n), 0.0, 0.0
    cut = np.geomspace(f0, f1, n)
    for i in range(n):
        a = 1 - np.exp(-2 * np.pi * cut[i] / SR)
        y1 += a * (noise[i] - y1)
        y2 += a * (y1 - y2)
        out[i] = y1 - y2  # a soft band-pass around the moving cut-off
    t = np.linspace(0, 1, n)
    shape = np.where(t < peak_at, (t / peak_at) ** 2, np.exp(-(t - peak_at) / 0.08))
    return level * out * shape / (np.max(np.abs(out)) + 1e-12)


# --- the cues --------------------------------------------------------------------------

def weapon_zap():
    """The shot, the most frequent sound in the game: short, dry, the same shape every time."""
    return mix(0.07, (punch(0.06, 260, 120, 0.01, 0.016, 1.0), 0),
               (band_noise(0.04, 3000, 8000, 0.006, 0.9), 0),
               (band_noise(0.02, 1200, 3000, 0.003, 0.45), 0))


def _tick(level=1.0):
    """The hit marker's tick: a 2 to 3 ms crack above 3 kHz, plus a hair of mid to give it a front."""
    return mix(0.02, (band_noise(0.02, 3200, 9000, 0.0025, level), 0), (band_noise(0.015, 1200, 3200, 0.0012, 0.35 * level), 0))


def hit_thwack():
    scrap = ring(0.06, [3170, 4430, 5810, 7340], 0.012, 0.35)
    return mix(0.1, (_tick(1.0), 0), (scrap, 0.001), (punch(0.04, 260, 170, 0.01, 0.009, 0.3), 0))


def crit_ping():
    tink = ring(0.16, [3330, 4870, 6260, 8170, 9050], 0.05, 0.7)
    return mix(0.18, (_tick(1.0), 0), (tink, 0.004), (punch(0.04, 260, 170, 0.01, 0.009, 0.3), 0))


def kill_pop():
    crunch = drive(band_noise(0.08, 300, 3500, 0.016, 1.0), 3.0) * 0.55
    debris = np.zeros(int(0.2 * SR))
    for i, at in enumerate((0.045, 0.075, 0.11)):
        place(debris, band_noise(0.012, 3500, 9000, 0.002, 0.25 - 0.06 * i), at + RNG.uniform(0, 0.01))
    return mix(0.22, (punch(0.12, 220, 70, 0.018, 0.035, 1.0), 0), (crunch, 0),
               (band_noise(0.02, 4500, 10000, 0.003, 0.6), 0), (debris, 0))


def kill_chain_tier(tier):
    """Each link racks one more click and rises a little further: heavier, never a higher note."""
    seconds = 0.12 + 0.035 * tier
    out = mix(seconds, (sweep_noise(seconds, 1800, 1800 + 900 * tier, 0.35 + 0.05 * tier), 0))
    for i in range(tier):
        place(out, band_noise(0.014, 2500, 8000, 0.0025, 0.9), 0.004 + 0.032 * i)
    if tier >= 3:
        place(out, punch(0.18, 160, 55, 0.03, 0.05 + 0.01 * tier, 0.5 + 0.1 * (tier - 3)), 0.032 * (tier - 1))
    return out


def hurt():
    """Damage is a body blow from below with an overdriven crunch and a short static tear: never a note."""
    crunch = drive(band_noise(0.2, 250, 2200, 0.05, 1.0), 4.0) * 0.6
    tear = sweep_noise(0.16, 4500, 900, 0.35, peak_at=0.15)
    return mix(0.32, (punch(0.25, 150, 48, 0.03, 0.07, 1.0), 0), (crunch, 0), (tear, 0.02))


def clank():
    zing = ring(0.15, [4130, 5620, 7230, 9310], 0.035, 0.7)
    return mix(0.17, (band_noise(0.015, 2000, 9000, 0.0015, 0.9), 0), (zing, 0.001),
               (band_noise(0.12, 4500, 9000, 0.03, 0.12), 0.01))


def boss_weak_hit():
    crunch = drive(band_noise(0.12, 300, 3200, 0.025, 1.0), 3.5) * 0.6
    return mix(0.3, (_tick(1.0), 0), (crunch, 0.002), (punch(0.25, 200, 55, 0.025, 0.06, 1.0), 0),
               (ring(0.1, [3170, 4430, 5810], 0.02, 0.3), 0.002))


def ui_tick():
    # a breath of room after the clicks keeps it 30 ms long, so it reads as a sound and not a glitch
    return mix(0.045, (band_noise(0.012, 2000, 7000, 0.002, 1.0), 0), (band_noise(0.012, 2000, 7000, 0.0018, 0.7), 0.006),
               (band_noise(0.04, 2000, 6000, 0.012, 0.3), 0.008))


def onbeat_clap():
    """A hit on the beat is a clap in the band's drums: three short bursts, then a small room."""
    out = np.zeros(int(0.18 * SR))
    for i, at in enumerate((0.0, 0.009, 0.018)):
        place(out, band_noise(0.02, 900, 6000, 0.004, 0.8 if i < 2 else 1.0), at)
    place(out, band_noise(0.16, 1000, 5000, 0.045, 0.35), 0.018)
    return out


CUES = {
    "weapon_zap": weapon_zap, "hit_thwack": hit_thwack, "crit_ping": crit_ping, "kill_pop": kill_pop,
    **{f"kill_chain_tier_{n}": (lambda n=n: kill_chain_tier(n)) for n in range(1, 6)},
    "hurt": hurt, "clank": clank, "boss_weak_hit": boss_weak_hit, "ui_tick": ui_tick,
}
SFX = {"onbeat_clap": onbeat_clap}


def finish(audio):
    """The event set's finishing: trim the silent tail, peak at -1 dBFS, a 4 ms fade."""
    nz = np.nonzero(np.abs(audio) > 1e-4)[0]
    audio = audio[: nz[-1] + 1] if len(nz) else audio
    audio = audio / np.max(np.abs(audio)) * 10 ** (-1 / 20)
    fade = min(int(0.004 * SR), len(audio) // 4)
    audio[-fade:] *= np.linspace(1, 0, fade)
    return audio.astype(np.float32)


def main():
    event_dir = Path(sys.argv[1])
    sfx_dir = Path(sys.argv[2]) if len(sys.argv) > 2 else None
    event_dir.mkdir(parents=True, exist_ok=True)
    for name, make in CUES.items():
        sf.write(event_dir / f"{name}.wav", finish(make()), SR, subtype="PCM_16")
    if sfx_dir:
        sfx_dir.mkdir(parents=True, exist_ok=True)
        for name, make in SFX.items():
            sf.write(sfx_dir / f"{name}.wav", finish(make()), SR, subtype="PCM_16")
    print(f"{len(CUES)} feedback cues written to {event_dir}" + (f", {len(SFX)} to {sfx_dir}" if sfx_dir else ""))


if __name__ == "__main__":
    main()
