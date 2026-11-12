extends SceneTree

const BossPlate := preload("res://src/ui/boss_plate.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const Warden := preload("res://src/combat/warden.gd")
const Hud := preload("res://src/ui/hud.gd")
const Intent := preload("res://src/movement/intent.gd")
const MachineFx := preload("res://src/presentation/machine_fx.gd")
const Objectives := preload("res://src/core/objectives.gd")
const Palette := preload("res://src/core/palette.gd")
const Roster := preload("res://src/combat/roster.gd")
const Rows := preload("res://src/presentation/flourish_rows.gd")
const T := preload("res://tests/support/t.gd")

# One fact, one voice at the big beats of a fight (ruling cx, wave 36). Each beat is driven by its
# own event in a real game and the word carriers it puts up are counted: toasts, stamps, captions,
# cards, world words (a flourish's sound word or a machine's) and the boss plate's name.
#   warden break   no toast; the plate tick and the next objective stay
#   phase change   one stamp, one caption, one world word, never two of a kind at once
#   arrival        one card, one world word at a time, and the plate keeps its name off meanwhile
#   rout           no toast; at most one of each kind and three carriers in the two seconds after
#   colour         no celebration stamp is drawn in the hazard colour
#   names          the flume Warden's plate reads its card's name; the core toast says what it does
# Gaps, written down: the HUD's own clock (toast, achievement panel and call-in timers) is private
# to its process and is not stepped here, so the achievement panel (Brindle's rout earns one), the
# victory card and the speech bubble are read only as far as a public read reaches them
# (corner_rects, screens.visible); a lingering panel would still show as a carrier, a late one would not.
# Each count has a planted case: the removed toast row, and the removed shout, put back in a copy
# must trip the same check. Evidence limit: rules and counts, not how the beat reads on screen.

const DT := 1.0 / 90.0
const WINDOW := 2.0
const ROUT_CARRIERS := 3
# The HUD still toasts a phase's name (hud.gd:359-360, another unit's file). That one toast per
# phase is owed: check 52 collects every distinct toast over the phase window and wants exactly
# [the phase's name as the HUD prints it]. Change PHASE_TOAST_OWED to false when the HUD stops
# toasting phase names, and the list must then be empty. A second toast fails it.
const PHASE_TOAST_OWED := true
const BREAK_KINDS := ["beacon_unsealed", "reward_offered"]
const PLANTED_TOASTS := {"beacon_unsealed": "Warden broken: gates open", "reward_offered": "Reward gates ahead", "boss_defeated": "Brindle routed"}
const PLANTED_SHOUTS := {"kind": "sfx_word", "at": 0.5, "for": 1.6, "text": "WOOO!", "at_share": Vector2(0.40, 0.33)}

class LegacyGame extends "res://src/game.gd":
	func _chosen_table():
		return preload("res://tests/doubles/two_world_defs.gd").FirstWorld

var _game
var _t := T.new("moment_voices_test")
var _started := false
var _phase_name := ""


func _initialize() -> void:
	_game = LegacyGame.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null or _started:
		return false
	_started = true
	Harness.install(_game)
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_run_all()
	return false


func _run_all() -> void:
	await process_frame
	_tables()
	_colours()
	_names()
	_warden_break()
	_to_arena()
	_arrival()
	_phases()
	_rout()
	var code: int = _t.verdict()
	_game.free()
	quit(code)


# The kinds the HUD toasts for these events: its own public read for the live table.
func _toasting(kinds: Array) -> Array:
	return kinds.filter(func(kind): return kind in Hud.toast_kinds())


# The HUD's rule applied to a copy of the table, for the planted case. Check 00 holds it equal to
# Hud.toast_kinds() on the live table, so it cannot drift from the HUD's own rule.
func _rule_toasts(table: Dictionary, kind: String) -> bool:
	var row: Dictionary = table.get(kind, {})
	if String(row.get("hud", "")) == "" or kind in Hud.CARD_OWNED or kind in Hud.PRESENTATION_OWNED or kind in Hud.RETIRED_TOASTS:
		return false
	return int(row.get("priority", 0)) > EventKinds.TOAST_PRIORITY or kind in Hud.NOTABLE or kind == "event_ended"


# Celebration stamps drawn in the hazard colour, as "row form text", and how many were seen.
func _hazard_celebrations(rows: Dictionary) -> Dictionary:
	var celebrate := ["CLOCKED IN", "SHIFT COMPLETE", "ROUTED", "HIRED"]
	var seen := 0
	var bad: Array = []
	for id in rows:
		for form in ["full", "short"]:
			for piece in rows[id].get(form, []):
				if piece.kind == "stamp" and String(piece.text) in celebrate:
					seen += 1
					if String(piece.get("colour", "HAZARD")) == "HAZARD":
						bad.append("%s %s %s" % [id, form, piece.text])
	return {"seen": seen, "bad": bad}


# The rout's two count rules, shared by the live check and the planted one.
func _one_voice(counts: Dictionary, machine: int) -> bool:
	return _worst(counts) <= 1 and counts.get("sfx_word", 0) + machine <= 1


func _few_carriers(counts: Dictionary, machine: int, extra: int) -> bool:
	return _total(counts) + machine + extra <= ROUT_CARRIERS


# Pieces that start inside the window, counted by kind.
func _by_kind(pieces: Array, window := WINDOW) -> Dictionary:
	var out := {}
	for piece in pieces:
		if float(piece.at) < window:
			out[String(piece.kind)] = int(out.get(String(piece.kind), 0)) + 1
	return out


func _worst(counts: Dictionary) -> int:
	var worst := 0
	for kind in counts:
		worst = maxi(worst, int(counts[kind]))
	return worst


func _total(counts: Dictionary) -> int:
	var sum := 0
	for kind in counts:
		sum += int(counts[kind])
	return sum


# The toast kinds and the table itself: the three rows say nothing, and a copy with them restored does.
func _tables() -> void:
	var equal := true
	for kind in EventKinds.ROWS:
		equal = equal and (kind in Hud.toast_kinds()) == _rule_toasts(EventKinds.ROWS, kind)
	_t.check("00 the planted-case rule matches the HUD's own toast kinds on the live table", equal, "")
	_t.eq("01 the real table toasts nothing for a Warden break or a rout", _toasting(BREAK_KINDS + ["boss_defeated"]), [])
	var planted: Dictionary = EventKinds.ROWS.duplicate(true)
	for kind in PLANTED_TOASTS:
		planted[kind]["hud"] = PLANTED_TOASTS[kind]
	var restored: Array = (BREAK_KINDS + ["boss_defeated"]).filter(func(kind): return _rule_toasts(planted, kind))
	_t.check("02 planted: the three toast rows put back are caught", restored.size() == 3, str(restored))
	_t.eq("03 the next objective stays", EventKinds.objective("reward_offered"), "Roll through a gate")
	_t.eq("04 the plate tick stays", Objectives.done_words("warden"), "Warden broken")
	_t.eq("05 the core toast says what the core does", EventKinds.hud("core_gained"), "Gates may offer rares")
	_t.check("06 the sounds stay on the rows", EventKinds.row("beacon_unsealed").sound == "stinger_unseal" and EventKinds.row("reward_offered").sound == "gates_open"
		and EventKinds.row("boss_defeated").sound == "stinger_boss_defeated", "")


# Every stamp resolves to a colour: a celebration is amber, never the hazard colour.
func _colours() -> void:
	var live := _hazard_celebrations(Rows.ROWS)
	_t.check("10 every celebration stamp is amber", live.seen == 8 and live.bad.is_empty(), "%d stamps, hazard: %s" % [live.seen, live.bad])
	# Planted: one celebration stamp set back to the hazard colour in a copy of the rows is reported.
	var planted: Dictionary = Rows.ROWS.duplicate(true)
	for piece in planted["brindle_rout"]["full"]:
		if piece.kind == "stamp":
			piece["colour"] = "HAZARD"
	var caught := _hazard_celebrations(planted)
	_t.check("11 planted: a celebration stamp set back to hazard is reported", caught.bad == ["brindle_rout full ROUTED"], str(caught.bad))


# A minimal posture Warden: what the plate and the run summary read for its name.
class NamedWarden:
	extends Node3D
	var family := "reactor"
	var variant := ""

	func fight() -> String:
		return "posture"

	func is_dead() -> bool:
		return false

	func chunks_left() -> int:
		return 4


# The name follows the variant: the dam's reactor Warden is the Reactor Warden, the flume's
# meltdown one is the Meltdown Warden its card names. Returns what the plate and summary read.
func _read_names(table: Dictionary) -> Dictionary:
	var out := {}
	for stage in [{"id": "dam", "variant": ""}, {"id": "flume", "variant": "meltdown"}]:
		var w := NamedWarden.new()
		w.variant = stage.variant
		_game.add_child(w)
		var plate := BossPlate.new()
		plate.bind(w)
		out[stage.id] = {"plate": plate.plate_name(), "summary": _game.run_moments._stagger_name(w, false)}
		plate.free()
		w.free()
	return out


func _name_errors(table: Dictionary) -> Array:
	var want := {"reactor:": "Reactor Warden", "reactor:meltdown": "Meltdown Warden", "swarm:": "Hive Warden", "swarm:brood": "Brood Warden", "mind:": "Mind Warden", "mind:choir": "Crown Warden"}
	var bad: Array = []
	for key in want:
		var parts: PackedStringArray = key.split(":")
		if String(table.get(parts[0], {}).get(parts[1], "")) != want[key]:
			bad.append(key)
	return bad


# Variants that take their family's name on purpose (none today).
const SHARES_FAMILY_NAME: Array[String] = []


# Every variant warden.gd reads has its own name row or is on the short list above.
func _variant_name_gaps() -> Array:
	var gaps: Array = []
	for variant in Warden.VARIANTS:
		if variant == "" or variant in SHARES_FAMILY_NAME:
			continue
		var family: String = Warden.VARIANT_FAMILIES[variant]
		if not Roster.WARDEN_NAMES.get(family, {}).has(variant):
			gaps.append(variant)
	return gaps


func _names() -> void:
	_t.eq("25 every Warden variant has its own name row or shares on purpose", _variant_name_gaps(), [])
	_t.eq("26 the lore's names: brood is the Brood Warden, choir the Crown Warden", [Roster.warden_name("swarm", "brood"), Roster.warden_name("mind", "choir")], ["Brood Warden", "Crown Warden"])
	var card: String = String(Rows.pieces("flume_warden_reveal", false)[0].card[0])
	var read := _read_names(Roster.WARDEN_NAMES)
	_t.eq("20 the flume Warden's plate and summary read its card's name", [read.flume.plate.to_upper(), read.flume.summary], [card, "The Meltdown Warden"])
	_t.eq("21 the dam's Warden reads Reactor Warden on the plate and in the summary", [read.dam.plate, read.dam.summary], ["Reactor Warden", "The Reactor Warden"])
	_t.eq("22 the NAMES.md name for a variant with no name of its own is its family's", Roster.warden_name("reactor", "nothing"), "Reactor Warden")
	_t.eq("23 the name table has no wrong mapping", _name_errors(Roster.WARDEN_NAMES), [])
	# Planted: a variant mapped to the wrong name is reported.
	var table: Dictionary = Roster.WARDEN_NAMES.duplicate(true)
	table["reactor"][""] = "Meltdown Warden"
	_t.eq("24 planted: the dam mapped to Meltdown Warden is reported", _name_errors(table), ["reactor:"])


# The Warden break through the HUD's own signals: nothing is toasted at either one.
func _warden_break() -> void:
	var hud = _game.hud
	_game.events.beacon_unsealed.emit(1)
	var after_unseal: Array = hud.toast_texts()
	_game.events.reward_offered.emit([])
	var after_offer: Array = hud.toast_texts()
	_t.check("30 a Warden break raises no toast", after_unseal.is_empty() and after_offer.is_empty(), "%s %s" % [after_unseal, after_offer])


func _to_arena() -> void:
	Harness.start_run(_game)
	_game.presentation.flourish.stop_all()
	_game.flow.enter_stage(3, Vector3(0.0, 0.0, 16.0), false)
	_game.flow._finish_stage()


func _arrival() -> void:
	var player = _game.presentation.flourish
	_t.check("40 the arena opens on the arrival row", player.playing and player.id == "brindle_arrival", player.id)
	var worst := {}
	var plate = _game.hud.boss_plate
	var held_while_up: bool = plate != null and plate.name_held()
	var cards := 0
	var t := 0.0
	while t < WINDOW:
		player.advance(DT)
		var live := {}
		for kind in player.live_kinds():
			live[kind] = int(live.get(kind, 0)) + 1
		for kind in live:
			worst[kind] = maxi(int(worst.get(kind, 0)), int(live[kind]))
		t += DT
	cards = int(worst.get("card", 0))
	_t.check("41 the arrival never shows two of a kind at once", _worst(worst) <= 1 and cards == 1, str(worst))
	_t.check("42 the plate keeps its name off while the card is up", held_while_up, "plate %s" % [plate != null])
	player.advance(player.length() + 0.1)
	_t.check("43 and shows it when the card has gone", plate != null and not plate.name_held() and plate.plate_name() == "Admiral Brindle", "held %s" % [plate.name_held() if plate != null else "no plate"])


func _phases() -> void:
	var player = _game.presentation.flourish
	var fx = _game.presentation.machine_fx
	var hud = _game.hud
	_game.events.boss_phase_changed.connect(func(_n: int, phase_name: String): _phase_name = phase_name)
	for phase in [2, 3]:
		player.stop_all()
		var before: int = fx.moments.filter(func(m): return m[1] == "word").size()
		_game.boss.jump_to_phase(phase)
		var row_id := "brindle_phase_%d" % phase
		_t.check("50 phase %d plays its row" % phase, player.playing and player.id == row_id, player.id)
		var kinds := _by_kind(Rows.resolve(row_id, player.short, 7))
		var toasts: Array = []
		var worst := {}
		var t := 0.0
		while t < WINDOW:
			player.advance(DT)
			fx._process(DT)
			for text in hud.toast_texts():
				if not text in toasts:
					toasts.append(text)
			var live := {}
			for kind in player.live_kinds():
				live[kind] = int(live.get(kind, 0)) + 1
			for kind in live:
				worst[kind] = maxi(int(worst.get(kind, 0)), int(live[kind]))
			t += DT
		var machine: int = fx.moments.filter(func(m): return m[1] == "word").size() - before
		# PF-26: the boss's own change carries a phase turn, so Brindle's turns draw no stamp and no machine word over the fight.
		_t.check("51 phase %d: one caption and no word over the fight, nothing else on its own" % phase,
			kinds.get("caption", 0) == 1 and not kinds.has("stamp") and not kinds.has("sfx_word") and not kinds.has("card") and machine == 0 and _worst(worst) <= 1,
			"row %s, machine words %d, live %s" % [kinds, machine, worst])
		var owed: Array = [Hud.toast_text("boss_phase_changed", {"name": _phase_name.capitalize()})] if PHASE_TOAST_OWED else []
		_t.check("52 phase %d: the toasts over the window are exactly the phase name the HUD still owes" % phase, toasts == owed, "toasts %s, owed %s" % [toasts, owed])
		# Planted: a second toast raised inside the window is seen by the same collection.
		var planted_seen: Array = []
		hud.toast("Second voice")
		for i in 3:
			for text in hud.toast_texts():
				if not text in planted_seen:
					planted_seen.append(text)
		_t.check("53 planted: a second toast in the window is reported" if phase == 2 else "53 planted again (phase 3)", (toasts + planted_seen) != owed and "Second voice" in planted_seen, str(planted_seen))
		player.advance(WINDOW)


# The rout, driven by the boss's own defeat: counted over the two seconds after it.
func _rout() -> void:
	var player = _game.presentation.flourish
	var fx = _game.presentation.machine_fx
	var hud = _game.hud
	player.stop_all()
	var before: int = fx.moments.filter(func(m): return m[1] == "word").size()
	# A phase toast still on screen from the fight is not the rout's.
	var lingering: Array = hud.toast_texts()
	Harness.defeat(_game)
	_t.check("60 the defeat plays the rout row", player.playing and player.id == "brindle_rout", player.id)
	var toasts := {}
	var panels := 0
	var t := 0.0
	while t < WINDOW:
		player.advance(DT)
		fx._process(DT)
		var screens = _game.get("screens")
		if hud.corner_rects().any(func(r): return r["name"] == "plate") or (screens != null and screens.visible):
			panels += 1
		for text in hud.toast_texts():
			if not text in lingering:
				toasts[text] = true
		t += DT
	var counts := _by_kind(Rows.resolve("brindle_rout", player.short, 7))
	var machine: int = fx.moments.filter(func(m): return m[1] == "word").size() - before
	var extra: int = toasts.size() + (1 if panels > 0 else 0)
	var carriers := _total(counts) + machine + extra
	_t.check("61 the rout raises no toast and the victory card still waits (the achievement panel needs the HUD clock, not stepped here)", toasts.is_empty() and panels == 0, "%s, panel frames %d" % [toasts.keys(), panels])
	_t.check("62 at most one of each kind, world words from the row and the machine together", _one_voice(counts, machine),
		"row %s, machine words %d" % [counts, machine])
	_t.check("63 at most three carriers in all", _few_carriers(counts, machine, extra), "%d carriers: row %s, machine %d, toasts and panels %d" % [carriers, counts, machine, extra])
	_t.check("64 the kept three are the shout, the stamp and the caption", counts.get("sfx_word", 0) == 1 and counts.get("stamp", 0) == 1 and counts.get("caption", 0) == 1
		and Rows.pieces("brindle_rout", false).any(func(p): return p.kind == "sfx_word" and p.text == "FWOOMP"), str(counts))
	_t.check("65 Brindle's fall carries no word of his own", not MachineFx.BOSSES["brindle"].has("fall_word"), "")
	# Planted: the removed shout put back in a copy of the row trips the same counts.
	var planted: Array = Rows.pieces("brindle_rout", false).duplicate(true)
	planted.append(PLANTED_SHOUTS)
	var planted_counts := _by_kind(planted)
	_t.check("66 planted: with a second shout put back, both rout rules trip", not _one_voice(planted_counts, machine) and not _few_carriers(planted_counts, machine, extra),
		str(planted_counts))
	# The rout's stamp is amber, read from the resolved piece.
	var stamp_colour := Palette.AMBER
	for piece in Rows.resolve("brindle_rout", false, 7):
		if piece.kind == "stamp":
			stamp_colour = (Palette as Script).get_script_constant_map().get(String(piece.get("colour", "HAZARD")), Palette.HAZARD)
	_t.check("67 the rout's stamp is not the hazard colour", stamp_colour != Palette.HAZARD, str(stamp_colour))
