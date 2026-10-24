"""Fill every place and moment with its own twist of a current pick, and keep a registry of tunes.

    python gapfill.py <render folder> [tune id ...]

Andrew (2026-10-17): "The music is on point, finally" -- carry the current tracks through every
place and moment, each with its own twist, and hide some to discover and come back to. Every tune
here is an ACE-Step cover of one of his current picks (its beats and motifs kept, at cover strength
0.55 to 0.65), stretched to the moment's tempo, told the moment's mood in its caption, then split and
mastered through evolve.py's spice chain (--light for the calm ones). Two seeds per tune.

Writes <render folder>/gapfill/<tune id>-s<seed>.wav and tunes.json beside this file: one row per
tune with its id, display name, place, parent pick, whether it is hidden, and its takes, for the
camp jukebox's discovered-tunes list.
"""

import json
import subprocess
import sys
from pathlib import Path

import soundfile as sf

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from overnight import DEMUCS, PICKS  # noqa: E402

PY = sys.executable
SEEDS = sys.argv[sys.argv.index("--seeds") + 1].split(",") if "--seeds" in sys.argv else ["4101", "4102"]
NO = " No vocals. No pentatonic or East Asian melody or instruments."
PARENTS = {c: rel for c, (rel, _, _, _) in PICKS.items()}
PARENTS["combat-hype"] = "renders/lab-round6-1/grid129/combat-hype-cover-mechswing-s2601-129bpm.wav"

