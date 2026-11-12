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
const Palette := preload("res://src/core/palette.gd")

# The Spillway's pacing locks (src/world/stage_locks.gd, lock_rows.gd) on the real park_dam:
# - rows: the dam and the flume each have a gate and a lock whose kinds the director can spawn;
#   every fact has a WORLD_ROWS row whose specific sound the bank bakes;
# - gate: a shut clamp takes a hit with no posture gain and answers warden_gate_refused; a pack
#   counts only when every member is dead (a despawned member spoils it, a lone arrival is no
#   pack), each counted pack lights a pip and plays warden_gate_pip, and the wanted count opens it
#   (warden_gate_opened), after which a hit gains posture again;
# - riders (ruling w): a crew's homeless rider (director.gd _home_pack_spots) neither holds nor
#   spoils its count, a crew of riders alone counts as a plain pack, and the bot hand goes for the
#   crew's housed members, the crew nearest to a pip first;
# - lock: on the ground inside within_m of the beacon the yard shuts round the ball with its crew,
#   the wall turns an escaping ball back, the last crew member down opens it, and the crew counts
#   toward the gate; its kills roll no panel and the cleared yard pays one (ruling af); the Warden already awake leaves it unfired;
# - sentry (systems audit pass E): on the dam one lobber lands up the ball's line once, inside the sentry's
#   circle and before the yard shuts, as a plain enemy that is no crew;
# - plate (w22 first-timer red team): while the yard holds, the objective plate says so and no edge
#   marker points past its wall; while the clamp is shut on an awake Warden, the plate says so and its
#   ring fills with the pips, an edge marker with the plate's glyph points at the crew nearest a pip
#   (w23 cautious red team watch 5) while the Warden's keeps its own, and the open clamp hands the
#   plate back to the guard and drops the crew marker;
# - StageLocks.active = false (bot_run --locks=0) leaves the stage with neither.

# Kills inside the physics step, after every other node: a kill that lands after the locks' tick
# (fleet, combat, a pilot kit) still counts once its body is freed.
class LateKiller extends Node:
	var targets: Array = []

	func _init() -> void:
		process_physics_priority = 1000

	func _physics_process(_delta: float) -> void:
		for enemy in targets:
			if is_instance_valid(enemy) and not enemy.is_dead():
				enemy._die()
		targets.clear()


var _t := T.new("stage_locks_test")
var _facts: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	seed(1)
	_rows()
	await _gate()
	await _riders()
	await _lock()
	await _sentry()
	await _timed_out()
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


# The clamp row's crew markers (edge_markers.gd), as the HUD reads them this frame.
func _crew_markers(game) -> Array:
	return game.hud.edge_markers.targets().filter(func(m): return m["kind"] == "pack_arrived")


func _count(kind: String) -> int:
	return _facts.filter(func(f): return f["kind"] == kind).size()


func _rows() -> void:
	for map in ["park_dam", "park_flume"]:
		var row: Dictionary = LockRows.row(map)
		_t.check("%s has a gate and a lock" % map, row.has("gate") and row.has("lock"))
		_t.check("%s gate wants packs" % map, int(row["gate"]["packs"]) >= 1)
		_t.check("%s lock lands in waves" % map, (row["lock"]["waves"] as Array).size() >= 2)
		for wave in row["lock"]["waves"]:
			for kind in wave:
				_t.check("%s lock kind %s is a director kind" % [map, kind], kind in preload("res://src/world/director.gd").KIND_NAMES)
			for kept_out in ["boom_tender", "mag_trapper", "plated_brute"]:
				_t.check("%s keeps %s out of the ring" % [map, kept_out], not kept_out in wave)
	_t.check("other parks have no row", LockRows.row("park_pit").is_empty() and LockRows.row("park_test").is_empty())
	for kind in ["arena_locked", "arena_wave", "arena_unlocked", "warden_gate_pip", "warden_gate_refused", "warden_gate_opened"]:
		var entry: Dictionary = EventKinds.world_row(kind)
		_t.check("%s has a WORLD_ROWS row" % kind, not entry.is_empty())
		var next := String(entry.get("sound_next", ""))
		_t.check("%s plays its own baked sound" % kind, SfxBank.has_recipe(next) and Rows.heard(entry) == next, next)
		_t.check("%s bakes audio" % kind, SfxBank.samples(next).size() > 1000)


