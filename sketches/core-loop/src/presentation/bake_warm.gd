extends Node

# Readies the bake look for a world's enemies after stage entry, one kit a frame, so the first
# spawn of a kind does not rebuild its meshes' tangents mid-fight (perf lane F: at f451 of a
# stage 1 run three first spawns spent 4.5-8 ms each in BakeLook.dress, almost all of it in
# tangent_safe; gate/perf-dress-35d7d63c/). Each kit's static _parts() is the mesh set every one
# of its spawns shares, so the copies tangent_safe hangs off those meshes are the ones dress
# finds later. On screen a rigged kit (SpecialRig.seat) draws its GLB's own scene instead, so
# that scene is held, as hero_assets holds the Warden scenes, and its meshes readied the same way.
# Materials are left to dress: a twin depends on how the spawn uses its surfaces.
# The kinds the stage can send (Director.kinds_sent: its packs and its elite) are then each built
# once more, as a spawn builds them (the kit's own setup(), dressed by its own deferred bake), in an
# inert holder far under the stage for one frame, so the render pipelines their surfaces need
# compile then and not at the first spawn's first frame (six surface pipelines at f451 on the 4080;
# #241 comment 6399644476). The holder stands a second frame with what play adds to the kind
# (glow_warm: its hidden parts shown, its death debris, its owned glow switched the other way).
# A kind stands once a session, at the first stage that can send it. Until
# 10 November 2026 the list was the dam's ordinary packs by hand, and the elite's plated brute, the
# one skinned body among them, built its pipelines the frame the dropship landed it (77 to 81 ms on
# the 4080, seed 40317 f4345, three runs of three).
# After them come the run's first moments, once a session: the first kill's scrap pickups, the
# first armour read (its class icon and stamp words), the first synergy ring and the first arc
# mark each draw a material nothing else drew before, and on the 4080 a lock pack's first multi-kill
# paid for all of them in one frame (stage 1 f3822, 47-61 ms, 22 pipelines the frame after; unit 23
# receipt on #494). The first machine word (KLANG on a heavy hit) rasterizes its glyphs in that
# frame's deferred Label3D update (44 ms of it on the cloud box), so word labels with every glyph
# a word draws stand first too, a few glyphs a frame (all of them in one frame was 51 ms on the 4080). Each is built by its owner's own builder in an inert holder for
# one frame, and the codex category icons it paints on the CPU are drawn ahead. The materials are held, so their shaders stay compiled.
# A bot run that builds stages whole skips it, like fleet._warm_scripts, so frame costs stay as
# they were where seeds must replay.

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

# The first moments with a view, in the order the warm builds them, one a frame; then each codex
# category icon ("codex_icon:<category>"), one a frame. "hero_chunks" starts a threaded load of the kill
# chunks' glb and holds it when done, so the first discovery burst reads it from the cache, not the disk.
const FIRSTS := ["scrap_pickup", "armour_read", "synergy_ring", "arc_mark", "machine_words", "hero_chunks"]
# The machine word glyphs one warm frame rasterizes.
const GLYPHS_A_FRAME := 4
# Far under every stage, so the two frames a warm spawn stands there are never seen.
const OUT_OF_SIGHT := Vector3(0.0, -10000.0, 0.0)

static var _warm := {}
# Kinds a spawn warm has stood, so each stands once a session.
static var _stood := {}
# Rig scenes held for the session, so every spawn's load() returns the scene whose meshes were readied.
static var _held := {}
# Threaded loads a first started, held once done.
static var _loading: Array[String] = []
static var _firsts_done := false
# The first moments' materials, held so the shaders their views compiled are never freed.
static var _kept: Array[Material] = []
# death_warm's glowing twins, held so their shaders stay compiled (BakeLook holds the resting ones).
static var _glows: Array[Material] = []

var ctx
var _queue: Array = []
# The kinds the entered stage can send that have not stood yet.
var _to_stand: Array = []
# The kind whose spawn warm is standing now.
var _standing := ""
var _first_queue: Array = []
var _shown: Node3D


static func hook(ctx_ref) -> void:
	var node := new()
	node.name = "BakeWarm"
	# The run's briefing pauses the tree a few frames after the stage is entered. The warm goes on
	# under it, behind a still picture, and not in the first frames the player rolls.
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
			return


# Teardown: a load still on the loader thread is collected, so a quit before it lands leaves no
# loader thread running (the quit abort, exit 134, scrapkeep#322).
func _exit_tree() -> void:
	settle()