# id, display name, place, parent pick, bpm, key, strength, light mix, hidden, caption
TUNES = [
    # The six landmarks: a short statement when the landmark comes into view.
    ("landmark-spillway-dam", "Over the Dam", "Spillway Works: the dam", "roam-spillway", 172, "D minor", 0.6, False, False,
     "Instrumental soaring drum and bass with jazz-fusion harmony: a wall of water and a brass fanfare that opens up wide. Rolling breakbeat, booming sluice-gate thuds and steam hiss as percussion, an alto sax hook over big brass swells. Majestic, rushing, triumphant."),
    ("landmark-penstock", "Penstock Pressure", "Spillway Works: the penstock tower", "spillway-loop", 129, "D minor", 0.6, False, False,
     "Instrumental pumping house with jazz chords: rising pressure in a tower of pipes. Piston kicks, steam whistles that climb in pitch, a wheezing pipe-organ riff answering a tenor sax. Building, mechanical, proud."),
    ("landmark-headframe", "Down the Headframe", "The Dig: the headframe", "roam-dig", 172, "E minor", 0.6, False, False,
     "Instrumental dark drum and bass with jazz harmony: a mine elevator dropping into the earth. Clanking cage chains and winch whirs as percussion, a baritone sax growl, deep rolling sub bass. Heavy, descending, gritty."),
    ("landmark-sinkhole", "Sinkhole Echo", "The Dig: the sinkhole", "dig-loop", 129, "E minor", 0.6, False, False,
     "Instrumental dub house with jazz chords, inside a vast echoing pit. Dripping water and distant metal knocks with long dub delays, muted trumpet phrases bouncing off the walls, a deep wobbling bass. Mysterious, cavernous, hypnotic."),
    ("landmark-hanging-isle", "The Hanging Isle", "The Highdraft: the hanging isle", "roam-highdraft", 172, "G minor", 0.6, False, False,
     "Instrumental airy liquid drum and bass with jazz-fusion harmony, floating past an island in the sky. Harp glissandos, vibraphone, wind gusts and creaking rope as percussion, a soprano sax gliding over it. Weightless, wondrous, bright."),
    ("landmark-crown-spire", "Crown of the Spire", "The Highdraft: the crown spire", "highdraft-loop", 129, "G minor", 0.6, False, False,
     "Instrumental soaring progressive house with jazz harmony at the top of the world. A wordless choir pad, ringing bells, propeller whirs, a soprano sax playing its biggest phrase. Epic, high, a little uneasy."),
    # Random events.
    ("event-scrap-stampede", "Scrap Stampede", "Event: scrap stampede", "combat-hype", 150, "D minor", 0.55, False, False,
     "Instrumental frantic electro swing house: a stampede of scrap. Galloping drums, clattering metal and tumbling junk as percussion, a gritty electro bass, honking baritone sax riffs and brass stabs. Chaotic, fun, breathless."),
    ("event-surge-run", "Surge Run", "Event: surge run", "roam-spillway", 180, "D minor", 0.55, False, False,
     "Instrumental racing drum and bass with jazz-fusion chords, against the clock. A ticking stopwatch and rev-up whirs as percussion, a fast alto sax chase line, synth-brass hits on every turn. Urgent, thrilling, fast."),
    ("event-hold-relay", "Hold the Relay", "Event: hold the relay", "boss-brindle", 129, "D minor", 0.55, False, False,
     "Instrumental tense dark electro house with jazz bite, holding a position under fire. A relay clicking like a metronome, electric crackle, a pulsing bass and stabbing brass, a muted trumpet calling out. Stubborn, building, tense."),
    ("event-flood", "Flood Gates", "Event: flood", "spillway-loop", 129, "D minor", 0.6, False, False,
     "Instrumental underwater dub house with jazz chords, the stage flooding. Muffled kick, bubbling filter sweeps, gurgling pipes and rushing water as percussion, a tenor sax heard as if through water. Rising, swirling, strange."),
    ("event-dust-squall", "Dust Squall", "Event: dust squall", "roam-dig", 160, "E minor", 0.55, False, False,
     "Instrumental gritty desert western drum and bass with jazz harmony, a dust storm rolling in. Twanging baritone guitar, howling wind, sand hissing on metal, a harmonica-like reed and a growling sax. Dusty, wild, driving."),
    ("event-arena", "Round Arena", "Event and camp: the arena", "combat-hype", 129, "D minor", 0.55, False, False,
     "Instrumental big-room electro swing house for an arena fight with a crowd. Stomp-stomp-clap crowd rhythm, an announcer-like brass fanfare, a heavy electro bass and a hype alto sax hook. Rowdy, proud, pumping."),
    # Fights and shops.
    ("miniboss", "Heavyweight", "Mini-boss fights", "combat-hype", 135, "D minor", 0.6, False, False,
     "Instrumental heavy industrial electro house with jazz bite, a big machine stepping up. Hammering pistons and anvil hits as percussion, a distorted electro bass riff, brass stabs and a desperate alto sax. Heavy, aggressive, hype."),
    # The rogue fleet mini-bosses' anthems (design-v3/rogues/BRIEFS.md): each a singable lead hook,
    # a big-room build, a drop and a second, bigger drop; kick and bass carry the weight, the lead on top.
    ("anthem-gate-crane", "Gate Crane No. 14", "Rogue mini-boss: the Spillway's gate crane", "combat-hype", 140, "D minor", 0.5, False, False,
     "Instrumental bass-heavy big-room Eurodance anthem, a rogue gate crane swinging its hook. A bright singable synth-brass lead hook that swings up an octave and back down a fifth like a pendulum, leading over everything. Four-on-the-floor kick and a pumping sidechained sub bass carry the weight under it. A muted brass stab on every clang of the steel gate leaf. A long riser build, a huge drop, then a second, bigger drop. Heavy, triumphant, hype."),
    ("anthem-haul-skip", "Haul Skip No. 31", "Rogue mini-boss: the Dig's haul skip", "roam-dig", 145, "E minor", 0.5, False, False,
     "Instrumental bass-heavy big-room Eurodance anthem, a runaway mine skip on its rails. A driving offbeat rolling bass that clatters like rail wheels, and a singable synth lead on top: a there-and-back phrase that repeats one tone higher on the return. Punchy kick, a Latin cowbell pattern under the drop. A long riser build, a huge drop, then a second, bigger drop. Gritty, driving, hype."),
    ("anthem-cable-tender", "Cable Tender No. 7", "Rogue mini-boss: the Highdraft's cable tender", "roam-highdraft", 150, "G minor", 0.5, False, False,
     "Instrumental bass-heavy big-room Eurodance anthem, a cable machine that never stops pulling tension. A tense held-note synth lead that tightens and then snaps into a fast falling run, always on top of the mix. Hard kick and a thick sidechained sub bass under it. Jazz-harmony electric piano pads in the break. A long riser build, a big drop, then a second drop that cracks like a whip. Tense, soaring, hype."),
    ("moss-shop", "Moss's Counter", "Moss's shop", "camp", 112, "D minor", 0.55, True, False,
     "Instrumental warm bossa-nova lounge with jazz chords, a cosy junk shop. Brushed drums, upright bass, a mellow electric piano, a breathy tenor sax, a cash-register ding and ticking clocks. Relaxed, friendly, a little sly."),
    ("fabricator", "The Fabricator", "The fabricator", "title-b", 120, "D minor", 0.55, False, False,
     "Instrumental mechanical funk house with jazz chords, a machine building something. Ratchets, welding sparks, conveyor clanks and piston hits locked to the beat, a robotic synth lead answered by a saxophone. Busy, clever, satisfying."),
    ("camp-course", "The Course", "Camp: the movement course", "title-c", 172, "D major", 0.55, False, False,
     "Instrumental upbeat showtime drum and bass with jazz brass, a timed obstacle course. Starting-pistol snare, ticking timer, bright brass and an alto sax racing the clock. Cheeky, fast, joyful."),
    # Run modifiers.
    ("modifier-curse", "Cursed Run", "Run modifier: a curse", "summary-loss", 100, "D minor", 0.6, True, False,
     "Instrumental dark jazz-club lounge with a sinister twist, a cursed run. Detuned piano, a creeping upright bass, a smoky tenor sax that bends notes flat, ghostly whirs and a distant ticking clock. Moody, eerie, sly."),
    ("modifier-par", "Beat the Par", "Run modifier: par time", "title-c", 176, "D major", 0.55, False, False,
     "Instrumental breakneck drum and bass with big-band brass, racing par time. A ticking stopwatch, a fast walking bass, brass shouts and a screaming alto sax. Frantic, joyful, triumphant."),
    # Hidden: found, not given.
    ("secret-lost-tape", "The Lost Tape", "Hidden: the Cable Reach cache", "title-a", 90, "D minor", 0.6, True, True,
     "Instrumental lo-fi jazz hip-hop from a worn cassette found in a cache. Dusty boom-bap drums, tape hiss and wow, a warm Rhodes, a sleepy tenor sax playing the theme. Nostalgic, intimate, warm."),
    ("secret-after-hours", "Moss After Hours", "Hidden: Moss's bay jukebox", "summary-loss", 96, "D minor", 0.55, True, True,
     "Instrumental late-night jazz club trio and sax, the bar after closing. Brushed drums, walking upright bass, a piano comping softly, a tenor sax stretching the melody out. Smoky, loose, intimate."),
    ("secret-brindle-swing", "Brindle Swings", "Hidden: a rare remix", "boss-brindle", 160, "D minor", 0.55, False, True,
     "Instrumental big-band swing with electro bass, a boss theme played by a full jazz orchestra. Swinging ride and snare, trombone section riffs, trumpet shouts, a clarinet and alto sax trading solos. Brassy, playful, hot."),
    ("secret-chip-keepers", "Chiptune Keepers", "Hidden: a rare remix", "combat-hype", 150, "D minor", 0.55, False, True,
     "Instrumental chiptune electro house with jazz chords, a fight theme played on an 8-bit console. Square-wave lead, noise-channel drums, an arpeggiated bass and a fat modern sub. Bouncy, nerdy, hype."),
    ("secret-highdraft-rain", "Rain over the Highdraft", "Hidden: a rare remix", "roam-highdraft", 86, "G minor", 0.6, True, True,
     "Instrumental slow jazz with light rain on a canvas sail, a clear night high in the sky. Crisp brushes and ride cymbal, bright vibraphone melody, a soprano sax lead up front. Calm, dreamy, lonely, open and airy."),
    ("secret-dig-dub", "Deep Works Dub", "Hidden: a rare remix", "dig-loop", 140, "E minor", 0.6, False, True,
     "Instrumental heavy dubstep-jazz from deep underground. Huge half-time drums, a growling wobble bass, pickaxe clinks, a baritone sax through a dub echo. Dark, heavy, swaggering."),
]