func _kill(enemy) -> void:
	if is_instance_valid(enemy) and not enemy.is_dead():
		enemy._die()


func _spawn_pack(game, kinds: Array, seq: int, near: Vector3, riders := []) -> Array:
	var out := []
	for i in kinds.size():
		var spot: Vector3 = near + Vector3(8.0 * i - 8.0, 0.0, -30.0)
		var enemy = game.ctx.spawner.spawn_enemy(kinds[i], game.ctx.terrain.drop_point(spot.x, spot.z, 2.4))
		enemy.set_meta("pack_seq", seq)
		game.world.locks.note_member(enemy, seq, i in riders)
		out.append(enemy)
	return out


func _gate() -> void:
	var game = await _game()
	var locks = game.flow.gate
	_t.check("flow.gate is the world's locks", locks != null and locks == game.world.locks)
	_t.eq("stage 1 is park_dam", String(game.ctx.terrain.map().title), "park_dam")
	_t.check("gate shut on entry", locks.locked())
	_t.check("the clamp keeps quiet before the Warden wakes", not game.flow.objective_text().contains("clamp"), game.flow.objective_text())
	var warden = game.flow.warden
	_t.check("park Warden spec carries the gate", is_instance_valid(warden) and warden.spec.get("posture_gate") is Callable)
	var before: float = warden._posture.posture
	game.ctx.spawner.strike(warden, "ram", 400.0)
	await physics_frame
	_t.eq("shut clamp: a hit gains no posture", warden._posture.posture, before)
	_t.eq("shut clamp answers a hit", _count("warden_gate_refused"), 1)
	_t.check("objective names the clamp once it is awake", game.flow.objective_text().contains("clamp"), game.flow.objective_text())
	var plate: Dictionary = game.hud.objective_reading()
	_t.eq("the plate says the clamp is shut while it holds", [plate["id"], plate["words"]], ["break_clamp_crews", "Break the clamp crews"])
	_t.eq("its ring starts empty", plate["progress"], 0.0)
	_t.eq("in slate, a locked thing", plate["color"], Palette.SLATE)
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
	await process_frame
	_t.eq("no crew that can count, no crew marker", _crew_markers(game), [])
	var first := _spawn_pack(game, ["chaser", "chaser", "lobber"], 103, at)
	_kill(first[0])
	_kill(first[1])
	await physics_frame
	_t.eq("a pack with one standing counts nothing", locks.cleared, 0)
	await process_frame
	var crew_marks := _crew_markers(game)
	_t.check("the clamp row's marker points at the crew still standing", crew_marks.size() == 1 and is_instance_valid(first[2])
		and (crew_marks[0]["at"] as Vector3).distance_to(first[2].global_position) < 0.1, "%s" % [crew_marks])
	_t.check("the crew marker carries the plate's glyph", crew_marks.size() == 1 and crew_marks[0]["icon"] == game.hud.objective_reading()["icon"])
	var warden_marks: Array = game.hud.edge_markers.targets().filter(func(m): return m["kind"] == "warden_engaged")
	_t.check("the Warden's marker keeps the Warden's glyph", warden_marks.size() == 1 and warden_marks[0]["icon"] == "obj_warden", "%s" % [warden_marks])
	_kill(first[2])
	for i in 2:
		await physics_frame
	_t.eq("a broken pack lights one pip", locks.cleared, 1)
	_t.eq("the pip plays", _count("warden_gate_pip"), 1)
	var collar: Node3D = locks.get_node_or_null("WardenGateCollar")
	_t.check("the collar shows on the Warden", collar != null and collar.global_position.distance_to(warden.global_position) < 0.1)
	_t.check("the collar holds one pip per wanted pack", locks._pips.size() == locks.packs_wanted())
	_t.check("first pip lit, second dark", locks._pips[0].material_override == locks._pip_lit and locks._pips[1].material_override == locks._pip_dark)
	_t.eq("the plate's ring fills with the pips", game.hud.objective_reading()["progress"], 1.0 / locks.packs_wanted())
	var second := _spawn_pack(game, ["mag_trapper", "lobber"], 104, at)
	var late := LateKiller.new()
	root.add_child(late)
	late.targets = second.duplicate()
	for i in 3:
		await physics_frame
	late.queue_free()
	_t.eq("a late kill still counts", locks.cleared, 2)
	# The rest of the wanted crews (the dam asks for more than two since the w19 pacing rows).
	var seq := 105
	while locks.cleared < locks.packs_wanted() and seq < 112:
		_t.check("the clamp holds at %d of %d" % [locks.cleared, locks.packs_wanted()], locks.locked())
		for enemy in _spawn_pack(game, ["chaser", "lobber"], seq, at):
			_kill(enemy)
		seq += 1
		for i in 2:
			await physics_frame
	_t.check("the wanted packs open the clamp", not locks.locked(), "cleared %d of %d" % [locks.cleared, locks.packs_wanted()])
	_t.eq("the release plays once", _count("warden_gate_opened"), 1)
	_t.eq("the open clamp hands the plate back to the dam Warden's own row", game.hud.objective_reading()["id"], "ride_sheet")
	await process_frame
	_t.eq("the open clamp shows no crew marker", _crew_markers(game), [])
	_t.check("the collar goes", locks._collar == null)
	game.ctx.spawner.strike(warden, "ram", 400.0)
	await physics_frame
	_t.check("open clamp: a hit gains posture", warden._posture.posture > before or warden._posture.staggered, "%s" % warden._posture.posture)
	game.free()
	await process_frame


