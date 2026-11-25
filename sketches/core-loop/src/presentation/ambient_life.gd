extends Node3D

# Ambient life's thin view (AMBIENT-LIFE.md). Everything it decides lives in ambient_homes.gd (where),
# ambient_pool.gd (what each one does) and ambient_kinds.gd (the one record per kind); this node only
# builds a park's homes on stage entry, ticks the pool at 10 Hz, draws the live members from a small
# pool of reused GLB instances and plays their calls. A kind whose GLB is not built yet is skipped,
# so with no models the node holds nothing and does no work. It is candy: no physics body, no event,
# no damage, no shadow, and it hides for every boss and Warden beat.

const AmbientKinds := preload("res://src/core/ambient_kinds.gd")
const AmbientHomes := preload("res://src/presentation/ambient_homes.gd")
const AmbientPool := preload("res://src/presentation/ambient_pool.gd")
const EnemyMotion := preload("res://src/presentation/enemy_motion.gd")

const TICK_S := 0.1
const VIEW_END_M := 140.0
const ROOF_REACH_M := 14.0
const ROOF_MIN_M := 1.5
const FALLBACK_ROOF_M := 2.5
const WORLD_MASK := 1
# A home steeper than this (from the ground callable) or with a structure over it is vetoed at build.
const MAX_SLOPE_DEG := 30.0
const SLOPE_STEP_M := 1.0
const COVER_REACH_M := 40.0
const COVER_DY_M := 0.5
const PLAN_AFTER_STEPS := 2

var ctx
var map_id := ""
var pool: AmbientPool
var voices: Array[AudioStreamPlayer3D] = []
# Reused instances: kind -> free Array[Node3D]; member id -> the instance it wears now.
var _free := {}
var _worn := {}
var _alive := 0
var _scenes := {}
# Test seam: kind -> PackedScene standing in for a GLB that is not built yet.
var models := {}
var _streams := {}
var _active := true
var _latched := false
var _built_for := -1
var _entries := 0
var _since := 0.0
var _ground: Callable
var _prev := {}
var _loop_now := {}
var _fade_now := {}
var _plan_stage := -1
var _plan_wait := 0
var _planner: AmbientHomes.Planner


func setup(context) -> void:
	ctx = context
	name = "AmbientLife"
	ctx.events.stage_entered.connect(_stage_entered)
	ctx.events.stage_content_cleared.connect(_clear_stage)
	ctx.events.warden_engaged.connect(func(_stage: int): _latched = true)
	ctx.events.boss_arena_entered.connect(func(): _latched = true)
	for i in AmbientKinds.MAX_VOICES:
		var voice := AudioStreamPlayer3D.new()
		voice.name = "Voice%d" % i
		voice.bus = "Ambient" if AudioServer.get_bus_index("Ambient") != -1 else ("SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master")
		voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		voice.unit_size = 2.0
		voice.max_distance = AmbientKinds.FALLOFF_M
		add_child(voice)
		voices.append(voice)
	if ctx.terrain.is_ready(ctx.terrain.stage):
		_build_stage(ctx.terrain.stage)


func _stage_entered(stage: int, _retry: bool) -> void:
	_active = true
	_latched = false
	# A retry keeps its homes. A new stage's structures join the physics space on the next physics
	# steps, so the plan waits for them and the cover veto (unfit) sees a gatehouse built this frame.
	_entries += 1
	_cancel_plan()
	if stage == _built_for and pool != null:
		_build_stage(stage)
		return
	_release_all()
	pool = null
	# Planned via _physics_process instead of awaiting tree.physics_frame so freeing this node
	# mid-stage-entry never resumes a dangling coroutine on a freed instance.
	_plan_stage = stage
	_plan_wait = PLAN_AFTER_STEPS


func _physics_process(_delta: float) -> void:
	if _plan_stage < 0 or not is_inside_tree():
		return
	if _plan_wait > 0:
		_plan_wait -= 1
		if _plan_wait > 0:
			return
		# The plan a kind a physics step (AmbientHomes.Planner): planned whole it was 28 ms of one frame
		# just after the flume's entry on the cloud (scrapkeep#494). A newer entry drops this one.
		_planner = _begin_plan(_plan_stage)
		if _planner == null:
			_plan_stage = -1
			return
	if _planner != null and not _planner.step():
		var homes := _planner.homes
		_planner = null
		_plan_stage = -1
		_finish_plan(homes)


