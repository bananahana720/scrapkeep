extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Parts := preload("res://src/build/parts.gd")
const ItemGen := preload("res://src/build/item_gen.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const RewardView := preload("res://src/ui/reward_view.gd")
const UiFonts := preload("res://src/core/ui_fonts.gd")

# The cobalt rung finish (design-v3/cobalt-rung-w1.md): the find card wears its rung's stamp,
# so a first cobalt find reads NEW FLEET GRADE rather than a bare NEW, and every cobalt find
# plays the rung's own voice (the item ladder's blue: a coil whine and click) under its bell.
# A find that waits for its crate plays the coil with the burst. A common find stays on its
# tick alone, and the stamp fits the card's corner. The cue log records a requested cue even
# when the headless bus skips it, so these checks read what the ceremony asks for.
# smoke: timeout=120s

var _t := preload("res://tests/support/t.gd").new("cobalt_rung_voice_test")
var _game


func _initialize() -> void:
	_run()


func _run() -> void:
	_check_recipe()
	_game = Game.new()
	_game.test_mode = true
	_game.table = "alpha"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await physics_frame
	_check_stamps()
	_check_voice()
	_game.free()
	quit(_t.verdict())


static func _first_of(rarity: String) -> String:
	for id in Parts.ids():
		if Parts.rarity_of(id) == rarity:
			return id
	return ""


func _check_recipe() -> void:
	var buf := SfxBank.samples("rung_coil")
	var peak := 0.0
	for x in buf:
		peak = maxf(peak, absf(x))
	var seconds := float(buf.size()) / SfxBank.RATE
	_t.check("the coil recipe bakes", SfxBank.has_recipe("rung_coil") and SfxBank.TRIM_DB.has("rung_coil"), "recipe and trim row")
	_t.check("the coil is short and in level", seconds > 0.2 and seconds < 0.4 and peak > 0.5 and peak <= 0.91, "%.3f s, peak %.3f" % [seconds, peak])


func _check_stamps() -> void:
	var ceremony = _game.presentation.ceremony
	var cases := [["rare", true, "NEW FLEET GRADE"], ["rare", false, "FLEET GRADE"], ["common", true, "NEW FIELD KIT"],
		["common", false, "FIELD KIT"], ["relic", true, "RELIC"]]
	var widest := 0.0
	for c in cases:
		var part := _first_of(c[0])
		if part == "":
			_t.skip("stamp %s" % c[0], "no %s part on the alpha table" % c[0])
			continue
		var find: Dictionary = ceremony.find_of(part, "shop")
		find["first"] = c[1]
		var stamp := String(ceremony.card_state(find, 0, false)["stamp"])
		_t.eq("%s %s card stamp" % ["first" if c[1] else "repeat", c[0]], stamp, c[2])
		widest = maxf(widest, UiFonts.mono().get_string_size(stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 14.0)
	_t.eq("the stamps name the rungs", ItemGen.RARITY["rare"]["stamp"], "FLEET GRADE")
	_t.check("the widest stamp fits the card corner", widest < RewardView.CARD.x * 0.5, "%.0f px against a %.0f px card" % [widest, RewardView.CARD.x])


func _check_voice() -> void:
	var ceremony = _game.presentation.ceremony
	var log: Array = ceremony.audio.cue_log
	var rare := _first_of("rare")
	var common := _first_of("common")
	log.clear()
	var find: Dictionary = ceremony.find_of(rare, "shop")
	find["first"] = false
	find["tier"] = "rare"
	ceremony.present(find)
	var sounds: Array = log.map(func(row): return row[1])
	_t.check("a cobalt find plays the coil under its bell", "rung_coil" in sounds and "rarity_bell" in sounds, str(sounds))
	log.clear()
	find = ceremony.find_of(common, "shop")
	find["first"] = false
	find["tier"] = "common"
	ceremony.present(find)
	sounds = log.map(func(row): return row[1])
	_t.check("a common find keeps its tick alone", not "rung_coil" in sounds and "rarity_tick" in sounds, str(sounds))
	log.clear()
	find = ceremony.find_of(rare, "gate")
	find["first"] = false
	ceremony.present(find)
	sounds = log.map(func(row): return row[1])
	_t.check("a repeat cobalt gate pick (no crate) plays the coil with its tick", find["tier"] == "common" and "rung_coil" in sounds and "rarity_tick" in sounds,
		"%s at tier %s" % [sounds, find["tier"]])
	# In play a gate or boss find waits for its crate: the coil sounds with the burst, not the tick.
	ceremony.pause_armed = true
	log.clear()
	find = ceremony.find_of(rare, "warden")
	find["first"] = true
	ceremony.present(find)
	sounds = log.map(func(row): return row[1])
	_t.check("a crated cobalt find holds the coil at pickup", find["tier"] == "ceremony" and not "rung_coil" in sounds, "%s at tier %s" % [sounds, find["tier"]])
	log.clear()
	ceremony._queue.erase(find)
	ceremony._begin(find)
	ceremony._burst(int(ceremony.now_ms.call()))
	sounds = log.map(func(row): return row[1])
	_t.check("the crate's burst plays the coil", "rung_coil" in sounds and "ceremony_resolve" in sounds, str(sounds))
	ceremony._close(int(ceremony.now_ms.call()))
	_game.hold_play("ceremony", false)
	ceremony.pause_armed = false
