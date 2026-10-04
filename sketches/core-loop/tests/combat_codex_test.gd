extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const CodexEntries := preload("res://src/combat/codex_entries.gd")

# Combat's "enemy" codex entries: complete as data (id, category, name, hint, clue,
# text, owner, participants), and each one detected by combat's own code when the
# trick is pulled. Each trick is staged directly on the live game.

const REQUIRED := ["id", "category", "name", "hint", "clue", "text", "owner", "participants"]

var _game
var _combat
var _source := Intent.Scripted.new()
var _failures := 0
var _step := 0
var _clock := 0.0
var _lobber: Node3D
# Set by the last case; a script error that aborts a case leaves it false.
var _last_case_ran := false


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(check: String, ok: bool, detail: String) -> void:
	print("[%s] %s -> %s" % [check, detail, "PASS" if ok else "FAIL"])
	if not ok:
		_failures += 1


func _physics_process(delta: float) -> bool:
	if _game.flow == null:
		return false
	match _step:
		0:
			_setup()
			_data()
			_instant_tricks()
			_w7_tricks()
			_start_shell()
			_step = 1
		1:
			_clock += delta
			if _combat.discovered.has("shell_return") or _clock > 4.0:
				_report("shell_return", _combat.discovered.has("shell_return"),
					"a batted shell landed on its own lobber and killed it (%.2f s after the bat)" % _clock)
				_warden_tricks()
				return _finish()
	return false


func _setup() -> void:
	_combat = _game.ctx.spawner
	_game.ctx.calm = true
	_game.player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(1)
	_game.run.set_max_hp(99999.0)
	_combat.heft_override = 1.0


func _data() -> void:
	var ids := {}
	var complete := true
	for entry in _combat.codex_entries():
		for key in REQUIRED:
			var value = entry.get(key)
			var empty: bool = value == null or (value is String and value == "") or (value is Array and value.is_empty())
			complete = complete and not empty
		complete = complete and entry["category"] == "enemy"
		ids[entry["id"]] = true
	_report("data", complete and ids.size() == CodexEntries.ENTRIES.size() and ids.size() >= 5,
		"%d enemy entries, unique ids, every field filled: %s" % [ids.size(), ids.keys()])


func _chaser(offset: float, hp: float) -> Node3D:
	var ctx = _game.ctx
	var at: Vector3 = ctx.terrain.spawn_point(1) + Vector3(offset, 0.0, 60.0)
	var enemy: Node3D = ctx.spawner.spawn_enemy("chaser", ctx.terrain.drop_point(at.x, at.z, 1.6))
	enemy.hp = hp
	enemy.max_hp = hp
	return enemy


func _instant_tricks() -> void:
	var lunging := _chaser(0.0, 500.0)
	lunging.state = lunging.State.WINDUP
	_combat.strike(lunging, "ram", 14.0)
	_report("counter_ram", _combat.discovered.has("counter_ram"), "a ram on a chaser mid wind-up")

	for i in 3:
		_combat.strike(_chaser(4.0 * (i + 1), 10.0), "ram", 14.0)
	_report("crush_chain", _combat.discovered.has("crush_chain"), "three unplated one-hit ram kills in the same second")

	_game.events.dismounted.emit(Vector3(12.0, 4.0, 0.0))
	_combat.strike(_chaser(-8.0, 5.0), "runner", 10.0)
	_report("parting_shot", _combat.discovered.has("parting_shot"), "a laser kill right after a slingshot dismount")


