extends SceneTree
# smoke: solo timeout=300s

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const LockRows := preload("res://src/world/lock_rows.gd")
const StageLocks := preload("res://src/world/stage_locks.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const Rows := preload("res://src/presentation/rows.gd")
const T := preload("res://tests/support/t.gd")

# The Spillway's pacing locks (src/world/stage_locks.gd, lock_rows.gd) on the real park_dam:
# - rows: the dam and the flume each have a gate and a lock whose kinds the director can spawn;
#   every fact has a WORLD_ROWS row whose specific sound the bank bakes;
# - gate: a shut clamp takes a hit with no posture gain and answers warden_gate_refused; a pack
#   counts only when every member is dead (a despawned member spoils it, a lone arrival is no
#   pack), each counted pack lights a pip and plays warden_gate_pip, and the wanted count opens it
#   (warden_gate_opened), after which a hit gains posture again;
# - lock: on the ground inside within_m of the beacon the yard shuts round the ball with its crew,
#   the wall turns an escaping ball back, the last crew member down opens it, and the crew counts
#   toward the gate; the Warden already awake leaves it unfired;
# - StageLocks.active = false (bot_run --locks=0) leaves the stage with neither.

var _t := T.new("stage_locks_test")
var _facts: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	seed(1)
	_rows()
	await _gate()
	await _lock()
	await _skipped_when_engaged()
	await _off()
	quit(_t.verdict())


func _game():
	var game := Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	await process_frame
	game.player.source = Intent.Scripted.new()
	_facts = []
	game.events.world_fact.connect(func(kind: String, at: Vector3): _facts.append({"kind": kind, "at": at}))
	game.flow.press_start()
	game.flow.choose_class(0)
	for i in 8:
		await physics_frame
	return game


func _count(kind: String) -> int:
	return _facts.filter(func(f): return f["kind"] == kind).size()


func _rows() -> void:
	for map in ["park_dam", "park_flume"]:
		var row: Dictionary = LockRows.row(map)
		_t.check("%s has a gate and a lock" % map, row.has("gate") and row.has("lock"))
		_t.check("%s gate wants packs" % map, int(row["gate"]["packs"]) >= 1)
		for kind in row["lock"]["kinds"]:
			_t.check("%s lock kind %s is a director kind" % [map, kind], kind in preload("res://src/world/director.gd").KIND_NAMES)
		_t.check("%s keeps the boom tender out of the ring" % map, not "boom_tender" in row["lock"]["kinds"])
	_t.check("other parks have no row", LockRows.row("park_pit").is_empty() and LockRows.row("park_test").is_empty())
	for kind in ["arena_locked", "arena_unlocked", "warden_gate_pip", "warden_gate_refused", "warden_gate_opened"]:
		var entry: Dictionary = EventKinds.world_row(kind)
		_t.check("%s has a WORLD_ROWS row" % kind, not entry.is_empty())
		var next := String(entry.get("sound_next", ""))
		_t.check("%s plays its own baked sound" % kind, SfxBank.has_recipe(next) and Rows.heard(entry) == next, next)
		_t.check("%s bakes audio" % kind, SfxBank.samples(next).size() > 1000)


func _kill(enemy) -> void:
	if is_instance_valid(enemy) and not enemy.is_dead():
		enemy._die()


func _spawn_pack(game, kinds: Array, seq: int, near: Vector3) -> Array:
	var out := []
	for i in kinds.size():
		var spot: Vector3 = near + Vector3(8.0 * i - 8.0, 0.0, -30.0)
		var enemy = game.ctx.spawner.spawn_enemy(kinds[i], game.ctx.terrain.drop_point(spot.x, spot.z, 2.4))
		enemy.set_meta("pack_seq", seq)
		game.world.locks.note_member(enemy, seq)
		out.append(enemy)
	return out


func _gate() -> void:
	var game = await _game()
	var locks = game.flow.gate
	_t.check("flow.gate is the world's locks", locks != null and locks == game.world.locks)
	_t.eq("stage 1 is park_dam", String(game.ctx.terrain.map().title), "park_dam")
	_t.check("gate shut on entry", locks.locked())
	var warden = game.flow.warden
	_t.check("park Warden spec carries the gate", is_instance_valid(warden) and warden.spec.get("posture_gate") is Callable)
	var before: float = warden._posture.posture
	game.ctx.spawner.strike(warden, "ram", 400.0)
	await physics_frame
	_t.eq("shut clamp: a hit gains no posture", warden._posture.posture, before)
	_t.eq("shut clamp answers a hit", _count("warden_gate_refused"), 1)
	_t.check("objective names the clamp", game.flow.objective_text().contains("clamp"), game.flow.objective_text())
	var at: Vector3 = warden.global_position
	# A lone arrival is no pack; a pack with a member gone alive is spoiled.
	var lone := _spawn_pack(game, ["chaser"], 101, at)
	_kill(lone[0])
	var spoiled := _spawn_pack(game, ["chaser", "lobber"], 102, at)
	_kill(spoiled[0])
	spoiled[1].queue_free()
	for i in 3:
		await physics_frame
	_t.eq("lone and spoiled packs count nothing", locks.cleared, 0)
	var first := _spawn_pack(game, ["chaser", "chaser", "lobber"], 103, at)
	_kill(first[0])
	_kill(first[1])
	await physics_frame
	_t.eq("a pack with one standing counts nothing", locks.cleared, 0)
	_kill(first[2])
	for i in 2:
		await physics_frame
	_t.eq("a broken pack lights one pip", locks.cleared, 1)
	_t.eq("the pip plays", _count("warden_gate_pip"), 1)
	var collar: Node3D = locks.get_node_or_null("WardenGateCollar")
	_t.check("the collar shows on the Warden", collar != null and collar.global_position.distance_to(warden.global_position) < 0.1)
	_t.check("the collar holds one pip per wanted pack", locks._pips.size() == locks.packs_wanted())
	_t.check("first pip lit, second dark", locks._pips[0].material_override == locks._pip_lit and locks._pips[1].material_override == locks._pip_dark)
	var second := _spawn_pack(game, ["mag_trapper", "lobber"], 104, at)
	for enemy in second:
		_kill(enemy)
	for i in 2:
		await physics_frame
	_t.check("two packs open the clamp", not locks.locked(), "cleared %d" % locks.cleared)
	_t.eq("the release plays once", _count("warden_gate_opened"), 1)
	_t.check("the collar goes", locks._collar == null)
	game.ctx.spawner.strike(warden, "ram", 400.0)
	await physics_frame
	_t.check("open clamp: a hit gains posture", warden._posture.posture > before or warden._posture.staggered, "%s" % warden._posture.posture)
	game.free()
	await process_frame


func _lock() -> void:
	var game = await _game()
	var locks = game.flow.gate
	var row: Dictionary = LockRows.row("park_dam")["lock"]
	_t.eq("lock armed on entry", locks.lock_state, "armed")
	var beacon: Vector3 = game.flow.beacon.global_position
	var spot := beacon + Vector3(0.0, 0.0, -float(row["within_m"]) + 20.0)
	var ground: Vector3 = game.ctx.terrain.drop_point(spot.x, spot.z, 1.0)
	game.player.reset_to(ground, Vector3.ZERO)
	var waited := 0
	while locks.lock_state == "armed" and waited < 240:
		await physics_frame
		waited += 1
	_t.eq("the yard shuts once the ball is grounded inside the circle", locks.lock_state, "locked")
	_t.eq("the slam plays", _count("arena_locked"), 1)
	var crew: Array = locks.crew_alive()
	_t.eq("the crew lands", crew.size(), (row["kinds"] as Array).size())
	_t.check("the wall stands", locks.get_node_or_null("ArenaLockWall") != null)
	_t.check("objective names the yard", game.flow.objective_text().contains("Yard locked"), game.flow.objective_text())
	_t.check("the bot hand goes for the crew", locks.foe_for(game.player.ball_position()) in crew)
	# A ball rolling out past the wall is turned back.
	var r := float(row["radius_m"])
	var c: Vector3 = locks.lock_centre
	var out := Vector3(c.x, 0.0, c.z) + Vector3(r + 6.0, 0.0, 0.0)
	game.player.reset_to(game.ctx.terrain.drop_point(out.x, out.z, 1.0), Vector3(20.0, 0.0, 0.0))
	for i in 3:
		await physics_frame
	_t.check("an escaping ball is sent back in", game.player.state.velocity.x < 0.0, str(game.player.state.velocity))
	for enemy in crew:
		_kill(enemy)
	for i in 3:
		await physics_frame
	_t.eq("the last crew down opens the yard", locks.lock_state, "spent")
	_t.check("won", locks.lock_won)
	_t.eq("the bells play", _count("arena_unlocked"), 1)
	_t.eq("the crew counts toward the gate", locks.cleared, 1)
	game.free()
	await process_frame


func _skipped_when_engaged() -> void:
	var game = await _game()
	var locks = game.flow.gate
	game.flow._engage()
	await physics_frame
	await physics_frame
	_t.eq("an awake Warden leaves the lock unfired", locks.lock_state, "spent")
	game.free()
	await process_frame


func _off() -> void:
	StageLocks.active = false
	var game = await _game()
	var locks = game.flow.gate
	_t.check("off: no clamp", not locks.locked() and not locks.has_gate())
	_t.eq("off: no lock", locks.lock_state, "")
	_t.check("off: the Warden spec has no gate", not game.flow.warden.spec.has("posture_gate"))
	StageLocks.active = true
	game.free()
	await process_frame
