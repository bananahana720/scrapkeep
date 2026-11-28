extends "res://src/world/device.gd"

const Parts := preload("res://src/build/parts.gd")
const Relics := preload("res://src/build/relics.gd")
const ItemGen := preload("res://src/build/item_gen.gd")
const TierMark := preload("res://src/build/tier_mark.gd")
const StageMap := preload("res://src/world/stage_map.gd")
const ModelKit := preload("res://src/world/model_kit.gd")
const Consumables := preload("res://src/build/consumables.gd")
const Comfort := preload("res://src/core/comfort.gd")


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
const PEDESTALS := [Vector3(-4.0, 0.0, -3.0), Vector3(0.0, 0.0, -3.5), Vector3(4.0, 0.0, -3.0)]
const PEDESTAL_REACH := 1.7
const RELIC_CHANCE := 0.2
const LANE_OFFSET := 6.0
const LANE_EDGE := 4.0
const LANE_LEVEL_SPAN := 2.0
const LANE_LEVEL_RISE := 1.0
const RIM_STRIP := 0.2
const RIM_GLOW := {"sealed": 1.6, "fired": 2.4}

enum { SEALED, OPEN, PICKING, TAKEN }

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
var consumable_dropped := ""
var relic_guaranteed := false
var relic_chance := RELIC_CHANCE
var _wall: Node3D
var _lid: Node3D
var _rim_glow: StandardMaterial3D
var _roof: GeometryInstance3D
var _pedestals: Array = []
var _inside: Array = []
var flag: Node3D
const MODEL := "res://assets/models/world_one/cracked_cache.glb"
const REQUIRED := ["CacheShell", "CacheRoof", "CacheWall", "CacheChest", "CacheLid", "CachePedestal"]
const FINISH := {"device_concrete": 0, "device_metal": 1}


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
	if ctx.events.has_signal("interact_fired"):
		ctx.events.interact_fired.connect(_on_interact_fired)


static func lane_clear(rect: Rect2, at: Vector3, height: Callable) -> bool:
	if not rect.grow(-LANE_EDGE).has_point(Vector2(at.x, at.z)):
		return false
	var east: float = height.call(at.x + LANE_LEVEL_SPAN, at.z)
	var west: float = height.call(at.x - LANE_LEVEL_SPAN, at.z)
	var north: float = height.call(at.x, at.z + LANE_LEVEL_SPAN)
	var south: float = height.call(at.x, at.z - LANE_LEVEL_SPAN)
	return maxf(absf(east - west), absf(north - south)) <= LANE_LEVEL_RISE


func _build_greybox() -> void:
	var concrete := PaletteMaterials.striped(Palette.VERDIGRIS, Palette.CHARCOAL)
	var groove := PaletteMaterials.solid(Palette.CHARCOAL)
	var tall := HEIGHT + SINK
	var mid := tall * 0.5 - SINK
	box(Vector3(HALF_W * 2.0 + 2.0, tall, 1.0), Vector3(0.0, mid, -HALF_D - 0.5), concrete, true)
	for s in [-1.0, 1.0]:
		box(Vector3(1.0, tall, HALF_D * 2.0 + 2.0), Vector3(s * (HALF_W + 0.5), mid, 0.0), concrete, true)
	_roof = box(Vector3(HALF_W * 2.0 + 2.0, 1.0, HALF_D * 2.0 + 2.0), Vector3(0.0, HEIGHT + 0.5, 0.0), concrete, true).get_child(1)
	box(Vector3(HALF_W * 2.0 + 2.2, 0.35, 0.3), Vector3(0.0, HEIGHT * 0.55, HALF_D + 1.05), groove)
	_wall = box(Vector3(HALF_W * 2.0, tall, 1.0), Vector3(0.0, mid, HALF_D + 0.5), PaletteMaterials.striped(Palette.SANDSTONE, Palette.VERDIGRIS), true)
	for k in 3:
		var crack := box(Vector3(HALF_W * 1.3, 0.2, 1.1), Vector3(0.0, -1.2 + k * 1.6, 0.0), groove, false, _wall)
		crack.rotation.z = 0.5 - k * 0.45
	var chest := Vector3(0.0, 0.0, -HALF_D + 1.2)
	chest.y = ground_y(chest)
	box(Vector3(2.0, 1.2, 1.4), chest + Vector3.UP * 0.6, PaletteMaterials.solid(Palette.VERDIGRIS))
	box(Vector3(2.05, 0.18, 1.45), chest + Vector3.UP * 0.8, groove)
	_lid = box(Vector3(2.1, 0.3, 1.5), chest + Vector3.UP * 1.35, PaletteMaterials.solid(Palette.VERDIGRIS))