func _cancel_plan() -> void:
	_plan_stage = -1
	_plan_wait = 0
	_planner = null


func _exit_tree() -> void:
	_cancel_plan()


func _clear_stage(_reason: String) -> void:
	_cancel_plan()
	_active = false
	_latched = true
	visible = false


func _build_stage(stage: int) -> void:
	if stage == _built_for and pool != null:
		pool.reset()
		_release_all()
		return
	var planner = _begin_plan(stage)
	if planner == null:
		return
	while planner.step():
		pass
	_finish_plan(planner.homes)


# The stage's home planner, or null for a stage with no ambient life (no park, no kind with a model).
func _begin_plan(stage: int) -> AmbientHomes.Planner:
	_release_all()
	pool = null
	_built_for = stage
	map_id = String(ctx.stages.of(stage).map)
	var map = ctx.terrain.map_for(stage)
	var park = map.get("park") if map != null else null
	if not park is Dictionary or park.is_empty():
		return null
	var kinds := []
	for id in AmbientKinds.for_park(map_id):
		if models.has(id) or ResourceLoader.exists(AmbientKinds.row(id)["model"]):
			kinds.append(id)
	if kinds.is_empty():
		return null
	_ground = ctx.terrain.ground_callable(stage)
	var ground := _ground
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	return AmbientHomes.Planner.new(park, kinds, map_id.hash(), func(at: Vector2, perch: String) -> bool: return unfit(ground, space, at, perch))


func _finish_plan(homes: Array) -> void:
	for home in homes:
		if home["perch"] == "ceiling":
			home["roof"] = _roof_above(home["at"])
	pool = AmbientPool.new()
	pool.setup(homes, map_id.hash())
	_prev.clear()


# A spot the park file cannot judge: ground steeper than MAX_SLOPE_DEG, a structure standing over the ground (such
# as a gatehouse the heightfield does not know), or, for a ceiling perch, no real roof to hang from.
static func unfit(ground: Callable, space: PhysicsDirectSpaceState3D, at: Vector2, perch: String) -> bool:
	# A roost hangs from its roof, so the floor under it may slope.
	if perch == "ceiling":
		return space == null or not _has_roof(ground, space, at)
	var e := SLOPE_STEP_M
	var dx: float = (ground.call(at.x + e, at.y, 0.0).y - ground.call(at.x - e, at.y, 0.0).y) / (2.0 * e)
	var dz: float = (ground.call(at.x, at.y + e, 0.0).y - ground.call(at.x, at.y - e, 0.0).y) / (2.0 * e)
	if rad_to_deg(atan(Vector2(dx, dz).length())) > MAX_SLOPE_DEG:
		return true
	if space == null:
		return false
	var floor_y: float = ground.call(at.x, at.y, 0.0).y
	var query := PhysicsRayQueryParameters3D.create(Vector3(at.x, floor_y + COVER_REACH_M, at.y), Vector3(at.x, floor_y - 1.0, at.y), WORLD_MASK)
	var hit := space.intersect_ray(query)
	return not hit.is_empty() and float(hit["position"].y) - floor_y > COVER_DY_M


# A bat hangs only under real cover: something solid between ROOF_MIN_M and ROOF_REACH_M above the ground.
static func _has_roof(ground: Callable, space: PhysicsDirectSpaceState3D, at: Vector2) -> bool:
	var floor_y: float = ground.call(at.x, at.y, 0.0).y
	var query := PhysicsRayQueryParameters3D.create(Vector3(at.x, floor_y + 0.5, at.y), Vector3(at.x, floor_y + ROOF_REACH_M, at.y), WORLD_MASK)
	var hit := space.intersect_ray(query)
	return not hit.is_empty() and float(hit["position"].y) - floor_y >= ROOF_MIN_M


# One upward ray at build for a bat's ceiling: height above the ground there, else a low fallback.
func _roof_above(at: Vector2) -> float:
	var floor_y: float = _ground.call(at.x, at.y, 0.0).y
	var space := get_world_3d().direct_space_state
	if space != null:
		var query := PhysicsRayQueryParameters3D.create(Vector3(at.x, floor_y + 0.5, at.y), Vector3(at.x, floor_y + ROOF_REACH_M, at.y), WORLD_MASK)
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			return maxf(float(hit["position"].y) - floor_y - 0.1, FALLBACK_ROOF_M * 0.5)
	return FALLBACK_ROOF_M