# Anthem candidates (ruling 19 Oct: every boss, mini-boss and intense event gets a bass-heavy EDM
# anthem). Rendered with --anthems into anthem-candidates.json, not tunes.json: they are takes for
# Andrew to pick from, and a pick replaces the slot's current track. Boss finals sit at 140 to 150.
ANTHEM = (" Bass-heavy big-room Eurodance anthem: a singable synth lead hook on top, a hard kick and pumping"
          " sub bass under it, a riser build, a huge drop, then a bigger second drop.")
ANTHEMS = [
    ("anthem-brindle", "Brindle Goes Big", "Boss: Brindle, the Spillway's foreman", "boss-brindle", 140, "D minor", 0.5, False, False,
     "Instrumental. A boiling flume boss that requisitions, stokes its furnace and scuttles. Brass-stab lead answered by an alto sax, furnace whoosh and steam-valve shrieks in the build." + ANTHEM + " Hot, proud, unstoppable."),
    ("anthem-waking", "The Waking Rises", "Boss: the Waking, under the Dig", "boss-waking", 145, "D minor", 0.5, False, False,
     "Instrumental. Something huge waking under the mine. A low growling lead that climbs a step each bar, rumbling stone and chain rattles in the build, baritone sax under the second drop." + ANTHEM + " Dark, colossal, driving."),
    ("anthem-mind", "All Hands", "Boss: the Mind, the foreman of the fleet", "boss-mind", 150, "E minor", 0.5, False, False,
     "Instrumental. The fleet's thinking machine calls every hand at once. A cold arpeggiated lead that turns into a soaring human-sounding synth melody, relay clicks and servo whirs in the build, a wordless choir pad on the second drop." + ANTHEM + " Epic, eerie, triumphant."),
    ("anthem-champion", "Champion's Lap", "Boss: the champion", "combat-hype", 145, "D minor", 0.5, False, False,
     "Instrumental. A victory-lap fight against the best. A bright stadium synth-brass lead, crowd stomp-clap in the build, an alto sax shout over the second drop." + ANTHEM + " Cocky, bright, hype."),
    ("anthem-miniboss", "Heavyweight Anthem", "Mini-boss: the surge mini-boss", "combat-hype", 140, "D minor", 0.5, False, False,
     "Instrumental. A big machine steps into the ring. A punchy two-note synth hook, hammering pistons and anvil hits in the build, brass stabs on the drop." + ANTHEM + " Heavy, aggressive, hype."),
    ("anthem-scrap-stampede", "Stampede Anthem", "Event: scrap stampede", "combat-hype", 150, "D minor", 0.5, False, False,
     "Instrumental. A stampede of scrap. A galloping synth lead, clattering junk percussion in the build, honking baritone sax riffs on the drop." + ANTHEM + " Chaotic, breathless, fun."),
    ("anthem-surge-run", "Surge Anthem", "Event: surge run", "roam-spillway", 150, "D minor", 0.5, False, False,
     "Instrumental. A race against the clock. A fast chasing synth lead, a ticking stopwatch and rev-up whirs in the build, synth-brass hits on the drop." + ANTHEM + " Urgent, thrilling."),
    ("anthem-hold-relay", "Hold the Line", "Event: hold the relay", "boss-brindle", 140, "D minor", 0.5, False, False,
     "Instrumental. Holding a position under fire. A stubborn repeating synth lead, a relay clicking like a metronome and electric crackle in the build, a muted trumpet call over the drop." + ANTHEM + " Stubborn, tense, rising."),
    ("anthem-flood", "Floodgate Anthem", "Event: flood", "spillway-loop", 140, "D minor", 0.5, False, False,
     "Instrumental. The stage floods. A rising synth lead that swells like water, rushing water and gurgling pipes in the build, a filter sweep that bursts open on the drop." + ANTHEM + " Rising, swirling, huge."),
    ("anthem-dust-squall", "Squall Anthem", "Event: dust squall", "roam-dig", 145, "E minor", 0.5, False, False,
     "Instrumental. A dust storm rolls in. A twanging baritone-guitar hook doubled by a synth lead, howling wind and sand hiss in the build, a growling sax on the second drop." + ANTHEM + " Dusty, wild, driving."),
    ("anthem-arena", "Arena Anthem", "Event and camp: the arena", "combat-hype", 145, "D minor", 0.5, False, False,
     "Instrumental. An arena fight with a roaring crowd. An announcer-style brass fanfare lead, stomp-stomp-clap crowd rhythm in the build, a hype alto sax hook on the drop." + ANTHEM + " Rowdy, proud, pumping."),
]

