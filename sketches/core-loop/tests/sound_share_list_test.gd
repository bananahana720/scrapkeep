extends SceneTree

const T := preload("res://tests/support/t.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Rows := preload("res://src/presentation/rows.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const Synth := preload("res://src/presentation/synth.gd")
const Palette := preload("res://src/core/palette.gd")
const Registry := preload("res://src/core/content_registry.gd")

# W1-41: every heard sound that two or more player facts share is named here, with its reason, so
# no new share slips in unnoticed. W1-42: the five fight facts that had no sound of their own now
# have one no other row hears. Cue choices are read from the row tables, not from a listen.
#
# What counts: every row in every event_kinds.gd table that names `sound` or `sound_next`, heard
# through Rows.heard (so a baked sound_next wins). A row is left out when it is not a player fact:
# priority 0 (bookkeeping) or a heard sound of "" or none. A row with no priority key (the state and
# line rows) counts. A share of a hazard-coloured row with an amber one (a risk with a reward) is
# never allowed, and is not on the list below: it must be split.

# sound -> {count, why}. count is how many counted rows hear it today; a row joining a share raises it.
const SHARED := {
	"beacon_hum": {"count": 3, "why": "one rising hum for a charge climbing: the beacon, a weak point opening and a vent venting (the gauge has its own climb since wave 44)"},
	"found_chime": {"count": 16, "why": "the find chime for a small paid or opened thing (an activity done, a route opened, a lap ended); all rewards"},
	"scrap_tick": {"count": 3, "why": "a scrap pip: scrap picked up, a Brindle reel, a lap checkpoint; all small pay"},
	"part_get": {"count": 2, "why": "a part taken: gained from a drop or picked from a tree"},
	"boost_whoosh": {"count": 9, "why": "the ball being carried faster: a boost, a sprint and each ride's lift; all one 'you are moving faster' whoosh"},
	"dash_whoosh": {"count": 3, "why": "a short burst sideways: a dash, a blink and a glide drop"},
	"land_thud": {"count": 3, "why": "the ball or an enemy meeting ground or a wall"},
	"pylon_plant": {"count": 2, "why": "a mount and entering the shop: both plant the ball in place"},
	"pylon_eject": {"count": 3, "why": "the ball leaving a mount or the shop: one 'popped out' spring (a shield vault has the rebound's snap since wave 44)"},
	"hit_thwack": {"count": 2, "why": "a hit that lands: a strike and a guard step (a pin has its double thwack since wave 44)"},
	"clank": {"count": 3, "why": "a hit turned aside: a deflect, a glance and a bet losing"},
	"event_end": {"count": 2, "why": "an event or an ambush ending; the ambush's real sound comes from its outcome row"},
	"launch_roar": {"count": 4, "why": "being thrown: a launch, the ultimate's start, a trebuchet and a geyser"},
	"boss_weak_hit": {"count": 2, "why": "a hit on a weak point and the open core state it leaves"},
	"shatter": {"count": 2, "why": "something broken: a hold and a guard chunk (the cloak and the wall have their own since wave 44)"},
	"hold_pit": {"count": 2, "why": "a hold starting and the held state it sets; both are the one risk"},
	"ui_tick": {"count": 7, "why": "the neutral tick for a small prompt or page change; these rows are not facts the player acts on"},
	"line_bite": {"count": 2, "why": "the harpoon biting: a body latched and a chain link"},
	"dry_tick": {"count": 4, "why": "a nothing-happened click: an expired line skill, a cancelled ultimate, a dry fire and a chain miss"},
	"line_zip": {"count": 2, "why": "the line letting go or ending: one zip"},
	"threat_tick": {"count": 3, "why": "a small hazard coming: the quiet warning for a ground or ceiling hazard with no grind of its own; all risks"},
	"threat_whistle": {"count": 2, "why": "an incoming hit's whistle for the hazards with no family tone of their own; all risks"},
	"slam_boom": {"count": 2, "why": "a heavy landing with no family sound of its own, and the harpoon smash; one heavy impact"},
	# Wave 44: each hazard family's own warning and landing, heard by every row of that family.
	"rock_grind_dust_hiss": {"count": 5, "why": "ground or roof about to give (a slump, a crust crack, a trestle, cinders, a cave-in): one grind and dust hiss; all risks"},
	"rockfall_boom": {"count": 4, "why": "ground or roof coming down (a slump, a crust crack, a trestle, a cave-in): one rockfall; all risks"},
	"fleet_falling_pure": {"count": 2, "why": "the Fleet's falling warning for its two drops, the barge and the zipline; both risks"},
	"fleet_anvil_brass_drop": {"count": 3, "why": "the Fleet landing (the barge, the cage, the zipline): one anvil and brass; all risks"},
	"boiler_falling_pure": {"count": 2, "why": "a pressure build about to blow, the boiler and the reactor overload: one steam whistle falling; both risks"},
	"lightning_falling_pure": {"count": 2, "why": "lightning about to strike, the charge and the mark: one falling tone with static; both risks"},
	"lightning_strike": {"count": 2, "why": "lightning striking, from the charge or the mark: one strike; both risks"},
	"crater_crump_sub_boom": {"count": 2, "why": "a crater made, by a reactor landing or an impact: one crump and sub; both risks"},
	"rebound_spring_snap": {"count": 2, "why": "the ball sprung off something, an enemy or a shield: one spring snap"},
	"callout_chime": {"count": 4, "why": "the callout card's chime for a lesson (scrap, gates, notes, a wall bait); the card's words say which"},
	"shop_bell": {"count": 2, "why": "the shop bell for a buy and for a charge"},
	"bench_clank": {"count": 2, "why": "the bench: a reroll and a sale"},
	"rarity_bell": {"count": 2, "why": "a rare reward and a payoff: both the rarity bell"},
	"arena_lock_slam": {"count": 2, "why": "a gate slamming: the arena locking and the sluice opening"},
	"arena_wave_whistle": {"count": 2, "why": "a crew arriving: an arena wave and the sluice warning; both danger cues"},
	"warden_gate_pip": {"count": 2, "why": "a pip at the Warden gate: the pip and the call window"},
	"warden_gate_release": {"count": 2, "why": "the Warden gate letting go: the gate opened and a call met"},
}

const FIVE := {
	"drop_landed": {"sound": "drop_thud", "danger": false},
	"missed_drop": {"sound": "drop_whiff", "danger": false},
	"evolution_fired": {"sound": "evolution_fired", "danger": false},
	"guard_critical": {"sound": "guard_creak", "danger": false},
}
const BEACON := {"beacon_unsealed": "stinger_unseal", "beacon_open": "beacon_open_chime"}

var _t := T.new("sound_share_list_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var counted := _counted({})
	_t.check("share list: the scan counted rows", counted.rows >= 200, str(counted.rows))
	_shares(counted.by)
	_planted()
	_five()
	_bank()
	quit(_t.verdict())


# {rows: how many rows counted, by: {sound: [{name, color}]}} over every constant table of rows, plus extra rows.
func _counted(extra: Dictionary) -> Dictionary:
	var by := {}
	var rows := 0
	var tables: Dictionary = (EventKinds as GDScript).get_script_constant_map()
	var all := {}
	for table_name in tables:
		var table = tables[table_name]
		if table is Dictionary:
			for kind in table:
				all["%s:%s" % [table_name, kind]] = table[kind]
	all.merge(extra)
	for name in all:
		var row = all[name]
		if not row is Dictionary or not (row.has("sound") or row.has("sound_next")):
			continue
		var sound := Rows.heard(row)
		if sound == "" or sound == EventKinds.NONE or int(row.get("priority", 1)) == 0:
			continue
		rows += 1
		if not by.has(sound):
			by[sound] = []
		by[sound].append({"name": name, "color": row.get("color", null)})
	return {"rows": rows, "by": by}


func _is_risk(color) -> bool:
	return color in [Palette.HAZARD, Palette.RUST, "hazard", "rust"]


func _is_reward(color) -> bool:
	return color in [Palette.AMBER, "amber"]


# The share failures: a share not on the list, a share bigger than its entry, and a risk shared with a reward.
func _failures(by: Dictionary) -> Array:
	var out := []
	for sound in by:
		var hearers: Array = by[sound]
		if hearers.size() < 2:
			continue
		var names := hearers.map(func(h): return h.name)
		if hearers.any(func(h): return _is_risk(h.color)) and hearers.any(func(h): return _is_reward(h.color)):
			out.append("%s mixes a risk with a reward: %s" % [sound, names])
		if not SHARED.has(sound):
			out.append("%s is shared and not on the list: %s" % [sound, names])
		elif hearers.size() > int(SHARED[sound].count):
			out.append("%s grew past its listed %d: %s" % [sound, int(SHARED[sound].count), names])
	return out


func _shares(by: Dictionary) -> void:
	var failures := _failures(by)
	for line in failures:
		print("  ", line)
	_t.check("share list: every share is on the list and no risk shares a reward", failures.is_empty(), "%d problems" % failures.size())
	var listed := 0
	for sound in SHARED:
		listed += 1
		_t.check("share list: %s still has the share its entry names" % sound, by.has(sound) and by[sound].size() == int(SHARED[sound].count), "%d hearers, listed %d" % [by.get(sound, []).size(), int(SHARED[sound].count)])
		_t.check("share list: %s has a reason" % sound, String(SHARED[sound].why).length() > 10)
	_t.check("share list: the loop ran over every entry", listed == SHARED.size() and listed >= 30, str(listed))


# A test-only copy of a row joins a listed share, and a copy of a hazard row joins an amber row's sound.
func _planted() -> void:
	var land: Dictionary = EventKinds.ROWS["landed"].duplicate()
	var planted := _failures(_counted({"PLANTED:landed_copy": land}).by)
	_t.check("planted: a copy of a row on a listed share fails the list", planted.size() == 1 and "land_thud" in planted[0], str(planted))
	var risk: Dictionary = EventKinds.ROWS["landed"].duplicate()
	risk["color"] = Palette.HAZARD
	risk["sound"] = "found_chime"
	var mixed := _failures(_counted({"PLANTED:risk_on_found": risk}).by)
	_t.check("planted: a risk on a reward's sound fails as mixed", mixed.any(func(l): return "mixes a risk with a reward" in l), str(mixed))
	var own: Dictionary = EventKinds.ROWS["landed"].duplicate()
	own["sound"] = "ui_tick"
	own["sound_next"] = "drop_thud"
	var shared_new := _failures(_counted({"PLANTED:thud_twin": own}).by)
	_t.check("planted: a second row hearing a new sound is named", shared_new.size() == 1 and "drop_thud" in shared_new[0] and "PLANTED:thud_twin" in shared_new[0], str(shared_new))


# Each of the five facts and the beacon's two rows hear a sound nothing else hears.
func _five() -> void:
	var by: Dictionary = _counted({}).by
	var looped := 0
	for kind in FIVE:
		looped += 1
		var row := Rows.row(kind)
		var sound := Rows.heard(row)
		_t.eq("five: %s hears its own sound" % kind, sound, FIVE[kind].sound)
		_t.check("five: only %s hears %s" % [kind, sound], by.has(sound) and by[sound].size() == 1 and String(by[sound][0].name).ends_with(":" + kind), str(by.get(sound, [])))
		_t.eq("five: %s is %s in the danger list" % [kind, "named" if FIVE[kind].danger else "not named"], sound in SfxBank.DANGER_SOUNDS, FIVE[kind].danger)
		_t.check("five: %s is a fact worth a sound (priority 1 or more)" % kind, int(row.get("priority", 0)) >= 1)
	_t.check("five: the loop ran over every fact", looped == FIVE.size() and looped == 4, str(looped))
	_t.check("five: the missed drop is a soft no, not a danger cue", not Rows.heard(Rows.row("missed_drop")) in SfxBank.DANGER_SOUNDS)
	var opened := 0
	for name in BEACON:
		opened += 1
		var row: Dictionary = EventKinds.state_row(name) if name == "beacon_open" else Rows.row(name)
		var sound := Rows.heard(row)
		_t.eq("beacon: %s hears its own sound" % name, sound, BEACON[name])
		var who: Array = by.get(sound, [])
		_t.check("beacon: only %s hears %s" % [name, sound], who.size() == 1, str(who))
	_t.check("beacon: the loop ran over both rows", opened == 2, str(opened))


func _bank() -> void:
	var ids := ["drop_thud", "drop_whiff", "guard_creak", "beacon_open_chime", "evolution_fired", "callout_warden_chime"]
	var looped := 0
	for id in ids:
		looped += 1
		_t.check("bank: %s has a recipe" % id, SfxBank.has_recipe(id))
		_t.check("bank: %s has a level" % id, SfxBank.TRIM_DB.has(id))
		var seconds := float(SfxBank.samples(id).size()) / float(SfxBank.RATE)
		var peak := Synth.wav_peak(SfxBank.stream(id))
		_t.check("bank: %s renders non-silent and under 1.5 s" % id, peak >= 0.1 and seconds > 0.02 and seconds < 1.5, "peak %.3f, %.3f s" % [peak, seconds])
		_t.check("bank: %s keeps a voice limit and a gap" % id, SfxBank.VOICE_LIMIT.has(id) or id == "evolution_fired", id)
	_t.check("bank: the loop ran over every sound", looped == ids.size(), str(looped))
	_t.check("bank: the beacon chime is keyed, the thud and creak are not", "beacon_open_chime" in SfxBank.KEYED_SOUNDS and not "drop_thud" in SfxBank.KEYED_SOUNDS and not "guard_creak" in SfxBank.KEYED_SOUNDS)