func _riders() -> void:
	var game = await _game()
	var locks = game.flow.gate
	var warden = game.flow.warden
	game.ctx.spawner.strike(warden, "ram", 400.0)
	await physics_frame
	var at: Vector3 = warden.global_position
	# Two crews in reach: one housed member and a rider left, and two housed members.
	var crew := _spawn_pack(game, ["chaser", "chaser", "lobber"], 201, at, [2])
	var fresh := _spawn_pack(game, ["chaser", "chaser"], 202, at + Vector3(0.0, 0.0, 6.0))
	_kill(crew[0])
	await physics_frame
	var ball: Vector3 = crew[1].global_position + Vector3(40.0, 0.0, 0.0)
	_t.check("the hand finishes the crew nearest a pip, not its rider", locks.foe_for(ball) == crew[1], "%s" % locks.foe_for(ball))
	_kill(crew[1])
	for i in 2:
		await physics_frame
	_t.check("the rider still stands", is_instance_valid(crew[2]) and not crew[2].is_dead())
	_t.eq("a crew with a live rider counts once its housed members are dead", locks.cleared, 1)
	_t.eq("its pip plays", _count("warden_gate_pip"), 1)
	_t.check("the hand leaves a counted crew's rider for the next crew", locks.foe_for(ball) in fresh, "%s" % locks.foe_for(ball))
	crew[2].queue_free()
	for f in fresh:
		f.queue_free()
	# A rider leaving alive spoils nothing; a crew of riders alone counts as a plain pack.
	var gone := _spawn_pack(game, ["chaser", "lobber"], 203, at, [1])
	gone[1].queue_free()
	await physics_frame
	_kill(gone[0])
	for i in 2:
		await physics_frame
	_t.eq("a rider gone alive spoils nothing: its crew counts", locks.cleared, 2)
	game.free()
	await process_frame
	game = await _game()
	locks = game.flow.gate
	at = game.flow.warden.global_position
	var only := _spawn_pack(game, ["chaser", "lobber"], 204, at, [0, 1])
	_kill(only[0])
	await physics_frame
	_t.eq("a crew of riders waits for every member", locks.cleared, 0)
	_kill(only[1])
	for i in 2:
		await physics_frame
	_t.eq("a crew of riders counts like a plain pack", locks.cleared, 1)
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
	var waves: Array = row["waves"]
	var crew: Array = locks.crew_alive()
	_t.eq("the first wave lands", crew.size(), (waves[0] as Array).size())
	_t.check("the wall stands", locks.get_node_or_null("ArenaLockWall") != null)
	_t.check("objective names the yard", game.flow.objective_text().contains("Yard locked"), game.flow.objective_text())
	game.hud._process(0.0)
	_t.eq("the plate says the yard is locked", [game.hud.objective_reading()["id"], game.hud.objective_reading()["words"]],
			["break_yard_crew", "Break the yard crew"])
	_t.eq("no edge marker points out past the wall", game.hud.edge_markers.targets(), [])
	_t.check("the bot hand goes for the crew", locks.foe_for(game.player.ball_position()) in crew)
	var logged: int = game.build.kill_log.size()
	var dry: int = game.build.dropper.dry
	var panels: int = game.build.scrap.panel_count()
	# A ball rolling out past the wall is turned back.
	var r := float(row["radius_m"])
	var c: Vector3 = locks.lock_centre
	var out := Vector3(c.x, 0.0, c.z) + Vector3(r + 6.0, 0.0, 0.0)
	game.player.reset_to(game.ctx.terrain.drop_point(out.x, out.z, 1.0), Vector3(20.0, 0.0, 0.0))
	for i in 3:
		await physics_frame
	_t.check("an escaping ball is sent back in", game.player.state.velocity.x < 0.0, str(game.player.state.velocity))
	for w in waves.size():
		for enemy in crew:
			_kill(enemy)
		for i in 3:
			await physics_frame
		if w + 1 < waves.size():
			_t.eq("wave %d down: the yard holds" % (w + 1), locks.lock_state, "locked")
			_t.eq("wave %d down: the next whistles in" % (w + 1), _count("arena_wave"), w + 1)
			# The gap runs on game time. The kill's hit stop can slow the rest of a frame that runs
			# several ticks (game.gd hit_stop), so a loaded box lands the wave a few ticks late:
			# wait for it, and check it lands no sooner than the gap and no later than one slowed frame after.
			var gap := int(ceil(float(row["wave_gap_s"]) * Engine.physics_ticks_per_second))
			var ticks := 3
			while locks.crew_alive().is_empty() and ticks < gap * 2:
				await physics_frame
				ticks += 1
			_t.check("wave %d waits out the gap" % (w + 2), ticks >= gap, "%d of %d ticks" % [ticks, gap])
			_t.check("wave %d lands within a frame of the gap" % (w + 2), ticks <= gap + 2 + Engine.max_physics_steps_per_frame,
					"%d of %d ticks" % [ticks, gap])
			crew = locks.crew_alive()
			_t.eq("wave %d lands" % (w + 2), crew.size(), (waves[w + 1] as Array).size())
	_t.eq("the last crew down opens the yard", locks.lock_state, "spent")
	_t.check("won", locks.lock_won)
	_t.eq("the bells play", _count("arena_unlocked"), 1)
	game.hud._process(0.0)
	_t.check("the open yard hands the plate back", game.hud.objective_reading()["id"] != "break_yard_crew", game.hud.objective_reading()["id"])
	_t.check("the open yard shows its markers again", not game.hud.edge_markers.targets().is_empty())
	_t.eq("the crew counts toward the gate", locks.cleared, 1)
	# Ruling af: the crew rolls no panels and the cleared yard pays one (build.gd yard_cleared).
	var since: Array = game.build.kill_log.slice(logged)
	var crew_kills := since.filter(func(k: Array): return k.size() > 6 and bool(k[6]))
	var crew_size := 0
	for wave in waves:
		crew_size += (wave as Array).size()
	_t.eq("every crew kill is logged as the yard's", crew_kills.size(), crew_size)
	_t.check("no crew kill drops a panel", crew_kills.all(func(k: Array): return not bool(k[5])))
	_t.eq("the cleared yard pays one panel", since.filter(func(k: Array): return String(k[1]) == "yard_clear" and bool(k[5])).size(), 1)
	_t.eq("the yard leaves pity alone", game.build.dropper.dry, dry)
	_t.eq("its panel lies in the field", game.build.scrap.panel_count(), panels + 1)
	game.free()
	await process_frame