# Phase anthems (Andrew, 23 Oct): a fight's anthem has halves. Phase 1 is intense; the next phase
# ratchets it up by magnitudes: faster, heavier bass, a more erratic, layered and complex lead.
# Bosses have up to three phases, mini-bosses two. Each later phase is a cover of the phase-1 pick
# (its hook kept), 10 BPM up per phase, in the same key. Rendered with --phases into anthem-phases.json.
RATCHET = (" Phase two of the same anthem, ratcheted up by magnitudes: the same lead hook now faster, more"
           " erratic, layered with counter-melodies and stutter edits, a heavier distorted sub bass, harder kick.")
FINALE = (" Final phase of the same anthem at full overdrive: the lead hook doubled in octaves and chopped into"
          " frantic runs, a growling reese bass, rolling kicks, every layer at once, then a last huge drop.")
P1 = {"anthem-gate-crane": "anthem-gate-crane-s4102", "anthem-haul-skip": "anthem-haul-skip-s4102",
      "anthem-cable-tender": "anthem-cable-tender-s4101", "anthem-miniboss": "anthem-miniboss-s4202",
      "anthem-brindle": "anthem-brindle-s4202", "anthem-waking": "anthem-waking-s4202", "anthem-champion": "anthem-champion-s4201",
      "anthem-mind": "anthem-mind-s4304"}