func _build_pedestals(parts: Array) -> void:
	for spot in PEDESTALS:
		var at: Vector3 = spot + Vector3.UP * ground_y(spot)
		var pedestal := Node3D.new()
		pedestal.position = at
		pedestal.visible = false
		add_child(pedestal)
		if parts.is_empty():
			cylinder(0.8, 0.6, Vector3.UP * 0.3, PaletteMaterials.solid(Palette.CHARCOAL), pedestal)
		else:
			ModelKit.attach_part(parts, "CachePedestal", pedestal)
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
	var animate := not Comfort.reduced_motion and is_inside_tree()
	if animate:
		_lid.rotation.x = -0.06
		var tw := _lid.create_tween()
		tw.set_parallel(true)
		tw.tween_property(_lid, "position", lid_target, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_lid, "rotation:x", -0.9, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_lid.position = lid_target
		_lid.rotation.x = -0.9
	if is_inside_tree():
		var lid_at := _lid.global_position + Vector3.UP * 0.5
		ctx.burst(self, "brass_spark", lid_at, 14, Palette.BRASS)
		ctx.burst(self, "steam_puff", lid_at, 6)
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
	var mark := TierMark.mark(rarity, PaletteMaterials.solid(gem_color(rarity), 2.0))
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
	var pool := Relics.eligible(ctx.run.class_id(), Relics.held(ctx.run.parts), tree, ctx.stages.world_of(ctx.run.stage), true)
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
	var panel := ModelKit.attach_part(parts, "CacheWall", _wall)
	panel.position = Vector3.ZERO
	ModelKit.attach_part(parts, "CacheShell", self)
	ModelKit.attach_part(parts, "CacheRoof", self)
	var chest := Vector3(0.0, 0.0, -HALF_D + 1.2)
	chest.y = ground_y(chest)
	var body := ModelKit.attach_part(parts, "CacheChest", self)
	body.position = chest
	_lid = ModelKit.attach_part(parts, "CacheLid", self)
	_lid.position = chest + Vector3.UP * 1.35


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


static func _finish_size(vertices: PackedVector3Array) -> Vector3:
	var reach := Vector3.ZERO
	for at in vertices:
		reach = reach.max(at.abs())
	return reach * 2.0


static func _finish_surface(mat: StandardMaterial3D, vertices: PackedVector3Array) -> Material:
	if FINISH.has(mat.resource_name):
		return StageMap.dressed_surface(Color.WHITE, FINISH[mat.resource_name],
			_finish_size(vertices), Palette.CHARCOAL, mat)
	return mat


static func _parts() -> Array:
	return ModelKit.device_parts(MODEL, REQUIRED, "cracked_cache", _finish_surface)


static func model_part(part_name: String, parent: Node3D) -> MeshInstance3D:
	return ModelKit.attach_part(_parts(), part_name, parent)


func _on_world_fact(kind: String, at: Vector3) -> void:
	if kind != "cache_spent" or at != global_position:
		return
	_drop_consumable()
	if flag != null:
		return
	flag = raise_flag(self, to_global(Vector3(-HALF_W + 1.2, HEIGHT + 1.0, HALF_D - 0.6)), Comfort.reduced_motion)


func _on_interact_fired(fam: String, device_id: String, _at: Vector3) -> void:
	if fam == family and device_id == id:
		_drop_consumable()


func _drop_consumable() -> void:
	if consumable_dropped != "" or system == null:
		return
	consumable_dropped = Consumables.roll_id(system.luck(id + ":consumable"))
	if consumable_dropped != "" and ctx != null and ctx.spawner != null and ctx.spawner.get("consumables") != null:
		var drop_local := Vector3(0.0, ground_y(Vector3(0.0, 0.0, 0.5)), 0.5)
		ctx.spawner.consumables.drop_consumable(consumable_dropped, to_global(drop_local))


func _exit_tree() -> void:
	if ctx != null and ctx.events != null and ctx.events.has_signal("interact_fired") and ctx.events.interact_fired.is_connected(_on_interact_fired):
		ctx.events.interact_fired.disconnect(_on_interact_fired)


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
