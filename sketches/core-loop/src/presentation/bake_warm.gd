extends Node

const AppShell := preload("res://src/core/app_shell.gd")
const BakeLook := preload("res://src/presentation/bake_look.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const Terrain := preload("res://src/world/terrain.gd")
const Director := preload("res://src/world/director.gd")
const EnemyMotion := preload("res://src/presentation/enemy_motion.gd")
const ArmourMarks := preload("res://src/presentation/armour_marks.gd")
const Vfx := preload("res://src/presentation/vfx.gd")
const CodexStyle := preload("res://src/presentation/codex_style.gd")
const Combat := preload("res://src/combat/combat.gd")
const ScrapField := preload("res://src/build/scrap_field.gd")
const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const MachineFx := preload("res://src/presentation/machine_fx.gd")
const ArenaMindDress := preload("res://src/presentation/arena_mind_dress.gd")
const MindDress := preload("res://src/boss/mind_dress.gd")
const World23ChunkCraft := preload("res://src/presentation/world23_chunk_craft.gd")

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
	3: [
		preload("res://src/combat/kite_drone.gd"), preload("res://src/combat/gap_net.gd"),
		preload("res://src/combat/gyro_jammer.gd"), preload("res://src/combat/deflector.gd"),
	],
}
const WORLD_RIGS := {
	1: [
		"res://assets/models/world_one/enemy_foreman.glb", "res://assets/models/world_one/enemy_dispatcher.glb",
		"res://assets/models/world_one/enemy_splitter.glb", "res://assets/models/world_one/enemy_splitter_piece.glb",
	],
	3: [
		"res://assets/models/highdraft/boss_mind_base.glb",
		"res://assets/models/highdraft/boss_mind_kit.glb",
	],
}

const FIRSTS := ["scrap_pickup", "armour_read", "synergy_ring", "arc_mark", "machine_words", "hero_chunks"]
const GLYPHS_A_FRAME := 4
const OUT_OF_SIGHT := Vector3(0.0, -10000.0, 0.0)

static var _warm := {}
static var _stood := {}
static var _held := {}
static var _loading: Array[String] = []
static var _firsts_done := false
static var _kept: Array[Material] = []
static var _glows: Array[Material] = []

var ctx
var _queue: Array = []
var _to_stand: Array = []
var _standing := ""
var _first_queue: Array = []
var _shown: Node3D


static func hook(ctx_ref) -> void:
	var node := new()
	node.name = "BakeWarm"
	node.process_mode = Node.PROCESS_MODE_ALWAYS
	node.ctx = ctx_ref
	ctx_ref.root.add_child(node)
	ctx_ref.events.stage_entered.connect(node._on_stage_entered)


func _on_stage_entered(stage: int, _retry: bool) -> void:
	if SimClock.ticks and not Terrain.threaded_in_bot_runs:
		return
	for row in ctx.stages.DEFS:
		if row["stage"] == stage:
			var world := int(row.get("world", 0))
			_to_stand = Director.kinds_sent(row, ctx.stages).filter(func(kind) -> bool: return not _stood.has(kind))
			_to_stand.erase(_standing)
			for item in WORLD_KITS.get(world, []) + (WORLD_RIGS.get(world, []) if EnemyMotion.active() else []):
				var owed: bool = not _warm.has(item) or (item is Script and kind_of(item) in _to_stand)
				if owed and not _queue.has(item):
					_queue.append(item)
			if not _firsts_done and _first_queue.is_empty():
				_first_queue = firsts()
			if world == 3:
				warm_mind_shaders()
				if not _first_queue.has("mind_shaders") and not _warm.has("mind_shaders"):
					_first_queue.push_front("mind_shaders")
			return


static func warm_mind_shaders() -> void:
	if _warm.has("mind_shaders_cpu"):
		return
	_warm["mind_shaders_cpu"] = true
	if not AppShell.headless():
		ArenaMindDress.prepare()
		MindDress.prepare()
	ArenaMindDress.warm_kit()
	World23ChunkCraft.warm_shaders()


func _exit_tree() -> void:
	settle()


static func settle() -> void:
	for path: String in _loading:
		if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_held[path] = ResourceLoader.load_threaded_get(path)
	_loading.clear()
	ArenaMindDress.settle()
	MindDress.settle()


func _process(_delta: float) -> void:
	if _switched_off():
		return
	for path: String in _loading.duplicate():
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_held[path] = ResourceLoader.load_threaded_get(path)
		if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_loading.erase(path)
	if _shown != null:
		if _shown.has_meta("spawn_warm") and not _shown.has_meta("debris_warm"):
			_shown.set_meta("debris_warm", true)
			glow_warm(_shown)
			return
		if _standing != "":
			_stood[_standing] = true
			_standing = ""
		_shown.queue_free()
		_shown = null
	if not _queue.is_empty():
		var item = _queue.pop_front()
		warm(item)
		if item is Script and kind_of(item) in _to_stand:
			_standing = kind_of(item)
			_to_stand.erase(_standing)
			_shown = spawn_holder(self)
			spawn_into(item, _shown, ctx.player, ctx.spawner.get("ground") if ctx.spawner != null else null)
	elif not _first_queue.is_empty():
		_shown = first_view(_first_queue.pop_front(), self)
		_firsts_done = _first_queue.is_empty()