func _process(delta: float) -> void:
	# A Warden or boss beat hides members through the pool's own fade (boss in _gather), so they
	# leave over 0.25 s instead of popping; the node goes dark once the last one has faded.
	var hiding: bool = _latched or ctx.flow.boss_active
	visible = _active and ctx.flow.in_play() and not (hiding and (pool == null or pool.drawn().is_empty()))
	if pool == null:
		return
	_since += delta
	if _since >= TICK_S:
		var dt := _since
		_since = 0.0
		_tick(dt)
	_draw(clampf(_since / TICK_S, 0.0, 1.0))


func _tick(dt: float) -> void:
	for m in pool.members:
		_prev[m.id] = [m.pos, m.facing]
	pool.step(dt, _gather())
	for m in pool.members:
		if m.wants_call:
			_voice(m, "call")
		if m.wants_react_sound:
			_voice(m, "react")


func _gather() -> Dictionary:
	var threats: Array = []
	var telegraphs: Array = []
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e is Node3D and not (e.has_method("is_dead") and e.is_dead()):
			threats.append(e.global_position)
	for g in get_tree().get_nodes_in_group("telegraph"):
		if is_instance_valid(g) and g is Node3D and g.is_visible_in_tree():
			var at: Vector3 = g.center if "center" in g else g.global_position
			telegraphs.append(at)
			threats.append(at)
	var ground := _ground
	return {
		"player": ctx.player.shown_position(), "threats": threats, "telegraphs": telegraphs,
		"boss": _latched or ctx.flow.boss_active or not _active, "reduced": EnemyMotion.motion_scale == 0.0,
		"ground": func(x: float, z: float) -> float: return (ground.call(x, z, 0.0) as Vector3).y,
	}


# --- Instances: one pooled scene copy per drawn member, never more than CAP alive. ---

func _draw(alpha: float) -> void:
	var drawn := {}
	for m in pool.drawn():
		var node := _wear(m)
		if node == null:
			continue
		drawn[m.id] = true
		var before: Array = _prev.get(m.id, [m.pos, m.facing])
		node.visible = visible
		node.position = (before[0] as Vector3).lerp(m.pos, alpha)
		node.rotation.y = lerp_angle(float(before[1]), m.facing, alpha) + AmbientKinds.FRONT_YAW
		_pose(node, m)
	for id in _worn.keys():
		if not drawn.has(id):
			_shed(id)


func _wear(m: AmbientPool.Member) -> Node3D:
	if _worn.has(m.id):
		return _worn[m.id]
	var list: Array = _free.get(m.kind, [])
	var node: Node3D
	if not list.is_empty():
		node = list.pop_back()
	else:
		if _alive >= AmbientKinds.CAP:
			if not _evict_other(m.kind):
				return null
		node = _make(m.kind)
		if node == null:
			return null
	_worn[m.id] = node
	node.visible = true
	_loop_now.erase(m.id)
	_fade_now.erase(m.id)
	return node


func _shed(id: int) -> void:
	var node: Node3D = _worn[id]
	_worn.erase(id)
	node.visible = false
	var kind := String(node.get_meta("kind"))
	if not _free.has(kind):
		_free[kind] = []
	_free[kind].append(node)


# At the cap with only another kind's spare: free that spare so this kind can have its instance.
func _evict_other(kind: String) -> bool:
	for other in _free:
		if other != kind and not (_free[other] as Array).is_empty():
			(_free[other] as Array).pop_back().free()
			_alive -= 1
			return true
	return false


func _release_all() -> void:
	_worn.clear()
	for kind in _free:
		for node: Node3D in _free[kind]:
			node.free()
	_free.clear()
	for child in get_children():
		if not child is AudioStreamPlayer3D:
			child.free()
	_alive = 0
	_loop_now.clear()
	_fade_now.clear()


