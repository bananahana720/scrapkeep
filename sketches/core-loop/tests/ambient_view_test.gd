extends SceneTree

const AmbientKinds := preload("res://src/core/ambient_kinds.gd")
const AmbientLife := preload("res://src/presentation/ambient_life.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const T := preload("res://tests/support/t.gd")

# Ambient life's view (ambient_life.gd) against a minimal fake context: with no GLB it builds
# nothing, with stand-in models (a mesh, a stray body, three clips) it draws at most CAP instances
# that carry no body, no shadow and repeating loops, it hides for the Warden, and neither the
# view nor the pool can publish an event or deal damage.

const SOURCES := ["res://src/presentation/ambient_life.gd", "res://src/presentation/ambient_pool.gd", "res://src/presentation/ambient_homes.gd"]
const BANNED := ["emit_signal", ".emit(", "damage", "collision_layer", "collision_mask", "add_to_group", "GameEvents"]

var _t := T.new("ambient_view_test")


class FakeStage:
	extends RefCounted
	var map := "park_dam"


class FakeStages:
	extends RefCounted
	func of(_stage: int) -> FakeStage:
		return FakeStage.new()


class FakeTerrain:
	extends RefCounted
	var stage := 1
	var map := ParkMap.new("res://src/world/park/park_dam.json")
	func is_ready(_stage: int) -> bool:
		return true
	func map_for(_stage: int):
		return map
	func ground_callable(_stage: int) -> Callable:
		return func(x: float, z: float, lift: float) -> Vector3: return Vector3(x, 1.0 + lift, z)


class FakeFlow:
	extends RefCounted
	var boss_active := false
	func in_play() -> bool:
		return true


class FakePlayer:
	extends RefCounted
	var node := Node3D.new()
	func shown_position() -> Vector3:
		return node.global_position


class FakeCtx:
	extends RefCounted
	var events: Node
	var stages := FakeStages.new()
	var terrain := FakeTerrain.new()
	var flow := FakeFlow.new()
	var player := FakePlayer.new()


func _initialize() -> void:
	_main()


func _main() -> void:
	await process_frame
	await _run()
	quit(_t.verdict())


func _bodies(node: Node) -> int:
	return node.find_children("*", "CollisionObject3D", true, false).size()


# A stand-in GLB: one lit mesh that casts shadows, a stray static body, and idle/move/react clips that do not loop.
func _model() -> PackedScene:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	mesh.mesh = BoxMesh.new()
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(mesh)
	mesh.owner = root
	var body := StaticBody3D.new()
	body.name = "Stray"
	root.add_child(body)
	body.owner = root
	var player := AnimationPlayer.new()
	player.name = "Anim"
	var library := AnimationLibrary.new()
	for clip in ["idle", "move", "react"]:
		var animation := Animation.new()
		animation.length = 1.0
		library.add_animation(clip, animation)
	player.add_animation_library("", library)
	root.add_child(player)
	player.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	return scene


func _run() -> void:
	var events := GameEvents.new()
	root.add_child(events)
	var ctx := FakeCtx.new()
	ctx.events = events
	root.add_child(ctx.player.node)
	var park: Dictionary = ctx.terrain.map.park
	_t.check("fake park loads", ctx.terrain.map.ok and not park.is_empty())

	# No GLB anywhere (this slice): the node holds no model and no body, and ticking it costs nothing.
	var bare := AmbientLife.new()
	root.add_child(bare)
	bare.setup(ctx)
	var models_exist := AmbientKinds.for_park("park_dam").any(func(id): return ResourceLoader.exists(AmbientKinds.row(id)["model"]))
	if not models_exist:
		_t.check("no GLB: no pool, no instance", bare.pool == null and _alive(bare) == 0)
	bare._process(0.1)
	_t.eq("no CollisionObject3D without models", _bodies(bare), 0)
	bare.free()

	# Stand-in models for every Spillway kind.
	var life := AmbientLife.new()
	for id in AmbientKinds.for_park("park_dam"):
		life.models[id] = _model()
	root.add_child(life)
	life.setup(ctx)
	_t.check("stand-ins build a pool", life.pool != null and life.pool.members.size() > 0, str(life.pool.members.size() if life.pool else 0))
	# Stand by the first home: the nearest members go live.
	var home: Vector2 = life.pool.members[0].home
	ctx.player.node.global_position = Vector3(home.x + 40.0, 1.0, home.y)
	var peak := 0
	for i in 150:
		life._process(0.05)
		peak = maxi(peak, _alive(life))
	_t.check("instances drawn (%d), at most CAP" % peak, peak > 0 and peak <= AmbientKinds.CAP)
	_t.eq("no CollisionObject3D in the subtree", _bodies(life), 0)
	var shadows := true
	var ranged := true
	var loops := true
	var checked := 0
	for view in life.find_children("*", "GeometryInstance3D", true, false):
		checked += 1
		shadows = shadows and view.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ranged = ranged and view.visibility_range_end == 140.0
	for player in life.find_children("*", "AnimationPlayer", true, false):
		for clip in player.get_animation_list():
			var want := Animation.LOOP_NONE if String(clip).ends_with("react") else Animation.LOOP_LINEAR
			loops = loops and player.get_animation(clip).loop_mode == want
	_t.check("every mesh (%d) casts no shadow, ends at 140 m" % checked, checked > 0 and shadows and ranged)
	_t.check("idle and move loop, react plays once into its hold", loops)
	_t.check("an instance plays a loop clip", life.find_children("*", "AnimationPlayer", true, false).any(func(p): return p.is_playing()))
	_t.check("two audio voices, quiet past FALLOFF_M", life.voices.size() == AmbientKinds.MAX_VOICES and life.voices[0].max_distance == AmbientKinds.FALLOFF_M)

	# The Warden hides everything until the stage is entered again.
	events.warden_engaged.emit(1)
	for i in 20:
		life._process(0.05)
	_t.check("warden_engaged hides all", life.pool.drawn().is_empty() and not life.visible)
	events.stage_entered.emit(1, false)
	for i in 3:
		await physics_frame
	for i in 60:
		life._process(0.05)
	_t.check("stage re-entry brings them back", not life.pool.drawn().is_empty() and life.visible)
	ctx.flow.boss_active = true
	for i in 20:
		life._process(0.05)
	_t.check("boss_active hides all", life.pool.drawn().is_empty() and not life.visible)
	ctx.flow.boss_active = false
	events.stage_content_cleared.emit("clear")
	_t.check("stage_content_cleared hides the node", not life.visible)

	await _unfit()

	# Source: nothing here publishes an event, deals damage or opens a collision layer.
	for path in SOURCES:
		var code := ""
		for line in FileAccess.get_file_as_string(path).split("\n"):
			code += line.split("#")[0] + "\n"
		for word in BANNED:
			_t.check("%s has no %s" % [path.get_file(), word], not code.contains(word))

	# A call still playing at quit leaves its wav and playback in the AudioServer ("resources still in
	# use at exit"). Free the view, which stops its voices, then step frames until no playback holds a stream.
	var held: Array = life._streams.values().filter(func(s): return s != null)
	print("ambient voices playing at teardown: %d of %d streams loaded" % [life.voices.filter(func(v): return v.playing).size(), held.size()])
	life.free()
	var released := false
	for frame in 600:
		# `held` and the lambda's own argument are the two references left once the playbacks are gone.
		if not held.any(func(s): return s.get_reference_count() > 2):
			print("ambient streams released after %d frames" % frame)
			released = true
			break
		await process_frame
	_t.check("ambient streams released before quit", released)


# The build veto: steep ground and a structure over the ground are unfit, flat open ground is fit, and a ceiling
# perch needs its roof.
func _unfit() -> void:
	var flat := func(x: float, z: float, lift: float) -> Vector3: return Vector3(x, 1.0 + lift, z)
	var steep := func(x: float, z: float, lift: float) -> Vector3: return Vector3(x, x * 0.8 + lift, z)
	var gentle := func(x: float, z: float, lift: float) -> Vector3: return Vector3(x, x * 0.4 + lift, z)
	_t.check("ground at 39 degrees is unfit", AmbientLife.unfit(steep, null, Vector2(5.0, 5.0), "ground"))
	_t.check("ground at 22 degrees is fit", not AmbientLife.unfit(gentle, null, Vector2(5.0, 5.0), "ground"))
	var roof := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(10.0, 2.0, 10.0)
	roof.add_child(shape)
	roof.position = Vector3(200.0, 6.0, 200.0)
	root.add_child(roof)
	for i in 3:
		await physics_frame
	var space := root.get_world_3d().direct_space_state
	_t.check("open flat ground is fit", not AmbientLife.unfit(flat, space, Vector2(0.0, 0.0), "ground"))
	_t.check("ground under a structure is unfit", AmbientLife.unfit(flat, space, Vector2(200.0, 200.0), "rim"))
	_t.check("a ceiling perch under a structure is fit", not AmbientLife.unfit(flat, space, Vector2(200.0, 200.0), "ceiling"))
	_t.check("a ceiling perch with no roof is unfit", AmbientLife.unfit(flat, space, Vector2(0.0, 0.0), "ceiling"))
	_t.check("a ceiling perch with no physics space is unfit", AmbientLife.unfit(flat, null, Vector2(200.0, 200.0), "ceiling"))
	_t.check("a ceiling perch on sloped floor under a roof is fit", not AmbientLife.unfit(func(x: float, z: float, lift: float) -> Vector3: return Vector3(x, 1.0 + (x - 200.0) * 0.8 + lift, z), space, Vector2(200.0, 200.0), "ceiling"))
	var shelf := StaticBody3D.new()
	var shelf_shape := CollisionShape3D.new()
	shelf_shape.shape = BoxShape3D.new()
	(shelf_shape.shape as BoxShape3D).size = Vector3(10.0, 0.4, 10.0)
	shelf.add_child(shelf_shape)
	shelf.position = Vector3(-200.0, 1.0 + AmbientLife.ROOF_MIN_M - 0.5, -200.0)
	root.add_child(shelf)
	var high := StaticBody3D.new()
	var high_shape := CollisionShape3D.new()
	high_shape.shape = BoxShape3D.new()
	(high_shape.shape as BoxShape3D).size = Vector3(10.0, 0.4, 10.0)
	high.add_child(high_shape)
	high.position = Vector3(-400.0, 1.0 + AmbientLife.ROOF_REACH_M + 2.0, -400.0)
	root.add_child(high)
	for i in 3:
		await physics_frame
	_t.check("a shelf under ROOF_MIN_M is no roof", AmbientLife.unfit(flat, space, Vector2(-200.0, -200.0), "ceiling"))
	_t.check("a roof past ROOF_REACH_M is no roof", AmbientLife.unfit(flat, space, Vector2(-400.0, -400.0), "ceiling"))
	shelf.free()
	high.free()
	roof.free()


func _alive(life: Node) -> int:
	var n := 0
	for child in life.get_children():
		if child is Node3D and not child is AudioStreamPlayer3D and child.visible:
			n += 1
	return n
