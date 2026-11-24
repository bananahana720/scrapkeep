extends "res://src/world/device.gd"

const Parts := preload("res://src/build/parts.gd")
const Relics := preload("res://src/build/relics.gd")
const ItemGen := preload("res://src/build/item_gen.gd")
const TierMark := preload("res://src/build/tier_mark.gd")
const StageMap := preload("res://src/world/stage_map.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const FxLibrary := preload("res://src/presentation/fx_library.gd")
const EnemyMotion := preload("res://src/presentation/enemy_motion.gd")

# A cracked wall and the buried cache behind it, the secrets family (LOOP-REDESIGN
# section 9): a verdigris concrete pocket with a charcoal groove, its open side walled
# off by a cracked face. The wall is the ask. Meet it at BREAK_SPEED, or sprinting at
# SPRINT_SPEED, or land a smash beside it, and it crumbles the tick before contact, so
# the ball keeps its speed; slower, it is a wall. The sealed cache's gauge is how fast
# you are coming at the wall, so the ring filling says what the wall wants.
#
# Inside, E opens the chest (the one place on the map you stop on purpose) and three
# parts rise on pedestals; roll onto one to take it and the others sink.

const BREAK_SPEED := 18.0
const SPRINT_SPEED := 8.0
const WALL_REACH := 3.0
const SLAM_REACH := 7.0
const HALF_W := 6.0
const HALF_D := 5.0
const HEIGHT := 6.0
const SINK := 1.5
const PICKS := 3
const PICK_RARITIES := ["common", "rare"]
# Left of the chest, the chest itself, right of it: along the back wall, so the ball
# that stopped to open it is clear of all three.
const PEDESTALS := [Vector3(-4.0, 0.0, -3.0), Vector3(0.0, 0.0, -3.5), Vector3(4.0, 0.0, -3.0)]
const PEDESTAL_REACH := 1.7
# RL2: the chance a cache's last pedestal holds a relic for a slot the pilot has not
# filled (a part on the relic rung) instead of an ordinary part. Drawn from the device's own luck stream under another key,
# so the parts roll above it consumes exactly what it did before relics.
const RELIC_CHANCE := 0.2
const LANE_OFFSET := 6.0
const LANE_EDGE := 4.0
const LANE_LEVEL_SPAN := 2.0
const LANE_LEVEL_RISE := 1.0
# The shell's own warm glow, brighter once the wall is fired. No light: a per-cache
# OmniLight3D freed with the cache on a stage change made Godot 4.7.2 Forward+ segfault on
# the next boss entry (GPU only), as the wave 9 cage light did.
const RIM_STRIP := 0.2
const RIM_GLOW := {"sealed": 1.6, "fired": 2.4}

enum { SEALED, OPEN, PICKING, TAKEN }

# The keeper flag a spent cache puts up (W46 E1-15, design-v3/WAYFINDING.md section 4): its visited mark, so a player
# circling back reads a finished cache from one still open. A six-turn copper spring pole and a square of sand cloth
# tied on with copper rope (tools/blender/world_one/keeper_flag.py), never mint: mint means press now, and a spent cache
# asks for nothing. The model is authored at real size (0.6 by 0.4 m cloth) and stands at FLAG_SCALE, the device's own
# storybook scale (its chest is 2 m wide), so it reads from the chase camera. It springs up from its coil over
# FLAG_SETTLE_S, then its cloth sways in a vertex wind; under reduced motion it stands still. No light, no collider.
const FLAG_MODEL := "res://assets/models/world_one/keeper_flag.glb"
const FLAG_SCALE := 3.0
const FLAG_SETTLE_S := 0.8
const FLAG_SPRUNG_FROM := 0.15
const FLAG_CLOTH := "FlagCloth"
const FLAG_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform float sway = 1.0;
void vertex() {
	// VERTEX.x runs along the fly from the hoist, which stays pinned to the pole.
	float fly = clamp(VERTEX.x / 0.6, 0.0, 1.0);
	float t = TIME * 2.2;
	VERTEX.z += sin(t - fly * 4.0) * fly * 0.07 * sway;
	VERTEX.y += (sin(t * 0.7 + fly * 2.0) * 0.02 - 0.03 * fly * fly) * sway;
}
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.95;
}
"""

var state := SEALED
var offers: Array = []
var taken := ""
# An authored cache can set relic_guaranteed to always hold one; relic_chance is the test seam.
var relic_guaranteed := false
var relic_chance := RELIC_CHANCE
var _wall: Node3D
var _lid: Node3D
var _rim_glow: StandardMaterial3D
var _roof: GeometryInstance3D
var _pedestals: Array = []
var _inside: Array = []
# The keeper flag once the cache is spent (raise_flag), else null.
var flag: Node3D
const MODEL := "res://assets/models/world_one/cracked_cache.glb"
const REQUIRED := ["CacheShell", "CacheRoof", "CacheWall", "CacheChest", "CacheLid", "CachePedestal"]
static var _shared: Array = []
# VX3: the shell and chest wear the workshop finish (concrete and painted metal), whose
# chipped edges give the pocket a lighter rim. The finish multiplies the vertex colours, so the
# amber signpost painted into them stays amber.
const FINISH := {"device_concrete": 0, "device_metal": 1}
static var _loaded := false


func _init() -> void:
	family = "secret"


func build() -> void:
	if not relic_guaranteed:
		var lane := global_position + global_basis.z * LANE_OFFSET
		if lane_clear(ctx.terrain.map().play_rect, lane, ctx.terrain.height):
			global_position = lane
			global_position.y = ctx.terrain.height(lane.x, lane.z)
	var parts := _parts()
	if parts.is_empty():
		_build_greybox()
	else:
		_build_model(parts)
	_build_pedestals(parts)
	_build_rim_glow()
	ctx.events.slammed.connect(_on_slammed)
	ctx.events.world_fact.connect(_on_world_fact)


# The lane spot is used only inside the play rect (less LANE_EDGE) and on ground that is level over
# LANE_LEVEL_SPAN metres; otherwise the cache stays where the map placed it.
static func lane_clear(rect: Rect2, at: Vector3, height: Callable) -> bool:
	if not rect.grow(-LANE_EDGE).has_point(Vector2(at.x, at.z)):
		return false
	var east: float = height.call(at.x + LANE_LEVEL_SPAN, at.z)
	var west: float = height.call(at.x - LANE_LEVEL_SPAN, at.z)
	var north: float = height.call(at.x, at.z + LANE_LEVEL_SPAN)
	var south: float = height.call(at.x, at.z - LANE_LEVEL_SPAN)
	return maxf(absf(east - west), absf(north - south)) <= LANE_LEVEL_RISE


func _build_greybox() -> void:
	var concrete := Palette.striped(Palette.VERDIGRIS, Palette.CHARCOAL)
	var groove := Palette.solid(Palette.CHARCOAL)
	var tall := HEIGHT + SINK
	var mid := tall * 0.5 - SINK
	box(Vector3(HALF_W * 2.0 + 2.0, tall, 1.0), Vector3(0.0, mid, -HALF_D - 0.5), concrete, true)
	for s in [-1.0, 1.0]:
		box(Vector3(1.0, tall, HALF_D * 2.0 + 2.0), Vector3(s * (HALF_W + 0.5), mid, 0.0), concrete, true)
	_roof = box(Vector3(HALF_W * 2.0 + 2.0, 1.0, HALF_D * 2.0 + 2.0), Vector3(0.0, HEIGHT + 0.5, 0.0), concrete, true).get_child(1)
	box(Vector3(HALF_W * 2.0 + 2.2, 0.35, 0.3), Vector3(0.0, HEIGHT * 0.55, HALF_D + 1.05), groove)
	_wall = box(Vector3(HALF_W * 2.0, tall, 1.0), Vector3(0.0, mid, HALF_D + 0.5), Palette.striped(Palette.SANDSTONE, Palette.VERDIGRIS), true)
	for k in 3:
		var crack := box(Vector3(HALF_W * 1.3, 0.2, 1.1), Vector3(0.0, -1.2 + k * 1.6, 0.0), groove, false, _wall)
		crack.rotation.z = 0.5 - k * 0.45
	var chest := Vector3(0.0, 0.0, -HALF_D + 1.2)
	chest.y = ground_y(chest)
	box(Vector3(2.0, 1.2, 1.4), chest + Vector3.UP * 0.6, Palette.solid(Palette.VERDIGRIS))
	box(Vector3(2.05, 0.18, 1.45), chest + Vector3.UP * 0.8, groove)
	_lid = box(Vector3(2.1, 0.3, 1.5), chest + Vector3.UP * 1.35, Palette.solid(Palette.VERDIGRIS))


func _build_pedestals(parts: Array) -> void:
	for spot in PEDESTALS:
		var at: Vector3 = spot + Vector3.UP * ground_y(spot)
		var pedestal := Node3D.new()
		pedestal.position = at
		pedestal.visible = false
		add_child(pedestal)
		if parts.is_empty():
			cylinder(0.8, 0.6, Vector3.UP * 0.3, Palette.solid(Palette.CHARCOAL), pedestal)
		else:
			_attach(parts, "CachePedestal", pedestal)
		var gem := Node3D.new()
		gem.name = "Gem"
		gem.position = Vector3.UP * 1.4
		pedestal.add_child(gem)
		var label := WorldPrompt.new()
		label.attach(pedestal, Vector3.UP * 2.6, Interactables.REACH * 2.0)
		pedestal.add_child(label)
		_pedestals.append({"node": pedestal, "gem": gem, "label": label, "at": at})


func stand_down() -> void:
	if ctx.events.slammed.is_connected(_on_slammed):
		ctx.events.slammed.disconnect(_on_slammed)


func reach_point() -> Vector3:
	return global_transform * Vector3(0.0, ground_y(Vector3(0.0, 0.0, -HALF_D + 1.2)) + 1.0, -HALF_D + 1.2)


func ready_now() -> bool:
	return state == OPEN


func gauge() -> float:
	return clampf(_approach() / BREAK_SPEED, 0.0, 1.0) if state == SEALED else -1.0


func terms() -> String:
	return "three parts"


func broken() -> bool:
	return state != SEALED


# The ball's speed into the wall's outer face, in m/s.
func _approach() -> float:
	var v: Vector3 = ctx.player.state.velocity
	return -v.dot(global_basis.z)


func tick(_delta: float) -> void:
	match state:
		SEALED:
			_watch_wall()
		PICKING:
			_watch_pedestals()


func _watch_wall() -> void:
	var local := to_local(ctx.player.ball_position())
	var toward := _approach()
	var ahead := local.z - (HALF_D + 1.0)
	if ahead < -1.0 or ahead > WALL_REACH + maxf(0.0, toward) / 30.0 or absf(local.x) > HALF_W + 1.0 or local.y > HEIGHT + 2.0:
		return
	if toward >= BREAK_SPEED or (ctx.player.kit.sprinting and toward >= SPRINT_SPEED):
		crumble()


func _on_slammed(at: Vector3, _strength: float, _flatness: float) -> void:
	if state != SEALED:
		return
	var local := to_local(at)
	if local.z > HALF_D and local.z < HALF_D + SLAM_REACH and absf(local.x) <= HALF_W + 1.0:
		crumble()


func crumble() -> void:
	if state != SEALED:
		return
	state = OPEN
	var at: Vector3 = _wall.global_position
	_wall.position += Vector3.DOWN * 400.0
	_wall.visible = false
	_rim_glow.emission_energy_multiplier = RIM_GLOW.fired
	ctx.events.world_fact.emit("wall_crumbled", at)
	ctx.events.world_fact.emit("route_opened", at)


func fire() -> bool:
	state = PICKING
	var lid_target := _lid.position + Vector3(0.0, 0.6, -0.4)
	var animate := EnemyMotion.motion_scale > 0.0 and is_inside_tree()
	if animate:
		var tw := _lid.create_tween()
		tw.set_parallel(true)
		tw.tween_property(_lid, "position", lid_target, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_lid, "rotation:x", -0.9, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_lid.position = lid_target
		_lid.rotation.x = -0.9
	if is_inside_tree():
		var lid_at := _lid.global_position + Vector3.UP * 0.5
		FxLibrary.burst(self, "brass_spark", lid_at, 14, Palette.BRASS)
		FxLibrary.burst(self, "steam_puff", lid_at, 6)
	offers = Parts.roll(system.luck(id), PICK_RARITIES, ctx.run.class_id(), ctx.run.parts, PICKS)
	var relic := _relic_offer()
	if relic != "":
		if offers.size() < PICKS:
			offers.append(relic)
		else:
			offers[offers.size() - 1] = relic
	var ball: Vector3 = ctx.player.ball_position()
	_inside.clear()
	for i in _pedestals.size():
		var p: Dictionary = _pedestals[i]
		var shown := i < offers.size()
		p["node"].visible = shown
		_inside.append(_on(p, ball))
		if not shown:
			continue
		if animate:
			var ped: Node3D = p["node"]
			var top_y := ped.position.y
			ped.position.y = top_y - 0.85
			var ptw := ped.create_tween()
			ptw.tween_interval(float(i) * 0.06)
			ptw.tween_property(ped, "position:y", top_y, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var d: Resource = Parts.def(offers[i])
		var rarity: String = d.rarity if d != null else "common"
		_set_gem(p["gem"], rarity)
		var words := Parts.display_name(offers[i]).split(" ", false)
		var icon: String = "cat_" + (d.icon_category if d != null and d.icon_category != "" else "utility")
		p["label"].set_parts(" ".join(words.slice(0, WorldPrompt.TITLE_WORDS)), "", icon)
	return true


# A pedestal gem is its rarity's mark (TierMark): the rung's shape in the rung's colour.
static func _set_gem(holder: Node3D, rarity: String) -> void:
	for child in holder.get_children():
		holder.remove_child(child)
		child.queue_free()
	var mark := TierMark.mark(rarity, Palette.solid(gem_color(rarity), 2.0))
	# Device surfaces take colour from the mesh (device_props_asset_test); primitives read white.
	for m: MeshInstance3D in mark.find_children("*", "MeshInstance3D", true, false):
		m.material_override.vertex_color_use_as_albedo = true
	holder.add_child(mark)


# A pedestal gem wears its rarity's rung of the item ladder, the colour the reward card uses.
static func gem_color(rarity: String) -> Color:
	var id := ItemGen.resolve_rarity(rarity)
	return ItemGen.RARITY[id if id != "" else "common"]["color"]


# The relic part this cache holds, or "". Only a relic of this stage's world the pilot can use
# for an empty slot.
func _relic_offer() -> String:
	var tree = ctx.player.tree if ctx.player != null else null
	var pool := Relics.eligible(ctx.run.class_id(), Relics.held(ctx.run.parts), tree, ctx.stages.world_of(ctx.run.stage))
	if pool.is_empty():
		return ""
	var rng: RandomNumberGenerator = system.luck(id + ":relic")
	var roll := rng.randf()
	var pick := rng.randi()
	if not relic_guaranteed and roll >= relic_chance:
		return ""
	return Relics.part_of(pool[pick % pool.size()])


func _on(p: Dictionary, ball: Vector3) -> bool:
	var at: Vector3 = to_global(p["at"])
	return Vector2(ball.x - at.x, ball.z - at.z).length() <= PEDESTAL_REACH and absf(ball.y - at.y) < 3.0


# A pedestal takes the ball that rolls onto it, not one already standing there when
# the chest opened, so opening never picks for you.
func _watch_pedestals() -> void:
	var ball: Vector3 = ctx.player.ball_position()
	for i in offers.size():
		var now := _on(_pedestals[i], ball)
		if now and not _inside[i]:
			take(i)
			return
		_inside[i] = now


func take(index: int) -> void:
	taken = offers[index]
	state = TAKEN
	spent = true
	for p in _pedestals:
		p["node"].visible = false
	ctx.run.add_part(taken, "cache")
	ctx.events.world_fact.emit("cache_spent", global_position)


func _collision_box(size: Vector3, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	body.position = at
	add_child(body)
	return body


func _build_model(parts: Array) -> void:
	var tall := HEIGHT + SINK
	var mid := tall * 0.5 - SINK
	_collision_box(Vector3(HALF_W * 2.0 + 2.0, tall, 1.0), Vector3(0.0, mid, -HALF_D - 0.5))
	for s in [-1.0, 1.0]:
		_collision_box(Vector3(1.0, tall, HALF_D * 2.0 + 2.0), Vector3(s * (HALF_W + 0.5), mid, 0.0))
	_collision_box(Vector3(HALF_W * 2.0 + 2.0, 1.0, HALF_D * 2.0 + 2.0), Vector3(0.0, HEIGHT + 0.5, 0.0))
	_wall = _collision_box(Vector3(HALF_W * 2.0, tall, 1.0), Vector3(0.0, mid, HALF_D + 0.5))
	var panel := _attach(parts, "CacheWall", _wall)
	panel.position = Vector3.ZERO
	_attach(parts, "CacheShell", self)
	_attach(parts, "CacheRoof", self)
	var chest := Vector3(0.0, 0.0, -HALF_D + 1.2)
	chest.y = ground_y(chest)
	var body := _attach(parts, "CacheChest", self)
	body.position = chest
	_lid = _attach(parts, "CacheLid", self)
	_lid.position = chest + Vector3.UP * 1.35


# The workshop finish shader carries no emission, so the glow is this cache's own additive
# overlay on its shell (greybox: the roof), one material per cache.
# The warm rim is a thin additive strip along the shell's top front edge, on its own mesh. An overlay on
# the whole shell washed the teal workshop finish to near white (wave 12). No Light3D anywhere.
func _build_rim_glow() -> void:
	_rim_glow = StandardMaterial3D.new()
	_rim_glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_rim_glow.albedo_color = Color.BLACK
	_rim_glow.vertex_color_use_as_albedo = true
	_rim_glow.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_rim_glow.emission_enabled = true
	_rim_glow.emission = Palette.SAND
	_rim_glow.emission_energy_multiplier = RIM_GLOW.sealed
	var strip := MeshInstance3D.new()
	strip.name = "CacheRimGlow"
	var bar := CapsuleMesh.new()
	bar.radius = RIM_STRIP * 0.5
	bar.height = HALF_W * 2.0
	bar.radial_segments = 8
	bar.rings = 2
	strip.mesh = bar
	strip.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	strip.position = Vector3(0.0, HEIGHT - RIM_STRIP, HALF_D)
	strip.material_override = _rim_glow
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(strip)


# Mesh-local size for the workshop shader's edge chips; meshes need not be centred.
static func _finish_size(vertices: PackedVector3Array) -> Vector3:
	var reach := Vector3.ZERO
	for at in vertices:
		reach = reach.max(at.abs())
	return reach * 2.0


static func _slot_material(slot: String) -> StandardMaterial3D:
	if slot not in ["device_concrete", "device_metal", "device_marks"]:
		return null
	var mat := Palette.solid(Color.WHITE)
	mat.resource_name = slot
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95 if slot == "device_concrete" else 0.85
	if slot == "device_metal":
		mat.roughness = 0.68
		mat.metallic = 0.28
	return mat


static func _parts() -> Array:
	if _loaded:
		return _shared
	_loaded = true
	var packed: PackedScene
	if ResourceLoader.exists(MODEL):
		packed = load(MODEL) as PackedScene
	if packed != null:
		var scene := packed.instantiate()
		if scene == null:
			push_warning("cracked_cache: %s cannot instantiate; keeping greybox" % MODEL)
			return _shared
		var valid := scene is Node3D
		var found := {}
		for view: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			if view.mesh == null or view.mesh.get_surface_count() == 0:
				valid = false
				break
			var mesh := view.mesh.duplicate() as Mesh
			for s in mesh.get_surface_count():
				var source := mesh.surface_get_material(s)
				var mat := _slot_material(String(source.resource_name)) if source != null else null
				var arrays := mesh.surface_get_arrays(s)
				if (mat == null or arrays.size() != Mesh.ARRAY_MAX
					or arrays[Mesh.ARRAY_VERTEX] == null or arrays[Mesh.ARRAY_VERTEX].is_empty()
					or arrays[Mesh.ARRAY_COLOR] == null or arrays[Mesh.ARRAY_COLOR].size() != arrays[Mesh.ARRAY_VERTEX].size()):
					valid = false
					break
				var finished: Material = mat
				if FINISH.has(mat.resource_name):
					finished = StageMap.dressed_surface(Color.WHITE, FINISH[mat.resource_name],
						_finish_size(arrays[Mesh.ARRAY_VERTEX]), Palette.CHARCOAL, mat)
				mesh.surface_set_material(s, finished)
			var xf := Transform3D.IDENTITY
			var walk: Node = view
			while walk != scene and walk != null:
				if walk is Node3D:
					xf = (walk as Node3D).transform * xf
				walk = walk.get_parent()
			found[String(view.name)] = true
			_shared.append({"name": String(view.name), "mesh": mesh, "xform": xf})
		valid = valid and found.size() == REQUIRED.size()
		for required in REQUIRED:
			valid = valid and found.has(required)
		scene.free()
		if not valid:
			_shared.clear()
	if _shared.is_empty():
		push_warning("cracked_cache: %s missing or malformed; keeping greybox" % MODEL)
	return _shared


# One named part of the model on parent, or null when the model is missing. The park's cracked
# pockets (activities.gd) wear the shell, wall and pedestal over colliders of their own.
static func model_part(part_name: String, parent: Node3D) -> MeshInstance3D:
	return _attach(_parts(), part_name, parent)


static func _attach(parts: Array, part_name: String, parent: Node3D) -> MeshInstance3D:
	for part in parts:
		if part.name == part_name:
			var view := MeshInstance3D.new()
			view.name = part.name
			view.mesh = part.mesh
			view.transform = part.xform
			parent.add_child(view)
			return view
	return null


# take() publishes cache_spent at this cache; hearing its own fact, the cache puts its keeper flag up on the roof's
# front corner, over the open wall, where it reads from every side.
func _on_world_fact(kind: String, at: Vector3) -> void:
	if kind != "cache_spent" or at != global_position or flag != null:
		return
	flag = raise_flag(self, to_global(Vector3(-HALF_W + 1.2, HEIGHT + 1.0, HALF_D - 0.6)), UiTokens.reduced_motion)


# The keeper flag under parent with its foot at `at` (world), sprung up from its coil unless still, its cloth swaying
# unless still; null when the model is missing. One call for every finished cache: this device's own, and the park's
# cracked pockets (site_markers.gd, on their activity_done). Freed with parent.
static func raise_flag(parent: Node3D, at: Vector3, still := false) -> Node3D:
	var packed: PackedScene = load(FLAG_MODEL) as PackedScene if ResourceLoader.exists(FLAG_MODEL) else null
	var raised: Node3D = packed.instantiate() as Node3D if packed != null else null
	if raised == null:
		return null
	raised.name = "KeeperFlag"
	var pole := StandardMaterial3D.new()
	pole.vertex_color_use_as_albedo = true
	pole.roughness = 0.7
	var cloth := ShaderMaterial.new()
	cloth.shader = Shader.new()
	cloth.shader.code = FLAG_SHADER
	cloth.set_shader_parameter("sway", 0.0 if still else 1.0)
	for view: MeshInstance3D in raised.find_children("*", "MeshInstance3D", true, false):
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		view.material_override = cloth if String(view.name) == FLAG_CLOTH else pole
	parent.add_child(raised)
	raised.global_position = at
	raised.scale = Vector3.ONE * FLAG_SCALE
	if not still:
		raised.scale = Vector3(FLAG_SCALE, FLAG_SCALE * FLAG_SPRUNG_FROM, FLAG_SCALE)
		raised.create_tween().tween_property(raised, "scale", Vector3.ONE * FLAG_SCALE, FLAG_SETTLE_S) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	return raised
