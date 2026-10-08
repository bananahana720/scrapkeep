extends SceneTree

const Game := preload("res://src/game.gd")
const Profile := preload("res://src/core/profile.gd")
const Progress := preload("res://src/core/progress.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Achievements := preload("res://src/core/achievements.gd")
const Intent := preload("res://src/movement/intent.gd")
const T := preload("res://tests/support/t.gd")

# The fresh-profile unlock sequence (ROADMAP "Content and progression"): a test-mode game
# starts on an empty profile under its own storage_dir with Sable alone selectable (P-R21).
# Bus events then arrive in the game's own order and each reward opens exactly its pilot:
# the world-one rescue opens Rivet, Brindle opens Tarn, the Dig rescue opens Kest, the Mind
# opens the remembered cannon and the third ledger leaf handed to Moss opens Tally. Leaf
# three is found by the world-three boss, which is the Mind (progress.gd LEDGER_FOUND,
# achievements.gd mind_quieted), so the cannon opens before Tally. After every step the
# selectable set is checked whole, against the saved file reloaded and the class-select keys
# and clicks. Nothing writes the profile directly; Moss takes leaves through shop.enter.

const SABLE := "pylon_engineer"
const RIVET := "runner_gunner"
const KEST := "demolitions_caster"
const TARN := "tarn"
const TALLY := "tally"
const CANNON := "remembered_cannon"
# A step: its label, the pilot ids it newly opens, and the full selectable set after it.
const SEQUENCE := [
	["rivet_rescue", [RIVET], [SABLE, RIVET]],
	["brindle_routed", [TARN], [SABLE, RIVET, TARN]],
	["leaf_one_returned", [], [SABLE, RIVET, TARN]],
	["dig_rescue", [KEST], [SABLE, RIVET, KEST, TARN]],
	["leaf_two_returned", [], [SABLE, RIVET, KEST, TARN]],
	["mind_quieted", [CANNON], [SABLE, RIVET, KEST, TARN, CANNON]],
	["leaf_three_returned", [TALLY], [SABLE, RIVET, KEST, TARN, TALLY, CANNON]],
]
const PILOT_ROWS_IN_ORDER := ["rivet_rescued", "brindle_routed", "dig_rescued", "mind_quieted", "ledger_balanced"]

var _t := T.new("profile_unlock_sequence_test")
var _game
var _earned: Array = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	await _frames(5)
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_game.events.achievement_earned.connect(func(id: String): _earned.append(id))
	var profile = _game.ctx.profile
	_t.check("S0 profile under a fresh storage_dir", profile.path.begins_with(_game.storage_dir + "/"), profile.path)
	_t.eq("S0 the profile starts with no pilots", _profile_pilots(profile), [])
	_t.eq("S0 the profile starts with no achievements", Achievements.ids().filter(func(id): return profile.earned(id)), [])
	_game.flow.open_class_select()
	_t.eq("S0 Sable alone is selectable", _selectable(), [SABLE])
	if not await _gate("S0", [SABLE]):
		_finish()
		return
	for step in SEQUENCE:
		_emit(step[0])
		var label := "S %s" % step[0]
		_t.eq("%s selectable set" % label, _selectable(), step[2])
		_t.eq("%s profile pilots" % label, _profile_pilots(profile), _rewarded(step[2]))
		_check_disk(label, step[2])
		if not await _gate(label, step[1]):
			break
		if _t.failures > 0:
			break
	_achievements()
	_finish()


func _finish() -> void:
	_game.queue_free()
	quit(_t.verdict())


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


# The game's own order for each step, through the bus (and Moss's bay for a leaf hand-in).
func _emit(step: String) -> void:
	var events = _game.events
	match step:
		"rivet_rescue":
			events.world_entered.emit(1)
			events.rescue_completed.emit("rivet")
		"brindle_routed":
			events.world_entered.emit(1)
			events.enemy_killed.emit("brindle", Vector3.ZERO, 0)
			events.boss_defeated.emit()
		"dig_rescue":
			events.world_entered.emit(2)
			events.rescue_completed.emit("dig")
		"mind_quieted":
			events.world_entered.emit(3)
			events.boss_defeated.emit()
		"leaf_one_returned", "leaf_two_returned", "leaf_three_returned":
			if step == "leaf_two_returned":
				# The Waking falls in the Dig and finds leaf two before the bay.
				events.world_entered.emit(2)
				events.boss_defeated.emit()
			var shop = _game.ctx.build.shop
			var before: int = _game.progress.leaves_returned()
			shop.enter()
			shop.leave()
			_t.eq("S %s Moss takes one leaf" % step, _game.progress.leaves_returned(), before + 1)


# Pilot ids the gate lets start, in class order.
func _selectable() -> Array:
	var out: Array = []
	for def in _game.flow.classes:
		if _game.pilot_unlocked(def):
			out.append(def.id)
	return out


func _profile_pilots(profile) -> Array:
	var out: Array = []
	for def in ClassDef.all():
		if profile.has_pilot(def.id):
			out.append(def.id)
	return out


# The pilots the profile holds after a step: every selectable non-starter.
func _rewarded(selectable: Array) -> Array:
	var out: Array = []
	for def in ClassDef.all():
		if selectable.has(def.id) and not def.starter:
			out.append(def.id)
	return out


func _check_disk(label: String, want: Array) -> void:
	_t.check("%s profile.json on disk" % label, FileAccess.file_exists(_game.ctx.profile.path), _game.ctx.profile.path)
	var reloaded := Profile.new(_game.ctx.profile.path)
	_t.check("%s reload succeeds" % label, reloaded.load_profile(), reloaded.last_error)
	var opened: Array = []
	for def in ClassDef.all():
		if def.starter or reloaded.has_pilot(def.id):
			opened.append(def.id)
	_t.eq("%s reloaded selectable set" % label, opened, want)
	_t.eq("%s reloaded pilots match" % label, _profile_pilots(reloaded), _profile_pilots(_game.ctx.profile))


# Every locked card refuses its key and its click; each pilot in fresh starts from its key
# and from its card. Returns false when the screen never settles.
func _gate(label: String, fresh: Array) -> bool:
	var flow = _game.flow
	if not await _settle_select(label):
		return false
	var cards: Array = _game.screens.class_cards()
	_t.eq("%s one card per class" % label, cards.size(), flow.classes.size())
	for i in flow.classes.size():
		var def = flow.classes[i]
		if _game.pilot_unlocked(def):
			continue
		_game._screen_key(KEY_1 + i)
		_t.check("%s locked %s key starts nothing" % [label, def.id], flow.state_name() == "class_select" and not flow.in_play(), flow.state_name())
		_click(cards[i])
		_t.check("%s locked %s click starts nothing" % [label, def.id], flow.state_name() == "class_select" and not flow.in_play(), flow.state_name())
	for id in fresh:
		var i := _index(id)
		for how in ["key", "click"]:
			if how == "key":
				_game._screen_key(KEY_1 + i)
			else:
				_click(_game.screens.class_cards()[i])
			_t.check("%s %s %s starts" % [label, id, how], flow.in_play() and _game.run.class_def.id == id, flow.state_name())
			if not await _back_to_select(label):
				return false
	return true


func _index(id: String) -> int:
	for i in _game.flow.classes.size():
		if _game.flow.classes[i].id == id:
			return i
	return -1


func _settle_select(label: String) -> bool:
	for i in 120:
		await physics_frame
		var cards: Array = _game.screens.class_cards()
		if i >= 20 and _game.flow.state_name() == "class_select" and not cards.is_empty() and cards.all(func(c): return not c.disabled):
			return true
	_t.check("%s class select settles" % label, false, _game.flow.state_name())
	return false


func _back_to_select(label: String) -> bool:
	await _frames(20)
	_game.run.damage(99999.0, "test")
	for i in 120:
		await physics_frame
		if _game.flow.state_name() == "dead":
			_game._screen_key(KEY_C)
			return await _settle_select(label)
	_t.check("%s run ends after damage" % label, false, _game.flow.state_name())
	return false


func _achievements() -> void:
	var profile = _game.ctx.profile
	var pilot_rows: Array = Achievements.ids().filter(func(id): return Achievements.reward_of(id).has("pilot"))
	pilot_rows.sort()
	var want: Array = PILOT_ROWS_IN_ORDER.duplicate()
	want.sort()
	_t.eq("A every pilot-reward row is in the sequence", pilot_rows, want)
	for id in PILOT_ROWS_IN_ORDER:
		_t.check("A %s earned" % id, profile.earned(id), id)
		_t.eq("A %s announced once" % id, _earned.count(id), 1)
	_t.eq("A pilot rows announced in game order", _earned.filter(func(id): return PILOT_ROWS_IN_ORDER.has(id)), PILOT_ROWS_IN_ORDER)
	var reloaded := Profile.new(profile.path)
	reloaded.load_profile()
	_t.check("A pilot rows earned on disk", PILOT_ROWS_IN_ORDER.all(func(id): return reloaded.earned(id)), str(PILOT_ROWS_IN_ORDER))
	_t.eq("A three leaves returned", _game.progress.leaves_returned(), Progress.LEDGER_WORLDS)


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
