extends Node

# Readies the bake look for a world's enemies after stage entry, one kit a frame, so the first
# spawn of a kind does not rebuild its meshes' tangents mid-fight (perf lane F: at f451 of a
# stage 1 run three first spawns spent 4.5-8 ms each in BakeLook.dress, almost all of it in
# tangent_safe; gate/perf-dress-35d7d63c/). Each kit's static _parts() is the mesh set every one
# of its spawns shares, so the copies tangent_safe hangs off those meshes are the ones dress
# finds later. On screen a rigged kit (SpecialRig.seat) draws its GLB's own scene instead, so
# that scene is held, as hero_assets holds the Warden scenes, and its meshes readied the same way.
# Materials are left to dress: a twin depends on how the spawn uses its surfaces.
# The kinds stage 1 spawns are then each built once more, as a spawn builds them (the kit's own
# setup(), dressed by its own deferred bake), in an inert holder far under the stage for one frame,
# so the render pipelines their surfaces need compile then and not at the first spawn's first
# frame (six surface pipelines at f451 on the 4080; #241 comment 6399644476).
# After them come the run's first moments, once a session: the first kill's scrap pickups, the
# first armour read (its class icon and stamp words), the first synergy ring and the first arc
# mark each draw a material nothing else drew before, and on the 4080 a lock pack's first multi-kill paid for all of them in one
# frame (stage 1 f3822, 47-61 ms, 22 pipelines the frame after; unit 23 receipt on #494). Each is
# built by its owner's own builder in an inert holder for one frame, and the codex category icons
# it paints on the CPU are drawn ahead. The materials are held, so their shaders stay compiled.
# A bot run that builds stages whole skips it, like fleet._warm_scripts, so frame costs stay as
# they were where seeds must replay.

const BakeLook := preload("res://src/presentation/bake_look.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const Terrain := preload("res://src/world/terrain.gd")
const EnemyMotion := preload("res://src/presentation/enemy_motion.gd")
const ArmourMarks := preload("res://src/presentation/armour_marks.gd")
const Vfx := preload("res://src/presentation/vfx.gd")
const CodexStyle := preload("res://src/presentation/codex_style.gd")
const Combat := preload("res://src/combat/combat.gd")
const ScrapField := preload("res://src/build/scrap_field.gd")
const HeroAssets := preload("res://src/presentation/hero_assets.gd")

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

# Stage 1's pack kinds (alpha_defs PACKS_DAM; its elite and set pieces are not here), by kind
# name: the ones the warm also builds once.
const SPAWN_WARM := ["chaser", "lobber", "mag_trapper", "jolt_layer", "hooker", "ramp_flipper", "boom_tender"]
# The first moments with a view, in the order the warm builds them, one a frame; then each codex
# category icon ("codex_icon:<category>"), one a frame. "hero_chunks" starts a threaded load of the kill
# chunks' glb and holds it when done, so the first discovery burst reads it from the cache, not the disk.
const FIRSTS := ["scrap_pickup", "armour_read", "synergy_ring", "arc_mark", "hero_chunks"]
# Far under every stage, so the one frame a warm spawn stands there is never seen.
const OUT_OF_SIGHT := Vector3(0.0, -10000.0, 0.0)

static var _warm := {}
# Rig scenes held for the session, so every spawn's load() returns the scene whose meshes were readied.
static var _held := {}
# Threaded loads a first started, held once done.
static var _loading: Array[String] = []
static var _firsts_done := false
# The first moments' materials, held so the shaders their views compiled are never freed.
static var _kept: Array[Material] = []

var ctx
var _queue: Array = []
var _first_queue: Array = []
var _shown: Node3D


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
			if not _firsts_done and _first_queue.is_empty():
				_first_queue = firsts()
			return


func _process(_delta: float) -> void:
	for path: String in _loading.duplicate():
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_held[path] = ResourceLoader.load_threaded_get(path)
		if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_loading.erase(path)
	if _shown != null:
		_shown.queue_free()
		_shown = null
	if not _queue.is_empty():
		var item = _queue.pop_front()
		warm(item)
		if item is Script and kind_of(item) in SPAWN_WARM:
			# Held before setup runs, so a setup that fails still leaves with the next frame.
			_shown = spawn_holder(self)
			spawn_into(item, _shown, ctx.player, ctx.spawner.get("ground") if ctx.spawner != null else null)
	elif not _first_queue.is_empty():
		_shown = first_view(_first_queue.pop_front(), self)
		# Done only once built, so a warm node freed part way leaves the rest to the next one.
		_firsts_done = _first_queue.is_empty()


static func firsts() -> Array:
	var queue: Array = FIRSTS.duplicate()
	for id in CodexStyle.CATEGORIES:
		queue.append("codex_icon:" + String(id))
	return queue


# One first moment's views, as their owners build them, in an inert holder under `parent`
# (null for a codex icon, which is drawn into its cache instead).
static func first_view(first: String, parent: Node) -> Node3D:
	var views: Array[Node3D] = []
	match first:
		"armour_read":
			views = ArmourMarks.warm_views()
		"synergy_ring":
			views = [Vfx.ring_view(0, Color.WHITE)]
		"arc_mark":
			views = [Combat.arc_mark_view()]
		"scrap_pickup":
			views = ScrapField.warm_views()
		"hero_chunks":
			var path := HeroAssets.CHUNKS_PATH
			if ResourceLoader.exists(path) and not _held.has(path) and ResourceLoader.load_threaded_request(path) == OK:
				_loading.append(path)
		_ when first.begins_with("codex_icon:"):
			CodexStyle.icon(first.trim_prefix("codex_icon:"))
	if views.is_empty():
		return null
	var holder := spawn_holder(parent)
	holder.name = "FirstWarm"
	holder.remove_meta("spawn_warm")
	holder.set_meta("first_warm", first)
	for view in views:
		holder.add_child(view)
		if view is GeometryInstance3D and view.material_override != null and not _kept.has(view.material_override):
			_kept.append(view.material_override)
	return holder


# A kit as a spawn builds it, under `parent`: Combat.spawn_enemy's add then setup() (an empty spec
# but its kind), so its body, paint and extras are the live ones, and its own deferred bake
# dresses it. The holder never processes, and the kit leaves the enemy group and every collision
# layer, so nothing in play finds it; the holder is its world root, so nothing it builds lands
# in the stage.
static func spawn_view(kit: Script, parent: Node, target, ground) -> Node3D:
	var holder := spawn_holder(parent)
	spawn_into(kit, holder, target, ground)
	return holder


static func spawn_holder(parent: Node) -> Node3D:
	var holder := Node3D.new()
	holder.name = "SpawnWarm"
	holder.set_meta("spawn_warm", true)
	holder.process_mode = Node.PROCESS_MODE_DISABLED
	holder.position = OUT_OF_SIGHT
	parent.add_child(holder)
	return holder


static func spawn_into(kit: Script, holder: Node3D, target, ground) -> void:
	var enemy: Node3D = kit.new()
	holder.add_child(enemy)
	enemy.setup(target, ground, holder, func() -> bool: return false, 1.0, {"kind": kind_of(kit)})
	enemy.remove_from_group("enemy")
	if enemy is CollisionObject3D:
		enemy.collision_layer = 0
		enemy.collision_mask = 0


# A kit's kind name: its script's file name (src/combat/mag_trapper.gd is "mag_trapper").
static func kind_of(kit: Script) -> String:
	return kit.resource_path.get_file().get_basename()


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