func _lobbers(game) -> Array:
	return game.get_tree().get_nodes_in_group("enemy").filter(func(e): return String(e.get("kind")) == "lobber" and not e.is_dead())


func _sentry() -> void:
	var game = await _game()
	var locks = game.flow.gate
	var row: Dictionary = LockRows.row("park_dam")["lock"]
	var sentry: Dictionary = row["sentry"]
	_t.eq("the dam's sentry is a lobber", sentry["kind"], "lobber")
	_t.check("the sentry lands before the yard shuts", float(sentry["within_m"]) > float(row["within_m"]))
	for enemy in game.get_tree().get_nodes_in_group("enemy"):
		if String(enemy.get("kind")) not in ["warden", "vault", ""]:
			enemy.queue_free()
	await physics_frame
	var beacon: Vector3 = game.flow.beacon.global_position
	var spot := beacon + Vector3(0.0, 0.0, -float(sentry["within_m"]) + 10.0)
	var ground: Vector3 = game.ctx.terrain.drop_point(spot.x, spot.z, 1.0)
	game.player.reset_to(ground, Vector3.ZERO)
	for i in 6:
		await physics_frame
	var lobbers := _lobbers(game)
	_t.eq("one lobber lands", lobbers.size(), 1)
	_t.eq("the yard is still armed", locks.lock_state, "armed")
	if lobbers.size() == 1:
		var at: Vector3 = lobbers[0].global_position
		var ball: Vector3 = game.player.ball_position()
		var ahead := Vector3(beacon.x - ball.x, 0.0, beacon.z - ball.z).normalized().dot(Vector3(at.x - ball.x, 0.0, at.z - ball.z))
		_t.near("it stands ahead_m up the line to the beacon", ahead, float(sentry["ahead_m"]), 3.0)
		_t.check("it is in shell range of the ball", Vector2(at.x - ball.x, at.z - ball.z).length() < 75.0)
		_t.check("it is no crew", not lobbers[0].has_meta("yard_crew"))
	var spot2 := beacon + Vector3(0.0, 0.0, -float(sentry["within_m"]) + 30.0)
	game.player.reset_to(game.ctx.terrain.drop_point(spot2.x, spot2.z, 1.0), Vector3.ZERO)
	for i in 6:
		await physics_frame
	_t.eq("it lands once", _lobbers(game).size(), lobbers.size())
	# The yard shuts with the sentry outside the wall: it goes, and the crew lands as before.
	var spot3 := beacon + Vector3(0.0, 0.0, -float(row["within_m"]) + 20.0)
	game.player.reset_to(game.ctx.terrain.drop_point(spot3.x, spot3.z, 1.0), Vector3.ZERO)
	var waited := 0
	while locks.lock_state == "armed" and waited < 240:
		await physics_frame
		waited += 1
	await physics_frame
	_t.eq("the yard shuts", locks.lock_state, "locked")
	_t.check("a sentry outside the wall leaves as the yard shuts", lobbers.size() == 1 and not is_instance_valid(lobbers[0]))
	_t.eq("the crew is the first wave alone", locks.crew_alive().size(), (row["waves"][0] as Array).size())
	game.free()
	await process_frame


