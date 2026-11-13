"""The full Scrapkeep event-sound set, synthesized from code. Names match sfx_bank.gd keys.

    python event_set.py <out_dir>

Families share one record so a sound's kind is audible without looking:
- impact: noise and low sine, no pitch above the bass, onset in the first 5 ms
- reward: D Dorian bells, Rhodes and sax, rising lines
- danger: tritones, rasp and falling glides, never in the reward key's consonance
- boss: brass stabs and the versus fanfare
- stinger: short ii-V-I cadences that land on D
- ui: tiny Rhodes and wood
The scrap ladder climbs D Dorian degree by degree. The combat feedback cues (impact family, the kill chain)
are written by feedback_set.py as unpitched percussion; their makers here are kept only for the shared seed.
Writes 48 kHz mono 16-bit WAVs, peak -1 dBFS, plus manifest.json with each cue's family.
"""

import json
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

sys.path.insert(0, str(Path(__file__).resolve().parent))
from event_sounds import SR, bell, env, hz, noise_burst, place, rhodes, sax, t_of  # noqa: E402

RNG = np.random.default_rng(2026)
# Combat feedback cues are percussion now and feedback_set.py writes them (Andrew, 13 November 2026).
from feedback_set import EVENT_OWNED as FEEDBACK_OWNED  # noqa: E402
LADDER = ["A4", "B4", "D5", "E5", "A5"]


def sweep(seconds, f0, f1, level=1.0, attack=None):
    """Band-limited noise whose brightness glides from f0 to f1: a whoosh. With attack set,
    it starts at full level for moves the player triggers, instead of swelling in."""
    n = int(seconds * SR)
    noise = RNG.standard_normal(n)
    out, y = np.empty(n), 0.0
    cut = np.geomspace(f0, f1, n)
    for i in range(n):
        a = 1 - np.exp(-2 * np.pi * cut[i] / SR)
        y += a * (noise[i] - y)
        out[i] = y
    shape = np.sin(np.pi * np.linspace(0, 1, n)) ** 1.5
    if attack:
        shape = env(seconds, attack, seconds / 3)
    return level * out * shape / (np.max(np.abs(out)) + 1e-9)


def sub(seconds, f_start, f_end, decay, level=1.0):
    t = t_of(seconds)
    f = f_end + (f_start - f_end) * np.exp(-t / (decay / 4))
    return level * np.sin(2 * np.pi * np.cumsum(f) / SR) * env(seconds, 0.0008, decay)


def square(note, seconds, level=1.0, duty=0.5):
    """Chiptune square: the game inside the game."""
    t = t_of(seconds)
    phase = (hz(note) * t) % 1.0
    return level * np.where(phase < duty, 1.0, -1.0) * env(seconds, 0.001, seconds / 2.5)


def brass(note, seconds, level=1.0):
    """Brass stab: a sawtooth whose brightness opens fast and closes."""
    f, t = hz(note), t_of(seconds)
    bright = 2 + 10 * np.exp(-t / 0.06)
    tone = sum(np.sin(2 * np.pi * k * f * t) / k * np.exp(-k / bright) for k in range(1, 16))
    return level * tone * env(seconds, 0.006, seconds / 2.2)


def crunch(seconds, decay, level=1.0):
    return level * np.tanh(4 * noise_burst(seconds, decay, 8))


def chord(fn, notes, seconds, level, at=0.0, spread=0.0):
    out = np.zeros(int((seconds + at + spread * len(notes)) * SR))
    for i, note in enumerate(notes):
        place(out, fn(note, seconds, level), at + spread * i)
    return out


def mix(seconds, *parts):
    out = np.zeros(int(seconds * SR))
    for sound, at in parts:
        place(out, sound, at)
    return out


# impact ------------------------------------------------------------------------------

def hit_thwack():
    return mix(0.2, (crunch(0.08, 0.02, 1.0), 0), (sub(0.18, 220, 90, 0.06, 0.9), 0))


def slam_boom():
    """The stomp: a body-sized boom dropping an octave, a crack on top and a debris tail."""
    return mix(0.9, (sub(0.8, 120, 38, 0.35, 1.2), 0), (crunch(0.12, 0.03, 0.8), 0),
               (noise_burst(0.6, 0.18, 30) * 0.25, 0.03))