for _id, _take in P1.items():
    PARENTS[_id] = f"gapfill/{_take}.wav"
_SHORT = {"anthem-gate-crane": ("Gate Crane No. 14", "a rogue gate crane swinging its hook", 140, "D minor"),
          "anthem-haul-skip": ("Haul Skip No. 31", "a runaway mine skip on its rails", 145, "E minor"),
          "anthem-cable-tender": ("Cable Tender No. 7", "a cable machine pulling tension", 150, "G minor"),
          "anthem-miniboss": ("Heavyweight Anthem", "a big machine in the ring", 140, "D minor"),
          "anthem-champion": ("Champion's Lap", "a victory-lap fight against the best", 145, "D minor"),
          "anthem-brindle": ("Brindle Goes Big", "the Spillway's foreman boiling over", 140, "D minor"),
          "anthem-waking": ("The Waking Rises", "something huge waking under the mine", 145, "D minor"),
          "anthem-mind": ("All Hands", "the fleet's thinking machine calling every hand", 150, "E minor")}
PHASES = []
for _id, (_name, _scene, _bpm, _key) in _SHORT.items():
    PHASES.append((f"{_id}-p2", f"{_name}, Phase 2", "Phase 2: " + _scene, _id, _bpm + 10, _key, 0.6, False, False,
                   f"Instrumental bass-heavy big-room Eurodance anthem, {_scene}." + RATCHET))
    if _id in ("anthem-brindle", "anthem-waking", "anthem-mind"):
        PHASES.append((f"{_id}-p3", f"{_name}, Phase 3", "Phase 3: " + _scene, _id, _bpm + 20, _key, 0.55, False, False,
                       f"Instrumental bass-heavy big-room Eurodance anthem, {_scene}." + FINALE))


def tempo_of(path):
    name = Path(path).stem
    for part in name.split("-"):
        if part.endswith("bpm") and part[:-3].isdigit():
            return float(part[:-3])
    return None


