"""Bones and clips for the four kill-first specials, timed to their sounds.

Each body recipe calls one function here after it has built its meshes and sockets; the
function rigs the meshes (kill_first_rig.Rig) and keys the clips. Times are seconds from
the frame the matching sound starts (design-v3/sound/specials.py, PR #12):

  Foreman     idle 3.72 loop (two bars: the punch clock ticks the beat, steam at 3.5 and
              7.5 beats, the throat-clear at 6); tell 0.9 (horn full from frame one, steam
              at 0.55); break 2.4 (ka-chunk at 0, sigh, trombone wah at 0.45, 0.71, 0.97,
              1.23).
  Dispatcher  idle 3.72 loop (radar quarter turn on each beat ping, paper feed on the
              teleprinter off-beats); tell 1.0 (tube sucks up over 0.45, dings at 0.45 and
              0.6, the drop); break 1.6 (printer jam, spring sproing, beacon falls).
  Splitter    crawl 3.72 loop (a step on every beat); tell 0.4 (seams flare, three voices
              converge and cut dead at 0.4: the split frame); break_split 0.2 (rammed: the
              pods burst out, then the runtime swaps in three pieces); break_clean 1.0 (fat
              pop and the reward ding).
  Piece       scurry one beat loop; pop_in 0.25 (born out of the burst).
  Linker      idle 3.72 loop; brace 0.8 (pluck at 0, the cable twangs taut while the dish
              braces); braced one beat loop (the hum); slack 0.5 (back to idle); cut 2.4
              (snap, clang at 0.12, the dish rattles like a lost hubcap).

Tone (TONE-BIBLE.md): machines are workers, so every tell is a big readable anticipation
pose (squash, snap, hold) and every death is the downed-machine gag played straight, then
the wink: the Foreman's hat lands askew, the Dispatcher's eyes boing out on a spring.
"""
import math

from kill_first_rig import BAR2, BEAT, FPS, Rig, hold, merge, shake

F = 1 / FPS


def _beats(n=8):
    return [b * BEAT for b in range(n)]


FOREMAN_CLIPS = {"idle": BAR2, "tell": 0.9, "break": 2.4}


