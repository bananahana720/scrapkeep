extends SceneTree

const BossPlate := preload("res://src/ui/boss_plate.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
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
# Each count has a planted case: the removed toast row, and the removed shout, put back in a copy
# must trip the same check. Evidence limit: rules and counts, not how the beat reads on screen.

const DT := 1.0 / 90.0
const WINDOW := 2.0
const ROUT_CARRIERS := 3
const BREAK_KINDS := ["beacon_unsealed", "reward_offered"]
const PLANTED_TOASTS := {"beacon_unsealed": "Warden broken: gates open", "reward_offered": "Reward gates ahead", "boss_defeated": "Brindle routed"}
const PLANTED_SHOUTS := {"kind": "sfx_word", "at": 0.5, "for": 1.6, "text": "WOOO!", "at_share": Vector2(0.40, 0.33)}

class LegacyGame extends "res://src/game.gd":
	func _chosen_table():
		return preload("res://tests/doubles/two_world_defs.gd").FirstWorld

var _game
var _t := T.new("moment_voices_test")
var _started := false


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


# The kinds the HUD would toast for these events in this table, by the HUD's own rule.
func _toasting(table: Dictionary, kinds: Array) -> Array:
	var out: Array = []
	for kind in kinds:
		var row: Dictionary = table.get(kind, {})
		if String(row.get("hud", "")) == "" or kind in Hud.CARD_OWNED or kind in Hud.PRESENTATION_OWNED or kind in Hud.RETIRED_TOASTS:
			continue
		if int(row.get("priority", 0)) > EventKinds.TOAST_PRIORITY or kind in Hud.NOTABLE:
			out.append(kind)
	return out


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
	_t.eq("01 the real table toasts nothing for a Warden break or a rout", _toasting(EventKinds.ROWS, BREAK_KINDS + ["boss_defeated"]), [])
	var planted: Dictionary = EventKinds.ROWS.duplicate(true)
	for kind in PLANTED_TOASTS:
		planted[kind]["hud"] = PLANTED_TOASTS[kind]
	_t.check("02 planted: the three toast rows put back are caught", _toasting(planted, BREAK_KINDS + ["boss_defeated"]).size() == 3,
		str(_toasting(planted, BREAK_KINDS + ["boss_defeated"])))
	_t.eq("03 the next objective stays", EventKinds.objective("reward_offered"), "Roll through a gate")
	_t.eq("04 the plate tick stays", Objectives.done_words("warden"), "Warden broken")
	_t.eq("05 the core toast says what the core does", EventKinds.hud("core_gained"), "Core found: richer gates")
	_t.check("06 the sounds stay on the rows", EventKinds.row("beacon_unsealed").sound == "stinger_unseal" and EventKinds.row("reward_offered").sound == "gates_open"
		and EventKinds.row("boss_defeated").sound == "stinger_boss_defeated", "")


# Every stamp resolves to a colour: a celebration is amber, never the hazard colour.
func _colours() -> void:
	var celebrate := ["CLOCKED IN", "SHIFT COMPLETE", "ROUTED!", "HIRED"]
	var seen := 0
	var bad: Array = []
	for id in Rows.ROWS:
		for form in ["full", "short"]:
			for piece in Rows.pieces(id, form == "short"):
				if piece.kind == "stamp" and String(piece.text) in celebrate:
					seen += 1
					if String(piece.get("colour", "HAZARD")) == "HAZARD":
						bad.append("%s %s %s" % [id, form, piece.text])
	_t.check("10 every celebration stamp is amber", seen == 8 and bad.is_empty(), "%d stamps, hazard: %s" % [seen, bad])
	var hazard_stamp := {"kind": "stamp", "text": "ROUTED!", "at": 0.9, "for": 1.5}
	_t.check("11 planted: a stamp with no colour reads as hazard", String(hazard_stamp.get("colour", "HAZARD")) == "HAZARD", "")


func _names() -> void:
	var card: String = String(Rows.pieces("flume_warden_reveal", false)[0].card[0])
	_t.eq("20 the flume Warden's plate reads its card's name", BossPlate.NAMES[Roster.REACTOR].to_upper(), card)


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
	for phase in [2, 3]:
		player.stop_all()
		var before: int = fx.moments.filter(func(m): return m[1] == "word").size()
		_game.boss.jump_to_phase(phase)
		var row_id := "brindle_phase_%d" % phase
		_t.check("50 phase %d plays its row" % phase, player.playing and player.id == row_id, player.id)
		var kinds := _by_kind(Rows.resolve(row_id, player.short, 7))
		var toasts: Array = hud.toast_texts()
		var worst := {}
		var t := 0.0
		while t < WINDOW:
			player.advance(DT)
			fx._process(DT)
			var live := {}
			for kind in player.live_kinds():
				live[kind] = int(live.get(kind, 0)) + 1
			for kind in live:
				worst[kind] = maxi(int(worst.get(kind, 0)), int(live[kind]))
			t += DT
		var machine: int = fx.moments.filter(func(m): return m[1] == "word").size() - before
		_t.check("51 phase %d: one stamp, one caption, one machine word, nothing else on its own" % phase,
			kinds.get("stamp", 0) == 1 and kinds.get("caption", 0) == 1 and not kinds.has("sfx_word") and not kinds.has("card") and machine == 1 and _worst(worst) <= 1,
			"row %s, machine words %d, live %s, toasts %s" % [kinds, machine, worst, toasts])
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
	var t := 0.0
	while t < WINDOW:
		player.advance(DT)
		fx._process(DT)
		for text in hud.toast_texts():
			if not text in lingering:
				toasts[text] = true
		t += DT
	var counts := _by_kind(Rows.resolve("brindle_rout", player.short, 7))
	var machine: int = fx.moments.filter(func(m): return m[1] == "word").size() - before
	var carriers := _total(counts) + machine + toasts.size()
	_t.check("61 the rout raises no toast", toasts.is_empty(), str(toasts.keys()))
	_t.check("62 at most one of each kind, world words from the row and the machine together", _worst(counts) <= 1 and counts.get("sfx_word", 0) + machine <= 1,
		"row %s, machine words %d" % [counts, machine])
	_t.check("63 at most three carriers in all", carriers <= ROUT_CARRIERS, "%d carriers: row %s, machine %d, toasts %d" % [carriers, counts, machine, toasts.size()])
	_t.check("64 the kept three are the shout, the stamp and the caption", counts.get("sfx_word", 0) == 1 and counts.get("stamp", 0) == 1 and counts.get("caption", 0) == 1
		and Rows.pieces("brindle_rout", false).any(func(p): return p.kind == "sfx_word" and p.text == "FWOOMP"), str(counts))
	_t.check("65 Brindle's fall carries no word of his own", not MachineFx.BOSSES["brindle"].has("fall_word"), "")
	# Planted: the removed shout put back in a copy of the row trips the same counts.
	var planted: Array = Rows.pieces("brindle_rout", false).duplicate(true)
	planted.append(PLANTED_SHOUTS)
	var planted_counts := _by_kind(planted)
	_t.check("66 planted: a second shout put back is caught", counts.get("sfx_word", 0) < planted_counts.get("sfx_word", 0) and _total(planted_counts) + machine + toasts.size() > carriers,
		str(planted_counts))
	# The rout's stamp is amber, read from the resolved piece.
	var stamp_colour := Palette.AMBER
	for piece in Rows.resolve("brindle_rout", false, 7):
		if piece.kind == "stamp":
			stamp_colour = (Palette as Script).get_script_constant_map().get(String(piece.get("colour", "HAZARD")), Palette.HAZARD)
	_t.check("67 the rout's stamp is not the hazard colour", stamp_colour != Palette.HAZARD, str(stamp_colour))
