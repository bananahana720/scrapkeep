extends Node3D

const Palette := preload("res://src/core/palette.gd")
const PhysicsLayers := preload("res://src/core/physics_layers.gd")
const LocalMesh := preload("res://src/world/local_mesh.gd")
const RideRail := preload("res://src/world/ride_rail.gd")
const BayLap := preload("res://src/world/bay_lap.gd")
const WorldPrompt := preload("res://src/ui/world_prompt.gd")
const StageMap := preload("res://src/world/stage_map.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const RecipeProps := preload("res://src/presentation/recipe_props.gd")
const ModelKit := preload("res://src/world/model_kit.gd")
const PropMeshes := preload("res://src/presentation/craft_prop_meshes.gd")
const KIT := "res://assets/models/world_one/bay_kit.glb"
const KIT_PARTS := ["BayCabin", "BayBellFrame", "BayBell", "BayMarbleToy", "BayYardWall", "BayPost", "BayPin", "CradleCup", "CradleMast"]


const TRACK_L := 10.0
const TRACK_R := 14.0
const DECK_U := 31.0
const DECK_V := 21.0
const RIM := 4.0
const LIFT := 46.0
const BACK := 30.0
const FLIGHT := 3.0
const FLIGHT_OUT := 3.6
const RIDE_LIFT := 14.0
const EXIT_LEAD := 10.0
const ENTRY_SPEED := 9.0
const CRADLE_RADIUS := 3.5
const CRADLE_SIDE := 10.0
const PAD := Vector2(14.0, 0.0)
const PAD_RADIUS := 2.5
const LANDING := Vector2(4.0, 0.0)
const YARD := Rect2(2.0, -8.0, 10.0, 16.0)
const MOSS := Vector2(-13.0, 0.0)
const MOSS_REACH := 5.0
const CABIN := Vector2(-17.0, 0.0)
const BELL := Vector2(-6.0, -7.0)
const JUKEBOX := Vector2(-6.0, 7.0)
const MARBLE_TOY := Vector2(-2.0, -7.5)
const TOY_REACH := 2.2
const TOY_REST := 0.8
const MARBLE_STEPS := 5
const MARBLE_STEP_SECONDS := 0.32
const PINS := [Vector2(7.0, -5.0), Vector2(8.0, -5.8), Vector2(8.0, -4.2), Vector2(9.0, -6.6), Vector2(9.0, -5.0), Vector2(9.0, -3.4)]
const PIN_RESET := 3.0
const FALL_OFF := 6.0
const PARK := Vector3(0.0, -2000.0, 0.0)
const MAP_LIMIT := 185.0

var docked := false
var inside := false
var banked := 0.0
var facing := Vector3.FORWARD
var exit_target := Vector3.ZERO
var cradle_at := Vector3.ZERO
var visits := 0
var jukebox := 0
var lap := BayLap.new([Vector2(0.0, -(TRACK_R - 1.0)), Vector2(TRACK_L + TRACK_R - 1.0, 0.0),
	Vector2(0.0, TRACK_R - 1.0), Vector2(-(TRACK_L + TRACK_R - 1.0), 0.0)])
var gravity := 26.0
var cruise := 14.0

var _barge: Node3D
var _cradle: Node3D
var _prompt
var _pins: Array[RigidBody3D] = []
var _pins_down := false
var _pin_clock := 0.0
var _rest := {}
var _marble: MeshInstance3D
var _marble_clock := -1.0
var _bell: MeshInstance3D
var _bell_swing := 0.0
var _warned := false


func setup(g: float, cruise_speed: float) -> void:
	name = "MossBay"
	gravity = g
	cruise = cruise_speed
	_barge = Node3D.new()
	_barge.name = "Barge"
	add_child(_barge)
	_build_deck()
	_build_cabin()
	_build_toys()
	_build_yard()
	_build_pad()
	_cradle = Node3D.new()
	_cradle.name = "Cradle"
	add_child(_cradle)
	_build_cradle()
	undock()


func dock(offers: Array, height: Callable, space: PhysicsDirectSpaceState3D, map: RefCounted = null) -> bool:
	if offers.is_empty() or inside:
		if inside and not offers.is_empty():
			_aim_exit(offers)
		return docked
	var centre := Vector3.ZERO
	for o in offers:
		centre += o["at"]
	centre /= offers.size()
	var f: Vector3 = offers[0]["facing"]
	facing = Vector3(f.x, 0.0, f.z).normalized()
	var side := facing.cross(Vector3.UP).normalized()
	var half := 0.0
	for o in offers:
		half = maxf(half, absf(((o["at"] as Vector3) - centre).dot(side)) + float(o.get("width", 8.0)) * 0.5)
	var placed := false
	for s in [1.0, -1.0]:
		var cradle: Vector3 = centre + side * s * (half + CRADLE_SIDE)
		var ground_y: float = height.call(cradle.x, cradle.z)
		if absf(ground_y - float(height.call(centre.x, centre.z))) > 3.0 or not _on_map(cradle, map):
			continue
		var mid := centre - facing * (BACK + DECK_U)
		var top := -INF
		var inside_map := true
		for du in [-DECK_U, 0.0, DECK_U]:
			for dv in [-DECK_V, 0.0, DECK_V]:
				var p: Vector3 = mid + facing * du + side * dv
				inside_map = inside_map and _on_map(p, map)
				top = maxf(top, height.call(p.x, p.z))
		if not inside_map:
			continue
		var deck := Vector3(mid.x, top + LIFT, mid.z)
		for lift in [0.0, 18.0]:
			var at: Vector3 = deck + Vector3.UP * lift
			if space == null or not _blocked(space, at):
				_place(at, Vector3(cradle.x, ground_y, cradle.z))
				placed = true
				break
		if placed:
			break
	if not placed:
		if not _warned:
			_warned = true
			push_warning("bay: no clear dock beside these gates; the bay stays away this time")
		return false
	_aim_exit(offers)
	docked = true
	return true


func _place(deck_at: Vector3, cradle: Vector3) -> void:
	var basis := Basis(facing, Vector3.UP, facing.cross(Vector3.UP).normalized())
	_barge.transform = Transform3D(basis, deck_at)
	_barge.visible = true
	cradle_at = cradle + Vector3.UP * 1.0
	_cradle.position = cradle
	_cradle.visible = true
	_prompt.set_parts("Moss's workshop", "", "obj_launch")
	_reset_pins()
	for pin in _pins:
		pin.freeze = false


func _aim_exit(offers: Array) -> void:
	var gate: Vector3 = offers[0]["at"]
	exit_target = gate - facing * EXIT_LEAD + Vector3.UP * 1.0


static func _on_map(p: Vector3, map: RefCounted = null) -> bool:
	if map is ParkMap and map.ok and map.park.has("play_rect"):
		var rect: Rect2 = map.play_rect
		if rect.position.is_finite() and rect.size.is_finite() and rect.end.is_finite() and rect.size.x > 0.0 and rect.size.y > 0.0:
			return p.x > rect.position.x and p.x < rect.end.x and p.z > rect.position.y and p.z < rect.end.y
	return absf(p.x) < MAP_LIMIT and absf(p.z) < MAP_LIMIT


func _blocked(space: PhysicsDirectSpaceState3D, at: Vector3) -> bool:
	var box := BoxShape3D.new()
	box.size = Vector3(DECK_U * 2.0, 12.0, DECK_V * 2.0)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = box
	q.collision_mask = PhysicsLayers.WORLD_MASK
	q.transform = Transform3D(Basis(facing, Vector3.UP, facing.cross(Vector3.UP).normalized()), at + Vector3.UP * 2.0)
	var own: Array[RID] = []
	for body in _barge.find_children("*", "CollisionObject3D", true, false):
		own.append((body as CollisionObject3D).get_rid())
	q.exclude = own
	return not space.intersect_shape(q, 1).is_empty()


func undock() -> void:
	docked = false
	inside = false
	lap.reset()
	_barge.transform = Transform3D(Basis.IDENTITY, PARK)
	_barge.visible = false
	_cradle.position = PARK
	_cradle.visible = false
	if _prompt != null:
		_prompt.set_parts("", "", "obj_launch")
	for pin in _pins:
		pin.freeze = true


func deck_y() -> float:
	return _barge.global_position.y


func to_deck(p: Vector3) -> Vector2:
	var local: Vector3 = _barge.global_transform.affine_inverse() * p
	return Vector2(local.x, local.z)


func deck_point(uv: Vector2, up := 1.0) -> Vector3:
	return _barge.global_transform * Vector3(uv.x, deck_height(uv.x, uv.y) + up, uv.y)


func on_deck(p: Vector3) -> bool:
	var uv := to_deck(p)
	return docked and absf(uv.x) <= DECK_U and absf(uv.y) <= DECK_V and p.y > deck_y() - 2.0


func in_yard(p: Vector3) -> bool:
	return inside and on_deck(p) and YARD.has_point(to_deck(p))


func near_moss(p: Vector3) -> bool:
	return inside and on_deck(p) and to_deck(p).distance_to(MOSS) <= MOSS_REACH


func moss_point() -> Vector3:
	return deck_point(MOSS, 1.6)


func pad_point() -> Vector3:
	return deck_point(PAD, 1.0)


static func deck_height(u: float, v: float) -> float:
	var d := Vector2(u, v).distance_to(Vector2(clampf(u, -TRACK_L, TRACK_L), 0.0))
	var o := d - TRACK_R
	if o <= -4.0:
		return 0.0
	if o <= 2.0:
		return -0.5 * sin((o + 4.0) / 6.0 * PI)
	if o <= 7.0:
		return RIM * pow((o - 2.0) / 5.0, 2.0)
	return RIM


func step(delta: float, ball: Vector3, velocity: Vector3, riding: bool) -> Array:
	var facts := []
	if not docked:
		return facts
	_animate(delta)
	var planar := Vector2(velocity.x, velocity.z).length()
	if not inside:
		if riding or Vector2(ball.x - cradle_at.x, ball.z - cradle_at.z).length() > CRADLE_RADIUS or absf(ball.y - cradle_at.y) > 3.0:
			return facts
		inside = true
		visits += 1
		banked = planar
		lap.reset()
		var land := deck_point(LANDING, 1.0)
		var dist := Vector2(land.x - ball.x, land.z - ball.z).length()
		facts.append({"kind": "entered", "banked": banked})
		facts.append({"kind": "ride", "ride": RideRail.arc("bay_cradle", ball, land, ENTRY_SPEED, ENTRY_SPEED, FLIGHT, gravity,
			{"flight_planar": dist / FLIGHT})})
		return facts
	if riding:
		return facts
	if ball.y < deck_y() - FALL_OFF:
		inside = false
		facts.append({"kind": "left", "velocity": velocity})
		return facts
	var uv := to_deck(ball)
	if uv.distance_to(PAD) <= PAD_RADIUS and absf(ball.y - deck_point(PAD).y) < 2.5:
		inside = false
		lap.reset()
		var speed := maxf(banked, maxf(planar, cruise))
		var dist := Vector2(exit_target.x - ball.x, exit_target.z - ball.z).length()
		var ride = RideRail.arc("bay_pad", ball, exit_target, speed, cruise, FLIGHT_OUT, gravity,
			{"flight_planar": dist / FLIGHT_OUT, "release_heading": facing, "min_lift": RIDE_LIFT})
		facts.append({"kind": "ride", "ride": ride})
		facts.append({"kind": "left", "velocity": facing * speed})
		return facts
	_toys(delta, ball, uv, facts)
	for f in lap.step(delta, uv, planar):
		var fact := {"kind": "fact", "fact": f["kind"], "at": ball}
		if f["kind"] == "lap_finished":
			fact["seconds"] = f["seconds"]
			fact["best"] = f["best"]
			if f["under_par"]:
				facts.append({"kind": "codex", "id": "pit_stop_lap", "at": ball})
		facts.append(fact)
	_pin_watch(delta, ball, facts)
	return facts


func _toys(delta: float, ball: Vector3, uv: Vector2, facts: Array) -> void:
	for key in _rest.keys():
		_rest[key] = maxf(0.0, _rest[key] - delta)
	if ball.y > deck_y() + 3.0:
		return
	if uv.distance_to(BELL) <= TOY_REACH and _rest.get("bell", 0.0) <= 0.0:
		_rest["bell"] = TOY_REST
		_bell_swing = 1.0
		facts.append({"kind": "fact", "fact": "bay_bell", "at": deck_point(BELL, 3.0)})
	if uv.distance_to(JUKEBOX) <= TOY_REACH and _rest.get("jukebox", 0.0) <= 0.0:
		_rest["jukebox"] = TOY_REST * 2.0
		jukebox = (jukebox + 1) % 2
		facts.append({"kind": "fact", "fact": "bay_jukebox", "at": deck_point(JUKEBOX, 1.5), "track": jukebox})
	if uv.distance_to(MARBLE_TOY) <= TOY_REACH and _marble_clock < 0.0:
		_marble_clock = 0.0
	if _marble_clock >= 0.0:
		var before := int(_marble_clock / MARBLE_STEP_SECONDS)
		_marble_clock += delta
		var now := int(_marble_clock / MARBLE_STEP_SECONDS)
		if now > before and now <= MARBLE_STEPS:
			facts.append({"kind": "fact", "fact": "bay_marble_note", "at": deck_point(MARBLE_TOY, 1.4), "step": now})
		if now > MARBLE_STEPS:
			_marble_clock = -1.0


func _pin_watch(delta: float, _ball: Vector3, facts: Array) -> void:
	if _pins_down:
		_pin_clock -= delta
		if _pin_clock <= 0.0:
			_reset_pins()
		return
	for pin in _pins:
		if pin.global_basis.y.dot(Vector3.UP) < 0.6:
			_pins_down = true
			_pin_clock = PIN_RESET
			facts.append({"kind": "fact", "fact": "bay_pins", "at": pin.global_position})
			return


func _reset_pins() -> void:
	_pins_down = false
	for k in _pins.size():
		var pin := _pins[k]
		var uv: Vector2 = PINS[k]
		pin.transform = Transform3D(Basis.IDENTITY, Vector3(uv.x, deck_height(uv.x, uv.y) + 0.75, uv.y))
		pin.linear_velocity = Vector3.ZERO
		pin.angular_velocity = Vector3.ZERO


func _animate(delta: float) -> void:
	if _bell != null:
		_bell_swing = maxf(0.0, _bell_swing - delta * 0.8)
		_bell.rotation.z = sin(Time.get_ticks_msec() / 90.0) * 0.4 * _bell_swing
	if _marble != null:
		if _marble_clock >= 0.0:
			var f := clampf(_marble_clock / (MARBLE_STEP_SECONDS * MARBLE_STEPS), 0.0, 1.0)
			var zig := fposmod(f * MARBLE_STEPS, 1.0)
			_marble.position = Vector3(MARBLE_TOY.x - 0.9 + f * 1.8, 2.1 - f * 0.9, MARBLE_TOY.y + (zig - 0.5) * 1.2)
		else:
			_marble.position = Vector3(MARBLE_TOY.x - 0.9, 2.1, MARBLE_TOY.y - 0.6)


func _build_deck() -> void:
	var tint := func(u: float, v: float) -> Color:
		var o := Vector2(u, v).distance_to(Vector2(clampf(u, -TRACK_L, TRACK_L), 0.0)) - TRACK_R
		if o > -4.0 and o <= 7.0:
			return Palette.CHARCOAL.lerp(Palette.VERDIGRIS, 0.5)
		if YARD.grow(0.4).has_point(Vector2(u, v)) and not YARD.grow(-0.4).has_point(Vector2(u, v)):
			return Palette.SAND
		if o > 7.0:
			return Palette.RUST.lerp(Palette.SANDSTONE, 0.3)
		return Palette.SANDSTONE.lerp(Palette.SAND, 0.4)
	var deck := LocalMesh.grid(_barge, "BayDeck", Vector2(DECK_U * 2.0, DECK_V * 2.0), 1.0, deck_height, tint)
	var deck_view := deck.get_child(1) as MeshInstance3D
	deck_view.material_override = _paint(Color.WHITE, 1, Vector3.ZERO, deck_view.material_override)
	RecipeProps.base("moss_hover_barge", _barge, Transform3D.IDENTITY)
	RecipeProps.shells("moss_hover_barge", _barge, Transform3D.IDENTITY)
	for corner in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var jet := Vector3(corner.x * (DECK_U - 6.0), -4.5, corner.y * (DECK_V - 5.0))
		var steam := MeshInstance3D.new()
		steam.mesh = PropMeshes.fluted_plume_column(4.0, 2.4, 6.0)
		steam.material_override = Palette.unshaded(Color(Palette.SAND, 0.25))
		steam.position = jet + Vector3.DOWN * 4.5
		_barge.add_child(steam)
	var line := MeshInstance3D.new()
	var line_size := Vector3(1.2, 0.08, 8.5)
	line.mesh = PropMeshes.bevel_prop_box(line_size)
	line.material_override = _paint(Palette.SAND, 3, line_size)
	line.position = Vector3(0.0, 0.02 + deck_height(0.0, -(TRACK_R - 1.0)), -(TRACK_R - 1.0))
	_barge.add_child(line)


func _build_cabin() -> void:
	var cabin := StaticBody3D.new()
	cabin.name = "MossCabin"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(5.0, 6.0, 8.0)
	shape.shape = box
	cabin.add_child(shape)
	cabin.position = Vector3(CABIN.x, 3.0, CABIN.y)
	_barge.add_child(cabin)
	var front := CABIN.x + 2.55
	if _model("BayCabin", cabin, Vector3.ZERO) != null:
		_shelf_parts(front)
		return
	var body := MeshInstance3D.new()
	body.mesh = PropMeshes.bevel_prop_box(box.size)
	body.material_override = _paint(Palette.VERDIGRIS)
	cabin.add_child(body)
	_visual(Vector3(0.1, 4.6, 7.0), Vector3(front, 3.4, 0.0), _paint(Palette.RUST, 2))
	_visual(Vector3(0.14, 1.3, 1.8), Vector3(front + 0.02, 1.2, 0.0), _bay_mat(Palette.CHARCOAL))
	_visual(Vector3(1.0, 1.0, 6.0), Vector3(front + 0.8, 0.5, 0.0), _bay_mat(Palette.RUST.lerp(Palette.SANDSTONE, 0.3)))
	_visual(Vector3(0.6, 0.12, 5.0), Vector3(front + 0.35, 5.2, 0.0), _bay_mat(Palette.COPPER))
	_shelf_parts(front)
	var hook := MeshInstance3D.new()
	hook.mesh = PropMeshes.launcher_mouth_ring(0.42)
	hook.material_override = _paint(Palette.COPPER)
	hook.position = Vector3(front + 0.3, 4.0, 3.0)
	hook.rotation.z = PI * 0.5
	_barge.add_child(hook)
	_visual(Vector3(0.3, 0.45, 0.35), Vector3(front + 0.3, 3.55, 3.0), _bay_mat(Palette.CHARCOAL))
	var dial := MeshInstance3D.new()
	dial.mesh = PropMeshes.fluted_plume_column(0.55, 0.55, 0.08)
	dial.material_override = _paint(Palette.SAND)
	dial.position = Vector3(front + 0.12, 4.9, 3.0)
	dial.rotation.z = PI * 0.5
	_barge.add_child(dial)
	_visual(Vector3(0.05, 0.2, 0.08), Vector3(front + 0.18, 5.3, 3.25), _bay_mat(Palette.RUST))
	_visual(Vector3(0.05, 0.45, 0.06), Vector3(front + 0.18, 4.95, 3.0), _bay_mat(Palette.CHARCOAL))
	var mug := MeshInstance3D.new()
	mug.mesh = PropMeshes.bay_mug_mesh(0.20, 0.22, 0.40)
	mug.material_override = _paint(Palette.SAND)
	mug.position = Vector3(front + 0.8, 1.2, -1.8)
	_barge.add_child(mug)
	_visual(Vector3(0.08, 0.1, 0.1), Vector3(front + 1.02, 1.36, -1.8), _bay_mat(Palette.CHARCOAL))
	var tin := MeshInstance3D.new()
	tin.mesh = PropMeshes.bay_mug_mesh(0.30, 0.30, 0.45)
	tin.material_override = _paint(Palette.COPPER)
	tin.position = Vector3(front + 0.8, 1.22, 2.0)
	_barge.add_child(tin)
	for k in 3:
		var leaf := MeshInstance3D.new()
		leaf.mesh = PropMeshes.bay_marble_orb(0.22)
		leaf.material_override = _paint(Palette.VERDIGRIS.lerp(Palette.ARC, 0.25))
		leaf.position = Vector3(front + 0.8 + (k - 1) * 0.15, 1.6 + k * 0.08, 2.0 + (k - 1) * 0.12)
		_barge.add_child(leaf)


func _shelf_parts(front: float) -> void:
	var rarities := [Palette.ARC, Palette.COBALT, Palette.AMBER]
	for k in 3:
		var part := MeshInstance3D.new()
		part.mesh = PropMeshes.bay_part_trophy()
		part.material_override = _bay_mat(rarities[k], 0.6)
		part.position = Vector3(front + 0.4, 5.65, -1.6 + k * 1.6)
		part.rotation = Vector3(PI * 0.25, 0.0, PI * 0.25)
		_barge.add_child(part)


func _build_toys() -> void:
	var bell_at := Vector3(BELL.x, 3.9, BELL.y)
	if _model("BayBellFrame", _barge, Vector3(BELL.x, 0.0, BELL.y)) != null:
		_bell = _model("BayBell", _barge, bell_at)
	else:
		for side in [-1.0, 1.0]:
			_visual(Vector3(0.3, 5.0, 0.3), Vector3(BELL.x + side * 1.6, 2.5, BELL.y), _bay_mat(Palette.RUST))
		_visual(Vector3(3.6, 0.3, 0.3), Vector3(BELL.x, 5.0, BELL.y), _bay_mat(Palette.RUST))
		_bell = MeshInstance3D.new()
		_bell.mesh = PropMeshes.bay_bell_mesh()
		_bell.material_override = _paint(Palette.BRASS.lerp(Palette.COPPER, 0.5))
		_bell.position = bell_at
		_barge.add_child(_bell)
	var juke_at := Transform3D(Basis.IDENTITY, Vector3(JUKEBOX.x, 0.0, JUKEBOX.y + 1.6))
	RecipeProps.base("moss_jukebox", _barge, juke_at)
	RecipeProps.shells("moss_jukebox", _barge, juke_at)
	_visual(Vector3(2.4, 0.1, 2.4), Vector3(JUKEBOX.x, 0.05, JUKEBOX.y), _paint(Palette.AMBER, 3, Vector3(2.4, 0.1, 2.4)))
	if _model("BayMarbleToy", _barge, Vector3(MARBLE_TOY.x, 0.0, MARBLE_TOY.y)) == null:
		_visual(Vector3(2.4, 1.6, 1.6), Vector3(MARBLE_TOY.x, 0.8, MARBLE_TOY.y - 1.4), _bay_mat(Palette.RUST.lerp(Palette.SANDSTONE, 0.4)))
		for k in MARBLE_STEPS:
			var step_bar := _visual(Vector3(0.5, 0.08, 1.3), Vector3(MARBLE_TOY.x - 0.9 + k * 0.4, 2.05 - k * 0.18, MARBLE_TOY.y - 0.8),
				_bay_mat(Palette.COPPER))
			step_bar.rotation.x = 0.3 if k % 2 == 0 else -0.3
	_marble = MeshInstance3D.new()
	_marble.mesh = PropMeshes.bay_marble_orb(0.22)
	_marble.material_override = _bay_mat(Palette.SAND, 0.4)
	_barge.add_child(_marble)
	_visual(Vector3(2.4, 0.1, 2.4), Vector3(MARBLE_TOY.x, 0.05, MARBLE_TOY.y), _paint(Palette.SAND, 3, Vector3(2.4, 0.1, 2.4)))


func _build_yard() -> void:
	var wall := StaticBody3D.new()
	wall.name = "YardWall"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8.0, 5.0, 1.4)
	shape.shape = box
	wall.add_child(shape)
	if _model("BayYardWall", wall, Vector3.ZERO) == null:
		var mesh := MeshInstance3D.new()
		mesh.mesh = PropMeshes.bevel_prop_box(box.size)
		mesh.material_override = _paint(Palette.VERDIGRIS, 0, box.size)
		wall.add_child(mesh)
	wall.position = Vector3(YARD.position.x + YARD.size.x * 0.5, 2.5, YARD.end.y + 0.8)
	_barge.add_child(wall)
	var post := StaticBody3D.new()
	var ps := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.6
	cyl.height = 9.0
	ps.shape = cyl
	post.add_child(ps)
	if _model("BayPost", post, Vector3.ZERO) == null:
		var pv := MeshInstance3D.new()
		pv.mesh = PropMeshes.fluted_plume_column(0.6, 0.6, 9.0)
		pv.material_override = _paint(Palette.COPPER)
		post.add_child(pv)
	post.position = Vector3(YARD.position.x + 1.0, 4.5, YARD.position.y - 0.8)
	_barge.add_child(post)
	_visual(Vector3(1.6, 1.6, 1.6), post.position + Vector3.UP * 5.0, _bay_mat(Palette.AMBER, 1.2))
	for k in PINS.size():
		var pin := RigidBody3D.new()
		pin.name = "Pin%d" % k
		pin.mass = 0.4
		var s := CollisionShape3D.new()
		var c := CylinderShape3D.new()
		c.radius = 0.3
		c.height = 1.5
		s.shape = c
		pin.add_child(s)
		if _model("BayPin", pin, Vector3.ZERO) == null:
			var v := MeshInstance3D.new()
			v.mesh = PropMeshes.bay_pin_mesh()
			v.material_override = _paint(Palette.SAND)
			pin.add_child(v)
		_barge.add_child(pin)
		_pins.append(pin)
	_reset_pins()