def smash_crack():
    """Bashing into a wall: splintering metal, a clang on D2, a short skitter."""
    clang = bell("D2", 0.5, ratio=2.76, level=0.6)
    skitter = noise_burst(0.02, 0.004, 2)
    out = mix(0.6, (crunch(0.15, 0.04, 1.0), 0), (clang, 0.004), (sub(0.25, 160, 60, 0.08, 0.7), 0))
    for i in range(4):
        place(out, skitter * (0.3 - 0.06 * i), 0.12 + 0.05 * i + RNG.uniform(0, 0.015))
    return out


def land_thud():
    return mix(0.3, (sub(0.28, 90, 45, 0.1, 1.0), 0), (noise_burst(0.05, 0.012, 20) * 0.5, 0))


def hop():
    return mix(0.18, (sub(0.15, 140, 260, 0.05, 0.6), 0), (sweep(0.12, 800, 3000, 0.25), 0.0))


def boost_whoosh():
    return mix(0.5, (sweep(0.45, 300, 6000, 0.9), 0), (sub(0.4, 60, 110, 0.2, 0.4), 0))


def dash_whoosh():
    return sweep(0.25, 2000, 400, 0.9, attack=0.002)


def near_whoosh():
    return sweep(0.18, 4000, 900, 0.6, attack=0.002)


def crit_ping():
    return mix(0.35, (crunch(0.05, 0.012, 0.8), 0), (bell("A6", 0.3, ratio=3.01, level=0.7), 0.002))


def kill_pop():
    return mix(0.35, (crunch(0.06, 0.015, 0.7), 0), (bell("D6", 0.25, ratio=2.0, level=0.5), 0.01),
               (square("A5", 0.1, 0.12), 0.03))


def kill_chain_tier(tier):
    """Each tier adds a note of the ladder, so a chain plays a rising phrase."""
    out = mix(0.6, (crunch(0.05, 0.012, 0.5), 0))
    for i, note in enumerate(LADDER[:tier]):
        place(out, square(note, 0.09, 0.18) + rhodes(note, 0.09, 0.3), 0.01 + 0.055 * i)
    return out


def armor_shed():
    plates = mix(0.5, (crunch(0.1, 0.025, 0.6), 0))
    for i, note in enumerate(("D3", "A2", "F2")):
        place(plates, bell(note, 0.25, ratio=2.4, level=0.4), 0.05 + 0.07 * i)
    return plates


def hurt():
    """Danger family: a short tritone rasp, never in the reward consonance."""
    return mix(0.35, (crunch(0.08, 0.02, 0.7), 0), (brass("Ab3", 0.25, 0.4), 0.0), (brass("D3", 0.25, 0.4), 0.0))


def death():
    """Melodramatic, then the wink: a falling sub and a dying brass Ab over D, then one bell."""
    out = mix(2.2, (sub(1.2, 200, 30, 0.6, 1.0), 0), (crunch(0.2, 0.06, 0.7), 0))
    place(out, chord(brass, ("D3", "Ab3"), 0.9, 0.35), 0.05)
    place(out, bell("D6", 0.5, ratio=2.0, level=0.3), 1.6)
    return out


# reward ------------------------------------------------------------------------------

def scrap_tick(tier):
    note = LADDER[tier - 1]
    return mix(0.2, (bell(note, 0.15, level=0.7), 0), (rhodes(note, 0.15, 0.35), 0),
               (noise_burst(0.008, 0.002, 2) * 0.3, 0))


def pickup_fountain():
    out = np.zeros(int(0.8 * SR))
    for i, note in enumerate(("D5", "E5", "F5", "A5", "B5", "D6")):
        place(out, bell(note, 0.25, level=0.4) + rhodes(note, 0.25, 0.2), 0.05 * i)
    return out


def part_get():
    return mix(0.7, (noise_burst(0.015, 0.004, 2) * 0.5, 0),
               (chord(rhodes, ("D4", "F4", "A4", "C5", "E5"), 0.6, 0.18, spread=0.02), 0.02))