def foreman(root, body_obj, signal_obj, hand_obj):
    rig = Rig(root, "ForemanRig", [
        ("Root", (0, -2.0, 0), None),
        ("Chassis", (0, -1.3, 0), "Root"),
        ("Cabinet", (0, 1.2, 0), "Chassis"),
        ("Hat", (0, 3.05, 0), "Cabinet"),
        ("Moustache", (0, 1.76, -0.52), "Cabinet"),
        ("Hand", (0, 2.25, -0.56), "Cabinet"),
        ("Mast", (0, 1.2, 0.72), "Chassis"),
        ("HornBig", (-0.1, 4.5, 0.62), "Mast"),
        ("HornSmall", (0.14, 4.5, 0.62), "Mast"),
    ])

    def part(c, lo, hi):
        if c.y < -1.25:
            return "Root"
        if c.y > 4.3 and hi.y > 4.6 and abs(c.x) > 0.05:
            return "HornBig" if c.x < 0 else "HornSmall"
        if hi.y > 3.6 or (c.z > 0.6 and c.y > 1.25 and abs(c.x) < 0.6):
            return "Mast"
        if c.y > 2.95 and abs(c.z) < 0.65:
            return "Hat"
        if 1.65 < c.y < 1.85 and c.z < -0.45 and abs(c.x) < 0.5:
            return "Moustache"
        if c.y > 1.15 and abs(c.x) < 0.75 and abs(c.z) < 0.6:
            return "Cabinet"
        return "Chassis"

    rig.bind(body_obj, part)
    rig.bind(signal_obj, part)
    rig.bind(hand_obj, lambda c, lo, hi: "Hand")

    hand, cab = [], []
    for b, tb in enumerate(_beats()):
        a = 45 * b
        hand += [(tb, {"rot": (0, 0, a)}), (tb + 2 * F, {"rot": (0, 0, a + 51)}), (tb + 4 * F, {"rot": (0, 0, a + 45)})]
        cab += [(tb, {}), (tb + 2 * F, {"scale": (1.03, 0.965, 1.03)}), (tb + 6 * F, {})]
    hand = hold(hand, BAR2)
    cab = hold(cab, BAR2)
    hat = [(0, {})]
    for at in (3.5 * BEAT, 7.5 * BEAT):
        hat += [(at, {}), (at + 2 * F, {"loc": (0, 0.14, 0), "rot": (-7, 0, 3)}), (at + 6 * F, {})]
    hat = hold(hat, BAR2)
    clear = 6 * BEAT
    tache = merge([(0, {}), (clear, {})], shake(clear + F, clear + 0.4, 7, period=2 * F, decay=0.8),
                  [(clear + 0.5, {}), (BAR2, {})])
    q = BAR2 / 4
    mast = [(0, {}), (q, {"rot": (0, 0, 1.6)}), (2 * q, {}), (3 * q, {"rot": (0, 0, -1.6)}), (BAR2, {})]
    big = [(0, {}), (q * 0.5, {"rot": (2.5, 0, 0)}), (q * 1.5, {"rot": (-2.5, 0, 0)}), (q * 2.5, {"rot": (2.5, 0, 0)}),
           (q * 3.5, {"rot": (-2.5, 0, 0)}), (BAR2, {})]
    small = [(0, {}), (q, {"rot": (0, 0, -3)}), (2 * q, {}), (3 * q, {"rot": (0, 0, 3)}), (BAR2, {})]
    rig.clip("idle", BAR2, {"Hand": hand, "Cabinet": cab, "Hat": hat, "Moustache": tache, "Mast": mast,
                            "HornBig": big, "HornSmall": small})

    T = FOREMAN_CLIPS["tell"]
    rig.clip("tell", T, {
        "Chassis": [(0, {}), (2 * F, {"scale": (1.04, 0.95, 1.04)}), (5 * F, {"scale": (0.99, 1.02, 0.99)}),
                    (0.8, {"scale": (0.99, 1.01, 0.99)}), (T, {})],
        "Cabinet": [(0, {}), (2 * F, {"loc": (0, -0.08, 0), "scale": (1.07, 0.9, 1.07)}),
                    (5 * F, {"loc": (0, 0.1, 0), "rot": (9, 0, 0), "scale": (0.96, 1.06, 0.96)}),
                    (0.8, {"loc": (0, 0.08, 0), "rot": (7, 0, 0), "scale": (0.97, 1.05, 0.97)}), (T, {})],
        "Hat": [(0, {}), (2 * F, {"loc": (0, -0.05, 0)}), (5 * F, {"loc": (0, 0.3, 0), "rot": (16, 0, 0)}),
                (0.55, {"loc": (0, 0.24, 0), "rot": (11, 0, 0)}),
                (0.55 + 3 * F, {"loc": (0, 0.55, 0), "rot": (14, 0, -12)}),
                (0.8, {"loc": (0, 0.3, 0), "rot": (6, 0, -4)}), (T, {})],
        "Mast": merge([(0, {}), (2 * F, {"scale": (1, 0.86, 1)}), (5 * F, {"scale": (1, 1.12, 1), "rot": (-4, 0, 0)})],
                      shake(7 * F, 0.78, 2.2, base={"scale": (1, 1.1, 1), "rot": (-4, 0, 0)}),
                      [(T, {})]),
        "HornBig": merge([(0, {}), (2 * F, {"scale": 0.84}), (5 * F, {"scale": 1.45})],
                         shake(7 * F, 0.78, 5, field="rot", axis=0, base={"scale": 1.38}), [(T, {})]),
        "HornSmall": merge([(0, {}), (2 * F, {"scale": 0.8}), (5 * F, {"scale": 1.55})],
                           shake(8 * F, 0.78, 6, field="rot", axis=2, base={"scale": 1.48}), [(T, {})]),
        "Moustache": merge([(0, {}), (5 * F, {"scale": (1.4, 1.25, 1)})],
                           shake(7 * F, 0.7, 9, base={"scale": (1.35, 1.2, 1)}, decay=0.9), [(T, {})]),
    })

    B = FOREMAN_CLIPS["break"]
    wah = (0.45, 0.71, 0.97, 1.23)
    slump = [(0, {}), (0.04, {"loc": (0, -0.26, 0), "scale": (1.13, 0.8, 1.13)}),
             (0.12, {"loc": (0, 0.06, 0), "scale": (0.96, 1.05, 0.96)}), (0.3, {})]
    mast = [(0, {}), (0.04, {"scale": (1, 0.9, 1)}), (0.14, {"scale": (1, 1.06, 1)}), (0.3, {})]
    big = [(0, {}), (0.3, {})]
    small = [(0, {}), (0.3, {})]
    for i, s in enumerate(wah):
        k = i + 1
        last = i == len(wah) - 1
        lean = -4 * k if not last else -18
        slump += [(s, slump[-1][1]), (s + 0.08, {"rot": (lean - 2, 0, 0), "loc": (0, -0.05 * k, 0),
                                                  "scale": (1.02, 1 - 0.03 * k, 1.02)}),
                  (s + 0.16, {"rot": (lean, 0, 0), "loc": (0, -0.04 * k, 0), "scale": (1.01, 1 - 0.025 * k, 1.01)})]
        droop = -7 * k if not last else -34
        mast += [(s, mast[-1][1]), (s + 0.08, {"rot": (0, 0, droop - 4)}), (s + 0.16, {"rot": (0, 0, droop)})]
        big += [(s, big[-1][1]), (s + 0.1, {"rot": (-9 * k if not last else -48, 0, 0)})]
        small += [(s, small[-1][1]), (s + 0.12, {"rot": (-8 * k if not last else -40, 0, 6 * k)})]
    end = 1.23 + 0.8
    slump += [(end, {"rot": (-20, 0, 0), "loc": (0, -0.22, 0), "scale": (1.04, 0.86, 1.04)})]
    mast += [(end, {"rot": (0, 0, -36), "scale": (1, 0.96, 1)})]
    rig.clip("break", B, {
        "Chassis": [(0, {}), (0.04, {"scale": (1.05, 0.9, 1.05)}), (0.15, {}), (1.23, {}),
                    (end, {"scale": (1.03, 0.95, 1.03)}), (B, {"scale": (1.03, 0.95, 1.03)})],
        "Cabinet": hold(slump, B),
        "Hand": [(0, {}), (0.09, {"rot": (0, 0, 20)}), (0.5, {"rot": (0, 0, 925)}), (0.62, {"rot": (0, 0, 893)}),
                 (0.74, {"rot": (0, 0, 902)}), (0.86, {"rot": (0, 0, 900)}), (B, {"rot": (0, 0, 900)})],
        "Hat": [(0, {}), (0.09, {"loc": (0, 0.12, 0)}), (0.3, {"loc": (0, 1.15, 0), "rot": (0, 45, -14)}),
                (0.48, {"loc": (0, -0.02, 0), "rot": (8, 32, -18)}), (0.54, {"loc": (0, 0.09, 0), "rot": (8, 32, -18)}),
                (0.6, {"loc": (0, 0, 0), "rot": (7, 30, -20)}), (1.23, {"loc": (0, 0, 0), "rot": (7, 30, -20)}),
                (1.45, {"loc": (0, -0.08, -0.14), "rot": (-18, 30, -22)}), (B, {"loc": (0, -0.08, -0.14), "rot": (-18, 30, -22)})],
        "Mast": hold(mast, B),
        "HornBig": hold(big, B),
        "HornSmall": hold(small, B),
        "Moustache": merge(shake(0.02, 0.3, 14, period=2 * F, decay=0.75),
                           [(0, {}), (1.23, {}), (1.5, {"rot": (28, 0, 0), "loc": (0, -0.06, 0), "scale": (0.9, 1.2, 1)}),
                            (B, {"rot": (28, 0, 0), "loc": (0, -0.06, 0), "scale": (0.9, 1.2, 1)})]),
    })
    return rig