def source(root, tune):
    """The parent pick stretched to the tune's tempo with Rubber Band and cut to 64 s."""
    tid, _, _, parent, bpm = tune[:5]
    out = root / "gapfill" / "src" / f"{tid}-{bpm}.wav"
    if out.exists():
        return out
    out.parent.mkdir(parents=True, exist_ok=True)
    src = root / PARENTS[parent]
    read = tempo_of(src) or float(subprocess.run([PY, "-I", "-c", (
        "import sys; sys.path.insert(0, %r); import cut_loops, soundfile as sf; x, sr = sf.read(%r); "
        "m = x.mean(axis=1) if x.ndim > 1 else x; f, r = cut_loops.onset_envelope(m, sr); "
        "print(cut_loops.tempo(f, r, 80, 180))") % (str(HERE), str(src))], capture_output=True, text=True, check=True).stdout)
    tmp = out.with_suffix(".tmp.wav")
    subprocess.run(["rubberband", "-q", "--fine", "-T", f"{bpm / read:.5f}", str(src), str(tmp)], check=True, capture_output=True)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(tmp), "-t", "64", "-ar", "48000", str(out)], check=True)
    tmp.unlink()
    return out


def main(argv):
    root = Path(argv[0])
    wanted = {a for a in argv[1:] if not a.startswith("--") and a != ",".join(SEEDS)}
    table = PHASES if "--phases" in argv else ANTHEMS if "--anthems" in argv else TUNES
    tunes = [t for t in table if not wanted or t[0] in wanted]
    ace_path = root / "ace.json"
    ace = json.loads(ace_path.read_text())
    rnd = "gapfill"
    ace["experiments"][rnd] = {"hypothesis": "Gap fill: every place and moment gets a twist of a current pick; hidden tunes to discover.",
                               "variants": [dict(name=t[0], task_type="cover", src_audio=str(source(root, t)), audio_cover_strength=t[6],
                                                 bpm=t[4], keyscale=t[5], duration=64, thinking=False, lyrics="[Instrumental]",
                                                 caption=t[9] + NO) for t in tunes]}
    ace_path.write_text(json.dumps(ace, indent=1))
    before = set((root / "renders").glob(f"lab-{rnd}-*"))
    subprocess.run([str(HERE / "ace_lab.sh"), str(root), rnd, *SEEDS, "--mode", "final"], check=True)
    run = sorted(set((root / "renders").glob(f"lab-{rnd}-*")) - before)[-1]
    out = root / "gapfill"
    registry_path = HERE / {id(PHASES): "anthem-phases.json", id(ANTHEMS): "anthem-candidates.json"}.get(id(table), "tunes.json")
    registry = {r["id"]: r for r in json.loads(registry_path.read_text())} if registry_path.exists() else {}
    for job in json.loads((run / "manifest.json").read_text()):
        tune = next((t for t in tunes if t[0] == job["name"]), None)
        if tune is None or not job.get("success"):
            continue
        takes = []
        for audio in job["audios"]:
            name = f"{tune[0]}-s{audio['seed']}"
            raw = out / f"{name}-raw.wav"
            x, sr = sf.read(audio["path"])
            sf.write(raw, x, sr)
            subprocess.run(["nice", "-n", "10", str(DEMUCS), "-n", "htdemucs_6s", "-d", "cuda", "-o", str(out / "stems"), str(raw)],
                           check=True, capture_output=True)
            stems = out / "stems" / "htdemucs_6s" / raw.stem
            subprocess.run([PY, "-I", str(HERE / "evolve.py"), "master", str(stems), str(out / f"{name}.wav"),
                            "--light" if tune[7] else "--spice"], check=True)
            takes.append(f"{name}.wav")
        registry[tune[0]] = dict(id=tune[0], display_name=tune[1], place=tune[2], parent=tune[3], bpm=tune[4], key=tune[5],
                                 hidden=tune[8], takes=takes, pick=None)
        print(tune[0], len(takes), flush=True)
    registry_path.write_text(json.dumps([registry[t[0]] for t in table if t[0] in registry], indent=1) + "\n")


if __name__ == "__main__":
    main(sys.argv[1:])
