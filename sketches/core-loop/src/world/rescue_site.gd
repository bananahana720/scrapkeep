class_name RescueSite
extends Node3D

const Interactables := preload("res://src/world/interactables.gd")
const ShiftVariants := preload("res://src/core/shift_variants.gd")
const Palette := preload("res://src/core/palette.gd")
const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const EnemyMotion := preload("res://src/presentation/enemy_motion.gd")
const MODEL := "res://assets/models/world_one/rescue_cage.glb"
const REQUIRED := ["CageFrame", "CageGate", "CageLatch", "CageSeat"]
const PILOT_QUESTS := {"rivet": "runner_gunner", "dig": "demolitions_caster"}
const UNLOCK_CLIP := "unlock"
const IDLE_CLIP := "idle_loop"
const POSE_BLEND_FREED := "big_cheer"
# Crossfade between cage poses, and the pilot's walk out to where the freed cage opens.
const POSE_BLEND := 0.15
const FREE_MOVE := 0.45
static var model_path := MODEL
static var _shared := {}
static var _warned := {}

# The world rescues (DESIGN-V3, pilots): a caged pilot on a map, freed by the player. The
# map says where (StageMap.rescue_sites: id, at, quest, prompt, and optionally pilot, the class id
# sitting in the cage; without it PILOT_QUESTS names one by quest), the cage is an ally-family device
# in the interact system's hold consent, and finishing it emits rescue_completed(quest) on
# the bus; the profile layer earns the pilot's row from that fact. A quest is rescued once
# per run: a stage entry, so a retry, rebuilds an unfinished cage and keeps a freed one
# open. A new run clears the record.

const BREAK_SECONDS := 2.0
const RING_RADIUS := 4.0

var ctx
var system
var cages: Array = []
var _done := {}


# One cage. Hold E (the ally family's hold) to start the lock breaking; it gives way after
# BREAK_SECONDS whether or not E stays held, with the ring filling as the gauge.
class Cage extends "res://src/world/device.gd":
	var quest := ""
	var owner_site
	var progress := 0.0
	var breaking := false
	var _bars: Node3D
	var _freed_wall: Node3D
	var _model_gate: MeshInstance3D
	var _open_walls: Node3D
	var _latch: Node3D
	var _pilot: Node3D
	var _signal: StandardMaterial3D
	var _animator: AnimationPlayer
	var _pose := ""
	# True once the lock was seen breaking, so a spent cage was freed in front of the player
	# (not rebuilt spent on a retry): the pilot plays unlock (PILOT-CLIPS section 1.4) instead of
	# big_cheer when its GLB has it, then idle_loop. tick() stays as pinned.
	var _freed_now := false
	var _free_tween: Tween

	func _init() -> void:
		family = "ally"

	func build() -> void:
		quest = String(spec.get("quest", ""))
		ground_ring(RING_RADIUS, Interactables.color(family))
		var parts := RescueSite._parts()
		if parts.is_empty():
			_build_greybox()
		else:
			_build_model(parts)
		if owner_site != null and owner_site.is_done(quest):
			_bars.visible = false
			spent = true
		_visual_state()

	func _build_greybox() -> void:
		var steel := Palette.solid(Palette.CHARCOAL)
		var accent := Palette.solid(Interactables.color(family), 1.2)
		_bars = Node3D.new()
		add_child(_bars)
		_freed_wall = Node3D.new()
		_freed_wall.name = "FreedWallHinge"
		_freed_wall.position = Vector3(0.0, 0.0, 1.4)
		add_child(_freed_wall)
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				box(Vector3(0.3, 3.2, 0.3), Vector3(sx * 1.4, 1.6, sz * 1.4), steel, false, _bars)
		for s in [-1.0, 1.0]:
			box(Vector3(3.1, 0.25, 0.25), Vector3(0.0, 3.2, s * 1.4), steel, false, _bars)
			box(Vector3(0.25, 0.25, 3.1), Vector3(s * 1.4, 3.2, 0.0), steel, false, _bars)
			box(Vector3(0.12, 3.0, 0.12), Vector3(s * 0.5, 1.6, 1.4), steel, false, _bars)
			box(Vector3(0.12, 3.0, 0.12), Vector3(s * 0.5, 1.6, 0.0), steel, false, _freed_wall)
		box(Vector3(0.7, 0.5, 0.2), Vector3(0.0, 1.4, 1.5), accent, false, _bars)
		box(Vector3(0.7, 0.5, 0.2), Vector3(0.0, 1.4, 0.1), accent, false, _freed_wall)
		box(Vector3(0.8, 1.2, 0.8), Vector3(0.0, 0.6, 0.0), accent)

	func _build_model(parts: Array) -> void:
		_bars = Node3D.new()
		_bars.name = "LockedGate"
		add_child(_bars)
		for part in parts:
			var view := MeshInstance3D.new()
			view.name = part.name
			view.mesh = part.mesh
			view.transform = part.xform
			if part.name == "CageGate":
				_bars.add_child(view)
				_model_gate = view
			elif part.name == "CageLatch":
				_bars.add_child(view)
			else:
				add_child(view)
			if part.name == "CageLatch":
				_latch = view
				_signal = view.mesh.surface_get_material(0).duplicate()
				view.set_surface_override_material(0, _signal)
		_open_walls = Node3D.new()
		_open_walls.name = "FreedWalls"
		_open_walls.visible = false
		add_child(_open_walls)
		_build_freed_walls()
		var class_id := String(spec.get("pilot", RescueSite.PILOT_QUESTS.get(quest, "")))
		if class_id != "":
			_pilot = Node3D.new()
			_pilot.name = "RescuedPilot"
			_pilot.position = Vector3(0.0, 1.25, -0.25)
			_pilot.scale = Vector3.ONE * 1.6
			add_child(_pilot)
			var assets := HeroAssets.new()
			var fitted := assets.fit_pilot_into(_pilot, class_id, Interactables.color(family))
			_animator = fitted.get("animator")
			assets.free()
			if _animator != null:
				_animator.animation_finished.connect(_on_pilot_clip_done)

	func _on_pilot_clip_done(clip: StringName) -> void:
		# A pilot without an unlock clip would hold big_cheer's last frame; ease back to idle.
		var cheer_done := String(clip) == POSE_BLEND_FREED and spent
		if (String(clip) == UNLOCK_CLIP or cheer_done) and _animator.has_animation(IDLE_CLIP):
			_pose = IDLE_CLIP
			_animator.play(IDLE_CLIP, 0.1)

	func _build_freed_walls() -> void:
		var steel := Palette.solid(Palette.CHARCOAL)
		_freed_wall = Node3D.new()
		_freed_wall.name = "FreedWallHinge"
		_freed_wall.position = Vector3(0.0, 0.0, 1.4)
		_open_walls.add_child(_freed_wall)
		for side in 4:
			var wall := Node3D.new()
			wall.name = "FreedWall%d" % side
			if side == 0:
				_freed_wall.add_child(wall)
			else:
				_open_walls.add_child(wall)
			var turn: float = [0.0, PI, PI * 0.5, -PI * 0.5][side]
			var edge := 0.08
			wall.rotation.y = turn
			if side == 1:
				wall.position = Vector3(0.0, 0.0, -1.4)
			elif side == 2:
				wall.position = Vector3(1.4, 0.0, 0.0)
			elif side == 3:
				wall.position = Vector3(-1.4, 0.0, 0.0)
			for x in [-1.4, -0.5, 0.5, 1.4]:
				box(Vector3(edge, 3.0, edge), Vector3(x, 1.5, 0.0), steel, false, wall)
			for y in [0.06, 2.94]:
				box(Vector3(2.8, edge, edge), Vector3(0.0, y, 0.0), steel, false, wall)

	func _visual_state() -> void:
		_bars.visible = not spent
		if _model_gate != null:
			_model_gate.visible = not spent
		if _open_walls != null:
			_open_walls.visible = spent
		if _freed_wall != null:
			_freed_wall.visible = spent
			_freed_wall.rotation.x = PI * 0.5 if spent else 0.0
		if _latch == null:
			return
		var fill := clampf(progress / BREAK_SECONDS, 0.0, 1.0)
		_bars.position.y = fill * 0.75 if breaking else 0.0
		_latch.rotation.z = fill * PI * 0.5 if breaking else 0.0
		_signal.albedo_color = Palette.ARC if spent else (Palette.SAND if breaking else Palette.SLATE)
		_signal.emission_enabled = true
		# No per-cage light: cages are freed on every stage change, and a freed light
		# crashes Godot 4.7.2's renderer on the next sealed boss entry. The signal glows instead.
		_signal.emission = Palette.ARC if spent else Interactables.color(family)
		_signal.emission_energy_multiplier = 1.0 if spent else (1.2 + fill * 2.0 if breaking else 0.6)
		if _pilot != null:
			_place_pilot(fill)
		if breaking:
			_freed_now = true
		var pose := "big_cheer" if spent else ("heave" if breaking else "slump")
		if spent and _freed_now and _animator != null and _animator.has_animation(UNLOCK_CLIP):
			pose = UNLOCK_CLIP if _pose != IDLE_CLIP else IDLE_CLIP
		elif spent and _pose == IDLE_CLIP:
			pose = IDLE_CLIP
		if pose != _pose and _animator != null and _animator.has_animation(pose):
			var blend := POSE_BLEND if _pose != "" else 0.0
			_pose = pose
			_animator.play(pose, blend)

	# While caged the pilot follows the break gauge; on release it eases out to the freed spot
	# (landing in place under reduced motion) instead of teleporting.
	func _place_pilot(fill: float) -> void:
		if not spent:
			if _free_tween != null:
				_free_tween.kill()
				_free_tween = null
			_pilot.position = Vector3(0.0, 1.25 + (0.25 if breaking else 0.0), -0.25)
			_pilot.rotation.y = PI + (0.2 * sin(fill * TAU) if breaking else 0.0)
			return
		if _free_tween != null and _free_tween.is_valid():
			return
		var rest := Vector3(0.0, 1.6, 2.1)
		if _pilot.position.is_equal_approx(rest) or not _freed_now or not is_inside_tree() \
				or EnemyMotion.motion_scale <= 0.0:
			_pilot.position = rest
			_pilot.rotation.y = PI
			return
		_free_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_free_tween.tween_property(_pilot, "position", rest, FREE_MOVE)
		_free_tween.tween_property(_pilot, "rotation:y", PI, FREE_MOVE)

	func ready_now() -> bool:
		return not spent and not breaking

	func gauge() -> float:
		return progress / BREAK_SECONDS if breaking else -1.0

	# The site row's prompt (StageMap.rescue_sites "prompt"), so each cage names who it holds.
	func terms() -> String:
		return String(spec.get("prompt", "free the pilot"))

	func fire() -> bool:
		if spent or breaking:
			return false
		breaking = true
		progress = 0.0
		_visual_state()
		return false

	func tick(delta: float) -> void:
		if not breaking:
			return
		progress += delta
		_visual_state()
		if progress < BREAK_SECONDS:
			return
		breaking = false
		spent = true
		_visual_state()
		system.fired(self)
		owner_site.complete(quest)


static func _parts() -> Array:
	if _shared.has(model_path):
		return _shared[model_path]
	var parts := []
	var packed: PackedScene
	if ResourceLoader.exists(model_path):
		packed = load(model_path) as PackedScene
	if packed != null:
		var scene := packed.instantiate()
		if scene == null:
			_shared[model_path] = []
			_warned[model_path] = true
			push_warning("rescue_site: %s cannot instantiate; keeping greybox" % model_path)
			return []
		var valid := scene is Node3D
		var found := {}
		for view: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			if view.mesh == null or view.mesh.get_surface_count() != 1:
				valid = false
				break
			var source := view.mesh.surface_get_material(0)
			var arrays := view.mesh.surface_get_arrays(0)
			if source == null or source.resource_name not in ["cage_steel", "cage_signal"] \
					or arrays[Mesh.ARRAY_COLOR] == null or arrays[Mesh.ARRAY_VERTEX] == null \
					or arrays[Mesh.ARRAY_VERTEX].is_empty() \
					or arrays[Mesh.ARRAY_COLOR].size() != arrays[Mesh.ARRAY_VERTEX].size():
				valid = false
				break
			var mesh := view.mesh.duplicate() as Mesh
			var mat := Palette.solid(Color.WHITE)
			mat.resource_name = source.resource_name
			mat.vertex_color_use_as_albedo = true
			mat.roughness = 0.72
			mat.metallic = 0.25
			mesh.surface_set_material(0, mat)
			var xf := Transform3D.IDENTITY
			var walk: Node = view
			while walk != scene and walk != null:
				if walk is Node3D:
					xf = walk.transform * xf
				walk = walk.get_parent()
			found[String(view.name)] = true
			parts.append({"name": String(view.name), "mesh": mesh, "xform": xf})
		for required in REQUIRED:
			valid = valid and found.has(required)
		valid = valid and parts.size() == REQUIRED.size()
		scene.free()
		if not valid:
			parts.clear()
	_shared[model_path] = parts
	if parts.is_empty() and not _warned.has(model_path):
		_warned[model_path] = true
		push_warning("rescue_site: %s missing or malformed; keeping greybox" % model_path)
	return parts