func _build_pad() -> void:
	var pad := MeshInstance3D.new()
	pad.mesh = PropMeshes.launch_landing_pad(PAD_RADIUS)
	pad.material_override = _paint(Palette.AMBER, 3, Vector3(PAD_RADIUS * 2.0, 0.12, PAD_RADIUS * 2.0))
	pad.position = Vector3(PAD.x, 0.06, PAD.y)
	_barge.add_child(pad)
	for k in 3:
		var chevron := _visual(Vector3(0.4, 0.1, 1.8), Vector3(PAD.x + 0.9 + k * 0.9, 0.14, PAD.y), _bay_mat(Palette.AMBER, 0.8))
		chevron.rotation.y = 0.0


func _build_cradle() -> void:
	var ring := MeshInstance3D.new()
	ring.mesh = PropMeshes.launcher_mouth_ring(CRADLE_RADIUS)
	ring.material_override = _bay_mat(Palette.AMBER, 0.8)
	ring.position = Vector3.UP * 0.2
	_cradle.add_child(ring)
	if _model("CradleCup", _cradle, Vector3.UP * 0.05) != null and _model("CradleMast", _cradle, Vector3(CRADLE_RADIUS + 1.2, 6.0, 0.0)) != null:
		_cradle_prompt()
		return
	var cup := MeshInstance3D.new()
	cup.mesh = PropMeshes.fluted_plume_column(1.2, CRADLE_RADIUS - 0.8, 0.6)
	cup.material_override = _paint(Palette.COPPER)
	cup.position = Vector3.UP * 0.05
	_cradle.add_child(cup)
	var mast := MeshInstance3D.new()
	mast.mesh = PropMeshes.fluted_plume_column(0.35, 0.35, 12.0)
	mast.material_override = _paint(Palette.RUST)
	mast.position = Vector3(CRADLE_RADIUS + 1.2, 6.0, 0.0)
	_cradle.add_child(mast)
	var sign_mug := MeshInstance3D.new()
	sign_mug.mesh = PropMeshes.bay_mug_mesh(0.8, 0.9, 1.4)
	sign_mug.material_override = _bay_mat(Palette.SAND, 0.5)
	sign_mug.position = Vector3(CRADLE_RADIUS + 1.2, 12.6, 0.0)
	_cradle.add_child(sign_mug)
	_cradle_prompt()


func _cradle_prompt() -> void:
	var anchor := Node3D.new()
	anchor.position = Vector3(CRADLE_RADIUS + 1.2, 14.0, 0.0)
	_cradle.add_child(anchor)
	_prompt = WorldPrompt.new()
	_prompt.add_theme_color_override("font_color", Palette.SANDSTONE)
	_prompt.attach(anchor, Vector3.ZERO, 70.0)
	anchor.add_child(_prompt)


func _model(part: String, parent: Node3D, at: Vector3) -> MeshInstance3D:
	var view := ModelKit.part(KIT, KIT_PARTS, part, parent)
	if view != null:
		view.position = at
	return view


func _visual(size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = PropMeshes.bevel_prop_box(size)
	mesh.material_override = _paint(mat.albedo_color, 1, size) if mat is StandardMaterial3D and not mat.emission_enabled and mat.albedo_texture == null else mat
	mesh.position = at
	_barge.add_child(mesh)
	return mesh


func _bay_mat(color: Color, emit := 0.0) -> Material:
	return Palette.solid(color, emit) if emit > 0.0 else _paint(color)


func _paint(color: Color, kind := 1, size := Vector3.ZERO, original: Material = null) -> Material:
	return StageMap.dressed_surface(color, kind, size, Palette.CHARCOAL, original)