FOREMAN_SHOTS = [(None, 0, "rest"), ("idle", 2 * F, "idle_tick"), ("tell", 2 * F, "tell_inhale"),
                 ("tell", 0.3, "tell_blast"), ("tell", 0.62, "tell_steam"), ("break", 0.04, "break_kachunk"),
                 ("break", 0.3, "break_hat_flies"), ("break", 0.8, "break_wah"), ("break", 2.3, "break_slump")]


DISPATCHER_CLIPS = {"idle": BAR2, "tell": 1.0, "break": 1.6}
TUBE_CUTS = (-2.1, -2.8)


def dispatcher(root, body_obj, signal_obj, radar_obj):
    rig = Rig(root, "DispatcherRig", [
        ("Root", (0, -1.5, 0), None),
        ("Body", (0, -1.15, 0), "Root"),
        ("EyeL", (-0.52, 0.55, -1.5), "Body"),
        ("EyeR", (0.52, 0.55, -1.5), "Body"),
        ("Tongue", (-0.1, -0.05, -1.55), "Body"),
        ("Tube1", (0.62, -0.5, -1.675), "Body"),
        ("Tube2", (0.62, -0.535, -2.5), "Body"),
        ("Tube3", (0.62, -0.76, -3.05), "Body"),
        ("Mast", (0, 1.15, 0.7), "Body"),
        ("Radar", (0, 2.3, 0.7), "Mast"),
    ])

    def part(c, lo, hi):
        if c.y < -1.25 or (c.y < -1.15 and math.hypot(c.x, c.z) > 0.9):
            return "Root"
        if abs(c.x) < 0.25 and c.z > 0.5 and c.y > 1.15:
            return "Mast"
        for name, sx in (("EyeL", -1), ("EyeR", 1)):
            if abs(c.x - sx * 0.52) < 0.12 and abs(c.y - 0.55) < 0.12 and c.z < -1.4:
                return name
        if c.x > 0.3 and c.z < -1.0:
            return "Tube1" if c.z > TUBE_CUTS[0] else "Tube2" if c.z > TUBE_CUTS[1] else "Tube3"
        if c.z < -1.55 and c.y < -0.1 and -0.4 < c.x < 0.3:
            return "Tongue"
        return "Body"

    rig.bind(body_obj, part)
    rig.bind(signal_obj, part)
    rig.bind(radar_obj, lambda c, lo, hi: "Radar")

    radar, tongue, mast = [], [(0, {})], []
    for b, tb in enumerate(_beats()):
        a = 90 * b
        radar += [(tb, {"rot": (0, a, 0)}), (tb + 2 * F, {"rot": (0, a + 100, 0)}), (tb + 4 * F, {"rot": (0, a + 90, 0)})]
        off = tb + BEAT / 2
        tongue += [(off, {}), (off + F, {"loc": (0, 0, -0.05)}), (off + 3 * F, {"loc": (0, 0, -0.02)}), (off + 5 * F, {})]
        mast += [(tb, {}), (tb + 2 * F, {"rot": (0, 0, 2.5 if b % 2 else -2.5)}), (tb + 5 * F, {"rot": (0, 0, -1)}),
                 (tb + 8 * F, {})]
    eyes = [(0, {}), (2 * BEAT, {}), (2 * BEAT + 3 * F, {"loc": (0.06, 0.02, 0)}), (3.6 * BEAT, {"loc": (0.06, 0.02, 0)}),
            (4 * BEAT, {}), (6 * BEAT, {}), (6 * BEAT + 3 * F, {"loc": (-0.06, 0.02, 0)}),
            (7.6 * BEAT, {"loc": (-0.06, 0.02, 0)}), (BAR2, {})]
    rig.clip("idle", BAR2, {"Radar": hold(radar, BAR2), "Tongue": hold(tongue, BAR2), "Mast": hold(mast, BAR2),
                            "EyeL": eyes, "EyeR": eyes,
                            "Body": [(0, {}), (2 * F, {"scale": (1.015, 0.985, 1.015)}), (6 * F, {}), (4 * BEAT, {}),
                                     (4 * BEAT + 2 * F, {"scale": (1.015, 0.985, 1.015)}), (4 * BEAT + 6 * F, {}), (BAR2, {})]})

    T = DISPATCHER_CLIPS["tell"]
    bulge = {"scale": (1.38, 1.38, 1.0)}
    tube = {}
    for name, peak in (("Tube1", 0.12), ("Tube2", 0.27), ("Tube3", 0.4)):
        tube[name] = [(0, {}), (max(F, peak - 0.1), {}), (peak, bulge), (peak + 0.09, {})]
    tube["Tube3"] = [(0, {}), (0.3, {}), (0.4, bulge), (0.45, {"scale": (1.15, 1.15, 1)}),
                     (0.45 + 2 * F, {"rot": (14, 0, 0), "scale": (1.4, 1.4, 1.1)}),
                     (0.6, {"rot": (-4, 0, 0)}), (0.6 + 2 * F, {"rot": (6, 0, 0), "scale": (1.12, 1.12, 1)}),
                     (0.8, {"rot": (-1, 0, 0)}), (T, {})]
    for name in ("Tube1", "Tube2"):
        tube[name] += [(T, {})]
    wide = {"scale": (1.4, 1.4, 1.2)}
    rig.clip("tell", T, dict(tube, **{
        "Radar": merge([(0, {}), (3 * F, {"rot": (0, -8, 0)}), (5 * F, {"rot": (0, 0, 0)})],
                       shake(6 * F, 0.44, 3, field="rot", axis=1), [(0.6, {}), (T, {})]),
        "EyeL": [(0, {}), (3 * F, wide), (0.45, wide), (0.45 + 2 * F, {"scale": (0.8, 1.6, 1.2)}), (0.7, wide), (T, {})],
        "EyeR": [(0, {}), (3 * F, wide), (0.45, wide), (0.45 + 2 * F, {"scale": (0.8, 1.6, 1.2)}), (0.7, wide), (T, {})],
        "Body": [(0, {}), (0.4, {"rot": (-6, 0, 0), "scale": (1.05, 0.92, 1.05)}),
                 (0.45 + 2 * F, {"loc": (0, 0.16, 0), "rot": (3, 0, 0), "scale": (0.96, 1.07, 0.96)}),
                 (0.6, {"scale": (1.03, 0.96, 1.03)}), (0.6 + 2 * F, {"loc": (0, 0.07, 0)}), (0.8, {}), (T, {})],
        "Tongue": [(0, {}), (0.6, {}), (0.6 + 2 * F, {"loc": (0, -0.04, -0.12), "scale": (1.0, 1.7, 1.7)}),
                   (0.85, {"loc": (0, -0.02, -0.06), "scale": (1.0, 1.4, 1.4)}), (T, {})],
        "Mast": [(0, {}), (0.45, {}), (0.45 + 3 * F, {"rot": (0, 0, 5)}), (0.6, {"rot": (0, 0, -3)}), (0.8, {}), (T, {})],
    }))

    B = DISPATCHER_CLIPS["break"]
    sproing = 0.2
    def eye_boing(sx):
        out = (sx * 0.16, 0.08, -0.5)
        rows = merge([(0, {}), (sproing, {}), (sproing + 2 * F, {"loc": out, "scale": 1.7})],
                     shake(sproing + 4 * F, 1.0, 0.18, period=3 * F, field="loc", axis=2,
                           base={"loc": (sx * 0.14, 0.04, -0.4), "scale": 1.55}, decay=0.78),
                     [(1.2, {"loc": (sx * 0.14, -0.14, -0.38), "rot": (0, 0, sx * 25), "scale": 1.5})])
        return hold(rows, B)

    rig.clip("break", B, {
        "Body": merge(shake(0.0, 0.17, 5, period=F, decay=0.9),
                      [(0.6, {}), (1.4, {"rot": (0, 0, 9), "loc": (0, -0.15, 0), "scale": (1.04, 0.93, 1.04)}),
                       (B, {"rot": (0, 0, 9), "loc": (0, -0.15, 0), "scale": (1.04, 0.93, 1.04)})]),
        "Tongue": [(0, {}), (0.18, {"loc": (0, -0.05, -0.1), "scale": (1.15, 2.6, 2.6)}),
                   (0.3, {"loc": (0, -0.08, -0.08), "scale": (1.15, 2.4, 2.3)}),
                   (B, {"loc": (0, -0.12, -0.04), "scale": (1.15, 2.4, 2.0)})],
        "Mast": merge([(0, {}), (sproing, {}), (sproing + 2 * F, {"scale": (1, 1.9, 1)})],
                      shake(sproing + 4 * F, 1.1, 16, period=3 * F, base={"scale": (1, 1.7, 1)}, decay=0.8),
                      [(1.4, {"scale": (1, 1.6, 1), "rot": (0, 0, -24)}), (B, {"scale": (1, 1.6, 1), "rot": (0, 0, -24)})]),
        "Radar": [(0, {}), (sproing, {}), (0.8, {"rot": (0, 610, 0)}), (1.2, {"rot": (30, 700, 0)}),
                  (B, {"rot": (40, 710, 0)})],
        "EyeL": eye_boing(-1),
        "EyeR": eye_boing(1),
        "Tube3": [(0, {}), (0.6, {}), (1.4, {"rot": (-22, 0, 0)}), (B, {"rot": (-22, 0, 0)})],
        "Tube2": [(0, {}), (0.6, {}), (1.4, {"rot": (-7, 0, 0)}), (B, {"rot": (-7, 0, 0)})],
    })
    return rig


