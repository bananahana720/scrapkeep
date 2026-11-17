extends RefCounted

# The game's mix as rows (direction 21): bus levels, the master chain, a level snapshot per game
# state, the telegraph focus, the crowd rule and the per-cue voice caps. audio.gd reads these
# and owns no mix number of its own. Nothing here touches a node.
#
# Targets (offline bounce, tools/ace_bounce.gd + tools/mix_meter.py, Master bus):
#   integrated about -20 LUFS over a world 1 run, true peak at or under -1 dBTP,
#   short-term (3 s) peaks under about -13 LUFS, so a fight is loud by contrast, not by level.
# Sound is the fairness channel (direction 18): a telegraph (priority 2 and up, or a danger
# sound) is never quieted by the crowd rule and pulls the music and the ambience down instead.

# Fixed bus levels in dB, under the player's volume sliders (settings_store volumes, 0 to 1).
# Ambient carries the parks' life (ambient_life.gd) and sends to Master beside the effects.
# The band leads the effects (Andrew, 12 Nov: the effects drowned the music). Measured one side
# at a time (ace_bounce --only, skipper seed 1, 150 s, the recorded band on the PC): the music
# sat 1 to 4 LU under the effects in every state. SFX sits 4.5 dB lower than it did, and the
# music row is 3 dB higher with every non-fight state 3 dB deeper, so only the fights lift. The
# pass line is the music at least 3 LU over the effects in each fight state, with the whole mix
# within 1 LU of where it was. The effects' level is spread over warnings, slams and stingers,
# not the rapid hits (hit_thwack, weapon_zap and clank together are about 6% of it), so the bus
# is the lever, not a per-cue trim.
const BUS_DB := {"Music": -1.0, "SFX": -6.0, "UI": -8.0, "Ambient": -7.0}

# Glue on the effects bus: catches a pile-up before the master has to.
const SFX_COMP := {"threshold_db": -16.0, "ratio": 3.0, "attack_us": 3000.0, "release_ms": 120.0, "gain_db": 0.0}
const SFX_CEILING_DB := -2.0
# The master: a gentle compressor, then a hard ceiling with headroom for inter-sample peaks.
const MASTER_COMP := {"threshold_db": -14.0, "ratio": 2.5, "attack_us": 8000.0, "release_ms": 200.0, "gain_db": 0.0}
const MASTER_CEILING_DB := -1.5

# Level offsets in dB per state and bus, on top of BUS_DB. A missing bus is 0.
#   menu      title and class select: the theme leads, the effects step back
#   camp      the camp page: lighter (Andrew, 17 Oct: camp and summary keep them lighter)
#   roam      a stage with no fight on: the jazzy roam sits back so a fight is louder by contrast
#   combat    a stage under pressure: the music leans back so the fight reads
#   shop      Moss's bay: the shop tune is a backdrop to the bell and the rarity ticks
#   miniboss  a Warden or a champion: its anthem leads at full level, the park's life goes quiet
#   boss_1..3 Brindle's phases: the anthem ratchets with the phase, the life is gone
#   run_over  summary, death and victory: the jazz-club summary carries the moment
# No state moves the SFX bus: the stinger lane rides it, so a death, a victory or a run's first
# stinger always lands at full level.
const STATES := {
	"menu": {"Music": -6.0, "Ambient": -14.0},
	"camp": {"Music": -8.0, "Ambient": -6.0},
	"roam": {"Music": -5.0},
	"combat": {"Music": -1.5, "Ambient": -5.0},
	"shop": {"Music": -8.0, "Ambient": -6.0},
	"miniboss": {"Ambient": -10.0},
	"boss_1": {"Music": -1.0, "Ambient": -14.0},
	"boss_2": {"Music": -0.5, "Ambient": -14.0},
	"boss_3": {"Ambient": -16.0},
	"run_over": {"Music": -7.0, "Ambient": -16.0},
}
# The systemic pressure (pressure_changed) at which a stage counts as a fight, and below which
# it is roaming again (hysteresis, so a fight's edge does not flicker the mix).
const COMBAT_ON := 0.4
const COMBAT_OFF := 0.25


# Whether the stage counts as a fight at `pressure`, given whether it did a moment ago: the one
# hysteresis, read by the music's mix (audio.gd) and by the screen's busy gate (screen_busy.gd).
static func combat_after(was: bool, pressure: float) -> bool:
	if pressure >= COMBAT_ON:
		return true
	if pressure <= COMBAT_OFF:
		return false
	return was
# How fast a bus glides to its state's level, in dB per second: down fast, up slow, so the mix
# never jumps up under the player.
const GLIDE_DOWN_DB_S := 30.0
const GLIDE_UP_DB_S := 6.0