def rarity_bell(level):
    """Common is one bell, rare adds a fifth, epic adds the ninth and a chiptune run."""
    notes = {"common": ("D5",), "rare": ("D5", "A5"), "epic": ("D5", "A5", "E6")}[level]
    out = chord(lambda n, s, l: bell(n, s, ratio=2.0, level=l), notes, 0.9, 0.35, spread=0.06)
    if level == "epic":
        run = mix(0.5, *[(square(n, 0.06, 0.12), 0.04 * i) for i, n in enumerate(("A5", "B5", "D6", "E6", "A6"))])
        out = mix(1.2, (out, 0), (run, 0.25))
    return out


def found_chime():
    return mix(0.6, (rhodes("A4", 0.2, 0.5), 0), (rhodes("D5", 0.45, 0.6), 0.1), (bell("A5", 0.4, 2.0, 0.2), 0.1))


def lore_found():
    """A page turns in a jazz club: a soft Rhodes Gm9 rolled upward, a page rustle."""
    return mix(1.4, (sweep(0.25, 1500, 5000, 0.15), 0),
               (chord(rhodes, ("G3", "Bb3", "D4", "F4", "A4"), 1.1, 0.16, spread=0.06), 0.05))


def achievement_chime():
    """The rice-cooker tune: a sax pickup E-F#-A landing on a D6/9 bell chord."""
    out = np.zeros(int(1.6 * SR))
    for note, at, length in (("E5", 0.0, 0.11), ("F#5", 0.11, 0.11), ("A5", 0.22, 0.5)):
        place(out, sax(note, length, 0.25), at)
    place(out, chord(lambda n, s, l: bell(n, s, 2.0, l), ("D5", "F#5", "B5", "E6"), 1.0, 0.18), 0.5)
    return out


def rescue_fanfare():
    out = np.zeros(int(1.8 * SR))
    for i, (note, at) in enumerate((("A4", 0), ("D5", 0.15), ("F#5", 0.3), ("A5", 0.45))):
        place(out, brass(note, 0.18 if i < 3 else 0.9, 0.3), at)
    place(out, chord(brass, ("D4", "F#4", "A4", "E5"), 0.9, 0.18), 0.45)
    place(out, bell("D6", 0.8, 2.0, 0.2), 0.45)
    return out


def pilot_unlocked():
    return mix(2.2, (rescue_fanfare(), 0), (sweep(0.6, 400, 8000, 0.25), 1.2), (bell("A6", 0.6, 2.0, 0.25), 1.5))


def synergy_fanfare():
    run = mix(0.6, *[(square(n, 0.07, 0.15) + rhodes(n, 0.07, 0.2), 0.045 * i)
                     for i, n in enumerate(("D5", "F5", "A5", "C6", "E6", "A6"))])
    return mix(1.3, (run, 0), (chord(brass, ("D4", "A4", "C5", "E5"), 0.7, 0.2), 0.3))


# boss --------------------------------------------------------------------------------

def boss_arena_in():
    """The versus stinger: two brass hits, a drum fill, a held power chord, a gong-like clang."""
    out = np.zeros(int(2.4 * SR))
    for at in (0.0, 0.23):
        place(out, chord(brass, ("D3", "A3", "D4"), 0.18, 0.35), at)
        place(out, sub(0.2, 110, 50, 0.08, 0.8), at)
    for i in range(6):
        place(out, crunch(0.06, 0.015, 0.4 + 0.08 * i), 0.47 + 0.058 * i)
    place(out, chord(brass, ("D3", "A3", "C4", "E4"), 1.6, 0.3), 0.82)
    low = sub(1.0, 90, 40, 0.5, 1.0)
    # This sub is still at 13% of its level when it ends; without a fade the step clicks.
    release = int(0.03 * SR)
    low[-release:] *= np.linspace(1, 0, release)
    place(out, low, 0.82)
    place(out, bell("D2", 1.4, ratio=2.76, level=0.5), 0.82)
    return out


def boss_phase():
    return mix(1.2, (crunch(0.1, 0.03, 0.8), 0), (chord(brass, ("D3", "Ab3"), 0.25, 0.35), 0),
               (chord(brass, ("E3", "Bb3", "D4"), 0.8, 0.3), 0.3), (sub(0.8, 100, 40, 0.4, 0.9), 0.3))