DISPATCHER_SHOTS = [(None, 0, "rest"), ("idle", 3 * F, "idle_ping"), ("tell", 0.27, "tell_suck"),
                    ("tell", 0.4, "tell_crouch"), ("tell", 0.45 + 2 * F, "tell_drop"),
                    ("tell", 0.6 + 2 * F, "tell_ticket"), ("break", 0.18, "break_jam"),
                    ("break", 0.3, "break_sproing"), ("break", 1.5, "break_sag")]


SPLITTER_CLIPS = {"crawl": BAR2, "tell": 0.4, "break_split": 0.2, "break_clean": 1.0}
SPLIT_BURST = 0.45


def splitter(root, body_obj, glow_obj, R, FLOOR, AZ, NAMES):
    import splitter_pod
    from mathutils import Vector

    top = R * 0.93
    outs = {n: Vector((math.sin(az), 0.0, -math.cos(az))) for n, az in zip(NAMES, AZ)}
    bones = [("Root", (0, FLOOR, 0), None), ("Body", (0, -0.2, 0), "Root"), ("Core", (0, -0.2, 0), "Body"),
             ("Lamp", (0, top + 0.13, 0), "Root")]
    hips = {}
    for n, az in zip(NAMES, AZ):
        o = outs[n]
        bones.append(("Pod" + n.upper(), (o.x * R * 0.42, -0.2, o.z * R * 0.42), "Body"))
        for k, t in enumerate((-0.55, 0.55)):
            d = splitter_pod._dir(az + t * splitter_pod.HALF, -48)
            rr = R * splitter_pod._bulge(t) - 0.05 * R
            hips["Leg%s%d" % (n.upper(), k)] = (d[0] * rr, d[1] * rr, d[2] * rr)
    bones += [(name, hip, "Body") for name, hip in hips.items()]
    rig = Rig(root, "SplitterRig", bones)

    def part(c, lo, hi):
        if c.y > top + 0.05:
            return "Lamp"
        if c.y < -0.7 and math.hypot(c.x, c.z) > 0.5:
            return min(hips, key=lambda n: (Vector(hips[n]) - c).length)
        ang = math.atan2(c.x, -c.z)
        for n, az in zip(NAMES, AZ):
            if math.hypot(c.x, c.z) > 0.15 and abs((ang - az + math.pi) % math.tau - math.pi) < math.radians(40):
                return "Pod" + n.upper()
        return "Core"

    rig.bind(body_obj, part)
    rig.bind(glow_obj, part)
    pods = ["Pod" + n.upper() for n in NAMES]

    tracks = {name: [(0, {})] for name in hips}
    body, lamp = [], []
    for b, tb in enumerate(_beats()):
        up = [name for name in hips if (name.endswith("0") == (b % 2 == 0))]
        for name in hips:
            if name in up:
                tracks[name] += [(tb + 0.02, {}), (tb + BEAT * 0.4, {"loc": (0, 0.22, -0.12)}),
                                 (tb + BEAT * 0.85, {})]
        body += [(tb, {"loc": (0, -0.05, 0), "scale": (1.025, 0.965, 1.025)}), (tb + BEAT / 2, {"loc": (0, 0.04, 0)})]
        lean = 9 if b % 2 else -9
        lamp += [(tb, {"loc": (0, -0.05, 0)}), (tb + BEAT / 2, {"loc": (0, 0.04, 0), "rot": (0, 0, lean)})]
    tracks = {k: hold(v, BAR2) for k, v in tracks.items()}
    tracks["Body"] = body + [(BAR2, body[0][1])]
    tracks["Lamp"] = lamp + [(BAR2, lamp[0][1])]
    for i, pod in enumerate(pods):
        tracks[pod] = [(0, {})] + [(tb + BEAT / 2, {"rot": (0, 0, (3 if (b + i) % 2 else -3))})
                                   for b, tb in enumerate(_beats())] + [(BAR2, {})]
    rig.clip("crawl", BAR2, tracks)

    T = SPLITTER_CLIPS["tell"]
    tell = {}
    for n, pod in zip(NAMES, pods):
        o = outs[n]
        tell[pod] = [(0, {}), (0.15, {"loc": tuple(o * 0.04), "scale": 1.03}),
                     (0.3, {"loc": tuple(o * 0.11), "scale": 1.09}), (T, {"loc": tuple(o * 0.2), "scale": 1.16})]
    tell["Body"] = [(0, {})] + [(round(t, 4), {"rot": (a * 0.6, 0, a), "scale": 1.0 + t * 0.12})
                                for t, a in ((0.1, 1.0), (0.17, -2.0), (0.23, 3.0), (0.28, -4.0), (0.32, 5.0),
                                             (0.35, -6.0), (0.38, 6.0), (T, -6.0))]
    tell["Lamp"] = [(0, {}), (0.1, {"loc": (0, 0.03, 0), "scale": (1, 1.1, 1)}), (0.25, {"loc": (0, 0.1, 0), "scale": (0.9, 1.3, 0.9)}),
                    (T, {"loc": (0, 0.22, 0), "scale": (0.82, 1.6, 0.82)})]
    rig.clip("tell", T, tell)

    S = SPLITTER_CLIPS["break_split"]
    split = {"Body": [(0, {"rot": (-3.6, 0, -6), "scale": 1.05}), (S, {"scale": 1.05})],
             "Core": [(0, {}), (0.08, {"scale": 0.5}), (S, {"scale": 0.05})],
             "Lamp": [(0, {"loc": (0, 0.22, 0), "scale": (0.82, 1.6, 0.82)}), (0.1, {"loc": (0, 0.9, 0), "rot": (0, 0, 40)}),
                      (S, {"loc": (0, 1.3, 0), "rot": (0, 0, 80), "scale": 0.05})]}
    for n, pod in zip(NAMES, pods):
        o = outs[n]
        split[pod] = [(0, {"loc": tuple(o * 0.2), "scale": 1.16}),
                      (0.08, {"loc": tuple(o * (0.2 + SPLIT_BURST * 0.6) + Vector((0, 0.15, 0))), "rot": (0, 0, 0), "scale": 1.05}),
                      (S, {"loc": tuple(o * SPLIT_BURST), "scale": 0.95})]
    rig.clip("break_split", S, split)

    C = SPLITTER_CLIPS["break_clean"]
    clean = {"Body": [(0, {}), (0.06, {"loc": (0, -0.25, 0), "scale": (1.32, 0.5, 1.32)}),
                      (0.16, {"loc": (0, 0.12, 0), "scale": (0.92, 1.14, 0.92)}),
                      (0.3, {"loc": (0, -0.3, 0), "scale": (1.15, 0.72, 1.15)}),
                      (0.42, {"loc": (0, -0.26, 0), "scale": (1.12, 0.76, 1.12)}),
                      (C, {"loc": (0, -0.34, 0), "scale": (1.14, 0.7, 1.14)})],
             "Lamp": [(0, {}), (0.06, {"loc": (0, -0.4, 0)}), (0.3, {"loc": (0.5, 1.3, 0.3), "rot": (60, 0, -200)}),
                      (0.6, {"loc": (1.3, -2.2, 0.6), "rot": (90, 0, -380)}),
                      (0.68, {"loc": (1.35, -2.05, 0.6), "rot": (90, 0, -385)}),
                      (0.76, {"loc": (1.4, -2.2, 0.62), "rot": (90, 0, -400)}), (C, {"loc": (1.4, -2.2, 0.62), "rot": (90, 0, -450)})]}
    for name in hips:
        clean[name] = [(0, {}), (0.06, {"loc": (0, 0.1, 0)}), (0.3, {"loc": (0, 0.16, 0), "rot": (0, 0, 0)}), (C, {"loc": (0, 0.18, 0)})]
    rig.clip("break_clean", C, clean)
    return rig