# The telegraph focus: a danger sound or a threat row (audio.gd _is_telegraph), now or on the beat, drops the music and the ambience for hold_s,
# then they come back at GLIDE_UP_DB_S. A Warden fight sounds a warning about twice a second, so
# the focus held the music down for a third of a measured run, so it dips 2 dB (12 Nov); the
# band's own duck on every priority 2 cue (audio.gd play) still opens the room for the warning.
const FOCUS := {"Music": -2.0, "Ambient": -8.0, "hold_s": 0.4}

# Room for the Warden form's drop (tuning drop_room, off by default): offsets in dB that hold from
# just before the drop's beat for DROP_ROOM_BARS bars of the band's grid, gliding in at
# GLIDE_DOWN_DB_S both ways so a lift lands with the beat, and out at the usual glide. The PC's
# whole-mix read (10 Nov) had the drop only 1.1 to 1.6 dB over the held breath because the
# effects set a fight's level; the pass line is the drop at least 3 dB over the breath with no
# ceiling hit (SOUND-BIBLE "How it is checked").
#   duck  the effects step back, so the band's own drop is what changes
#   lift  the band comes up, the effects stay where they are
const DROP_ROOM := {"duck": {"SFX": -5.0}, "lift": {"Music": 3.0}}
const DROP_ROOM_BARS := 2
const DROP_ROOM_LEAD_S := 0.1

# Room for a fact the player must hear over anything (direction 18: sound is the fairness
# channel). When one of these sounds starts, every other effect voice already sounding, or
# starting within hold_s, drops by db, then comes back at its own level. Warnings keep theirs
# (audio.gd DANGER_SOUNDS), so a hit never hides the next tell. The PC's mix read (12 Nov) had
# hurt under reactor_erupt both times it played: the vent that erupts is what hit the player.
# A row with "only" makes room for just the sounds it names, warnings among them: the dodge's
# whoosh ducks the lane attack's tear (FX-28; the PC's read of 13 Nov had it under the tear in
# 22 of 55 starts, 65% buried). It ducks only voices of those sounds already sounding when the
# room is made, so a tear that starts during the hold plays at full level: a warning from an
# attack that is still a threat is never turned down. A hit's room (a row without "only") takes
# the ducked voices back to their level the moment it starts.
const MAKE_ROOM := {"hurt": {"db": -10.0, "hold_s": 0.35},
	"near_whoosh": {"db": -8.0, "hold_s": 0.3, "only": ["threat_tear"]}}


# The offset a voice of sound takes while room is held for room_for: none for room_for's own
# voices or a warning. A row with "only" gives its offset to the sounds it names when they are
# already sounding (sounding), never to a voice that starts while it is held.
static func room_db(room_for: String, sound: String, warning: bool, sounding := true) -> float:
	if sound == room_for or not MAKE_ROOM.has(room_for):
		return 0.0
	if MAKE_ROOM[room_for].has("only"):
		return float(MAKE_ROOM[room_for]["db"]) if sounding and sound in MAKE_ROOM[room_for]["only"] else 0.0
	if warning:
		return 0.0
	return float(MAKE_ROOM[room_for]["db"])

# The crowd rule: the high-rate cues in CROWD_SOUNDS (the ones a swarm or a streak stacks,
# 12 a second each in a measured Warden fight) get quieter as live effect voices pile up, by
# CROWD_DB_PER_DOUBLING for each doubling above CROWD_FREE, never below CROWD_FLOOR_DB.
# Kit signatures, ultimates and big moments are not on the list: overpowered pays (direction 5).
const CROWD_SOUNDS := ["weapon_zap", "hit_thwack", "clank", "scrap_tick", "cog_tick", "kill_pop", "crit_ping", "shatter",
	"dash_whoosh", "near_whoosh", "kest_kick_thump", "rarity_tick", "panel_note", "shell_spring", "land_thud", "hop"]
const CROWD_FREE := 6
const CROWD_DB_PER_DOUBLING := 3.0
const CROWD_FLOOR_DB := -9.0