def boss_weak_hit():
    return mix(0.45, (crunch(0.07, 0.018, 0.9), 0), (sub(0.3, 180, 55, 0.1, 0.9), 0),
               (bell("A5", 0.35, ratio=2.0, level=0.4), 0.005))


def stinger_boss_defeated():
    """The knockout: one unison hit, a beat of silence, then a ii-V-I with a sax run home."""
    out = np.zeros(int(3.6 * SR))
    place(out, chord(brass, ("D3", "A3", "D4", "F4"), 0.4, 0.35), 0)
    place(out, sub(0.6, 120, 40, 0.3, 1.1), 0)
    place(out, crunch(0.2, 0.05, 0.8), 0)
    place(out, chord(rhodes, ("E3", "G3", "B3", "D4"), 0.5, 0.18), 0.93)
    place(out, chord(rhodes, ("A2", "G3", "C#4", "F#4"), 0.5, 0.18), 1.4)
    for note, at, length in (("E4", 0.93, 0.12), ("F#4", 1.05, 0.12), ("A4", 1.17, 0.12),
                             ("C#5", 1.4, 0.24), ("D5", 1.86, 1.2)):
        place(out, sax(note, length, 0.26), at)
    place(out, chord(brass, ("D4", "F#4", "A4", "B4", "E5"), 1.4, 0.18), 1.86)
    return out


# stingers ----------------------------------------------------------------------------

def cadence(home, level=0.16, length=1.2, sax_line=()):
    """A ii-V-I in D Dorian landing on D6/9, with an optional sax line on top."""
    out = np.zeros(int((0.9 + length) * SR))
    place(out, chord(rhodes, ("E3", "G3", "B3", "D4"), 0.45, level), 0)
    place(out, chord(rhodes, ("A2", "G3", "C#4", "F#4"), 0.45, level), 0.45)
    place(out, chord(rhodes, home, length, level), 0.9)
    for note, at, length_ in sax_line:
        place(out, sax(note, length_, 0.24), at)
    return out


def stinger_run():
    return mix(2.4, (cadence(("D3", "A3", "B3", "E4", "F#4"), sax_line=(("A4", 0.9, 0.9),)), 0),
               (sub(0.4, 90, 45, 0.15, 0.8), 0.9))


def stinger_stage():
    return mix(1.6, (brass("A3", 0.15, 0.3), 0), (brass("D4", 0.6, 0.35), 0.15), (sub(0.4, 90, 45, 0.15, 0.7), 0.15))


def stinger_clear():
    return cadence(("D3", "A3", "B3", "E4", "F#4"), sax_line=(("E4", 0.0, 0.2), ("F#4", 0.45, 0.2), ("A4", 0.9, 0.8)))


def stinger_world():
    return mix(3.0, (rescue_fanfare(), 0), (cadence(("D3", "A3", "B3", "E4", "F#4"), 0.12, 1.4), 1.0))


def stinger_milestone():
    return mix(1.0, (synergy_fanfare(), 0))


def stinger_run_end():
    return mix(2.2, (sub(0.6, 120, 40, 0.3, 0.9), 0), (chord(brass, ("D3", "A3", "D4"), 0.5, 0.3), 0),
               (cadence(("D3", "F3", "A3", "C4", "E4"), 0.12, 1.0), 0.6))


# ui and warnings ---------------------------------------------------------------------

def ui_tick():
    return mix(0.06, (noise_burst(0.004, 0.001, 3) * 0.5, 0), (rhodes("A5", 0.05, 0.3), 0))


def callout_chime():
    return mix(0.5, (bell("A5", 0.2, 2.0, 0.5), 0), (bell("D6", 0.35, 2.0, 0.5), 0.09))


def shop_bell():
    return mix(0.9, (bell("B5", 0.8, ratio=2.0, level=0.5), 0), (bell("D6", 0.7, ratio=2.0, level=0.4), 0.07),
               (noise_burst(0.01, 0.003, 2) * 0.4, 0))


