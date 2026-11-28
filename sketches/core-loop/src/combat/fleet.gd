extends Node

const Roster := preload("res://src/combat/roster.gd")
const Holds := preload("res://src/combat/holds.gd")
const Habits := preload("res://src/combat/habits.gd")
const Swarm := preload("res://src/combat/swarm.gd")
const Enemy := preload("res://src/combat/enemy.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const SimClock := preload("res://src/core/sim_clock.gd")

const SCRIPTS := {
	"mag_trapper": preload("res://src/combat/mag_trapper.gd"),
	"hooker": preload("res://src/combat/hooker.gd"),
	"netcaster": preload("res://src/combat/netcaster.gd"),
	"bola_thrower": preload("res://src/combat/bola_thrower.gd"),
	"plated_brute": preload("res://src/combat/plated_brute.gd"),
	"deflector": preload("res://src/combat/deflector.gd"),
	"winch_drone": preload("res://src/combat/winch_drone.gd"),
	"gyro_jammer": preload("res://src/combat/gyro_jammer.gd"),
	"swatter": preload("res://src/combat/swatter.gd"),
	"ramp_flipper": preload("res://src/combat/ramp_flipper.gd"),
	"catch_trap": preload("res://src/combat/catch_trap.gd"),
	"reactor_relic": preload("res://src/combat/reactor_relic.gd"),
	"swarm_remnant": preload("res://src/combat/swarm_remnant.gd"),
	"mind_hand": preload("res://src/combat/mind_hand.gd"),
	"crew_fitter": preload("res://src/combat/crew_fitter.gd"),
}
const PLATING_SCALE := {"plated_brute": 0.6, "mind_hand": 0.5}
const PIN_WINDOW_FRAMES := 60


class SingleGuard extends RefCounted:
	var scatters := 0
	var _enemy: Node3D

	func _init(enemy: Node3D) -> void:
		_enemy = enemy

	func alive() -> Array:
		return [_enemy] if is_instance_valid(_enemy) and not _enemy.is_dead() else []

	func following() -> bool:
		return false

var ctx
var combat
var holds
var habits := Habits.new()
var mind_memory: Array = []
var swarms: Array = []
var packs: Array = []
var last_pack := {}
var scatters := 0
var follower_pins := 0

var _batch: Array = []
var _joining = null
var _launched := {}
var _loaded := {}
var _requested := {}


func setup(ctx_ref, combat_ref) -> void:
	ctx = ctx_ref
	combat = combat_ref
	name = "Fleet"
	holds = Holds.new()
	ctx.root.add_child(holds)
	holds.setup(ctx)
	habits.bind(ctx.events)
	ctx.events.run_started.connect(func(_class_id: String): reset_run())
	ctx.events.stage_entered.connect(func(_stage: int, _retry: bool):
		swarms.clear()
		_warm_scripts())
	ctx.events.enemy_pinned.connect(_on_pinned)


func events():
	return ctx.events


func reset_run() -> void:
	mind_memory.clear()
	swarms.clear()
	packs.clear()
	last_pack = {}


func makes(kind: String) -> bool:
	return SCRIPTS.has(kind) or (Roster.row(kind).has("script") and Roster.built(kind))


func make(kind: String) -> Node3D:
	if SCRIPTS.has(kind):
		return SCRIPTS[kind].new()
	if not makes(kind):
		return null
	if not _loaded.has(kind):
		var path := String(Roster.row(kind)["script"])
		if _requested.has(path) and ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED:
			_loaded[kind] = ResourceLoader.load_threaded_get(path)
			_requested.erase(path)
		else:
			_loaded[kind] = load(path)
	return _loaded[kind].new()


# Godot main-thread load() stalls ~420 ms on first spawn; skip threaded warm-up in deterministic bot runs.
func _warm_scripts() -> void:
	if SimClock.ticks and not SimClock.threaded_in_bot_runs:
		return
	for kind in Roster.ROWS.keys():
		if _loaded.has(kind) or SCRIPTS.has(kind) or not Roster.row(kind).has("script") or not Roster.built(kind):
			continue
		var path := String(Roster.row(kind)["script"])
		if not _requested.has(path) and not ResourceLoader.has_cached(path):
			if ResourceLoader.load_threaded_request(path) == OK:
				_requested[path] = true


func dress(kind: String, spec: Dictionary) -> Dictionary:
	if not makes(kind) and kind != "warden":
		return spec
	var out := spec.duplicate()
	out["kind"] = kind
	out["holds"] = holds
	out["fleet"] = self
	if PLATING_SCALE.has(kind):
		var stage: int = ctx.flow.stage()
		out["plating"] = float(roundi(PLATING_SCALE[kind] * float(combat.warden_spec(stage)["plating"])))
	if kind == "warden" and ctx.flow != null:
		out["variant"] = String(ctx.flow.stage_def().get("warden_variant", ""))
	if kind == "swarm_remnant":
		if _joining == null:
			_joining = Swarm.new(self)
			swarms.append(_joining)
		out["swarm"] = _joining
	return out


func on_spawned(enemy: Node3D, kind: String) -> void:
	if kind == "swarm_remnant" and _joining != null:
		var swarm = _joining
		if swarm.drones.size() == 1:
			var at := enemy.global_position
			for i in range(1, swarm.size()):
				var offset := Vector3(cos(TAU * i / swarm.size()), 0.0, sin(TAU * i / swarm.size())) * 1.8
				combat.spawn_enemy("swarm_remnant", at + offset)
			_joining = null
	if not Roster.is_reinforcement(kind):
		return
	if _batch.is_empty():
		_flush.call_deferred()
	_batch.append({"kind": kind, "at": enemy.global_position})


func spawn_guard(home: Vector3, at: Vector3, kind := "swarm_remnant") -> Object:
	if kind != "swarm_remnant":
		return SingleGuard.new(combat.spawn_enemy(kind, at))
	_joining = Swarm.new(self, home)
	swarms.append(_joining)
	var swarm = _joining
	combat.spawn_enemy("swarm_remnant", at)
	_joining = null
	return swarm


func on_swarm_scattered(swarm, at: Vector3, drones: int) -> void:
	scatters += 1
	ctx.events.swarm_scattered.emit(at, drones)
	for enemy in get_tree().get_nodes_in_group(Enemy.GROUP):
		if enemy.has_method("on_guard_scattered"):
			enemy.on_guard_scattered(swarm, at)


func on_follower_launched(_drone: Node3D, victim: Node3D) -> void:
	_launched[victim.get_instance_id()] = Engine.get_physics_frames()


func mind_adapt(habit: String, icon: String, at: Vector3) -> void:
	mind_memory.append({"habit": habit, "icon": icon})
	ctx.events.mind_adapted.emit(habit, icon)
	discover("what_it_learned", at)


func discover(id: String, at: Vector3) -> void:
	combat.discover(id, at)


func build_read() -> Dictionary:
	var class_id := ""
	if ctx.run.class_def != null:
		class_id = String(ctx.run.class_def.id)
	var tags: Array = []
	var tree = ctx.player.get("tree")
	if tree != null and tree.has_method("branch_tags"):
		tags = Array(tree.branch_tags())
	return {"class": class_id, "habits": habits.shares(), "branch_tags": tags}


func _physics_process(delta: float) -> void:
	if ctx == null:
		return
	habits.tick(delta)
	if ctx.run.class_def != null:
		Enemy.rim_color = ctx.run.class_def.color


func _flush() -> void:
	var by_faction := {}
	for spawn in _batch:
		var faction := Roster.faction_of(spawn["kind"])
		if not by_faction.has(faction):
			by_faction[faction] = []
		by_faction[faction].append(spawn)
	_batch.clear()
	for faction in by_faction:
		var members: Array = by_faction[faction]
		var sum := Vector3.ZERO
		var kinds: Array = []
		for spawn in members:
			sum += spawn["at"]
			kinds.append(spawn["kind"])
		var at := sum / members.size()
		last_pack = {"faction": faction, "at": at, "kinds": kinds, "icon": EventKinds.FACTION_ICONS.get(faction, "fac_fleet")}
		packs.append(last_pack)
		ctx.events.pack_arrived.emit(faction, at, kinds)


func _on_pinned(victim: Node3D, _damage: float) -> void:
	var id := victim.get_instance_id()
	if not _launched.has(id):
		return
	if Engine.get_physics_frames() - int(_launched[id]) <= PIN_WINDOW_FRAMES:
		follower_pins += 1
		discover("awaiting_operator", victim.global_position)
	_launched.erase(id)

