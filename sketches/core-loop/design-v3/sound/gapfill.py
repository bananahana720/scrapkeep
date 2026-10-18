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
    wanted = {a for a in argv[1:] if not a.startswith("--") and a not in SEEDS}
    tunes = [t for t in TUNES if not wanted or t[0] in wanted]
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
    registry_path = HERE / "tunes.json"
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
    registry_path.write_text(json.dumps([registry[t[0]] for t in TUNES if t[0] in registry], indent=1) + "\n")


if __name__ == "__main__":
    main(sys.argv[1:])