def verb_fail():
    """A polite no: two dry wood ticks and a low Rhodes on the flat second, Eb."""
    return mix(0.35, (noise_burst(0.005, 0.0015, 3) * 0.5, 0), (noise_burst(0.005, 0.0015, 3) * 0.4, 0.08),
               (rhodes("Eb3", 0.22, 0.4), 0.08))


def threat_whistle():
    """The telegraph: a rising tritone whistle with rasp, the one sound that means move."""
    t = t_of(0.6)
    f = hz("D5") * 2 ** (0.5 * np.minimum(t / 0.5, 1))  # glides up a tritone to Ab5
    tone = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.minimum(t / 0.02, 1) * np.minimum((0.6 - t) / 0.05, 1).clip(0, 1)
    return mix(0.6, (tone * 0.6, 0), (sweep(0.6, 1500, 6000, 0.2), 0))


CUES = {
    "hit_thwack": ("impact", hit_thwack), "slam_boom": ("impact", slam_boom),
    "smash_crack": ("impact", smash_crack), "land_thud": ("impact", land_thud), "hop": ("impact", hop),
    "boost_whoosh": ("impact", boost_whoosh), "dash_whoosh": ("impact", dash_whoosh),
    "near_whoosh": ("impact", near_whoosh), "crit_ping": ("impact", crit_ping), "kill_pop": ("impact", kill_pop),
    **{f"kill_chain_tier_{n}": ("reward", lambda n=n: kill_chain_tier(n)) for n in range(1, 6)},
    "armor_shed": ("impact", armor_shed), "hurt": ("danger", hurt), "death": ("danger", death),
    **{f"scrap_tick_{n}": ("reward", lambda n=n: scrap_tick(n)) for n in range(1, 6)},
    "pickup_fountain": ("reward", pickup_fountain), "part_get": ("reward", part_get),
    **{f"rarity_bell_{k}": ("reward", lambda k=k: rarity_bell(k)) for k in ("common", "rare", "epic")},
    "found_chime": ("reward", found_chime), "lore_found": ("reward", lore_found),
    "achievement_chime": ("reward", achievement_chime), "rescue_fanfare": ("reward", rescue_fanfare),
    "pilot_unlocked": ("reward", pilot_unlocked), "synergy_fanfare": ("reward", synergy_fanfare),
    "boss_arena_in": ("boss", boss_arena_in), "boss_phase": ("boss", boss_phase),
    "boss_weak_hit": ("boss", boss_weak_hit), "stinger_boss_defeated": ("boss", stinger_boss_defeated),
    "stinger_run": ("stinger", stinger_run), "stinger_stage": ("stinger", stinger_stage),
    "stinger_clear": ("stinger", stinger_clear), "stinger_world": ("stinger", stinger_world),
    "stinger_milestone": ("stinger", stinger_milestone), "stinger_run_end": ("stinger", stinger_run_end),
    "ui_tick": ("ui", ui_tick), "callout_chime": ("ui", callout_chime), "shop_bell": ("reward", shop_bell),
    "verb_fail": ("ui", verb_fail), "threat_whistle": ("danger", threat_whistle),
}


def main():
    out_dir = Path(sys.argv[1])
    out_dir.mkdir(parents=True, exist_ok=True)
    manifest = []
    for name, (family, make) in CUES.items():
        audio = make()  # always made, so the shared seed reaches every later cue unchanged
        if name in FEEDBACK_OWNED:
            continue
        nz = np.nonzero(np.abs(audio) > 1e-4)[0]
        audio = audio[: nz[-1] + 1] if len(nz) else audio
        audio = audio / np.max(np.abs(audio)) * 10 ** (-1 / 20)
        fade = min(int(0.004 * SR), len(audio) // 4)
        audio[-fade:] *= np.linspace(1, 0, fade)
        sf.write(out_dir / f"{name}.wav", audio.astype(np.float32), SR, subtype="PCM_16")
        manifest.append(dict(cue=name, family=family, seconds=round(len(audio) / SR, 3)))
    (out_dir / "manifest.json").write_text(json.dumps(manifest, indent=1))
    print(f"{len(manifest)} cues written to {out_dir}")


if __name__ == "__main__":
    main()
