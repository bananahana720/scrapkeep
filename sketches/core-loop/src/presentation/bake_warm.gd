extends Node

# Readies the bake look for a world's enemies after stage entry, one kit a frame, so the first
# spawn of a kind does not rebuild its meshes' tangents mid-fight (perf lane F: at f451 of a
# stage 1 run three first spawns spent 4.5-8 ms each in BakeLook.dress, almost all of it in
# tangent_safe; gate/perf-dress-35d7d63c/). Each kit's static _parts() is the mesh set every one
# of its spawns shares, so the copies tangent_safe hangs off those meshes are the ones dress
# finds later. On screen a rigged kit (SpecialRig.seat) draws its GLB's own scene instead, so
# that scene is held, as hero_assets holds the Warden scenes, and its meshes readied the same way.
# Materials are left to dress: a twin depends on how the spawn uses its surfaces.
# A bot run that builds stages whole skips it, like fleet._warm_scripts, so frame costs stay as
# they were where seeds must replay.

const BakeLook := preload("res://src/presentation/bake_look.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const Terrain := preload("res://src/world/terrain.gd")
const EnemyMotion := preload("res://src/presentation/enemy_motion.gd")

# The world's kits whose GLB bodies carry the bake (assets/models/world_one/enemy_*.glb).
const WORLD_KITS := {
	1: [
		preload("res://src/combat/chaser.gd"), preload("res://src/combat/lobber.gd"),
		preload("res://src/combat/hooker.gd"), preload("res://src/combat/mag_trapper.gd"),
		preload("res://src/combat/jolt_layer.gd"), preload("res://src/combat/plated_brute.gd"),
		preload("res://src/combat/ramp_flipper.gd"), preload("res://src/combat/boom_tender.gd"),
		preload("res://src/combat/reactor_relic.gd"), preload("res://src/combat/foreman.gd"),
		preload("res://src/combat/dispatcher.gd"), preload("res://src/combat/swatter.gd"),
		preload("res://src/combat/gyro_jammer.gd"), preload("res://src/combat/swarm_remnant.gd"),
		preload("res://src/combat/bola_thrower.gd"), preload("res://src/combat/deflector.gd"),
		preload("res://src/combat/netcaster.gd"), preload("res://src/combat/winch_drone.gd"),
		preload("res://src/combat/catch_trap.gd"), preload("res://src/combat/pit_jaw.gd"),
		preload("res://src/combat/miniboss.gd"), preload("res://src/combat/vault.gd"),
	],
}
# The GLB scenes the world's rigged kits seat on screen (foreman, dispatcher, splitter and its pieces).
const WORLD_RIGS := {
	1: [
		"res://assets/models/world_one/enemy_foreman.glb", "res://assets/models/world_one/enemy_dispatcher.glb",
		"res://assets/models/world_one/enemy_splitter.glb", "res://assets/models/world_one/enemy_splitter_piece.glb",
	],
}

static var _warm := {}
# Rig scenes held for the session, so every spawn's load() returns the scene whose meshes were readied.
static var _held := {}

var ctx
var _queue: Array = []


static func hook(ctx_ref) -> void:
	var node := new()
	node.name = "BakeWarm"
	node.ctx = ctx_ref
	ctx_ref.root.add_child(node)
	ctx_ref.events.stage_entered.connect(node._on_stage_entered)


func _on_stage_entered(stage: int, _retry: bool) -> void:
	if SimClock.ticks and not Terrain.threaded_in_bot_runs:
		return
	for row in ctx.stages.DEFS:
		if row["stage"] == stage:
			var world := int(row.get("world", 0))
			for item in WORLD_KITS.get(world, []) + (WORLD_RIGS.get(world, []) if EnemyMotion.active() else []):
				if not _warm.has(item) and not _queue.has(item):
					_queue.append(item)
			return


func _process(_delta: float) -> void:
	if not _queue.is_empty():
		warm(_queue.pop_front())


# The ramp every shaded twin draws, then one kit's shared meshes (a script's _parts(), or a
# rig scene's own meshes) with their tangent-safe copies.
static func warm(item) -> void:
	BakeLook.ramp()
	if _warm.has(item):
		return
	_warm[item] = true
	if item is Script:
		for mesh in meshes(item.call("_parts")):
			BakeLook.tangent_safe(mesh)
	elif ResourceLoader.exists(item):
		var scene := load(item) as PackedScene
		_held[item] = scene
		var model := scene.instantiate()
		for view: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			if view.mesh != null:
				BakeLook.tangent_safe(view.mesh)
		model.free()


# Every Mesh in a kit's parts, however the kit shapes them (a list of rows or a dictionary).
static func meshes(parts) -> Array:
	var out := []
	if parts is Mesh:
		out.append(parts)
	elif parts is Array:
		for item in parts:
			out.append_array(meshes(item))
	elif parts is Dictionary:
		for item in parts.values():
			out.append_array(meshes(item))
	return out
