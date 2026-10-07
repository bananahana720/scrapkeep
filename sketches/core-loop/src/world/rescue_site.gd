class_name RescueSite
extends Node3D

const Interactables := preload("res://src/world/interactables.gd")
const Palette := preload("res://src/core/palette.gd")
const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const MODEL := "res://assets/models/world_one/rescue_cage.glb"
const REQUIRED := ["CageFrame", "CageGate", "CageLatch", "CageSeat"]
const PILOT_QUESTS := {"rivet": "runner_gunner", "dig": "demolitions_caster"}
static var model_path := MODEL
static var _shared := {}
static var _warned := {}

# The world rescues (DESIGN-V3, pilots): a caged pilot on a map, freed by the player. The
# map says where (StageMap.rescue_sites: id, at, quest), the cage is an ally-family device
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
	var _latch: Node3D
	var _pilot: Node3D
	var _signal: StandardMaterial3D
	var _animator: AnimationPlayer
	var _pose := ""
	var _light: OmniLight3D

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
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				box(Vector3(0.3, 3.2, 0.3), Vector3(sx * 1.4, 1.6, sz * 1.4), steel, false, _bars)
		for s in [-1.0, 1.0]:
			box(Vector3(3.1, 0.25, 0.25), Vector3(0.0, 3.2, s * 1.4), steel, false, _bars)
			box(Vector3(0.25, 0.25, 3.1), Vector3(s * 1.4, 3.2, 0.0), steel, false, _bars)
			box(Vector3(0.12, 3.0, 0.12), Vector3(s * 0.5, 1.6, 1.4), steel, false, _bars)
		box(Vector3(0.7, 0.5, 0.2), Vector3(0.0, 1.4, 1.5), accent, false, _bars)
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
			if part.name in ["CageGate", "CageLatch"]:
				_bars.add_child(view)
			else:
				add_child(view)
			if part.name == "CageLatch":
				_latch = view
				_signal = view.mesh.surface_get_material(0).duplicate()
				view.set_surface_override_material(0, _signal)
		var class_id: String = RescueSite.PILOT_QUESTS.get(quest, "")
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
		_light = OmniLight3D.new()
		_light.name = "RescueLight"
		_light.position = Vector3(0, 2.7, 0.4)
		_light.omni_range = 5.0
		_light.shadow_enabled = false
		add_child(_light)

	func _visual_state() -> void:
		if _latch == null:
			return
		var fill := clampf(progress / BREAK_SECONDS, 0.0, 1.0)
		_bars.visible = not spent
		_bars.position.y = fill * 0.75 if breaking else 0.0
		_latch.rotation.z = fill * PI * 0.5 if breaking else 0.0
		_signal.albedo_color = Palette.ARC if spent else (Palette.SAND if breaking else Palette.SLATE)
		_signal.emission_enabled = true
		_signal.emission = Interactables.color(family)
		_signal.emission_energy_multiplier = 1.2 + fill * 2.0 if breaking else 0.6
		if _light != null:
			_light.light_color = Palette.ARC if spent else Interactables.color(family)
			_light.light_energy = 0.9 if spent else (1.8 if breaking else 0.25)
		if _pilot != null:
			_pilot.position = Vector3(0.0, 1.6, 1.8) if spent else Vector3(0.0, 1.25 + (0.25 if breaking else 0.0), -0.25)
			_pilot.rotation.y = PI + (0.2 * sin(fill * TAU) if breaking else 0.0)
		var pose := "big_cheer" if spent else ("heave" if breaking else "slump")
		if pose != _pose and _animator != null and _animator.has_animation(pose):
			_pose = pose
			_animator.play(pose)

	func ready_now() -> bool:
		return not spent and not breaking

	func gauge() -> float:
		return progress / BREAK_SECONDS if breaking else -1.0

	func terms() -> String:
		return "free the runner"

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
		_bars.visible = false
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


func _on_stage_entered(_stage: int, _retry: bool) -> void:
	clear()
	var map = ctx.terrain.map()
	if not "rescue_sites" in map:
		return
	for spec in map.rescue_sites:
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
	ctx.events.rescue_completed.emit(quest)
