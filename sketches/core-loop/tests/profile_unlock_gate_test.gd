extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Achievements := preload("res://src/core/achievements.gd")
const T := preload("res://tests/support/t.gd")

# The game owns the player profile and the class-select gate (P2). In a test-mode game:
# ctx.profile sits under storage_dir, loaded and able to save, and the game's Progress
# earns a row into it from the bus (P2-1). A key or a card click on a locked pilot starts
# nothing, an unlocked or starter pilot starts (P2-2); flow.choose_class stays ungated.
# Sable alone starts open (P-R21); Rivet, Kest, Tarn, Tally and the remembered cannon are each named by exactly one pilot reward (P2-3).
# The rescue rows earn from rescue_completed and the dig rescue unlocks Kest (P2-4); it runs
# last, because rivet_rescued unlocks the runner_gunner id the gate steps keep locked.

const STEPS := ["key_locked", "click_locked", "direct", "die_a", "back_a", "key_unlocked", "die_b", "back_b", "key_starter"]

var _t := T.new("profile_unlock_gate_test")
var _game
var _step := -1
var _wait := 0
var _locked


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	if _step < 0:
		_wait += 1
		if _wait < 5:
			return false
		_game.ctx.calm = true
		_game.player.source = Intent.Scripted.new()
		_p1()
		_p3()
		_locked = ClassDef.make({"id": "runner_gunner", "display_name": "Rivet", "starter": false})
		var rivet: Resource = _game.flow.classes[1]
		for prop in ["role", "species", "pitch", "weapon_id", "movement_id", "special_id", "smash_id", "color", "shape", "motif", "sound", "bible_home", "synergy_hooks"]:
			_locked.set(prop, rivet.get(prop))
		_game.flow.classes[1] = _locked
		_game.flow.open_class_select()
		_step = 0
		_wait = 0
		return false
	_wait += 1
	if _wait < 20:
		return false
	var flow = _game.flow
	if STEPS[_step] in ["click_locked", "key_unlocked"] and _game.screens.class_cards()[1].disabled:
		return false
	_wait = 0
	match STEPS[_step]:
		"key_locked":
			_game._screen_key(KEY_2)
			_t.check("P2-2 locked key starts nothing", flow.state_name() == "class_select" and not flow.in_play(), "state %s" % flow.state_name())
		"click_locked":
			var cards: Array = _game.screens.class_cards()
			_t.eq("P2-2 one card per row", cards.size(), flow.classes.size())
			_t.check("P2-2 the locked card takes clicks", not cards[1].disabled, "disabled %s" % cards[1].disabled)
			_click(cards[1])
			_t.check("P2-2 locked click starts nothing", flow.state_name() == "class_select" and not flow.in_play(), "state %s" % flow.state_name())
		"direct":
			flow.choose_class(1)
			_t.check("P2-2 choose_class stays ungated", flow.in_play() and _game.run.class_def == _locked, "state %s" % flow.state_name())
		"die_a":
			_game.run.damage(99999.0, "test")
		"back_a":
			_game._screen_key(KEY_C)
			_t.eq("P2-2 back at class select", flow.state_name(), "class_select")
			_game.ctx.profile.unlock_pilot(_locked.id)
		"key_unlocked":
			_click(_game.screens.class_cards()[1])
			_t.check("P2-2 a click on the unlocked card starts the pilot", flow.in_play() and _game.run.class_def == _locked, "state %s" % flow.state_name())
		"die_b":
			_game.run.damage(99999.0, "test")
		"back_b":
			_game._screen_key(KEY_C)
			_t.eq("P2-2 back at class select again", flow.state_name(), "class_select")
		"key_starter":
			_game._screen_key(KEY_1)
			_t.check("P2-2 starter key starts", flow.in_play() and _game.run.class_def == flow.classes[0], "state %s" % flow.state_name())
			_p4()
			_game.queue_free()
			quit(_t.verdict())
			return true
	if _t.failures > 0:
		_game.queue_free()
		quit(_t.verdict())
		return true
	_step += 1
	return false


func _p1() -> void:
	var profile = _game.ctx.profile
	_t.check("P2-1 profile exists", profile != null, "ctx.profile")
	_t.check("P2-1 path under storage_dir", profile.path.begins_with(_game.storage_dir + "/"), "path %s" % profile.path)
	_t.check("P2-1 loaded and can save", profile.can_save, "can_save")
	_t.check("P2-1 game holds a Progress", _game.progress != null, "progress node")
	_game.run.begin(_game.flow.classes[0])
	_game.events.beacon_unsealed.emit(1)
	_t.check("P2-1 bus fact earns warden_broken in ctx.profile", profile.earned("warden_broken"), "beacon_unsealed")
	_t.check("P2-1 profile.json written under storage_dir", FileAccess.file_exists(_game.storage_dir.path_join("profile.json")), "file")


func _p3() -> void:
	var owners := {}
	for id in Achievements.ROWS:
		var pilot: String = Achievements.reward_of(id).get("pilot", "")
		if pilot != "":
			owners[pilot] = owners.get(pilot, 0) + 1
	for def in ClassDef.all():
		var named: int = owners.get(def.id, 0)
		var open: bool = def.id == "pylon_engineer"
		_t.check("P2-3 %s is open (Sable) or named by exactly one pilot reward" % def.id, def.starter == open and (open or named == 1), "starter %s, rewards %d" % [def.starter, named])
	var starters := 0
	for def in ClassDef.all():
		starters += 1 if def.starter else 0
	_t.eq("P2-3 Sable is the only starter", starters, 1)
	_t.check("P2-3 and the starter is Sable", ClassDef.all()[0].starter and ClassDef.all()[0].id == "pylon_engineer", "first row")
	var class_ids: Array = ClassDef.all().map(func(d): return d.id)
	var unresolved: Array = []
	for pilot in owners:
		if not class_ids.has(pilot) and not Achievements.PENDING_PILOTS.has(pilot):
			unresolved.append(pilot)
	_t.eq("P2-3 every pilot reward resolves", unresolved, [])
	var pending_with_row: Array = Achievements.PENDING_PILOTS.filter(func(p): return class_ids.has(p))
	_t.eq("P2-3 pending pilots have no class row", pending_with_row, [])
	_t.check("P2-3 remembered_cannon is mind_quieted's alone",
		Achievements.for_pilot("remembered_cannon") == "mind_quieted" and owners.get("remembered_cannon", 0) == 1,
		"for_pilot %s, rewards %d" % [Achievements.for_pilot("remembered_cannon"), owners.get("remembered_cannon", 0)])


func _p4() -> void:
	var profile = _game.ctx.profile
	var kest
	for def in ClassDef.all():
		if def.id == "demolitions_caster":
			kest = def
	var before: bool = _game.pilot_unlocked(kest)
	_game.events.rescue_completed.emit("rivet")
	_game.events.rescue_completed.emit("dig")
	_t.check("P2-4 rescue_completed earns rivet_rescued", profile.earned("rivet_rescued"), "rivet")
	_t.check("P2-4 rescue_completed earns dig_rescued", profile.earned("dig_rescued"), "dig")
	_t.check("P2-4 the dig rescue unlocks demolitions_caster", not before and _game.pilot_unlocked(kest),
			"before %s, after %s" % [before, _game.pilot_unlocked(kest)])


func _click(control: Control) -> void:
	var at := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	root.push_input(motion, true)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		ev.position = at
		ev.global_position = at
		root.push_input(ev, true)