# v2 W7: each counter's opportunity, found through the unit's own code path.
func _w7_tricks() -> void:
	var ctx = _game.ctx
	var fleet = _combat.fleet
	var base: Vector3 = ctx.terrain.spawn_point(1) + Vector3(20.0, 0.0, 40.0)
	var hooker: Node3D = ctx.spawner.spawn_enemy("hooker", ctx.terrain.drop_point(base.x, base.z, 1.6))
	hooker._catch(0.0, Vector3.ZERO, hooker.anchor())
	fleet.holds.snap(hooker, "speed")
	_report("tether_snap", _combat.discovered.has("tether_snap"), "a tether held, then snapped by speed")

	var dish: Node3D = ctx.spawner.spawn_enemy("deflector", ctx.terrain.drop_point(base.x + 8.0, base.z, 1.6))
	dish.phase = dish.Phase.LIVE
	dish._go_live()
	dish.rebounds = 1
	dish._rebound_v = Vector3(-9.0, 0.0, 0.0)
	dish._window = 0.3
	_game.events.jumped.emit(false)
	_report("shield_vault", _combat.discovered.has("shield_vault") and dish.vaults == 1,
		"a jump in a deflector's rebound window vaulted at %.1f m/s" % dish.last_vault_speed)

	var at: Vector3 = base + Vector3(-12.0, 0.0, 0.0)
	var lead: Node3D = ctx.spawner.spawn_enemy("swarm_remnant", ctx.terrain.drop_point(at.x, at.z, 1.4))
	var victim: Node3D = ctx.spawner.spawn_enemy("chaser", ctx.terrain.drop_point(at.x + 2.5, at.z, 1.6))
	lead.swarm.state = lead.swarm.State.SCATTERED
	lead._lead_into_pin()
	_combat._pin_step(_game.get_tree().get_nodes_in_group("enemy"))
	_report("awaiting_operator", _combat.discovered.has("awaiting_operator"),
		"a scattered drone led into a chaser pinned it (%d pins)" % _combat.pins)

	var hand: Node3D = ctx.spawner.spawn_enemy("mind_hand", ctx.terrain.drop_point(base.x, base.z - 10.0, 1.8))
	fleet.habits.add("ram", 5.0)
	hand._commit(Vector3(0.0, 0.0, 5.0))
	_report("what_it_learned", _combat.discovered.has("what_it_learned") and fleet.mind_memory.size() == 1,
		"a Mind's hand read the ram habit and quoted it: %s" % [fleet.mind_memory])
	for node in [hooker, dish, victim, hand]:
		if is_instance_valid(node):
			node.queue_free()
	for drone in lead.swarm.drones:
		if is_instance_valid(drone):
			drone.queue_free()


func _start_shell() -> void:
	var ctx = _game.ctx
	var at: Vector3 = ctx.terrain.spawn_point(1) + Vector3(-30.0, 0.0, 20.0)
	_lobber = ctx.spawner.spawn_enemy("lobber", ctx.terrain.drop_point(at.x, at.z, 2.4))
	var landing: Vector3 = ctx.terrain.spawn_point(1)
	_combat._on_lobber_fired(_lobber.global_position + Vector3.UP * 2.6, landing, 1.9, _lobber)
	var shells: Array = _game.get_tree().get_nodes_in_group("enemy_shot")
	var batted := false
	for shell in shells:
		batted = batted or _combat._bat(shell)
	_report("bat", batted, "a shell in flight was batted back toward its lobber")
	_clock = 0.0


func _warden_tricks() -> void:
	_game.flow.enter_stage(2, Vector3.ZERO, false)
	_game.run.set_max_hp(99999.0)
	var ctx = _game.ctx
	var warden: Node3D = ctx.spawner.spawn_enemy("warden", ctx.terrain.beacon_point(2))
	var caps: Array = warden.cap_points()
	if caps.is_empty():
		_report("warden caps", false, "the stage 2 Warden has no cap points to stomp")
		return
	var cap: Vector3 = caps[0]
	_game.player.reset_to(cap + Vector3.UP * 1.3)
	_game.player.body().global_position = cap + Vector3.UP * 1.3
	warden._since_pulse = 0.6
	_combat.strike(warden, "stomp", 12.0)
	_report("pulse_stomp", _combat.discovered.has("pulse_stomp"), "a cap stomp 0.6 s after a pulse")

	warden._unplated = 2.0
	warden.hp = 5.0
	_combat.strike(warden, "runner", 10.0)
	_report("magnet_break", _combat.discovered.has("magnet_break"), "the Warden broken while its magnet had it unplated")
	_game.player.chain.combo = 3
	_game.events.line_state_changed.emit("chain_link", null, Vector3.ZERO, "")
	_report("chain", _combat.discovered.has("chain"), "a third link in one chain")
	_game.player.chain.combo = 0
	var all_found := true
	for id in CodexEntries.ids():
		all_found = all_found and _combat.discovered.has(id)
	_report("all", all_found, "discovered this run: %s" % [_combat.discovery_log])
	_last_case_ran = true


func _finish() -> bool:
	if not _last_case_ran:
		_report("ran to the end", false, "the Warden cases aborted before the last check")
	var ok := _failures == 0
	print("combat_codex_test: %s" % ("PASS" if ok else "FAIL"))
	_game.free()
	quit(0 if ok else 1)
	return true
