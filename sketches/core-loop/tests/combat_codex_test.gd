extends SceneTree
# F6 2026-10-04: magnet_break and the Warden cap stomp are gone with the plating fight.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const CodexEntries := preload("res://src/combat/codex_entries.gd")

# Combat's "enemy" codex entries: complete as data (id, category, name, hint, clue,
# text, owner, participants), and each one detected by combat's own code when the
# trick is pulled. Each trick is staged directly on the live game.

const REQUIRED := ["id", "category", "name", "hint", "clue", "text", "owner", "participants"]

# 2026-10-04: the default alpha table's stage 2 Warden fights by posture with no lesson,
# so it has no caps; the cap-stomp trick runs on the legacy table's caps Warden.
class LegacyGame extends "res://src/game.gd":
	func _chosen_table():
		return preload("res://tests/doubles/two_world_defs.gd").FirstWorld

var _game
var _combat
var _source := Intent.Scripted.new()
var _failures := 0
var _step := 0
var _clock := 0.0
var _lobber: Node3D
# The wave 9 units still waiting on the ball's teleport, and where the ball started.
var _w9_units := {}
var _w9_home := Vector3.ZERO
# Set by the last case; a script error that aborts a case leaves it false.
var _last_case_ran := false


func _initialize() -> void:
	_game = LegacyGame.new()
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
			_w9_settle()
			_step = 1
		1:
			# The ball's teleports land on a physics tick: first onto the floor, then off the
			# lane and the mark at cruise.
			_clock += delta
			if _game.player.ball_position().distance_to(_w9_home) < 0.5 or _clock > 1.0:
				_w9_tricks()
				_step = 2
		2:
			_clock += delta
			if _game.player.ball_position().distance_to(_w9_home) > 3.0 or _clock > 1.0:
				_w9_after_move()
				_start_shell()
				_step = 3
		3:
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


# Wave 9: the Dig and Highdraft units, each driven through its own attack. The drill,
# cutter and anchor finish now; the burrower, kite and lamps finish once the ball has
# moved off the lane and the mark at cruise speed (_w9_after_move).
func _w9_settle() -> void:
	var home: Vector3 = _game.player.ball_position()
	_w9_home = _game.ctx.terrain.drop_point(home.x, home.z, 1.05)
	_game.player.reset_to(_w9_home)
	_clock = 0.0


func _w9_tricks() -> void:
	var ctx = _game.ctx
	var fleet = _combat.fleet
	var home: Vector3 = _game.player.ball_position()

	var rig: Node3D = _w9_spawn("drill_crew", home + Vector3(10.0, 0.0, 6.0))
	rig._warn(_w9_to(rig))
	_combat.strike(rig, "slam", 14.0)
	_report("bore_breach", _combat.discovered.has("bore_breach") and rig.stopped == 1,
		"a slam on a drill crew mid-bore stopped it (stopped %d)" % rig.stopped)

	var cutter: Node3D = _w9_spawn("line_cutter", home + Vector3(-10.0, 0.0, 8.0))
	cutter._warn(_w9_to(cutter))
	cutter.phase = cutter.Phase.LIVE
	cutter._go_live()
	cutter._t = cutter.FLIGHT + 0.01
	cutter._live(0.0)
	_report("line_cut", _combat.discovered.has("line_cut") and cutter.dodged == 1,
		"an unhooked ball in the landing ring dodged the cutter (dodged %d)" % cutter.dodged)

	var crew: Node3D = _w9_spawn("anchor_crew", home + Vector3(0.0, 0.0, 10.0))
	crew._warn(_w9_to(crew))
	crew.phase = crew.Phase.LIVE
	crew._go_live()
	var hooked: bool = fleet.holds.held(crew)
	fleet.holds.snap(crew, "jump")
	_report("deck_winch", _combat.discovered.has("deck_winch") and hooked and crew.broken_by == "jump",
		"an anchor crew hooked the ball (%s), then a jump slipped it (%s)" % [hooked, crew.broken_by])
	for node in [rig, cutter, crew]:
		if is_instance_valid(node):
			node.queue_free()

	var burrower: Node3D = _w9_spawn("burrower", home + Vector3(8.0, 0.0, 0.0))
	burrower._warn(_w9_to(burrower))
	var kite: Node3D = _w9_spawn("kite_drone", home + Vector3(0.0, 0.0, 8.0))
	kite._warn(_w9_to(kite))
	var lamps: Node3D = _w9_spawn("lamp_swarm", home + Vector3(-5.0, 0.0, 0.0))
	lamps._warn(_w9_to(lamps))
	lamps.phase = lamps.Phase.LIVE
	lamps._go_live()
	_w9_units = {"burrower": burrower, "kite": kite, "lamps": lamps,
		"lane_had_ball": burrower._lane_had_ball, "mark_had_ball": kite.telegraph().contains(home)}
	var away := Vector3(0.0, 0.0, -4.0)
	_game.player.reset_to(home + away, away.normalized() * 1.2 * ctx.tuning.f("cruise"))
	_clock = 0.0