SPLITTER_SHOTS = [(None, 0, "rest"), ("crawl", BEAT * 0.4, "crawl_step"), ("tell", 0.25, "tell_swell"),
                  ("tell", 0.4, "tell_peak"), ("break_split", 0.1, "split_burst"), ("break_clean", 0.06, "clean_pop"),
                  ("break_clean", 0.3, "clean_lamp_flies"), ("break_clean", 0.95, "clean_deflated")]

PIECE_CLIPS = {"scurry": BEAT, "pop_in": 0.25}


def piece(root, body_obj, glow_obj, FLOOR):
    rig = Rig(root, "SplitterPieceRig", [
        ("Root", (0, FLOOR, 0), None),
        ("Body", (0, 0, 0), "Root"),
        ("Snout", (0, 0.05, -0.39), "Body"),
        ("LegL", (-0.3, -0.6, -0.1), "Body"),
        ("LegR", (0.3, -0.6, -0.1), "Body"),
    ])

    def part(c, lo, hi):
        if c.y < -0.45 and abs(c.x) > 0.15:
            return "LegL" if c.x < 0 else "LegR"
        if c.z < -0.35 and abs(c.x) < 0.15 and abs(c.y) < 0.2:
            return "Snout"
        return "Body"

    rig.bind(body_obj, part)
    rig.bind(glow_obj, part)
    b = BEAT
    lift = {"loc": (0, 0.14, -0.08)}
    rig.clip("scurry", b, {
        "LegL": [(0, {}), (b * 0.25, lift), (b * 0.5, {}), (b, {})],
        "LegR": [(0, {}), (b * 0.5, {}), (b * 0.75, lift), (b, {})],
        "Body": [(0, {"loc": (0, -0.03, 0)}), (b * 0.25, {"loc": (0, 0.03, 0), "rot": (-4, 0, 3)}),
                 (b * 0.5, {"loc": (0, -0.03, 0)}), (b * 0.75, {"loc": (0, 0.03, 0), "rot": (-4, 0, -3)}),
                 (b, {"loc": (0, -0.03, 0)})],
        "Snout": [(0, {}), (b * 0.5, {"loc": (0, 0, -0.04)}), (b, {})],
    })
    rig.clip("pop_in", PIECE_CLIPS["pop_in"], {
        "Root": [(0, {"scale": (1.5, 0.3, 1.5)}), (0.1, {"scale": (0.88, 1.25, 0.88)}),
                 (0.17, {"scale": (1.06, 0.94, 1.06)}), (0.25, {})],
        "Snout": [(0, {"loc": (0, 0, 0.15)}), (0.1, {"loc": (0, 0, -0.12)}), (0.25, {})],
    })
    return rig