func _switched_off() -> bool:
	var above := get_parent()
	while above != null and above.process_mode == Node.PROCESS_MODE_INHERIT:
		above = above.get_parent()
	return above != null and above.process_mode == Node.PROCESS_MODE_DISABLED


static func firsts() -> Array:
	var queue: Array = []
	for first: String in FIRSTS:
		if first != "machine_words":
			queue.append(first)
			continue
		for i in ceili(MachineFx.WARM_GLYPHS.length() / float(GLYPHS_A_FRAME)):
			queue.append("machine_words:%d" % i)
	for id in CodexStyle.CATEGORIES:
		queue.append("codex_icon:" + String(id))
	return queue


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
		"mind_shaders":
			_warm["mind_shaders"] = true
			warm_mind_shaders()
			var panel := MindDress.build_takeover_panel()
			views = [panel]
		"hero_chunks":
			# Godot headless Dummy rasterizer mesh RIDs are not thread-safe; load on main thread when headless.
			var path := HeroAssets.CHUNKS_PATH
			if ResourceLoader.exists(path) and not _held.has(path) and not _loading.has(path):
				if AppShell.headless():
					_held[path] = load(path)
				elif ResourceLoader.load_threaded_request(path) == OK:
					_loading.append(path)
		_ when first.begins_with("machine_words:"):
			views = MachineFx.warm_views(MachineFx.WARM_GLYPHS.substr(int(first.get_slice(":", 1)) * GLYPHS_A_FRAME, GLYPHS_A_FRAME))
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
	enemy.position = Vector3.ZERO
	enemy.remove_from_group("enemy")
	var bodies: Array = enemy.find_children("*", "CollisionObject3D", true, false)
	bodies.append(enemy)
	for body in bodies:
		if body is CollisionObject3D:
			body.collision_layer = 0
			body.collision_mask = 0


static func death_warm(holder: Node3D) -> int:
	var twins := {}
	for view: MeshInstance3D in holder.find_children("*", "MeshInstance3D", true, false):
		var mat: Material = view.material_override if view.material_override != null else view.get_active_material(0)
		var twin := BakeLook.unbaked(mat)
		if twin == null or twin == mat or twins.has(twin):
			continue
		twins[twin] = true
		var glow := twin.duplicate() as StandardMaterial3D
		glow.emission_enabled = not glow.emission_enabled
		_glows.append(glow)
		for look in [twin, glow]:
			var box := MeshInstance3D.new()
			box.mesh = BoxMesh.new()
			box.material_override = look
			holder.add_child(box)
	var body := holder.get_child(0) as Node3D if holder.get_child_count() > 0 else null
	if body != null and body.get("kind") is String:
		EnemyMotion.scatter(body, body.kind, Vector3.FORWARD)
	return twins.size()


static func glow_warm(holder: Node3D) -> int:
	var body := holder.get_child(0) as Node3D if holder.get_child_count() > 0 else null
	if body == null:
		return 0
	for part: Node3D in body.find_children("*", "Node3D", true, false):
		part.visible = true
	death_warm(holder)
	var owned: Array = body.owned_materials() if body.has_method("owned_materials") else []
	if owned.is_empty():
		return 0
	var flipped := {}
	var copies := 0
	for view: MeshInstance3D in holder.find_children("*", "MeshInstance3D", true, false):
		if view.mesh == null or not view.is_visible_in_tree():
			continue
		var wears := false
		for i in view.mesh.get_surface_count():
			wears = wears or view.get_active_material(i) in owned
		if not wears:
			continue
		var copy := MeshInstance3D.new()
		copy.name = view.name + "Glow"
		copy.mesh = view.mesh
		copy.skin = view.skin
		copy.cast_shadow = view.cast_shadow
		copy.transparency = view.transparency
		copy.material_overlay = view.material_overlay
		copy.layers = view.layers
		copy.transform = view.transform
		view.get_parent().add_child(copy)
		copy.skeleton = view.skeleton
		for i in view.mesh.get_surface_count():
			var mat: Material = view.get_active_material(i)
			if mat in owned and mat is StandardMaterial3D:
				if not flipped.has(mat):
					var glow := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
					glow.emission_enabled = not glow.emission_enabled
					_glows.append(glow)
					flipped[mat] = glow
				mat = flipped[mat]
			copy.set_surface_override_material(i, mat)
		copies += 1
	return copies


static func kind_of(kit: Script) -> String:
	return kit.resource_path.get_file().get_basename()


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