static func settle() -> void:
	for path: String in _loading:
		if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_held[path] = ResourceLoader.load_threaded_get(path)
	_loading.clear()


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
			# What play adds to the kind joins the holder now, and a node that leaves before a frame is
			# drawn never reaches the renderer: the holder stands this frame too, then goes.
			_shown.set_meta("debris_warm", true)
			glow_warm(_shown)
			return
		# Stood only now, with both frames drawn: a warm node freed part way leaves the kind to the next.
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
			# Held before setup runs, so a setup that fails still leaves, two frames on.
			_shown = spawn_holder(self)
			spawn_into(item, _shown, ctx.player, ctx.spawner.get("ground") if ctx.spawner != null else null)
	elif not _first_queue.is_empty():
		_shown = first_view(_first_queue.pop_front(), self)
		# Done only once built, so a warm node freed part way leaves the rest to the next one.
		_firsts_done = _first_queue.is_empty()


# Running always is for the pause alone. A game switched off (a test freezes its game this way to
# read a still tree) stops the warm with it: the mode in force above this node is the nearest
# ancestor's that sets one.
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
			# The headless renderer's mesh RIDs are not thread-safe (thread_guard.gd), so there the glb's
			# ArrayMeshes load on the main thread, as park_props._uncached does.
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


# A kit as a spawn builds it, under `parent`: Combat.spawn_enemy's add then setup() (an empty spec
# but its kind), so its body, paint and extras are the live ones, and its own deferred bake
# dresses it. The holder never processes, and the kit and everything it built leave the enemy
# group and every collision layer, so nothing in play finds it; the holder is its world root and
# the body is put back under it after setup, so nothing it builds lands in the stage.
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
	# A kit may seat itself on the ground it is handed (the dispatcher climbs its mast, which put a
	# stood one on the stage at the map's origin): the body goes back under the holder, and every
	# collider it built (the mast is terrain to the ball) leaves its layers with it.
	enemy.position = Vector3.ZERO
	enemy.remove_from_group("enemy")
	var bodies: Array = enemy.find_children("*", "CollisionObject3D", true, false)
	bodies.append(enemy)
	for body in bodies:
		if body is CollisionObject3D:
			body.collision_layer = 0
			body.collision_mask = 0


# A kind's death debris boxes draw with BakeLook.unbaked twins of its body's materials
# (EnemyMotion.scatter), and on the 4080 a twin's first use compiled its look's shader in the death
# frame: about 11 ms each for the first chaser and the first lobber at dam f3870 (#587 comment
# 6509692838). Called on a spawn warm's holder the frame after its kit was built, so its own deferred
# bake has dressed it: every dressed material there gets its twin, put to use on a box in the holder.
# The twins stay in BakeLook's cache, so a later death of the kind finds its look compiled. A body
# paint the kit owns is copied at the death, so its twin carries the paint's glow state then: a kill
# mid hit-flash or wind-up cue has emission on (enemy.gd _update_flash, chaser.gd's cue), another
# look, so each twin is also put to use with its emission switched the other way, and held.
# The boxes only count once a frame has been drawn with them in the tree: until 10 November 2026
# the holder was freed in the call that added them, so the renderer never saw one and the first
# death of a kind still built its box look (about 11 ms on the frame the debris appeared).
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
	# The rest of a death's debris is the body's own meshes thrown as pieces. They are built here as
	# a death builds them (inert, like everything under the holder), so anything a piece draws that
	# the standing body did not is drawn ahead as well.
	var body := holder.get_child(0) as Node3D if holder.get_child_count() > 0 else null
	if body != null and body.get("kind") is String:
		EnemyMotion.scatter(body, body.kind, Vector3.FORWARD)
	return twins.size()


# The holder's second frame. A stood body is at rest, but in play the kit flips the glow on the
# materials it owns (a hit flash; the plated brute's lit rim from its first tick as an elite) and
# shows parts it built hidden (the plate cracks), and each of those is a look the stood body never
# drew: on the 4080 the elite brute's lit plates built two pipelines the frame it landed (76 to
# 86 ms, seed 40317 f4344, the #724 read). So first the hidden parts are shown, then the death
# debris is thrown (death_warm: its boxes and the body's own meshes as pieces, cracks among them),
# then every mesh in the holder that wears a material the body owns gets a copy beside it (same
# mesh, skin and skeleton) wearing that material with its glow switched the other way. The copies'
# materials are held, so their shaders stay compiled. Returns how many copies stand.
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
		# A sibling, so the skeleton path reads the same from the copy.
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