func setup(ctx_ref, interact_ref) -> void:
	ctx = ctx_ref
	system = interact_ref
	name = "RescueSites"
	ctx.events.stage_entered.connect(_on_stage_entered)
	ctx.events.stage_content_cleared.connect(func(_reason: String): clear())
	ctx.events.run_started.connect(func(_class_id: String): _done.clear())


func _on_stage_entered(_stage: int, retry: bool) -> void:
	clear()
	if retry:
		# A retry rewinds run scrap to stage entry, so salvage-only variant cages re-arm alongside it.
		for quest in _done.keys():
			if ShiftVariants.cage_salvage_scrap(String(quest)) > 0:
				_done.erase(quest)
	var map = ctx.terrain.map()
	var specs: Array = []
	if "rescue_sites" in map:
		specs.append_array(map.rescue_sites)
	var map_id := String(map.park.get("map", "")) if "park" in map and map.park is Dictionary else ""
	specs.append_array(ShiftVariants.extra_cages(map_id, ctx.run))
	for spec in specs:
		var cage := Cage.new()
		cage.owner_site = self
		add_child(cage)
		var at: Vector2 = spec["at"]
		cage.global_position = ctx.terrain.drop_point(at.x, at.y, 0.0)
		var face: Vector2 = spec.get("face", Vector2(0.0, 1.0))
		cage.rotation.y = atan2(face.x, face.y)
		cage.setup(ctx, system, spec)
		system.register(cage)
		cages.append(cage)


func clear() -> void:
	for cage in cages:
		if is_instance_valid(cage):
			system.unregister(cage)
			cage.queue_free()
	cages.clear()


func is_done(quest: String) -> bool:
	return bool(_done.get(quest, false))


# Every cage still holding its pilot, as [{quest, at}] with at the cage's foot.
func waiting() -> Array:
	var out := []
	for c in cages:
		if is_instance_valid(c) and not c.spent:
			out.append({"quest": c.quest, "at": c.global_position})
	return out


func cage(quest: String):
	for c in cages:
		if c.quest == quest:
			return c
	return null


# The one place a rescue finishes: once per quest per run.
func complete(quest: String) -> void:
	if is_done(quest):
		return
	_done[quest] = true
	var salvage := ShiftVariants.cage_salvage_scrap(quest)
	if salvage > 0 and ctx.run != null and (ctx.build == null or not ctx.build.scrapless()):
		var found = cage(quest)
		var at: Vector3 = found.global_position if found != null else Vector3.ZERO
		ctx.run.add_scrap(salvage, at)
	ctx.events.rescue_completed.emit(quest)
