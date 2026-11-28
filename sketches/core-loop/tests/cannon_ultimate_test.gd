extends SceneTree
# 2026-10-11 (PC-CANNON): landing snapshots must include the zones for roster damage comparison.
# EXPECTED_CHECKS includes the count guard. Every check must run.
const EXPECTED_CHECKS := 48
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const Augments := preload("res://src/movement/augments.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const MindAttacks := preload("res://src/boss/mind_attacks.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")
const T := preload("res://tests/support/t.gd")
const DT := 1.0 / 60.0
const HOME := Vector3(0.0, 101.5, 0.0)
var _t := T.new("cannon_ultimate_test")
var _game
var _combat
var _player
var _ult
var _landed: Array = []
var _live: Dictionary = {}
var _strikes: Array = []
var _body


func _initialize() -> void:
	_run.call_deferred()


func _expected_checks() -> int:
	return EXPECTED_CHECKS


func _run() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await physics_frame
	_combat = _game.combat
	_player = _game.player
	_ult = _combat.ultimate
	_player.source = Intent.Scripted.new()
	_game.run.class_def = ClassDef.by_id("remembered_cannon")
	_player.fit_class(_game.run.class_def)
	_player.set_physics_process(false)
	_combat.set_physics_process(false)
	_ult.set_physics_process(false)
	_body = _player.body()
	_body.freeze = true
	var ground := StaticBody3D.new()
	ground.collision_layer = Augments.WORLD_MASK
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(120.0, 1.0, 120.0)
	collider.shape = box
	ground.add_child(collider)
	root.add_child(ground)
	ground.position = Vector3(0.0, 100.0, 0.0)
	await physics_frame
	_game.events.ultimate_landed.connect(func(id: String, at: Vector3, hits: int, damage: float): _landed.append([id, at, hits, damage, _combat._clock]))
	_game.events.enemy_struck.connect(func(enemy: Node3D, kind: String, force: float): _strikes.append([enemy, kind, force]))
	_ult.beat_seconds = func() -> float: return float(Harmony.BEAT) / Harmony.RATE
	await _cases()
	_t.eq("exact expected check count", _t.checks + 1, _expected_checks())
	quit(_t.verdict())


func _reset(id := "cannon_fire_mission") -> void:
	_ult._abort("stage")
	_combat.cannon.free_cannon()
	_combat._exposed.clear()
	for enemy in get_nodes_in_group("enemy"):
		enemy.remove_from_group("enemy")
		enemy.queue_free()
	_player.kit.drop_line()
	_player.chain.reset()
	_player.intent.clear()
	_player.abilities.refill()
	_player.abilities.ultimate_id = id
	_player.tree._knobs.clear()
	_body.global_position = HOME
	_player.state.velocity = Vector3.ZERO
	_ult.rail_query = Callable()
	_ult._beat = 0
	_ult.meter.locked = false
	_ult.meter.refund(100.0)
	_landed.clear()
	_live.clear()
	_strikes.clear()
	await physics_frame


func _aim(point: Vector3) -> Dictionary:
	var origin := HOME + Vector3.UP
	return {"origin": origin, "forward": (point - origin).normalized(), "harpoon": {"state": Augments.AIM_NONE}}


func _enemy(at: Vector3, kind := "chaser") -> Node3D:
	var enemy: Node3D = _combat.spawn_enemy(kind, at)
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	if "hp" in enemy:
		enemy.hp = 100000.0
		enemy.max_hp = 100000.0
	return enemy


# Drive the real carrier, calls, containment and strike code with one explicit clock.
# Physics queries use the fixture floor; bots below prove ordinary frame/input execution.
func _tick() -> void:
	_combat._clock += DT
	_ult.step(DT)
	if _ult._ride != null:
		_body.global_position = _ult._ride.point_at(_ult._ride.time)
	for entry in _combat.cannon._cannon:
		for h in entry["hazards"]:
			if not _live.has(h.get_instance_id()) and _combat._clock >= float(entry["options"].get("live_at", INF)):
				_live[h.get_instance_id()] = _combat._clock
	_combat.cannon.step_cannon(DT)


func _finish_ride() -> void:
	for i in 400:
		_tick()
		if _ult.phase() == "idle":
			return


func _cases() -> void:
	await _reset()
	_t.eq("Cannon's own line", _player.abilities.id_of(AbilityState.LINE), "cannon_lane_charge")
	_t.eq("Cannon's own ultimate", _player.abilities.ultimate_id, "cannon_fire_mission")
	var slots: Array = _player.abilities.slots()
	_t.eq("bar slot 3 names Lane Charge", slots.filter(func(s): return s["id"] == "cannon_lane_charge")[0]["number"], 3)
	_t.eq("Q resolves the Cannon icon", _player.abilities.ultimate()["icon"], "ab_cannon_ult")
	_player.kit.hooked = true
	_player.kit.anchor = HOME + Vector3.RIGHT * 10.0
	var target := Vector3(20.0, 100.5, 0.0)
	var p: Dictionary = _ult.plan(HOME, _aim(target))
	_t.eq("arc wins even with a standing line", p["path"], "arc")
	var sky := {"origin": HOME, "forward": Vector3.UP, "harpoon": {"state": Augments.AIM_NONE}}
	_t.eq("line fallback when the aimed floor is absent", _ult.plan(HOME, sky)["path"], "line")
	_player.kit.hooked = false
	_ult.rail_query = func(at: Vector3) -> Dictionary: return {"entry": at, "to": target}
	_t.eq("rail fallback", _ult.plan(HOME, sky)["path"], "rail")
	_ult.rail_query = Callable()
	_t.eq("hop fallback", _ult.plan(HOME, sky)["path"], "hop")
	_ult.start(_ult.plan(HOME, sky))
	_t.eq("full Q always starts", _ult.phase(), "windup")
	_ult.recall()
	_t.check("windup recall refunds in full", _ult.meter.full())

	await _reset()
	p["beats"] = 7
	p["flight"] = 7.0 * float(Harmony.BEAT) / Harmony.RATE
	p["seconds"] = _ult.WINDUP_SECONDS + p["flight"]
	p["legs"][0]["beats"] = 7
	p["legs"][0]["seconds"] = p["flight"]
	var foe := _enemy(target + Vector3.UP)
	_t.eq("sky reticle rejects the ground target", _ult._cannon_target(HOME, Vector3.UP, 26.0), HOME)
	_t.eq("pitched reticle selects its target", _ult._cannon_target(HOME, (foe.global_position - HOME).normalized(), 26.0), foe.global_position)
	_ult.start(p)
	_game.presentation.audio.engine.mode = _game.presentation.audio.engine.PLAY
	_game.presentation.audio.engine.render(Harmony.BEAT / 2 + 111)
	_game.presentation.audio._ult_armed = true
	_finish_ride()
	_t.eq("one landing", _landed.size(), 1)
	var calls: int = _ult._cannon_calls
	_t.check("seven beats make nine calls under the cap", calls == 9 and calls <= Weapons.CALL_CAP, str(calls))
	var audio = _game.presentation.audio
	var notes: Array = audio.cannon_log.filter(func(row): return row["kind"] == "cannon_call").map(func(row): return row["notes"][0])
	_t.eq("first three families in order", notes.slice(0, 3), [59, 64, 67])
	_t.eq("middle beat calls the four families", notes.slice(3, 7), [59, 64, 67, 74])
	_t.check("every called hazard has one shared live time", _live.size() >= calls and _live.values().all(func(at): return absf(float(at) - float(_landed[0][4])) <= DT + 0.0001), str([_live.values(), _landed]))
	_t.check("zone run-log fields", _ult.record().has("zones") and _ult.record().has("zone_hits") and _ult.record()["zone_hits"] > 0 and _ult.record()["zone_hits"] <= _ult.record()["zones"], str(_ult.record()))
	var logged: Dictionary = _game.run_log._record["ultimates"].back()
	_t.eq("landing snapshot includes zone hits", logged.get("zone_hits", 0), _ult.record()["zone_hits"])
	_t.near("landing snapshot includes zone damage", float(logged["damage"]), float(_ult.record()["damage"]), 0.01)
	var chord: Array = audio.cannon_log.filter(func(row): return row["kind"] == "cannon_landing")
	_t.eq("landing chord is all four motif notes", chord.back()["notes"], [59, 64, 67, 74])
	_t.check("landing is one chord", chord.back()["chord"])
	var drop: Array = audio.drop_log.back()
	_t.check("the music drop shares touchdown within one tick", absf(float(drop[1] - drop[0])) <= float(Harmony.RATE) / Engine.physics_ticks_per_second, str(drop))
	audio.engine.render(64)
	_t.check("the engine plays the touchdown drop", audio.engine.in_drop() and not audio.engine.building())

	await _reset()
	_ult.start(p)
	while _ult._beat < 2:
		_tick()
	var scheduled: float = _ult._cannon_due
	_ult.bail()
	_t.eq("bail does not land", _landed.size(), 0)
	_t.check("bail keeps committed calls", not _combat.cannon._cannon.is_empty())
	for i in 200:
		_tick()
	_t.check("bailed calls keep the original beat", not _live.is_empty() and _live.values().all(func(at): return absf(float(at) - scheduled) <= DT), str(_live))

	await _reset()
	_ult.start(p)
	while _ult._beat < 2:
		_tick()
	scheduled = _ult._cannon_due
	_ult._land(HOME)
	_t.eq("collision lands early once", _landed.size(), 1)
	for i in 200:
		_tick()
	_t.check("collision keeps the zone schedule", _live.values().all(func(at): return absf(float(at) - scheduled) <= DT), str(_live))

	await _reset()
	_ult.start(p)
	_ult._cannon_peak_done = true
	_t.check("void call refused", not _ult._cannon_call("lane", Vector3(300.0, 100.5, 300.0), target, _combat._clock + 1.0, 1.0))
	_t.check("floor beyond twelve metres refused", not _ult._cannon_call("lane", HOME + Vector3.UP * 30.0, target, _combat._clock + 1.0, 1.0))
	_t.eq("void never consumes the cap", _ult._cannon_calls, 0)
	var carrier = _ult._carrier(HOME, {"mode": "arc", "to": HOME + Vector3.RIGHT * 50.0, "seconds": 4.0})
	_t.near("apex never exceeds twenty metres", carrier.point_at(2.0).y - HOME.y, Weapons.APEX_CAP)
	_ult.recall()

	await _reset()
	var w := _enemy(target + Vector3.UP, "warden")
	var budget := {}
	for i in 20:
		_combat.cannon_set_piece_hit(w, 100.0, HOME, i == 19, false, budget)
	_t.check("one set piece adds at most the Warden posture cap", float(budget.get(w.get_instance_id(), 0.0)) <= preload("res://src/combat/ultimate.gd").warden_cap(w.monster_build()) and w.posture() > 0.0, str(budget))
	_t.eq("closed guard loses no chunk", w.chunks_left(), 4)
	w._apply_posture({"gain": 100.0, "contact": false})
	_t.check("core fixture is open", w.staggered())
	await physics_frame
	_combat.cannon_set_piece_hit(w, 60.0, HOME, true, false, budget)
	_t.eq("landing shatters the open core", w.chunks_left(), 3)

	await _reset()
	foe = _enemy(target + Vector3.UP)
	var hp: float = foe.hp
	_combat.cannon_set_piece_hit(foe, 60.0, HOME, true, false, {})
	var class_one: float = hp - foe.hp
	hp = foe.hp
	_combat.cannon_set_piece_hit(foe, 60.0 * 1.6, HOME, true, false, {})
	_t.near("class V damage follows the heft table", (hp - foe.hp) / class_one, 1.6, 0.001)
	foe.kind = "mind_fixture"
	_t.near("boss takes half set-piece damage", _combat.cannon_set_piece_hit(foe, 60.0, HOME, true, false, {}), 30.0)
	_combat.cannon_expose(foe, 2.5, "ram")
	_t.check("exposure has a visible mark", foe.has_node("CannonExposure"))
	_combat._clock += 2.499
	_combat.step_cannon_exposure()
	_t.check("mark lasts the full exposure window", _combat._exposed.has(foe.get_instance_id()))
	_combat._clock += 0.0011
	_combat.step_cannon_exposure()
	_t.check("mark ends at the window", not _combat._exposed.has(foe.get_instance_id()))
	_t.eq("Recital starts at lane", _combat.cannon._recital_index, 0)
	for family in MindAttacks.FAMILIES:
		_combat.cannon._cannon_recital(family, target)
	_t.check("ordered family hits discover Recital", _combat.discovered.has("cannon_recital"))
	_t.eq("Recital resets after its completion", _combat.cannon._recital_index, 0)
	var node_ids: Array = UpgradeTree.nodes("remembered_cannon").map(func(node): return node["id"])
	_t.check("movement ops stay in the Cannon tree", node_ids.size() == 30 and node_ids.all(func(id): return String(id).begins_with("c_")))
	_t.check("no Cannon movement node enters another pilot tree", UpgradeTree.TREES.keys().all(func(id): return id == "remembered_cannon" or UpgradeTree.nodes(id).all(func(node): return not node_ids.has(node["id"]))))