func _w9_after_move() -> void:
	var burrower: Node3D = _w9_units["burrower"]
	burrower.phase = burrower.Phase.LIVE
	burrower._go_live()
	_report("burrow_lane", _combat.discovered.has("burrow_lane") and _w9_units["lane_had_ball"] and burrower.bursts == 1,
		"the lane held the ball at commit (%s) and the burst came up empty" % _w9_units["lane_had_ball"])

	var kite: Node3D = _w9_units["kite"]
	kite.phase = kite.Phase.LIVE
	kite._go_live()
	kite._t = kite.DIVE + 0.01
	kite._live(0.0)
	_report("thermal_dive", _combat.discovered.has("thermal_dive") and _w9_units["mark_had_ball"] and kite.dives == 1,
		"the mark held the ball (%s) and the dive landed after it left" % _w9_units["mark_had_ball"])

	var lamps: Node3D = _w9_units["lamps"]
	if lamps.phase == lamps.Phase.LIVE:
		lamps._live(1.0 / 90.0)
	_report("lure_bloom", _combat.discovered.has("lure_bloom"),
		"a ball at cruise inside the bloom went through the light (tier %d)" % _game.player.speed_tier())
	for key in ["burrower", "kite", "lamps"]:
		if is_instance_valid(_w9_units[key]):
			_w9_units[key].queue_free()
	_w9_units.clear()
	_game.player.reset_to(_w9_home)


func _w9_spawn(kind: String, at: Vector3) -> Node3D:
	var ctx = _game.ctx
	return ctx.spawner.spawn_enemy(kind, ctx.terrain.drop_point(at.x, at.z, 1.6))


func _w9_to(unit: Node3D) -> Vector3:
	var to: Vector3 = _game.player.ball_position() - unit.global_position
	to.y = 0.0
	return to


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
	_report("posture warden", warden.fight() == "posture", "the stage 2 Warden fights on posture; caps and the magnet are gone")
	_game.player.chain.combo = 3
	_game.events.line_state_changed.emit("chain_link", null, Vector3.ZERO, "")
	_report("chain", _combat.discovered.has("chain"), "a third link in one chain")
	_game.player.chain.combo = 0
	var all_found := true
	var pending_ok := true
	for id in CodexEntries.ids():
		# 2026-10-04 (wave 9): detector-pending entries declare a hint but no enemy fires them yet.
		if CodexEntries.DETECTOR_PENDING.has(id):
			pending_ok = pending_ok and not _combat.discovered.has(id)
			continue
		all_found = all_found and _combat.discovered.has(id)
	_report("all", all_found, "discovered this run: %s" % [_combat.discovery_log])
	_report("pending stay undiscovered", pending_ok, "detector-pending: %s" % [CodexEntries.DETECTOR_PENDING])
	_last_case_ran = true


func _finish() -> bool:
	if not _last_case_ran:
		_report("ran to the end", false, "the Warden cases aborted before the last check")
	var ok := _failures == 0
	print("combat_codex_test: %s" % ("PASS" if ok else "FAIL"))
	_game.free()
	quit(0 if ok else 1)
	return true
