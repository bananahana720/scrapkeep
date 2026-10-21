"""Hybrid cover sources for the 8 failing Furnace FM takes (SCORE.md 'Per cue' steps 1-3).

Hybrid = parent bass 0 dB + parent drums -9 dB + parent other -12 dB + the motif lead (themes.py
sax voice, notes from themes.py derive()) laid out on the take's bpm grid along the brief's
arrangement map (~/scratch/w17/qp/briefs/heat.md). Run with python -B so themes.py writes no
bytecode into the repo.

    python -B build_hybrid.py build <take|all>
    python -B build_hybrid.py timeline <take>      prints the expected lead notes (json) for checks
"""
import json
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

SCORE = "/home/andrew/Projects/scrapkeep/.claude/worktrees/focused-curie-deb115/sketches/core-loop/design-v3/score"
sys.path.insert(0, SCORE)
import themes as T  # noqa: E402

SR = T.SR
RADIO = Path("/home/andrew/Music/Scrapkeep-sound-direction/sound-bible-2026-10-16/radio/src")
DOWN3 = Path("/home/andrew/scratch/w17/qp/remake/src")
WORK = Path("/home/andrew/scratch/w17/qp/hybrid-work")
OUT = Path("/home/andrew/scratch/w17/qp/remake/src")
GAINS_DB = {"bass": 0.0, "drums": -9.0, "other": -12.0}


# phrases: lists of (beat, midi, beats, swing) -------------------------------------------------

def ph(notes, swing):
    return [(b, m, d, swing) for b, m, d in notes]


def cue(c, first=None, last=None):
    notes, chords, swing = T.derive(c)
    if first:
        notes = T.take_bars(notes, first, last)
    return ph(notes, swing)


def octv(p, k):
    return [(b, m + 12 * k, d, s) for b, m, d, s in p]


def keyed(theme, first, last, tonic, mode):
    th = T.THEMES[theme]
    notes = T.take_bars(th["notes"], first, last)
    notes, _ = T.to_mode(th, notes, [], tonic, mode)
    return ph(notes, th["swing"])