func _make(kind: String) -> Node3D:
	var path: String = AmbientKinds.row(kind)["model"]
	if not _scenes.has(kind):
		_scenes[kind] = models.get(kind, load(path) if ResourceLoader.exists(path) else null)
	var scene: PackedScene = _scenes[kind]
	if scene == null:
		return null
	var node := scene.instantiate() as Node3D
	if node == null:
		return null
	node.set_meta("kind", kind)
	prepare(node)
	# Looked up once here, not per frame in _pose.
	node.set_meta("views", node.find_children("*", "GeometryInstance3D", true, false))
	node.set_meta("players", node.find_children("*", "AnimationPlayer", true, false))
	add_child(node)
	_alive += 1
	return node


# The candy rules on one instance: no shadow, a view range, no physics body, loops that repeat.
static func prepare(node: Node) -> void:
	for body in node.find_children("*", "CollisionObject3D", true, false):
		push_warning("ambient_life: %s carries a %s; removed (ambient life has no body)" % [node.get_meta("kind", node.name), body.get_class()])
		body.get_parent().remove_child(body)
		body.free()
	for view in node.find_children("*", "GeometryInstance3D", true, false):
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		view.visibility_range_end = VIEW_END_M
		# The recipes paint in vertex colours; the glTF import leaves them off the albedo.
		if view is MeshInstance3D and view.mesh != null:
			for i in view.mesh.get_surface_count():
				var mat := view.get_active_material(i) as BaseMaterial3D
				if mat != null and not mat.vertex_color_use_as_albedo:
					view.set_surface_override_material(i, _vertex_painted(mat))
	for player in node.find_children("*", "AnimationPlayer", true, false):
		for library in player.get_animation_library_list():
			var lib: AnimationLibrary = player.get_animation_library(library)
			for clip in lib.get_animation_list():
				# react plays once into its pose, then _pose loops its hold; idle and move repeat.
				lib.get_animation(clip).loop_mode = Animation.LOOP_NONE if String(clip).ends_with("react") else Animation.LOOP_LINEAR


# One vertex-painted copy per imported material, shared by every instance and kept for the session. A copy per
# instance died with its node, and freeing a posed, skinned creature then queried the freed material ("Parameter
# 'material' is null" on both renderers, first seen when a keeper stood by the ambient_view_test ball, 13 Nov).
static var _painted := {}


static func _vertex_painted(mat: BaseMaterial3D) -> BaseMaterial3D:
	if not _painted.has(mat):
		var copy := mat.duplicate() as BaseMaterial3D
		copy.vertex_color_use_as_albedo = true
		_painted[mat] = copy
	return _painted[mat]


func _pose(node: Node3D, m: AmbientPool.Member) -> void:
	if _fade_now.get(m.id, -1.0) != m.fade:
		_fade_now[m.id] = m.fade
		for view: GeometryInstance3D in node.get_meta("views"):
			view.transparency = 1.0 - m.fade
	var players: Array = node.get_meta("players")
	if players.is_empty():
		return
	var player: AnimationPlayer = players[0]
	player.speed_scale = m.loop_speed
	if _loop_now.get(m.id, "") != m.loop:
		_loop_now[m.id] = m.loop
		var clip := _clip(player, String(AmbientKinds.LOOPS[m.loop]))
		if clip != "":
			player.play(clip)
	elif m.loop == "react" and not player.is_playing() and player.assigned_animation != "" \
			and player.get_animation(player.assigned_animation).length > AmbientKinds.REACT_HOLD_S:
		player.play(player.assigned_animation)
		player.seek(AmbientKinds.REACT_HOLD_S, true)


static func _clip(player: AnimationPlayer, want: String) -> String:
	for name_ in player.get_animation_list():
		if name_ == want or String(name_).ends_with("/" + want) or String(name_).ends_with("_" + want):
			return String(name_)
	return ""


# --- Sound: MAX_VOICES players, quiet past FALLOFF_M; a missing wav is silence. ---

func _voice(m: AmbientPool.Member, which: String) -> void:
	var path: String = m.row["sound"][which]
	if not _streams.has(path):
		_streams[path] = load(path) if ResourceLoader.exists(path) else null
	var stream: AudioStream = _streams[path]
	if stream == null:
		return
	for voice in voices:
		if not voice.playing:
			voice.stream = stream
			voice.volume_db = float(m.row["volume_db"]) - (3.0 if which == "react" else 0.0)
			voice.position = m.pos
			voice.play()
			return