PIECE_SHOTS = [(None, 0, "rest"), ("scurry", BEAT * 0.25, "scurry"), ("pop_in", 0.0, "pop_squash"),
               ("pop_in", 0.1, "pop_stretch")]


LINKER_CLIPS = {"idle": BAR2, "brace": 0.8, "braced": BEAT, "slack": 0.5, "cut": 2.4}


def linker(root, body_obj, dish_obj, cable_obj, start, end, sag, hinge, dish_c, floor, pivot):
    from mathutils import Euler, Vector

    start, end, hinge, dish_c = Vector(start), Vector(end), Vector(hinge), Vector(dish_c)
    mid = start.lerp(end, 0.5) - Vector((0, sag, 0))
    rig = Rig(root, "LinkerRig", [
        ("Root", (0, floor, 0), None),
        ("Cab", (-0.1, 0.77, 0), "Root"),
        ("Crew", (-0.12, 1.2, 0.3), "Cab"),
        ("Ears", (-0.12, 1.4, 0.3), "Crew"),
        ("Boom", tuple(pivot), "Root"),
        ("DishAim", tuple(hinge), "Boom"),
        ("DishBrace", tuple(hinge), "DishAim"),
        ("Sag", tuple(mid), "Root"),
    ])

    def part(c, lo, hi):
        if abs(c.x) < 0.05 and abs(c.y - pivot[1]) < 0.05:
            return "Boom"
        if c.y < 0.5 and math.hypot(c.x, c.z) < 1.2 and c.x < 0.7:
            return "Root"
        if hi.y > 1.45 and c.z > 0.2 and abs(c.x + 0.12) < 0.3:
            return "Ears"
        if abs(c.x + 0.12) < 0.1 and c.z > 0.25 and 1.1 < c.y < 1.3:
            return "Crew"
        if abs(c.x + 0.1) < 0.55 and 0.7 < c.y < 1.5 and abs(c.z) < 0.5:
            return "Cab"
        return "Boom"

    rig.bind(body_obj, part)
    rig.bind(dish_obj, lambda c, lo, hi: "DishBrace")
    span = end - start

    def cable_weights(p):
        t = min(1.0, max(0.0, (p - start).dot(span) / span.length_squared))
        w = 4 * t * (1 - t)
        return {"Sag": w, "Root": (1 - w) * (1 - t), "DishAim": (1 - w) * t}

    rig.bind_smooth(cable_obj, cable_weights)
    rig.socket_to_bone("cable_dish", "DishAim")

    def dish_at(centre, rot):
        """DishBrace pose that puts the dish centre at a Godot point with a rotation about
        the hinge (bone axes are Godot axes)."""
        r = Euler([math.radians(a) for a in rot], "XYZ").to_matrix()
        loc = Vector(centre) - hinge - r @ (dish_c - hinge)
        return {"loc": tuple(loc), "rot": rot}

    taut = {"loc": (0, sag, 0)}
    braced_dish = {"rot": (6, 0, 0)}
    braced_boom = {"rot": (0, 0, -1.5)}
    perk = {"scale": (1, 1.4, 1)}
    lean = {"loc": (0, 0, 0.06)}

    q = BAR2 / 4
    ears = [(0, {})]
    crew = [(0, {})]
    for at in (1.25 * BEAT, 5.6 * BEAT):
        ears += [(at, {}), (at + 2 * F, {"scale": (1, 1.35, 1), "rot": (0, 0, 8)}), (at + 10 * F, {})]
        crew += [(at, {}), (at + 2 * F, {"loc": (0, -0.05, -0.03)}), (at + 12 * F, {})]
    rig.clip("idle", BAR2, {
        "Sag": [(0, {}), (q, {"loc": (0, 0.03, 0.08)}), (2 * q, {}), (3 * q, {"loc": (0, 0.03, -0.08)}), (BAR2, {})],
        "DishBrace": [(0, {}), (2 * q, {"rot": (2, 0, 0)}), (BAR2, {})],
        "Boom": [(0, {}), (2 * q, {"rot": (0, 0, 0.6)}), (BAR2, {})],
        "Ears": hold(ears, BAR2), "Crew": hold(crew, BAR2),
    })

    T = LINKER_CLIPS["brace"]
    rig.clip("brace", T, {
        "Sag": merge([(0, {}), (3 * F, {"loc": (0, sag * 1.12, 0)})],
                     shake(5 * F, 0.7, 0.07, period=2 * F, field="loc", axis=1, base=taut, decay=0.8), [(T, taut)]),
        "DishBrace": [(0, {}), (2 * F, {"rot": (-11, 0, 0)}), (6 * F, {"rot": (9, 0, 0)}), (10 * F, {"rot": (5, 0, 0)}),
                      (T, braced_dish)],
        "Boom": [(0, {}), (2 * F, {"rot": (0, 0, 1)}), (6 * F, {"rot": (0, 0, -2.4)}), (12 * F, {"rot": (0, 0, -1.2)}),
                 (T, braced_boom)],
        "Ears": [(0, {}), (3 * F, {"scale": (1, 1.55, 1)}), (8 * F, perk), (T, perk)],
        "Crew": [(0, {}), (4 * F, {"loc": (0, 0.03, 0.09)}), (T, lean)],
    })
    rig.clip("braced", BEAT, {
        "Sag": merge([(0, taut)], shake(2 * F, BEAT - 3 * F, 0.015, period=2 * F, field="loc", axis=1, base=taut),
                     [(BEAT, taut)]),
        "DishBrace": [(0, braced_dish), (BEAT / 2, {"rot": (6.6, 0, 0)}), (BEAT, braced_dish)],
        "Boom": [(0, braced_boom), (BEAT, braced_boom)],
        "Ears": [(0, perk), (BEAT, perk)], "Crew": [(0, lean), (BEAT, lean)],
    })
    S = LINKER_CLIPS["slack"]
    rig.clip("slack", S, {
        "Sag": [(0, taut), (0.18, {"loc": (0, -0.12, 0)}), (0.32, {"loc": (0, 0.05, 0)}), (S, {})],
        "DishBrace": [(0, braced_dish), (0.2, {"rot": (-2, 0, 0)}), (S, {})],
        "Boom": [(0, braced_boom), (0.22, {"rot": (0, 0, 0.6)}), (S, {})],
        "Ears": [(0, perk), (S, {})], "Crew": [(0, lean), (S, {})],
    })

    C = LINKER_CLIPS["cut"]
    land = Vector((hinge.x + 0.9, floor + 0.28, hinge.z + 1.1))
    flat = (-118, 0, 0)
    dish = [(0, {}), (0.12, dish_at(dish_c + Vector((0, -0.45, 0)), (14, 0, 0))),
            (0.18, dish_at(dish_c + Vector((0.05, -0.38, 0.05)), (20, 0, 4))),
            (0.33, dish_at(dish_c.lerp(land, 0.6) + Vector((0, 0.15, 0)), (-30, 0, 14)))]
    rattles, gap, at = [], 0.07, 0.4
    for k in range(9):
        rattles.append(at)
        at += gap
        gap *= 1.22
    for k, at in enumerate(rattles):
        tilt = 13 * (0.78 ** k) * (1 if k % 2 == 0 else -1)
        dish.append((at, dish_at(land, (flat[0] + tilt, 40 * k, tilt * 0.6))))
    dish.append((C, dish_at(land, (flat[0], 40 * len(rattles), 0))))
    rig.clip("cut", C, {
        "DishBrace": dish,
        "Sag": [(0, {}), (2 * F, {"loc": (-0.3, 0.25, 0.1)}), (0.3, {"loc": (0.2, -0.7, -0.15)}),
                (0.55, {"loc": (0.1, -0.55, 0.08)}), (0.8, {"loc": (0.15, -0.62, -0.03)}), (C, {"loc": (0.15, -0.6, 0)})],
        "Boom": [(0, {}), (0.1, {"rot": (0, 0, 11)}), (0.25, {"rot": (0, 0, 2)}), (0.4, {"rot": (0, 0, 5.5)}),
                 (0.6, {"rot": (0, 0, 3.5)}), (C, {"rot": (0, 0, 4)})],
        "Crew": [(0, {}), (0.12, {"loc": (0, -0.22, -0.05)}), (1.0, {"loc": (0, -0.22, -0.05)}),
                 (1.2, {"loc": (0, 0.02, 0.02)}), (C, {"loc": (0, 0.02, 0.02)})],
        "Ears": [(0, {}), (0.12, {"scale": (1, 0.6, 1)}), (1.2, {"scale": (1, 0.6, 1)}),
                 (1.35, {"scale": (1, 1.3, 1), "rot": (0, 0, -10)}), (1.6, {"rot": (25, 0, 0), "scale": (1, 0.8, 1)}),
                 (C, {"rot": (25, 0, 0), "scale": (1, 0.8, 1)})],
    })
    return rig


LINKER_SHOTS = [(None, 0, "rest"), ("brace", 2 * F, "brace_rear"), ("brace", 6 * F, "brace_shove"),
                ("braced", 0, "braced"), ("cut", 0.12, "cut_clang"), ("cut", 0.33, "cut_slide"),
                ("cut", 0.47, "cut_rattle"), ("cut", 1.3, "cut_peek"), ("cut", 2.3, "cut_lost")]