# A yard that runs out its max_s lets its survivors out as plain enemies: no panel for the yard,
# and a survivor killed on the open map rolls like any kill.
func _timed_out() -> void:
	var game = await _game()
	var locks = game.flow.gate
	var row: Dictionary = LockRows.row("park_dam")["lock"]
	var beacon: Vector3 = game.flow.beacon.global_position
	var spot := beacon + Vector3(0.0, 0.0, -float(row["within_m"]) + 20.0)
	game.player.reset_to(game.ctx.terrain.drop_point(spot.x, spot.z, 1.0), Vector3.ZERO)
	var waited := 0
	while locks.lock_state == "armed" and waited < 240:
		await physics_frame
		waited += 1
	var crew: Array = locks.crew_alive()
	_t.check("the timed yard shuts with a crew", locks.lock_state == "locked" and not crew.is_empty())
	var logged: int = game.build.kill_log.size()
	locks.lock_left = 0.0
	for i in 2:
		await physics_frame
	_t.eq("max_s opens the yard", locks.lock_state, "spent")
	_t.check("a timed-out yard is not won", not locks.lock_won)
	_t.check("its survivors leave the crew", crew.all(func(enemy): return not is_instance_valid(enemy) or not enemy.has_meta("yard_crew")))
	_kill(crew[0])
	await physics_frame
	var since: Array = game.build.kill_log.slice(logged)
	_t.check("a survivor's kill rolls like any kill", since.size() >= 1 and since.all(func(k: Array): return k.size() < 7 or not bool(k[6])), str(since))
	_t.eq("a timed-out yard pays nothing", since.filter(func(k: Array): return String(k[1]) == "yard_clear").size(), 0)
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
