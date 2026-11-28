extends Node3D

const Augments := preload("res://src/movement/augments.gd")
const Groups := preload("res://src/core/groups.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const HazardHits := preload("res://src/world/events/hazard_hits.gd")
const Palette := preload("res://src/core/palette.gd")
const PaletteMaterials := preload("res://src/presentation/palette_materials.gd")
const PhysicsLayers := preload("res://src/core/physics_layers.gd")
const RecipeProps := preload("res://src/presentation/recipe_props.gd")
const SpeedTier := preload("res://src/core/speed_tier.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")


class ValveBiteBody extends StaticBody3D:
	func anchor_point(_point: Vector3, _from = null) -> Vector3:
		return global_position


const BODY_PATH := "res://assets/models/grapple/sluice_valve_body.glb"
const WHEEL_PATH := "res://assets/models/grapple/sluice_valve_wheel.glb"
const BITE_GROUP := "sluice_valve_bite"
const WASH_SOURCE := "grapple_sluice"

const BITE_RADIUS := 1.15
const BITE_HEIGHT := 1.6
const YANK_MIN_SWING_SPEED := 4.0
const YANK_SWING_TURN_RATE := 4.5
const YANK_HOLD_TURN_RATE := 1.8
const YANK_OPEN_RAD := 0.40
const WHEEL_OPEN_RAD := TAU * 1.25
const WHEEL_OPEN_RATE := 7.0
const WHEEL_CLOSE_RATE := 2.2

const WARN_MIN_S := 0.6
const WARN_S := 0.9
const SURGE_LIVE_S := 0.8
const DRAIN_S := 0.6
const DEFAULT_CHARGE_S := 14.0
const DEFAULT_LENGTH_M := 24.0
const DEFAULT_HALF_WIDTH_M := 5.0
const DEFAULT_REACH_M := 4.0

const WASH_ENEMY_DAMAGE := 35.0
const WASH_ENEMY_TOSS := 28.0
const WASH_BALL_DAMAGE := 10.0
const WASH_BALL_TOSS := 16.0
const WASH_BALL_LIFT := 6.0
const SHEET_DEPTH_M := 0.65

var ctx
var cruise := 14.0
var valves: Array[Dictionary] = []

var _ground := Callable()
var _scene_cache := {}
var _water_mat: StandardMaterial3D
var _events_wired = null
var _stage_root: Node3D = null


func _ready() -> void:
	name = "SluiceValves"
	if not is_in_group(Groups.WORLD_TELEGRAPHS):
		add_to_group(Groups.WORLD_TELEGRAPHS)


func _exit_tree() -> void:
	_disconnect_events()
	clear_valves()


func build_from_specs(specs: Array, ground_fn: Callable, cruise_speed := 14.0, ctx_ref = null) -> void:
	clear_valves()
	ctx = ctx_ref
	cruise = maxf(1.0, cruise_speed)
	_ground = ground_fn
	_connect_events()
	if not is_in_group(Groups.WORLD_TELEGRAPHS):
		add_to_group(Groups.WORLD_TELEGRAPHS)
	_stage_root = Node3D.new()
	_stage_root.name = "StageValves"
	add_child(_stage_root)
	for spec in specs:
		if spec is Dictionary:
			valves.append(_build_valve(spec))


func clear_valves() -> void:
	for v in valves:
		_drop_hazard(v)
	valves.clear()
	if _stage_root != null and is_instance_valid(_stage_root):
		_stage_root.queue_free()
	_stage_root = null


func reset() -> void:
	for v in valves:
		_reset_valve(v)


func valve_ids() -> Array[String]:
	var out: Array[String] = []
	for v in valves:
		out.append(String(v["id"]))
	return out


func valve_of(id: String) -> Dictionary:
	for v in valves:
		if String(v["id"]) == id:
			return v
	return {}


func valve_for_body(body: Node) -> Dictionary:
	if body == null:
		return {}
	for v in valves:
		if v.get("bite_body") == body:
			return v
	return {}


func committed_hazards() -> Array:
	var out: Array = []
	for v in valves:
		var h: Hazard = v.get("hazard")
		if h != null and is_instance_valid(h):
			out.append(h)
	return out


func _connect_events() -> void:
	var ev = ctx.get("events") if ctx != null else null
	if ev == _events_wired:
		return
	_disconnect_events()
	if ev != null and ev.has_signal("harpoon_bit"):
		ev.harpoon_bit.connect(_on_harpoon_bit)
		_events_wired = ev


func _disconnect_events() -> void:
	if _events_wired != null and is_instance_valid(_events_wired):
		if _events_wired.has_signal("harpoon_bit") and _events_wired.harpoon_bit.is_connected(_on_harpoon_bit):
			_events_wired.harpoon_bit.disconnect(_on_harpoon_bit)
	_events_wired = null


func _on_harpoon_bit(body: Node3D, _at: Vector3) -> void:
	var v := valve_for_body(body)
	if v.is_empty():
		return
	v["hooked"] = true


func _build_valve(spec: Dictionary) -> Dictionary:
	var id := String(spec.get("id", "sluice_%d" % valves.size()))
	var at_2d := _vec2(spec.get("at", Vector2.ZERO))
	var foot := _ground_point(at_2d.x, at_2d.y)
	var lane: Dictionary = spec.get("lane", {})
	var from_2d := _vec2(lane.get("from", at_2d), at_2d)
	var lane_from := _ground_point(from_2d.x, from_2d.y)
	var dir := Vector3.BACK
	var length := DEFAULT_LENGTH_M
	if lane.has("to"):
		var to_2d := _vec2(lane["to"], from_2d + Vector2(0.0, DEFAULT_LENGTH_M))
		var span := to_2d - from_2d
		if span.length() > 0.01:
			dir = Vector3(span.x, 0.0, span.y).normalized()
			length = float(lane.get("length", span.length()))
	else:
		var dir_2d := _vec2(lane.get("dir", Vector2(0.0, 1.0)), Vector2(0.0, 1.0))
		if dir_2d.length() > 0.01:
			dir = Vector3(dir_2d.x, 0.0, dir_2d.y).normalized()
		length = float(lane.get("length", DEFAULT_LENGTH_M))
	length = maxf(1.0, length)
	var half_width := maxf(0.5, float(lane.get("half_width", float(lane.get("width", DEFAULT_HALF_WIDTH_M * 2.0)) * 0.5)))
	var reach := maxf(0.5, float(lane.get("reach", DEFAULT_REACH_M)))
	var charge := maxf(0.1, float(spec.get("charge", DEFAULT_CHARGE_S)))

	var holder := Node3D.new()
	holder.name = "GrappleSluice_" + id
	holder.position = foot
	holder.rotation.y = atan2(dir.x, dir.z)
	_stage_parent().add_child(holder)

	var body_node := _instantiate_glb(BODY_PATH, "SluiceValveBody", "enamel", Palette.COPPER)
	holder.add_child(body_node)
	var hub := body_node.find_child("socket_hub", true, false) as Node3D
	if hub == null:
		hub = Node3D.new()
		hub.name = "socket_hub"
		hub.position = Vector3(0.0, 1.95, 0.32)
		body_node.add_child(hub)

	var wheel_node := _instantiate_glb(WHEEL_PATH, "SluiceValveWheel", "steel", Palette.SAND)
	hub.add_child(wheel_node)
	var bite_socket := wheel_node.find_child("socket_bite", true, false) as Node3D
	if bite_socket == null:
		bite_socket = Node3D.new()
		bite_socket.name = "socket_bite"
		bite_socket.position = Vector3(0.0, 1.07, 0.0)
		wheel_node.add_child(bite_socket)

	var bite_body := ValveBiteBody.new()
	bite_body.name = id + "_bite"
	bite_body.collision_layer = PhysicsLayers.WORLD_MASK
	bite_body.collision_mask = PhysicsLayers.NONE
	bite_body.add_to_group(Augments.ANCHOR_GROUP)
	bite_body.add_to_group(Augments.WORLD_ANCHOR_GROUP)
	bite_body.add_to_group(BITE_GROUP)
	bite_body.set_meta("sluice_valve_id", id)
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = BITE_RADIUS
	cyl.height = BITE_HEIGHT
	col.shape = cyl
	bite_body.add_child(col)
	bite_socket.add_child(bite_body)

	var sheet := _build_water_sheet(lane_from, dir, length, half_width)
	_stage_parent().add_child(sheet)

	return {
		"id": id,
		"spec": spec,
		"holder": holder,
		"body": body_node,
		"wheel": wheel_node,
		"socket_hub": hub,
		"socket_bite": bite_socket,
		"bite_body": bite_body,
		"sheet": sheet,
		"sheet_base_y": lane_from.y,
		"foot": foot,
		"lane_from": lane_from,
		"dir": dir,
		"length": length,
		"half_width": half_width,
		"reach": reach,
		"charge": charge,
		"state": "ready",
		"hooked": false,
		"yank_turn": 0.0,
		"wheel_angle": 0.0,
		"warn_elapsed": 0.0,
		"last_warn_visible_s": 0.0,
		"surge_elapsed": 0.0,
		"drain_elapsed": 0.0,
		"charge_left": 0.0,
		"water_level": 0.0,
		"hazard": null,
		"struck_enemies": {},
		"ball_hit": false,
		"props_broken_this_surge": false,
		"yanks_triggered": 0,
		"enemies_washed": 0,
		"ball_hits": 0,
		"props_broken": 0,
		"last_ball_toss": Vector3.ZERO,
	}


func _build_water_sheet(lane_from: Vector3, dir: Vector3, length: float, half_width: float) -> MeshInstance3D:
	if _water_mat == null:
		_water_mat = PaletteMaterials.water(Palette.water_tone())
	var sheet := MeshInstance3D.new()
	sheet.name = "FloodWashSheet"
	var quad := PlaneMesh.new()
	quad.size = Vector2(half_width * 2.0, length)
	sheet.mesh = quad
	sheet.material_override = _water_mat
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mid := lane_from + dir * (length * 0.5)
	var up := Vector3.UP
	var side := up.cross(dir).normalized()
	sheet.transform = Transform3D(Basis(side, up, dir), mid + Vector3.UP * 0.05)
	sheet.visible = false
	return sheet


func _instantiate_glb(path: String, label: String, slot_name: String, fallback_color: Color) -> Node3D:
	var root: Node3D = null
	if ResourceLoader.exists(path):
		if not _scene_cache.has(path):
			_scene_cache[path] = load(path)
		var packed := _scene_cache[path] as PackedScene
		if packed != null:
			root = packed.instantiate() as Node3D
	if root == null:
		root = Node3D.new()
	root.name = label
	var slot_mat: Material = RecipeProps.slot_material(slot_name) if RecipeProps.is_slot_role(slot_name) else null
	if slot_mat == null:
		slot_mat = PaletteMaterials.solid(fallback_color)
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var orig := mi.mesh.surface_get_material(i)
			var mat_name := String(orig.resource_name) if orig != null else slot_name
			var chosen: Material = RecipeProps.slot_material(mat_name) if RecipeProps.is_slot_role(mat_name) else slot_mat
			mi.set_surface_override_material(i, chosen)
	return root


func _reset_valve(v: Dictionary) -> void:
	_drop_hazard(v)
	v["state"] = "ready"
	v["hooked"] = false
	v["yank_turn"] = 0.0
	v["wheel_angle"] = 0.0
	v["warn_elapsed"] = 0.0
	v["last_warn_visible_s"] = 0.0
	v["surge_elapsed"] = 0.0
	v["drain_elapsed"] = 0.0
	v["charge_left"] = 0.0
	v["water_level"] = 0.0
	v["struck_enemies"] = {}
	v["ball_hit"] = false
	v["props_broken_this_surge"] = false
	v["yanks_triggered"] = 0
	v["enemies_washed"] = 0
	v["ball_hits"] = 0
	v["props_broken"] = 0
	v["last_ball_toss"] = Vector3.ZERO
	(v["wheel"] as Node3D).rotation.z = 0.0
	(v["sheet"] as MeshInstance3D).visible = false


func _drop_hazard(v: Dictionary) -> void:
	var h: Hazard = v.get("hazard")
	if h != null and is_instance_valid(h):
		h.finish()
		if h.is_in_group(Threat.GROUP):
			h.remove_from_group(Threat.GROUP)
		h.queue_free()
	v["hazard"] = null


func yank(valve_id: String) -> bool:
	var v := valve_of(valve_id)
	if v.is_empty():
		return false
	return _arm_valve(v)


func _arm_valve(v: Dictionary) -> bool:
	if String(v["state"]) != "ready":
		return false
	_drop_hazard(v)
	var h := Hazard.new()
	var g := _ground
	if g.is_valid():
		h.ground = func(point: Vector3) -> float: return (g.call(point.x, point.z, 0.0) as Vector3).y
	else:
		var floor_y: float = float(v["sheet_base_y"])
		h.ground = func(_point: Vector3) -> float: return floor_y
	h.warn_floor = WARN_MIN_S
	var warn := maxf(WARN_MIN_S, float((v["spec"] as Dictionary).get("warn", WARN_S)))
	h.commit_lane(WASH_SOURCE + "_" + String(v["id"]), Threat.Type.LANE,
		v["lane_from"], v["dir"], 0.0, float(v["length"]), float(v["half_width"]),
		float(v["reach"]), warn, SURGE_LIVE_S)
	_stage_parent().add_child(h)
	v["hazard"] = h
	v["state"] = "warning"
	v["warn_elapsed"] = 0.0
	v["surge_elapsed"] = 0.0
	v["drain_elapsed"] = 0.0
	v["water_level"] = 0.0
	v["struck_enemies"] = {}
	v["ball_hit"] = false
	v["props_broken_this_surge"] = false
	v["yanks_triggered"] = int(v["yanks_triggered"]) + 1
	v["wheel_angle"] = maxf(float(v["wheel_angle"]), YANK_OPEN_RAD)
	(v["wheel"] as Node3D).rotation.z = float(v["wheel_angle"])
	_publish_world_fact("sluice_warning", v["foot"])
	return true


func _physics_process(delta: float) -> void:
	if ctx == null or valves.is_empty():
		return
	var flow = ctx.get("flow")
	if flow != null and flow.has_method("in_stage") and not flow.in_stage():
		return
	var player = ctx.get("player")
	if player == null:
		return
	var ball: Vector3 = player.ball_position()
	var vel: Vector3 = player.state.velocity
	var riding := false
	if ctx.get("world") != null:
		var launch = ctx.world.get("launch")
		riding = ctx.world.get("ride") != null or (launch != null and launch.flying())
	step(delta, ball, vel, player.kit, riding)


func step(delta: float, ball: Vector3, velocity: Vector3, kit = null, riding := false) -> Array:
	var facts: Array = []
	var planar := Vector2(velocity.x, velocity.z).length()
	var motion := {"pos": ball, "vel": velocity, "planar": planar, "riding": riding}
	for v in valves:
		_step_valve(v, delta, motion, kit, facts)
	return facts


func _step_valve(v: Dictionary, delta: float, motion: Dictionary, kit, facts: Array) -> void:
	var bite_body: Node3D = v["bite_body"]
	var hooked_now: bool = kit != null and bool(kit.hooked) and kit.anchor_body == bite_body
	v["hooked"] = hooked_now
	var wheel: Node3D = v["wheel"]
	var sheet: MeshInstance3D = v["sheet"]

	match String(v["state"]):
		"ready":
			if hooked_now:
				var planar: float = float(motion["planar"])
				var swing_pull: bool = planar >= YANK_MIN_SWING_SPEED or bool(kit.winching)
				var turn_rate := YANK_SWING_TURN_RATE if swing_pull else YANK_HOLD_TURN_RATE
				var turn := turn_rate * delta
				v["yank_turn"] = float(v["yank_turn"]) + turn
				v["wheel_angle"] = float(v["wheel_angle"]) + turn
				wheel.rotation.z = float(v["wheel_angle"])
				if float(v["yank_turn"]) >= YANK_OPEN_RAD:
					if _arm_valve(v):
						facts.append({"kind": "sluice_warning", "id": v["id"], "at": v["foot"]})
			else:
				v["yank_turn"] = maxf(0.0, float(v["yank_turn"]) - WHEEL_CLOSE_RATE * delta)
				v["wheel_angle"] = move_toward(float(v["wheel_angle"]), 0.0, WHEEL_CLOSE_RATE * delta)
				wheel.rotation.z = float(v["wheel_angle"])
			v["water_level"] = 0.0
			sheet.visible = false

		"warning":
			v["wheel_angle"] = move_toward(float(v["wheel_angle"]), WHEEL_OPEN_RAD, WHEEL_OPEN_RATE * delta)
			wheel.rotation.z = float(v["wheel_angle"])
			v["water_level"] = 0.0
			sheet.visible = false
			var h: Hazard = v["hazard"]
			if h == null or not is_instance_valid(h):
				_enter_drain(v)
				return
			var age_before := h.age
			var vis_before := h.state == Hazard.WARN and h.visible and h.painter() != null
			h.step(delta)
			if vis_before:
				v["warn_elapsed"] = float(v["warn_elapsed"]) + minf(delta, maxf(0.0, h.warn_seconds - age_before))
			if h.state == Hazard.WARN:
				return
			v["last_warn_visible_s"] = float(v["warn_elapsed"])
			v["state"] = "surging"
			v["surge_elapsed"] = 0.0
			v["water_level"] = 1.0
			_update_sheet(v)
			_publish_world_fact("sluice_open", v["lane_from"])
			facts.append({"kind": "sluice_open", "id": v["id"], "at": v["lane_from"]})
			_apply_wash(v, h, motion)
			if h.is_done():
				_enter_drain(v)

		"surging":
			v["wheel_angle"] = move_toward(float(v["wheel_angle"]), WHEEL_OPEN_RAD, WHEEL_OPEN_RATE * delta)
			wheel.rotation.z = float(v["wheel_angle"])
			v["surge_elapsed"] = float(v["surge_elapsed"]) + delta
			v["water_level"] = 1.0
			_update_sheet(v)
			var h: Hazard = v["hazard"]
			if h == null or not is_instance_valid(h):
				_enter_drain(v)
				return
			h.step(delta)
			if h.is_live():
				_apply_wash(v, h, motion)
			if h.is_done() or float(v["surge_elapsed"]) >= SURGE_LIVE_S:
				_enter_drain(v)

		"draining":
			v["drain_elapsed"] = float(v["drain_elapsed"]) + delta
			v["water_level"] = clampf(1.0 - float(v["drain_elapsed"]) / DRAIN_S, 0.0, 1.0)
			v["wheel_angle"] = move_toward(float(v["wheel_angle"]), 0.0, WHEEL_CLOSE_RATE * delta)
			wheel.rotation.z = float(v["wheel_angle"])
			_update_sheet(v)
			if float(v["drain_elapsed"]) >= DRAIN_S:
				_enter_charge(v)

		"charging":
			v["water_level"] = 0.0
			sheet.visible = false
			v["wheel_angle"] = move_toward(float(v["wheel_angle"]), 0.0, WHEEL_CLOSE_RATE * delta)
			wheel.rotation.z = float(v["wheel_angle"])
			var left := maxf(0.0, float(v["charge_left"]) - delta)
			v["charge_left"] = left
			if left <= 0.0:
				v["state"] = "ready"
				v["yank_turn"] = 0.0


func _enter_drain(v: Dictionary) -> void:
	_drop_hazard(v)
	v["state"] = "draining"
	v["drain_elapsed"] = 0.0
	v["struck_enemies"] = {}
	v["ball_hit"] = false
	v["props_broken_this_surge"] = false


func _enter_charge(v: Dictionary) -> void:
	_drop_hazard(v)
	v["state"] = "charging"
	v["charge_left"] = float(v["charge"])
	v["water_level"] = 0.0
	(v["sheet"] as MeshInstance3D).visible = false


func _update_sheet(v: Dictionary) -> void:
	var sheet: MeshInstance3D = v["sheet"]
	var lvl: float = float(v["water_level"])
	sheet.visible = lvl > 0.01
	if sheet.visible:
		sheet.position.y = float(v["sheet_base_y"]) + 0.05 + SHEET_DEPTH_M * lvl


func _apply_wash(v: Dictionary, h: Hazard, motion: Dictionary) -> void:
	var ball: Vector3 = motion["pos"]
	var velocity: Vector3 = motion["vel"]
	var planar: float = float(motion["planar"])
	var riding: bool = bool(motion["riding"])
	var dir: Vector3 = v["dir"]
	if not bool(v["props_broken_this_surge"]):
		v["props_broken_this_surge"] = true
		v["props_broken"] = int(v["props_broken"]) + _break_lane_props(h)
	var tree := get_tree() if is_inside_tree() else null
	if tree != null:
		var push := (dir + Vector3.UP * 0.35).normalized()
		var washed := HazardHits.strike(tree, h.contains, WASH_SOURCE, WASH_ENEMY_DAMAGE, WASH_ENEMY_TOSS,
			v["struck_enemies"], func(_p: Vector3) -> Vector3: return push)
		v["enemies_washed"] = int(v["enemies_washed"]) + washed
	if bool(v["ball_hit"]) or riding or _is_calm():
		return
	if not h.contains(ball):
		return
	if SpeedTier.of(planar, cruise) >= SpeedTier.CRUISE:
		return
	v["ball_hit"] = true
	v["ball_hits"] = int(v["ball_hits"]) + 1
	var run_ref = ctx.get("run") if ctx != null else null
	if run_ref != null and run_ref.has_method("damage"):
		run_ref.damage(WASH_BALL_DAMAGE, WASH_SOURCE)
	var toss := dir * WASH_BALL_TOSS + Vector3.UP * WASH_BALL_LIFT
	v["last_ball_toss"] = toss
	var player_ref = ctx.get("player") if ctx != null else null
	if player_ref != null and player_ref.has_method("set_velocity_now"):
		player_ref.set_velocity_now(velocity + toss, WASH_SOURCE)


func _break_lane_props(h: Hazard) -> int:
	if ctx == null:
		return 0
	var props = ctx.get("destructibles")
	if props == null or not is_instance_valid(props) or not props.has_method("ids") or not props.has_method("on_blast"):
		return 0
	var run_ref = ctx.get("run")
	var heft := int(run_ref.heft_class()) if run_ref != null and run_ref.has_method("heft_class") else -1
	var before: int = int(props.intact_count())
	for id: String in props.ids():
		if props.state_of(id) != "intact":
			continue
		var box: AABB = props.bounds_of(id)
		var centre := box.get_center()
		var foot := Vector3(centre.x, box.position.y + 0.1, centre.z)
		if h.contains(centre) or h.contains(foot):
			props.on_blast(centre, 0.25, WASH_SOURCE, 1, heft)
	return maxi(0, before - int(props.intact_count()))


func _is_calm() -> bool:
	return ctx != null and bool(ctx.get("calm"))


func _publish_world_fact(fact: String, at: Vector3) -> void:
	var ev = ctx.get("events") if ctx != null else null
	if ev != null and ev.has_signal("world_fact"):
		ev.world_fact.emit(fact, at)


func _stage_parent() -> Node3D:
	if _stage_root == null or not is_instance_valid(_stage_root):
		_stage_root = Node3D.new()
		_stage_root.name = "StageValves"
		add_child(_stage_root)
	return _stage_root


func _ground_point(x: float, z: float) -> Vector3:
	if _ground.is_valid():
		return _ground.call(x, z, 0.0) as Vector3
	return Vector3(x, 0.0, z)


static func _vec2(value: Variant, fallback := Vector2.ZERO) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback
