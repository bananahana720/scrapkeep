extends SceneTree

# 2026-10-11 (PC-KEST): real router, line payload, preview, tree and earned grants.
# Expected count includes the final count assertion; an incomplete case run fails.
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const Cosmetics := preload("res://src/core/cosmetics.gd")
const Achievements := preload("res://src/core/achievements.gd")
const Profile := preload("res://src/core/profile.gd")
const Progress := preload("res://src/core/progress.gd")
const Events := preload("res://src/core/game_events.gd")
const Codex := preload("res://src/core/codex.gd")
const CodexEntries := preload("res://src/combat/codex_entries.gd")
const T := preload("res://tests/support/t.gd")
const DT := 1.0 / 60.0
const EXPECTED_CHECKS := 60

var _t
var _game
var _player
var _combat
var _ult
var _source := Intent.Scripted.new()
var _rockets: Array = []
var _blasts: Array = []
var _ends: Array = []
var _card_events: Array = []


func _initialize() -> void:
	_t = T.new(get_script().resource_path.get_file().get_basename())
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _expected() -> int:
	return EXPECTED_CHECKS


func _never() -> bool:
	return false


func _enemy(at: Vector3, kind := "chaser") -> Node3D:
	var enemy: Node3D = _combat.spawn_enemy(kind, at)
	enemy.live = _never
	enemy.set_physics_process(false)
	if kind == "chaser":
		enemy.hp = 100000.0
		enemy.plating = 0.0
	return enemy


func _tick(fields := {}, dt := DT) -> void:
	_player.intent.clear()
	for key in fields:
		_player.intent.set(key, fields[key])
	_player._route_slots(dt)
	_combat._step_special(_player.intent, dt)
	_combat._step_line(_player.intent, dt)


func _cast() -> void:
	_tick({"slot_pick": 2, "fire_pressed": true, "fire_held": true})
	_tick({"fire_released": true})


func _flush_cards(frames := 3) -> void:
	for i in frames:
		await physics_frame
		_ult.flush_discoveries()


func _fresh() -> void:
	_ult._abort("stage")
	_ult.clear_payloads()
	_ult._id = ""
	_combat.sticky.clear()
	_player.kit.drop_line("reset")
	_player.kit.line_end = ""
	_player.kit.rewind_left = 0.0
	_player.chain.reset()
	_player.abilities.fit(ClassDef.by_id("demolitions_caster"))
	_player.tree.reset("demolitions_caster")
	_player.abilities.refill()
	_player.abilities.selected = "weapon"
	_player._fire_latched = false
	_combat._line_load = {}
	_combat._bite_pending = false
	_combat.last_line = {}
	_combat.cloak_left = 0.0
	_combat._rocket_left = 0.0
	_rockets.clear()
	_blasts.clear()
	_ends.clear()
	_player.intent.clear()


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_player = _game.player
	_player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(2)
	for i in 30:
		await physics_frame
	_combat = _game.combat
	_ult = _combat.ultimate
	_player.set_physics_process(false)
	_combat.set_physics_process(false)
	_ult.set_physics_process(false)
	_game.events.rocket_jumped.connect(func(at: Vector3, speed: float): _rockets.append([at, speed]))
	_game.events.sticky_detonated.connect(func(at: Vector3, crit: bool): _blasts.append([at, crit]))
	_game.events.synergy_discovered.connect(func(id: String, _category: String, _first: bool):
		_card_events.append([id, Engine.get_physics_frames()]))
	_game.events.line_state_changed.connect(func(state: String, _body: Node3D, _at: Vector3, _cause: String):
		if state == "chain_ended":
			_ends.append(state))
	await _cases()
	_t.eq("expected check count", _t.checks + 1, _expected())
	_game.free()
	quit(_t.verdict())


func _cases() -> void:
	_fresh()
	_t.eq("Kest has Cable Charge on 3 and Windhover on Q", [_player.abilities.id_of("line"), _player.abilities.ultimate_id], ["cable_charge", "windhover"])
	var lane: Dictionary = _combat._line_geometry(1.0)
	var from: Vector3 = lane["from"]
	var dir: Vector3 = (lane["to"] - from).normalized()
	var inside: Array = []
	for distance in [3.0, 7.0]:
		inside.append(_combat.sticky.drop(from + dir * distance, 1.0, 0.2, 10.0, INF))
	var outside: Dictionary = _combat.sticky.drop(from + Vector3(-dir.z, 0.0, dir.x) * 5.0, 1.0, 0.2, 10.0, INF)
	_tick({"slot_pick": 1, "fire_pressed": true, "fire_held": true})
	_tick({"fire_held": true}, 0.783333333)
	lane = _combat._line_geometry(1.0)
	_t.eq("held preview catches exactly two charges", lane["caught"].size(), 2)
	_t.eq("caught charge positions are the preview ticks", _player.indicator.shapes["kest_caught"]["points"], lane["caught"])
	_t.near("preview reads x1.5 before release", lane["bonus"], 1.5)
	_tick({"fire_released": true})
	_t.eq("release catches exactly the drawn two", _combat.last_burst["caught"], 2)
	_t.check("outside charge survives", _combat.sticky.charges.size() == 1 and _combat.sticky.charges.has(outside))
	_t.eq("caught blasts happen before the lane", _blasts.size(), 2)
	_t.near("full detonation lane pays 30 x 1.5", _combat.last_burst["damage"], 45.0)
	_t.eq("slot 2 snaps home on cast", _player.abilities.selected, "weapon")

	_fresh()
	var body := _enemy(_player.ball_position() + Vector3.RIGHT * 30.0)
	_player.grapple_to(body.global_position, Vector3.UP, body)
	_player.chain.combo = 3
	_cast()
	_t.near("30 m cable takes 0.5 s", _ult.cable["_duration"], 0.5)
	await _flush_cards()
	_t.check("direct Cable Charge opens its card", _game.ctx.codex.known("kest_cable_charge"))
	_t.check("cable is inert in travel", not _ult.cable.get("_set", false) and is_inf(_ult.cable["arm"]))
	_ult._step_payloads(0.49)
	_t.check("charge is still travelling at 0.49 s", not _ult.cable.get("_set", false))
	_ult._step_payloads(0.01)
	_t.check("charge sets at 0.50 s", _ult.cable.get("_set", false))
	_t.near("combo 3 snapshots 28 x 1.6", _ult.cable["damage"], 44.8)
	_t.check("body charge rides its target", _ult.cable["rider"] == body)
	_player.chain.combo = 6
	_t.near("later combo does not change the stored blast", _ult.cable["damage"], 44.8)
	_player.kit.drop_line("let_go")
	_ult._step_payloads(DT)
	_t.eq("line end detonates in its tick", _blasts.size(), 1)
	_t.check("line end removes the charge once", _ult.cable.is_empty() and _ult.payloads.charges.is_empty())
	body.free()

	_fresh()
	body = _enemy(_player.ball_position() + Vector3.RIGHT * 1.0)
	_player.grapple_to(body.global_position, Vector3.UP, body)
	_cast()
	_ult._step_payloads(1.0 / 60.0)
	for i in 118:
		_ult._step_payloads(DT)
	_t.eq("body fuse has not fired before 2 seconds", _blasts.size(), 0)
	_ult._step_payloads(2 * DT)
	_t.eq("body fuse detonates at 2 seconds within one tick", _blasts.size(), 1)
	body.free()

	_fresh()
	var wall: Vector3 = _player.ball_position() + Vector3.RIGHT * 3.0
	_player.grapple_to(wall, Vector3.LEFT, null)
	_cast()
	_ult._step_payloads(0.05)
	_player.intent.jump_held = true
	_player.kit.drop_line("let_go")
	_ult._step_payloads(DT)
	_t.eq("wall let-go blasts once", _blasts.size(), 1)
	_t.check("Space at 3 m emits rocket jump 22 to 30", _rockets.size() == 1 and _rockets[0][1] >= 22.0 and _rockets[0][1] <= 30.0)
	await _flush_cards()
	_t.check("Blast Vault discovery fired from this blast", _game.ctx.codex.known("kest_blast_vault"))

	_fresh()
	wall = _player.ball_position() + Vector3.RIGHT
	_player.grapple_to(wall, Vector3.LEFT, null)
	_cast()
	_ult._step_payloads(DT)
	body = _enemy(wall)
	_ult._step_payloads(5.9)
	_t.eq("wall charge ignores touching enemies", _blasts.size(), 0)
	_ult._step_payloads(0.11)
	_t.eq("wall fuse goes off at 6 seconds", _blasts.size(), 1)
	body.free()

	_fresh()
	_combat.discovered.erase("kest_cable_charge")
	_combat.discovered.erase("loaded_line")
	_game.ctx.codex._run_seen.erase("kest_cable_charge")
	_game.ctx.codex._run_seen.erase("loaded_line")
	_card_events.clear()
	_cast()
	_t.eq("unhooked cast loads Cable Charge", _combat.line_load()["id"], "cable_charge")
	_tick({}, 3.85)
	body = _enemy(_player.ball_position() + Vector3.RIGHT * 30.0)
	_player.grapple_to(body.global_position, Vector3.UP, body)
	_tick()
	_t.eq("bite at 3.9 seconds fires onto the body", _combat.last_line["on"], "body")
	_t.check("a loaded bite sets on arrival without travel", _ult.cable.get("_set", false) and _ult.cable["_duration"] == 0.0)
	_t.check("loaded bite opens the framework card first", _game.ctx.codex.known("loaded_line"))
	await _flush_cards()
	var cards: Array = _card_events.filter(func(c): return c[0] in ["loaded_line", "kest_cable_charge"])
	_t.check("framework and pilot cards occupy different physics frames", cards.size() == 2 and cards[0][0] == "loaded_line"
		and cards[1][0] == "kest_cable_charge" and cards[1][1] > cards[0][1], "cards %s" % [cards])
	body.free()
	_fresh()
	_cast()
	_tick({}, 4.1)
	_t.check("bite at 4.1 seconds has no load", _combat.line_load().is_empty())
	body = _enemy(_player.ball_position() + Vector3.RIGHT)
	_player.grapple_to(body.global_position, Vector3.UP, body)
	_tick()
	_t.check("expired load places no charge", _ult.cable.is_empty())
	body.free()

	_fresh()
	wall = _player.ball_position() + Vector3.RIGHT
	_player.grapple_to(wall, Vector3.LEFT, null)
	_cast()
	_ult._step_payloads(DT)
	_player.cut_line("cutter")
	_ult._step_payloads(DT)
	_t.eq("cut line pays one blast", _blasts.size(), 1)
	_fresh()
	body = _enemy(_player.ball_position() + Vector3.RIGHT)
	_player.grapple_to(body.global_position, Vector3.UP, body)
	_player.chain.combo = 3
	_cast()
	_ult._step_payloads(DT)
	var paid: float = _player.pay_chain(body.global_position)
	_game.events.harpoon_smashed.emit(body, body.global_position, 30.0)
	_t.near("haul smash pays combo 3 once", paid, 1.6)
	_t.eq("haul smash and charge blast share a tick", _blasts.size(), 1)
	_t.eq("charge never pays the chain a second time", _player.chain.combo, 0)
	body.free()

	_tree_cases()
	_grants()


func _tree_cases() -> void:
	_t.eq("Kest tree is structurally sound", UpgradeTree.problems("demolitions_caster"), [])
	var nodes: Array = UpgradeTree.nodes("demolitions_caster")
	var variants := ["minelayer", "air_raid", "minelayer", "air_raid", "air_raid", "minelayer", "minelayer", "air_raid"]
	for i in 8:
		var n: Dictionary = nodes[i + 6]
		var a := AbilityState.new()
		a.fit(ClassDef.by_id("demolitions_caster"))
		UpgradeTree.apply_pick(a, n)
		_t.eq("depth 3 swap " + n["id"], a.ultimate_id, variants[i])
	var knobs := ["ult_beats", "ult_volley", "ult_radius", "ult_beats", "ult_radius", "ult_encore", "ult_encore", "ult_radius",
		"ult_volley", "ult_beats", "ult_volley", "ult_encore", "ult_radius", "ult_beats", "ult_volley", "ult_encore"]
	var all_knobs := true
	for i in 16:
		all_knobs = all_knobs and nodes[i + 14].get("knob", {}).has(knobs[i])
	_t.check("all sixteen depth 4 nodes add their specified knob", all_knobs)
	# These are pilot-tree ops; the unit adds no stacking PartDef or shared movement row.
	var shared_movement := false
	for n in nodes.slice(6):
		shared_movement = shared_movement or n.get("class_id", "demolitions_caster") == ""
	_t.check("every new movement op stays in Kest's tree", not shared_movement)


func _grants() -> void:
	var pilots: Array = ClassDef.all().map(func(p): return p.id)
	_t.eq("new cosmetic tints and rows validate", Cosmetics.validate(Cosmetics.ROWS, pilots), [])
	var serial := 0
	while FileAccess.file_exists("user://pc-kest-grants-%d-%d.json" % [OS.get_process_id(), serial]):
		serial += 1
	var stamp := "%d-%d" % [OS.get_process_id(), serial]
	var profile := Profile.new("user://pc-kest-grants-%s.json" % stamp)
	profile.load_profile()
	var events := Events.new()
	var run = load("res://src/core/run_state.gd").new()
	var codex := Codex.new()
	root.add_child(codex)
	codex.setup(events, run, null, "user://pc-kest-codex-%s" % stamp)
	for entry in CodexEntries.all():
		codex.declare(entry)
	var progress := Progress.new()
	root.add_child(progress)
	progress.setup(events, run, profile, Callable(), codex)
	var ids := ["kest_blast_vault", "kest_homecoming", "kest_tick_tick_boom"]
	var items := ["trail_kest_fuse_smoke", "outfit_kest_rigger", "shell_kest_roost"]
	for i in 3:
		_t.check("item starts locked " + items[i], not profile.has_cosmetic(items[i]))
		codex.mark_discovered(ids[i])
		codex.mark_discovered(ids[i])
		_t.check("discovery grants once " + items[i], profile.has_cosmetic(items[i]) and profile.earned("ach_" + ids[i]))
	var again := Profile.new(profile.path)
	_t.check("earned items reload from the saved profile", again.load_profile() and items.all(func(id): return again.has_cosmetic(id)))
	_t.check("grants do not require a first-ever discovery", ids.all(func(id): return not Achievements.ROWS["ach_" + id].get("where", {}).has("first_time")))
	_t.check("undelivered trail and outfit are pending art", items.slice(0, 2).all(func(id): return Cosmetics.PENDING_ART.has(id)))
	_t.check("delivered Roost Frame is live", not Cosmetics.is_pending("shell_kest_roost") and FileAccess.file_exists("res://assets/models/world_one/shell_kest_roost.glb"))
	progress.free()
	codex.free()
	events.free()