def third_above(p, tonic, mode):
    """Diatonic third above each note (the champion brass line)."""
    t0, sc = T.TONIC[tonic], T.MODES[mode]
    out = []
    for b, m, d, s in p:
        o, pc = divmod(m - t0, 12)
        deg = max(i for i, x in enumerate(sc) if x <= pc)
        deg2 = deg + 2
        out.append((b, t0 + 12 * (o + deg2 // 7) + sc[deg2 % 7] + (pc - sc[deg]), d, s))
    return out


def sub(p, first, last):
    """Bars first..last of a phrase, re-timed to 0, swing kept."""
    lo, hi = 4 * (first - 1), 4 * last
    return [(b - lo, m, d, s) for b, m, d, s in p if lo <= b < hi]


def hold(midi, beats):
    return [(0, midi, beats, False)]


def join(*parts_and_bars):
    """join((phrase, bars), ...) -> one phrase, each part offset by the bars before it."""
    out, at = [], 0
    for p, nb in parts_and_bars:
        out += [(b + 4 * at, m, d, s) for b, m, d, s in p]
        at += nb
    return out


def letgo(tonic):
    return keyed("S", 3, 4, tonic, "major")


def halftime(p):
    return [(2 * b, m, 2 * d, s) for b, m, d, s in p]


REST = []

# per take: source, bpm, cues used, and the arrangement as (bars, lead phrase, phrase bars,
# counter phrase or None, counter bars, label). A phrase loops inside its section and is cut at
# the section end. Section bar counts come from each brief's (d) table.

def takes():
    K_brindle_ans = T.counter("boss-brindle")[0]  # K bars 1-2 after the 4-bar statement
    duel = join((cue("boss-brindle"), 4), (ph([(b - 16, m, d) for b, m, d in K_brindle_ans], True), 2))
    M4 = cue("boss-brindle")
    K2d = cue("roam-spillway")  # D Dorian call bars 1-2
    inv = cue("boss-mind")
    upright_g = keyed("K", 1, 8, "G", "lydian_minor")
    gmaj = cue("boss-mind-final")
    cannon = [(0, 59, 1, False), (1, 64, .5, False), (1.5, 67, .5, False), (2, 74, 2, False)]
    hd = cue("roam-highdraft")
    hd_last_withheld = sub(hd, 1, 2)[:-1]
    E2 = keyed("K", 1, 2, "E", "dorian")
    champ = cue("champion")
    champ_third = third_above(K2d, "D", "dorian")
    stamp_low = octv(cue("boss-brindle", 1, 2), -1)
    stamp = cue("boss-brindle", 1, 2)
    K2low = octv(K2d, -1)
    return {
        "take-brindle-afterburner": dict(
            src=RADIO / "take-brindle-afterburner-148.wav", bpm=148,
            cues="boss-brindle (M bars 1-4, D Aeolian, answered by K bars 1-2); Let-Go = S bars 3-4",
            sections=[
                (8, M4, 4, None, 0, "Hook: Stamp + decree (M 1-4) twice"),
                (16, duel, 6, None, 0, "Duel: M 1-4 answered by K 1-2"),
                (8, M4, 4, None, 0, "Build: M 1-4"),
                (16, duel, 6, None, 0, "Chorus: M and K trade"),
                (7, K2d, 2, None, 0, "Turn: K call"),
                (8, M4, 4, None, 0, "Bass only: Stamp"),
                (16, K2d, 2, None, 0, "Rebuild: Call alone"),
                (1, hold(62, 4), 1, None, 0, "Count-in: held D4"),
                (32, M4, 4, None, 0, "Finale: Stamp unison (kept at 148, the source tempo)"),
                (16, join((K2d, 2), (K2d, 2), (K2d, 2), (K2d, 2), (K2d, 2), (K2d, 2), (K2d, 2), (letgo("D"), 2)), 16, None, 0, "Final return: Call, last 2 bars Let-Go"),
                (1, hold(62, 1), 1, None, 0, "Button: D hit"),
            ]),
        "take-mind-overclock": dict(
            src=RADIO / "take-mind-overclock-150.wav", bpm=150,
            cues="boss-mind (K 1-8 inverted in G) then boss-mind-final (K 1-8 G major); Cannon cell from heat.md motif 4; Let-Go in G",
            sections=[
                (4, sub(inv, 1, 2), 2, None, 0, "Cold open: inverted call twice"),
                (16, inv, 8, None, 0, "Hard house A: inverted K"),
                (16, upright_g, 8, None, 0, "Answer: K upright, G"),
                (16, inv, 8, None, 0, "Glitch build: inverted K"),
                (16, upright_g, 8, octv(inv, -1), 8, "Peak: upright above, inverted below"),
                (6, inv, 8, None, 0, "Wind-down"),
                (4, join((cannon, 1), (hold(74, 8), 2)), 4, None, 0, "Fake ending: Cannon cell, held D5"),
                (1, hold(67, 4), 1, None, 0, "Count-in: held G4"),
                (32, gmaj, 8, None, 0, "Eurodance finale: K in G major"),
                (16, join((gmaj, 8), (sub(gmaj, 1, 6), 6), (letgo("G"), 2)), 16, None, 0, "Final return: K G major, Let-Go in G"),
                (4, hold(67, 16), 4, None, 0, "Button: G rings"),
            ]),
        "take-highdraft-hands-up": dict(
            src=RADIO / "take-highdraft-hands-up-145.wav", bpm=145,
            cues="roam-highdraft (K 1-8, G with minor third and raised fourth, last note cut short)",
            sections=[
                (8, sub(hd, 1, 2), 2, None, 0, "Hook: call bars 1-2"),
                (16, sub(hd, 1, 4), 4, None, 0, "Verse: K 1-4"),
                (8, sub(hd, 1, 4), 4, None, 0, "Riser: K 1-4"),
                (16, sub(hd, 1, 4), 4, None, 0, "Drop 1: K 1-4"),
                (8, sub(hd, 5, 8), 4, None, 0, "Breath: K 5-8, last note short"),
                (4, sub(hd, 1, 4), 4, None, 0, "Riser 2: K 1-4"),
                (16, hd, 8, None, 0, "Drop 2: all 8 bars"),
                (5.5, join((sub(hd, 1, 2), 2), (hd_last_withheld, 2)), 4, None, 0, "Final return: call, last note withheld"),
            ]),
        "take-top-shelf-overdrive": dict(
            src=RADIO / "take-top-shelf-overdrive-150.wav", bpm=150,
            cues="roam-spillway (K bars 1-2, D Dorian); E Dorian for the key change (to_mode)",
            sections=[
                (8, K2d, 2, None, 0, "Hook: Call"),
                (16, K2d, 2, None, 0, "Groove: Call"),
                (13, sub(K2d, 1, 1), 1, None, 0, "Filter build: bar 1 repeated"),
                (16, octv(K2d, 1), 2, K2d, 2, "808 drop: Call up an octave, answer at pitch"),
                (4, K2d, 2, None, 0, "Breath: Call"),
                (8, K2d, 2, None, 0, "Re-entry: Call"),
                (17.5, E2, 2, None, 0, "Key change: Call in E Dorian"),
                (1.25, hold(64, 1), 1.25, None, 0, "Button: E hit"),
            ]),
        "take-champion-club-mix": dict(
            src=DOWN3 / "take-champion-club-mix-140-down3.wav", bpm=140,
            cues="champion (K bars 1-2 up an octave, D Dorian, against M); brass third = diatonic third above at the original octave",
            sections=[
                (8, champ, 2, None, 0, "Hook: Call up an octave"),
                (16, champ, 2, champ_third, 2, "Verse: hook, brass a third above"),
                (8, champ, 2, None, 0, "Build"),
                (16, champ, 2, stamp_low, 2, "Drop 1: hook, Stamp under"),
                (8, hold(76, 8), 2, None, 0, "Breakdown: E5 held"),
                (4, champ, 2, None, 0, "Build 2"),
                (16, champ, 2, champ_third, 2, "Final drop: hook and brass third"),
                (3, join((letgo("D"), 2), (REST, 1)), 3, None, 0, "Tail: Let-Go"),
            ]),
        "take-round-arena-main-event": dict(
            src=DOWN3 / "take-round-arena-main-event-129-down3.wav", bpm=129,
            cues="combat-hype (K bars 1-2, D Dorian, against M bars 1-2)",
            sections=[
                (4, REST, 4, None, 0, "Stomp intro: lead silent"),
                (8, sub(K2d, 1, 1), 2, None, 0, "Fanfare: Call bar 1, then a bar of space"),
                (16, K2d, 2, None, 0, "Verse: Call and answer"),
                (8, K2d, 2, None, 0, "Build"),
                (16, K2d, 2, stamp_low, 2, "Big-room drop: hook, Stamp under"),
                (1, REST, 1, None, 0, "Ring bell"),
                (20, K2d, 2, stamp_low, 2, "Final round (kept at 129, the source tempo)"),
                (1, hold(62, 1), 1, None, 0, "Button"),
            ]),
        "take-heavyweight-big-room": dict(
            src=DOWN3 / "take-heavyweight-big-room-132-down3.wav", bpm=132,
            cues="combat-hype (K bars 1-2 D Dorian over M bars 1-2); Stamp from boss-brindle bars 1-2, an octave down",
            sections=[
                (8, stamp_low, 2, None, 0, "Riff: Stamp, low"),
                (16, K2d, 2, stamp_low, 2, "Build A: Call over the Stamp"),
                (4, K2d, 2, None, 0, "Anvil roll"),
                (16, K2d, 2, stamp_low, 2, "Drop 1"),
                (8, halftime(K2d), 4, None, 0, "Half-time sax"),
                (4, stamp_low, 2, None, 0, "Re-build: riff"),
                (16, K2d, 2, stamp_low, 2, "Double drop"),
                (2, letgo("D"), 2, None, 0, "Tail: Let-Go"),
            ]),
        "take-stampede-encore": dict(
            src=DOWN3 / "take-stampede-encore-150-down3.wav", bpm=150,
            cues="combat-hype call (K bars 1-2 D Dorian) down an octave; Stamp (boss-brindle bars 1-2) as brass counter",
            sections=[
                (4, K2low, 2, None, 0, "Hook: Call down an octave"),
                (16, join((K2low, 2), (REST, 2)), 4, join((REST, 2), (stamp, 2)), 4, "A: Call, Stamp between phrases"),
                (4, K2low, 2, None, 0, "Turn"),
                (8, K2low, 2, None, 0, "Bari break"),
                (2, REST, 2, None, 0, "Breath"),
                (16, K2low, 2, stamp, 2, "Final A: Call and Stamp together"),
                (3, join((letgo("D"), 2), (REST, 1)), 3, None, 0, "Bow: Let-Go"),
            ]),
    }


def timeline(take, spec, offset):
    """Absolute (seconds, midi, seconds) for lead and counter."""
    spb = 60 / spec["bpm"]
    lead, ctr, bar0 = [], [], 0.0
    for nb, p, pb, cp, cb, _ in spec["sections"]:
        for dst, phrase, plen in ((lead, p, pb), (ctr, cp or [], cb or 1)):
            k = 0
            while phrase and k * plen < nb:
                for b, m, d, s in phrase:
                    beat = 4 * (k * plen) + T.swung(b, s)
                    if beat >= 4 * nb:
                        continue
                    d = min(d, 4 * nb - beat)
                    dst.append((offset + (bar0 * 4 + beat) * spb, m, d * spb * 0.95))
                k += 1
        bar0 += nb
    return lead, ctr


def beat_offset(drums, bpm):
    """Phase of the beat grid in the drums stem, by folding an onset envelope over one beat."""
    mono = drums.mean(axis=1)
    hop = 240
    env = np.abs(mono[: len(mono) // hop * hop]).reshape(-1, hop).mean(axis=1)
    onset = np.maximum(np.diff(env, prepend=env[0]), 0)
    spb_frames = 60 / bpm * SR / hop
    phases = np.arange(len(onset)) % spb_frames
    bins = np.zeros(int(np.ceil(spb_frames)))
    np.add.at(bins, phases.astype(int), onset)
    return int(np.argmax(bins)) * hop / SR


def render(events, n, voice):
    buf = np.zeros(n)
    for at, m, dur in events:
        T.put(buf, voice(m, max(dur, 0.05)), at)
    return buf


def rms(x):
    return float(np.sqrt(np.mean(np.square(x)) + 1e-20))


def build(take, spec):
    src_audio, sr = sf.read(spec["src"], always_2d=True)
    assert sr == SR, sr
    n = len(src_audio)
    stem_dir = WORK / "stems" / "htdemucs" / spec["src"].stem
    stems = {k: sf.read(stem_dir / f"{k}.wav", always_2d=True)[0] for k in ("bass", "drums", "other")}
    for k, v in stems.items():
        stems[k] = np.pad(v, ((0, max(0, n - len(v))), (0, 0)))[:n]
    off = beat_offset(stems["drums"], spec["bpm"])
    lead_ev, ctr_ev = timeline(take, spec, off)
    lead = render(lead_ev, n, T.sax)
    ctr = render(ctr_ev, n, T.mute_brass)
    band = sum(10 ** (GAINS_DB[k] / 20) * stems[k] for k in GAINS_DB)
    # lead at full level: its RMS over the voiced part set to the parent full mix's RMS
    voiced = np.abs(lead) > 1e-4
    lead_gain = rms(src_audio) / (rms(lead[voiced]) if voiced.any() else 1)
    lead *= lead_gain
    ctr *= lead_gain * 10 ** (-6 / 20)
    mix = band.copy()
    mix[:, 0] += 0.55 * lead + 0.6 * ctr  # lead a touch left of centre, counter a touch right
    mix[:, 1] += 0.45 * lead + 0.4 * ctr
    lead_mono = lead / (np.abs(lead).max() or 1) * 0.8
    peak = np.abs(mix).max()
    ceiling = 10 ** (-1.5 / 20)
    trim_db = 0.0
    if peak > ceiling:
        trim_db = 20 * np.log10(ceiling / peak)
        mix *= ceiling / peak
    bpm = spec["src"].stem.split("-")[-2] if spec["src"].stem.endswith("down3") else spec["src"].stem.split("-")[-1]
    out = OUT / f"{take}-{bpm}-hybrid.wav"
    sf.write(out, mix.astype(np.float32), SR, subtype="PCM_24")
    sf.write(WORK / f"{take}-lead.wav", lead_mono.astype(np.float32), SR, subtype="PCM_24")
    meta = dict(take=take, out=str(out), src=str(spec["src"]), bpm=spec["bpm"], cues=spec["cues"],
                beat_offset_s=round(off, 4), gains_db=GAINS_DB, counter_db_rel_lead=-6,
                lead_gain=round(float(lead_gain), 3), master_trim_db=round(trim_db, 2),
                sections=[(nb, lab) for nb, *_, lab in spec["sections"]],
                lead_events=lead_ev)
    (WORK / f"{take}-meta.json").write_text(json.dumps(meta, indent=1))
    print(take, out.name, "offset", round(off, 3), "trim_db", round(trim_db, 2), "lead events", len(lead_ev))


def main(argv):
    allt = takes()
    names = list(allt) if argv[2] == "all" else argv[2:]
    for t in names:
        stem_dir = WORK / "stems" / "htdemucs" / allt[t]["src"].stem
        if not (stem_dir / "other.wav").exists():
            print("no stems yet:", t)
            continue
        build(t, allt[t])


if __name__ == "__main__":
    main(sys.argv)