# Simultaneous voices per cue (default VOICE_DEFAULT), and the shortest gap between two starts
# in ms. A burst of pickups or a held trigger stays crisp instead of turning into mush.
# Moss says one line at a time: a new line cuts the last one off. The Mind's quote is heard
# once per adaptation.
const VOICE_DEFAULT := 3
const VOICE_LIMIT := {"weapon_zap": 3, "scrap_tick": 3, "cog_tick": 3, "hit_thwack": 3, "kill_pop": 3, "enemy_arrive": 2, "beacon_hum": 1, "sluice_siren_two_tone": 1, "steam_whistle_rise": 1, "ride_cable_clink": 2, "ride_rolling_metal": 1,
	"hop": 2, "land_thud": 2, "hurt": 2, "babble": 1, "rarity_tick": 2, "panel_note": 3, "clank": 2, "grapple_clink": 2,
	"swarm_buzz": 2, "kill_chain_tier": 1, "achievement_chime": 1, "rescue_fanfare": 1,
	"menu_move": 2, "menu_confirm": 1, "menu_back": 1, "verb_fail": 1, "gauge_dry_click": 1, "marble_tick_ladder": 3,
	"drop_thud": 1, "drop_whiff": 1, "guard_creak": 1, "beacon_open_chime": 1, "callout_warden_chime": 1,
	# World 1's own sounds keep the limits of the stand-ins they replace: the gauge's climb is one voice like the
	# beacon hum it was, and a pin's double hit takes two where the single thwack took three.
	"motif_accumulate": 1, "pin_double_thwack": 2}
const MIN_GAP_MS := {"weapon_zap": 55, "scrap_tick": 40, "cog_tick": 40, "enemy_arrive": 200, "hit_thwack": 35, "land_thud": 80, "kill_pop": 45,
	"hurt": 90, "hop": 40, "mind_sable": 600, "mind_rivet": 600, "mind_kest": 600, "mind_tarn": 600, "mind_tally": 600, "mind_cannon": 600,
	"grapple_clink": 60, "ride_cable_clink": 60, "ride_rolling_metal": 250, "ride_hop_lift": 60, "ride_ledge_scuff": 60, "line_bite": 60, "slam_boom": 60, "core_slam": 60,
	"grown_sub": 60, "grown_crack": 60, "grown_tail": 120, "grown_rattle": 120,
	"achievement_chime": 400, "rescue_fanfare": 400, "clank": 90, "rarity_tick": 45,
	# A menu move repeats as fast as a held d-pad; a failed verb repeats as fast as the button is mashed.
	"menu_move": 45, "menu_confirm": 90, "menu_back": 90, "verb_fail": 150, "gauge_dry_click": 120, "marble_tick_ladder": 60,
	"drop_thud": 120, "drop_whiff": 200, "guard_creak": 700, "beacon_open_chime": 400, "callout_warden_chime": 300,
	# Each hazard landing keeps the shared slam's 60 ms, the line skill's motif the bite's 60, and the pin the thwack's clank-like 90.
	"flood_drop": 60, "fleet_anvil_brass_drop": 60, "lightning_strike": 60, "rockfall_boom": 60, "crater_crump_sub_boom": 60,
	"steam_whistle_percussion_drop": 60, "ancient_family_drop": 60, "motif_line": 60, "pin_double_thwack": 90}

const MENU_FLOWS := ["title", "class_select"]
const OVER_FLOWS := ["summary", "dead", "victory"]
const FIGHT_TRACKS := ["miniboss", "warden"]


# The mix state from the game's facts. flow is Flow.NAMES' current name, track the band's
# track ("level", "miniboss", "warden", a menu theme or a boss's music), combat the hysteresis
# flag. A boss is the flow's boss state only: a radio record or a menu theme still on air in a
# stage never reads as a boss.
static func resolve(flow: String, camp_open: bool, track: String, boss_phase: int, shop: bool, combat: bool) -> String:
	if flow in MENU_FLOWS or flow == "":
		return "camp" if camp_open else "menu"
	if flow in OVER_FLOWS:
		return "run_over"
	if flow == "boss":
		return "boss_%d" % clampi(boss_phase, 1, 3)
	if track in FIGHT_TRACKS:
		return "miniboss"
	if shop:
		return "shop"
	return "combat" if combat else "roam"


static func state_db(state: String, bus: String) -> float:
	return float(STATES.get(state, {}).get(bus, 0.0))


# The crowd rule's offset for a cue of priority with live voices already sounding.
static func crowd_db(live: int, priority: int) -> float:
	if priority >= 2 or live <= CROWD_FREE:
		return 0.0
	return maxf(CROWD_FLOOR_DB, -CROWD_DB_PER_DOUBLING * log(float(live) / CROWD_FREE) / log(2.0))


# One glide step from now toward want over delta seconds.
static func glide(now: float, want: float, delta: float, fast := false) -> float:
	if want < now or fast:
		if want > now:
			return minf(want, now + GLIDE_DOWN_DB_S * delta)
		return maxf(want, now - GLIDE_DOWN_DB_S * delta)
	return minf(want, now + GLIDE_UP_DB_S * delta)
