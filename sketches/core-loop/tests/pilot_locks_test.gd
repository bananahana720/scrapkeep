extends SceneTree

const Game := preload("res://src/game.gd")
const Profile := preload("res://src/core/profile.gd")
const Progress := preload("res://src/core/progress.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Achievements := preload("res://src/core/achievements.gd")
const ClassCard := preload("res://src/ui/class_card.gd")
const CampMenu := preload("res://src/ui/camp_menu.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const T := preload("res://tests/support/t.gd")

# Pilot locks (ruling P-R21). GP5-1: a fresh profile opens Sable only, and each unlock event,
# sent on the real bus in turn, opens its pilot and no other. GP5-2: the v2 fixture (Rivet and
# Kest free, Brindle routed) loads with Sable, Rivet, Kest and Tarn open and keeps them through
# save and reload. GP5-3: every class row's unlock label is 1 to 9 words, its rule names the
# achievement that rewards that pilot, and a locked pilot's camp line and card show it.
# GP5-4: the bot's --pilot pick runs a locked pilot on a fresh profile (flow.choose_class).
# GP5-5 (Andrew's "Either path", 2026-10-17): Tally opens on the sky-islands rescue or on three
# ledger leaves, whichever comes first; the other path still earns its row and opens no one else.

const NOW := 1700000000.0
const V2_FIXTURE := "res://tests/fixtures/profile_v2_rivet_kest.json"
const SABLE := "pylon_engineer"
const RIVET := "runner_gunner"
const KEST := "demolitions_caster"
const TARN := "tarn"
const TALLY := "tally"
const CANNON := "remembered_cannon"
const STEPS := [
	["rivet_rescue", RIVET],
	["dig_rescue", KEST],
	["brindle_routed", TARN],
	["third_leaf", TALLY],
	["mind_quieted", CANNON],
]

var _t := T.new("pilot_locks_test")
var _game


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_game.ctx.calm = true
	_gp5_3_labels()
	_gp5_4_bot_pick()
	# Isolate the bus-driven unlock sequences from the Game's own Progress listener (which shares _game.run).
	if _game.progress != null:
		_game.progress.free()
		_game.progress = null
		_game.ctx.progress = null
	_gp5_1_sequence()
	_gp5_2_v2_fixture()
	_gp5_5_either_path()
	_game.queue_free()
	quit(_t.verdict())
	return true


func _open(profile) -> Array:
	var out: Array = []
	for def in ClassDef.all():
		if def.starter or profile.has_pilot(def.id):
			out.append(def.id)
	return out


func _progress(profile) -> Progress:
	var progress := Progress.new()
	_game.add_child(progress)
	progress.setup(_game.events, _game.run, profile, func(): return NOW)
	return progress


func _emit(step: String) -> void:
	var events = _game.events
	match step:
		"rivet_rescue":
			events.world_entered.emit(1)
			events.rescue_completed.emit("rivet")
		"dig_rescue":
			events.world_entered.emit(2)
			events.rescue_completed.emit("dig")
		"brindle_routed":
			events.world_entered.emit(1)
			events.enemy_killed.emit("brindle", Vector3.ZERO, 0)
		"isles_rescue":
			events.world_entered.emit(3)
			events.rescue_completed.emit("isles")
		"third_leaf":
			for i in 3:
				events.world_fact.emit(Progress.LEDGER_FACT, Vector3.ZERO)
		"mind_quieted":
			events.world_entered.emit(3)
			events.boss_defeated.emit()


func _gp5_1_sequence() -> void:
	_t.eq("GP5-1 the game's fresh profile opens Sable only",
		_game.flow.classes.filter(func(d): return _game.pilot_unlocked(d)).map(func(d): return d.id), [SABLE])
	var profile := Profile.new("%s/pilot_locks_fresh.json" % _game.storage_dir)
	_t.check("GP5-1 fresh profile loads", profile.load_profile(), profile.last_error)
	var progress := _progress(profile)
	_t.eq("GP5-1 fresh profile has exactly Sable", _open(profile), [SABLE])
	_game.run.begin(ClassDef.all()[0])
	var want: Array = [SABLE]
	for step in STEPS:
		_emit(step[0])
		want.append(step[1])
		var ordered: Array = ClassDef.all().map(func(d): return d.id).filter(func(id): return want.has(id))
		_t.eq("GP5-1 %s opens %s and no other" % step, _open(profile), ordered)
	var reloaded := Profile.new(profile.path)
	reloaded.load_profile()
	_t.eq("GP5-1 the saved file holds all six", _open(reloaded), ClassDef.all().map(func(d): return d.id))
	progress.queue_free()


func _gp5_2_v2_fixture() -> void:
	var path := "%s/pilot_locks_v2.json" % _game.storage_dir
	var original := FileAccess.get_file_as_bytes(V2_FIXTURE)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(original)
	f.close()
	var want := [SABLE, RIVET, KEST, TARN]
	var profile := Profile.new(path)
	_t.check("GP5-2 v2 fixture loads", profile.load_profile(), profile.last_error)
	_t.eq("GP5-2 the migration keeps the v2 free pilots", _open(profile), [SABLE, RIVET, KEST])
	var progress := _progress(profile)
	_t.eq("GP5-2 v2 fixture opens Sable, Rivet, Kest and Tarn", _open(profile), want)
	_t.check("GP5-2 setup saved the opened pilots", FileAccess.file_exists(path + ".v2") and FileAccess.get_file_as_bytes(path + ".v2") == original, "backup %s" % (path + ".v2"))
	var saved = JSON.parse_string(FileAccess.get_file_as_string(path))
	# Re-pinned 2026-10-10 (w13 B5, CUSTOMIZE.md section 5): schema 4; the v2 fixture chains v2 to v3 to v4.
	_t.check("GP5-2 file is schema 4, unknown key and last pilot kept", saved is Dictionary and saved.get("schema") == Profile.SCHEMA and Profile.SCHEMA == 4
		and saved.get("kept_from_a_tool", {}).get("note") == "unknown keys ride through" and saved.get("last_pilot") == RIVET, str(saved))
	var again := Profile.new(path)
	again.load_profile()
	_t.eq("GP5-2 reload keeps them", _open(again), want)
	_t.check("GP5-2 resave", again.save(), again.last_error)
	var third := Profile.new(path)
	third.load_profile()
	_t.eq("GP5-2 round trip keeps them", _open(third), want)
	_t.check("GP5-2 achievements, cosmetics and equipped kept", third.earned("brindle_routed") and third.has_cosmetic("paint_any_night")
		and third.equipped(RIVET, "paint") == "paint_rivet_forge", "")
	progress.queue_free()


func _gp5_3_labels() -> void:
	var starts := 0
	for def in ClassDef.all():
		var by := String(def.unlock.get("by", ""))
		var label := String(def.unlock.get("label", ""))
		var words := label.split(" ", false).size()
		_t.check("GP5-3 %s label is 1 to %d words" % [def.id, ClassDef.UNLOCK_LABEL_WORDS], words >= 1 and words <= ClassDef.UNLOCK_LABEL_WORDS, "\"%s\" (%d)" % [label, words])
		_t.check("GP5-3 %s by is a known rule" % def.id, ClassDef.UNLOCK_BYS.has(by), by)
		_t.eq("GP5-3 %s starter follows by" % def.id, def.starter, by == "start")
		if by == "start":
			starts += 1
			continue
		var row := ClassDef.unlock_row(by)
		_t.eq("GP5-3 %s rule's row rewards this pilot" % def.id, Achievements.reward_of(row).get("pilot", ""), def.id)
		if def.unlock.has("or"):
			var other := String(def.unlock["or"])
			_t.check("GP5-3 %s or is a known rule with a row" % def.id, ClassDef.UNLOCK_BYS.has(other) and Achievements.ROWS.has(ClassDef.unlock_row(other)), other)
		_t.check("GP5-3 %s card hint leads with the label" % def.id, ClassCard.unlock_hint(def, _game.progress).begins_with(label), ClassCard.unlock_hint(def, _game.progress))
	_t.eq("GP5-3 one pilot starts open", starts, 1)
	var read: Dictionary = CampMenu.reading(_game)
	for p in read["pilots"]:
		if p["ready"]:
			continue
		var def = ClassDef.by_id(p["id"])
		var line := "%s is locked. %s" % [p["name"], ClassCard.unlock_hint(def, _game.progress)]
		_t.check("GP5-3 camp shows %s's label" % p["id"], (read["lines"] as PackedStringArray).has(line) and line.contains(String(def.unlock["label"])), line)


func _gp5_5_either_path() -> void:
	for order in [["isles_rescue", "third_leaf"], ["third_leaf", "isles_rescue"]]:
		var profile := Profile.new("%s/pilot_locks_%s.json" % [_game.storage_dir, order[0]])
		profile.load_profile()
		var progress := _progress(profile)
		_game.run.begin(ClassDef.all()[0])
		_emit(order[0])
		_t.eq("GP5-5 %s first opens Tally and no other" % order[0], _open(profile), [SABLE, TALLY])
		_emit(order[1])
		_t.eq("GP5-5 %s second keeps Tally and opens no other" % order[1], _open(profile), [SABLE, TALLY])
		_t.check("GP5-5 both rows earned after %s then %s" % order, profile.earned("isles_rescued") and profile.earned(ClassDef.unlock_row("leaves:3")), "")
		var reloaded := Profile.new(profile.path)
		reloaded.load_profile()
		_t.eq("GP5-5 the saved file keeps Tally (%s first)" % order[0], _open(reloaded), [SABLE, TALLY])
		progress.queue_free()


func _gp5_4_bot_pick() -> void:
	var index := BotDriver.class_index_for(11, CANNON)
	var def = _game.flow.classes[index]
	_t.check("GP5-4 the cannon is locked on the game's fresh profile", def.id == CANNON and not _game.pilot_unlocked(def), def.id)
	_game.flow.open_class_select()
	_game.flow.choose_class(index)
	_t.check("GP5-4 the bot's pick starts the locked cannon", _game.flow.in_play() and _game.run.class_def.id == CANNON, _game.flow.state_name())
