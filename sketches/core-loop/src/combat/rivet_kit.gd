extends Node

# Rivet's kit beyond the gun (design-v3/pilots/rivet.md sections 2.3 and 3): Line Drive on slot 3
# and the three Foundry Cutter set pieces on Q, all landing in the Breach Skid. combat.gd
# registers line_row() in its Rivet block; ultimate.gd's Rivet rows call tech, peak and landing
# here. Every number is a Weapons.LINE_*, CUTTER_*, FULL_CUT_*, BREACH_*, PRISM_* or DRIVE_*
# constant. Everything Rivet does runs in a straight line and turns back into forward speed.

const AbilityState := preload("res://src/core/ability_state.gd")
const Ultimate := preload("res://src/combat/ultimate.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const Augments := preload("res://src/movement/augments.gd")
const PlayerBall := preload("res://src/movement/player_ball.gd")
const RideRail := preload("res://src/world/ride_rail.gd")
const Hitscan := preload("res://src/combat/hitscan.gd")
const Palette := preload("res://src/core/palette.gd")
const Indicator := preload("res://src/movement/indicator.gd")
const TerrainFaces := preload("res://src/combat/terrain_faces.gd")
const DamageDoor := preload("res://src/combat/damage_door.gd")

const SET_PIECES := ["foundry_cutter", "prism_cutter", "juggernaut_drive"]
const BEAM_PIECES := ["foundry_cutter", "prism_cutter"]
const SHAPE_DISPATCH := {
	"foundry_cutter": ["tech", "peak", "landing"],
	"prism_cutter": ["tech", "peak", "landing"],
	"juggernaut_drive": ["tech", "peak", "landing", "drive_step"],
}
# Discoveries (section 8; CUSTOMIZE section 3 change 3): ten punches landed in one stage, thirty
# ignored holds and knocks in one run, a beam cutting three. Full Breach is no discovery: its
# grant reads ultimate_landed's hits for foundry_cutter (CUSTOMIZE.md:356, :412).
const LINE_TRUE_PUNCHES := 10
const SHRUG_HITS := 30
const CUTTER_CARD_CUTS := 3
# A pin this soon after a punch is that punch's pin (enemy_pinned names only the victim).
const PIN_WINDOW := 1.5
# The thrown-direction arrow the preview draws from a punched machine (section 2.3).
const ARROW_LENGTH := 6.0

class VolumeIndicator extends Indicator:
	# A scar runs to thousands of triangles, so each layer's are built once, in world space, as
	# packed arrays, and reach the mesh in one batch moved by _p's lift (and collapse) as one
	# transform: an ImmediateMesh call per vertex cost more than the carve.
	var scar_mesh := ArrayMesh.new()
	var _drawn_shapes := {}
	# layer -> {shape, vertices, colors}
	var _built := {}
	static var _strip_unit := PackedVector3Array([Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3(1, 0, 0), Vector3(-1, 0, 1), Vector3(-1, 0, 0)])
	static var _cap_unit := _cap_points(EDGE * 0.5)

	func _ready() -> void:
		super._ready()
		_mesh.mesh = scar_mesh

	func _process(delta: float) -> void:
		if shapes == _drawn_shapes and _collapsing.is_empty():
			return
		_drawn_shapes = shapes.duplicate()
		for layer in _collapsing.keys():
			_collapsing[layer]["t"] += delta
			if _collapsing[layer]["t"] >= COLLAPSE:
				_collapsing.erase(layer)
		scar_mesh.clear_surfaces()
		if shapes.is_empty() and _collapsing.is_empty():
			return
		var now := Time.get_ticks_msec() / 1000.0
		var vertices := PackedVector3Array()
		var colors := PackedColorArray()
		var built := {}
		for layer in shapes:
			var cached: Dictionary = _built.get(layer, {})
			if cached.is_empty() or not is_same(cached["shape"], shapes[layer]):
				cached = _build(shapes[layer], now)
			built[layer] = cached
			vertices.append_array(_placed(cached, 1.0))
			colors.append_array(cached["colors"])
		_built = built
		for layer in _collapsing:
			var entry: Dictionary = _collapsing[layer]
			var drawn := _build(entry["shape"], now)
			vertices.append_array(_placed(drawn, 1.0 - clampf(entry["t"] / COLLAPSE, 0.0, 1.0)))
			colors.append_array(drawn["colors"])
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_COLOR] = colors
		scar_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	func set_shape(layer: String, shape: Dictionary) -> void:
		if (shape["cells"] as Array).all(func(cell): return (cell["faces"] as Array).is_empty()):
			clear(layer)
			last_shape[layer] = shape
			return
		super.set_shape(layer, shape)

	# _p for every vertex at once: scaled by k into the origin, then lifted.
	static func _placed(drawn: Dictionary, k: float) -> PackedVector3Array:
		var origin: Vector3 = drawn["shape"]["origin"]
		return Transform3D(Basis.from_scale(Vector3.ONE * k), origin * (1.0 - k) + Vector3.UP * LIFT) * (drawn["vertices"] as PackedVector3Array)

	# The fills, then every keyline, then every strip and cap, so the charcoal keyline sits under
	# every edge. A part's edge belongs to two of its faces and its corners to three or more, so
	# each edge and each corner is drawn once, where the scar drew 40 triangles a face edge. The
	# colours are taken once: a volume record has no "fill" to breathe with.
	static func _build(shape: Dictionary, now: float) -> Dictionary:
		var look := style(shape, now)
		var fill: Color = look["fill"]
		var keyline := PackedColorArray()
		keyline.resize(6)
		keyline.fill(Palette.CHARCOAL)
		var strip := PackedColorArray()
		strip.resize(6)
		strip.fill(look["edge"])
		var cap := PackedColorArray()
		cap.resize(_cap_unit.size())
		cap.fill(look["edge"])
		var vertices := PackedVector3Array()
		var colors := PackedColorArray()
		var keylines := PackedVector3Array()
		var keyline_colors := PackedColorArray()
		var edges := PackedVector3Array()
		var edge_colors := PackedColorArray()
		var edged := {}
		var capped := {}
		for cell in shape["cells"]:
			for face in cell["faces"]:
				for i in range(1, face.size() - 1):
					vertices.append(face[0])
					vertices.append(face[i])
					vertices.append(face[i + 1])
					colors.append(fill)
					colors.append(fill)
					colors.append(fill)
				for i in face.size():
					var a: Vector3 = face[i]
					var b: Vector3 = face[(i + 1) % face.size()]
					if (edged.get(a, {}) as Dictionary).has(b) or (edged.get(b, {}) as Dictionary).has(a):
						continue
					if not edged.has(a):
						edged[a] = {}
					edged[a][b] = true
					var along := b - a
					var flat := Vector3(along.x, 0.0, along.z)
					var side := flat.cross(Vector3.UP).normalized() if flat.length_squared() > 0.0001 else Vector3.RIGHT
					keylines.append_array(Transform3D(Basis(side * (EDGE * 0.5 + KEYLINE), Vector3.UP, along), a) * _strip_unit)
					keyline_colors.append_array(keyline)
					edges.append_array(Transform3D(Basis(side * (EDGE * 0.5), Vector3.UP, along), a) * _strip_unit)
					edge_colors.append_array(strip)
					for corner: Vector3 in [a, b]:
						if not capped.has(corner):
							capped[corner] = true
							edges.append_array(Transform3D(Basis.IDENTITY, corner) * _cap_unit)
							edge_colors.append_array(cap)
		vertices.append_array(keylines)
		vertices.append_array(edges)
		colors.append_array(keyline_colors)
		colors.append_array(edge_colors)
		return {"shape": shape, "vertices": vertices, "colors": colors}

	# _cap's eight triangles about the origin.
	static func _cap_points(radius: float) -> PackedVector3Array:
		var points := PackedVector3Array()
		for i in 8:
			points.append(Vector3.ZERO)
			points.append(_around(TAU * float(i) / 8.0) * radius)
			points.append(_around(TAU * float(i + 1) / 8.0) * radius)
		return points


var volume_indicator: VolumeIndicator
var combat
var ctx
# Punches running down the cable: {target, force, mult, dir, left}.
var pulses: Array = []
# The haul in progress: {ride, anchor, seconds}, or {}.
var haul := {}
# What the last line cast did, for the audio row: {on, delay or seconds}.
var last_cue := {}
var last_punch := {}
var beam_shapes: Array = []
var selected_shapes: Array = []
var terrain := TerrainFaces.new()


static func shape_paths() -> Array:
	var paths: Array = []
	for id in SHAPE_DISPATCH:
		for entry in SHAPE_DISPATCH[id]:
			paths.append({"id": id, "entry": entry})
	return paths


static func ultimate_row(owner, id: String) -> Dictionary:
	return {"tech": func(beat, ball, aim, mult): return owner.get_node("RivetKit").tech(id, beat, ball, aim, mult),
		"peak": func(at): owner.get_node("RivetKit").peak(id, at),
		"landing": func(at, heft, chain): return owner.get_node("RivetKit").landing(id, at, heft, chain)}
# The aim the last beat read (ctx.aim_forward() on that tick); the peak, which gets only a
# point, cuts along it.
var _last_aim := Vector3.ZERO
var _clock := 0.0
var _piece := ""
var _cut := {}
var _rammed := {}
var _shoulder := 0.0
var _excepted: Array = []
var _scar_left := 0.0
var _punches := 0
var _shrugs := 0
var _entry_shrugs := 0
var _cards := {}
var _card_frame := -1


static func line_row(owner) -> Dictionary:
	var kit = load("res://src/combat/rivet_kit.gd").new()
	kit.name = "RivetKit"
	owner.add_child(kit)
	kit.setup(owner)
	return {"on_body": kit.on_body, "on_world": kit.on_world, "geometry": kit.geometry}


func setup(owner) -> void:
	combat = owner
	ctx = owner.ctx
	volume_indicator = VolumeIndicator.new()
	add_child(volume_indicator)
	process_physics_priority = 10
	ctx.events.run_started.connect(func(_pilot: String):
		_shrugs = 0
		_entry_shrugs = 0
		_punches = 0
		_cards.clear()
		_clear())
	ctx.events.stage_entered.connect(func(_stage: int, retry: bool):
		_shrugs = _entry_shrugs if retry else _shrugs
		_entry_shrugs = _shrugs
		_punches = 0
		_cards.clear()
		_clear())
	ctx.events.stage_content_cleared.connect(func(_reason: String): _clear())
	ctx.events.player_died.connect(_clear)
	ctx.events.ultimate_started.connect(func(id: String, _path: String, _from: Vector3, _to: Vector3, _seconds: float):
		_clear_piece()
		if id in SET_PIECES:
			_piece = id)
	ctx.events.ultimate_cancelled.connect(func(_id: String, _reason: String, _refund: bool): _clear_piece())
	ctx.events.enemy_pinned.connect(_on_pinned)
	ctx.events.cc_ignored.connect(_on_cc_ignored)
	ctx.events.synergy_discovered.connect(func(_id: String, _category: String, _first: bool):
		_card_frame = Engine.get_physics_frames())


func _rivet() -> bool:
	return ctx.player.class_def != null and ctx.player.class_def.id == "runner_gunner"


func _class() -> int:
	return clampi(int(ctx.run.heft_class()), 1, 5)


func _alive(enemy) -> bool:
	return not DamageDoor.dead(enemy)


func _warden(enemy: Node3D) -> bool:
	return enemy.has_method("_apply_posture") and enemy.has_method("staggered")


func _boss(enemy: Node3D) -> bool:
	return combat._target_class(enemy) == "boss"


func _enemies() -> Array:
	return get_tree().get_nodes_in_group("enemy").filter(func(enemy): return _alive(enemy))


func _knob(name: String, fallback):
	return combat.ultimate._knob(name, fallback) if combat.ultimate != null else fallback


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


# The ram force whose punch is `punch` now: punch_of("ram", f) is linear in f, so this inverts
# it exactly (heft, the sprint and the winch scale included).
func ram_force(punch: float) -> float:
	var base: float = combat.punch_of("ram", 0.0)
	var per: float = combat.punch_of("ram", 1.0) - base
	return (punch - base) / per if per > 0.0001 else 0.0


# The slam force whose punch is `punch` (the slam row has no base term).
func slam_force(punch: float) -> float:
	var per: float = combat.punch_of("slam", 1.0)
	return punch / per if per > 0.0001 else 0.0


# --- Line Drive -----------------------------------------------------------------------

# The committed throw direction: along the cable, away from the ball.
func punch_dir(target: Node3D) -> Vector3:
	var d := _flat(target.global_position - ctx.player.ball_position())
	return d.normalized() if d.length() > 0.01 else _flat(combat._flat_aim()).normalized()


# The punch's ram force: max(floor, share x the ball's planar speed).
func punch_force() -> float:
	return maxf(Weapons.LINE_PUNCH_FLOOR, Weapons.LINE_PUNCH_SHARE * ctx.player.planar_velocity().length())


func haul_stop(anchor: Vector3) -> Vector3:
	var ball: Vector3 = ctx.player.ball_position()
	var d := anchor - ball
	return anchor - d.normalized() * Augments.MIN_ROPE if d.length() > Augments.MIN_ROPE else ball


# The preview a tap draws from the pick to the click: on a body the 6 m throw arrow from the
# machine down the cable, on a world anchor the rod to the arrival point 2.5 m short.
func geometry(_fraction: float) -> Dictionary:
	var kit = ctx.player.kit
	var ball: Vector3 = ctx.player.ball_position()
	if kit.hooked and kit.on_body and is_instance_valid(kit.anchor_body):
		var at: Vector3 = kit.anchor_body.global_position
		var to: Vector3 = at + punch_dir(kit.anchor_body) * ARROW_LENGTH
		return ctx.player.yours({"kind": "line", "from": at, "to": to, "full_to": to, "width": 1.0, "fill": 1.0})
	var anchor: Vector3 = kit.anchor if kit.hooked else ball + combat._flat_aim() * ctx.player.grapple_range()
	var stop := haul_stop(anchor)
	return ctx.player.yours({"kind": "line", "from": ball, "to": stop, "full_to": stop, "width": 1.0, "fill": 1.0})


func on_body(target: Node3D, _fraction: float, mult: float) -> void:
	last_cue = {"on": "body", "delay": 0.0}
	if not _alive(target):
		return
	var delay: float = ctx.player.ball_position().distance_to(target.global_position) / Weapons.LINE_PULSE_SPEED
	pulses.append({"target": target, "force": punch_force(), "mult": mult, "dir": punch_dir(target), "left": delay})
	last_cue = {"on": "body", "delay": delay}
	combat.effects.arc(ctx.player.ball_position() + Vector3.UP * 0.5, target.global_position + Vector3.UP * 0.5, ctx.player.class_color())


func on_world(anchor: Vector3, _fraction: float, _mult: float) -> void:
	last_cue = {"on": "world", "seconds": 0.0}
	var player = ctx.player
	var ball: Vector3 = player.ball_position()
	var stop := haul_stop(anchor)
	var d := stop - ball
	if d.length() < 0.05:
		player.kit.drop_line("let_go")
		return
	var speed := maxf(player.state.velocity.length(), Weapons.LINE_HAUL_SPEED)
	var ride = RideRail.new()
	ride.kind = "rivet_haul"
	ride.mode = RideRail.LINE
	ride.origin = ball
	ride.target = stop
	ride.velocity = d.normalized() * speed
	ride.flight = d.length() / speed + RideRail.LET_GO
	ride.release_speed = speed
	ride.heading = _flat(d).normalized() if _flat(d).length() > 0.01 else Vector3.FORWARD
	ride.active = true
	haul = {"ride": ride, "anchor": anchor, "seconds": ride.flight}
	last_cue = {"on": "world", "seconds": ride.flight}
	# Crowd control slides off for the haul plus the grace; damage still lands (the sprint's rule).
	player.grant_immunity(ride.flight + Weapons.LINE_HAUL_GRACE)
	player.body().set_velocity_now(ride.velocity)
	player.indicator.set_shape("rivet_haul", player.yours({"kind": "line", "from": ball, "to": stop, "full_to": stop, "width": 1.0, "fill": 1.0}))


func _step_pulses(delta: float) -> void:
	for rec in pulses.duplicate():
		rec["left"] = float(rec["left"]) - delta
		if float(rec["left"]) > 0.0:
			continue
		pulses.erase(rec)
		# A target freed while the pulse ran cannot be assigned to a typed local; drop the pulse.
		if not is_instance_valid(rec["target"]):
			continue
		var target: Node3D = rec["target"]
		var kit = ctx.player.kit
		# The pulse runs down the cable: a line cut before it arrives carries nothing.
		if not _alive(target) or not kit.hooked or not kit.on_body or kit.anchor_body != target:
			continue
		_punch(target, float(rec["force"]), float(rec["mult"]), rec["dir"])


# The punch lands: a ram through punch_of("ram", f) x the chain multiplier, knock 34 along the
# cable with the overdrive impact's lift. A Warden's closed guard takes posture only, capped; an
# open core takes one ram contact and never shatters; a boss takes half and is not moved.
func _punch(target: Node3D, force: float, mult: float, dir: Vector3) -> void:
	var punch: float = combat.punch_of("ram", force) * mult
	if _warden(target):
		var result: Dictionary = target.judge_hit("ram", punch, false, 0)
		result["shatter"] = false
		if not target.staggered():
			result["gain"] = minf(float(result.get("gain", 0.0)), Weapons.LINE_WARDEN_POSTURE)
			result["crack"] = false
			# The shared glance fact drives both the slate burst and the low clank.
			ctx.events.strike_deflected.emit(target, "ram", float(result["punch"]), float(result["plating"]))
		target._apply_posture(result)
	elif _boss(target):
		combat.strike(target, "ram", ram_force(punch * Ultimate.BOSS_MULT), "", "special")
	else:
		combat._hit(target, "ram", ram_force(punch), dir, Weapons.LINE_PUNCH_KNOCK, "", "special", "overdrive")
	last_punch = {"id": target.get_instance_id(), "clock": _clock, "punch": punch, "dir": dir}
	_punches += 1
	if _punches == LINE_TRUE_PUNCHES:
		_discover("rivet_line_true", "loaded_line", target.global_position)


func _on_pinned(victim: Node3D, _damage: float) -> void:
	if last_punch.is_empty() or _clock - float(last_punch["clock"]) > PIN_WINDOW:
		return
	if is_instance_valid(victim) and victim.get_instance_id() != int(last_punch["id"]):
		_discover("rivet_line_drive", "loaded_line", victim.global_position)


func _step_haul(_delta: float) -> void:
	if haul.is_empty():
		return
	var kit = ctx.player.kit
	if not kit.hooked or kit.on_body:
		_end_haul(false)
		return
	var ride = haul["ride"]
	var v = ride.step(_delta)
	if v != null:
		ctx.player.body().set_velocity_now(v)
		return
	_end_haul(true)


# Arrival: the line lets go 2.5 m short and the ball keeps the haul's speed (a ride never cuts it).
func _end_haul(arrived: bool) -> void:
	if arrived:
		ctx.player.body().set_velocity_now(haul["ride"].velocity)
		ctx.player.kit.drop_line("let_go")
	haul = {}
	ctx.player.indicator.clear("rivet_haul")


func _step_preview() -> void:
	var player = ctx.player
	var kit = player.kit
	if _rivet() and haul.is_empty() and player.abilities.selected == AbilityState.LINE and kit.hooked \
			and player.abilities.id_of(AbilityState.LINE) == "line_drive":
		player.indicator.set_shape("rivet_line", geometry(1.0))
		if not kit.on_body:
			player.indicator.set_shape("rivet_arrival", player.yours({"kind": "ring", "centre": haul_stop(kit.anchor), "radius": player.tuning.RADIUS}))
		else:
			player.indicator.clear("rivet_arrival")
	else:
		player.indicator.clear("rivet_line")
		player.indicator.clear("rivet_arrival")


func _on_cc_ignored(_kind: String) -> void:
	if not _rivet():
		return
	_shrugs += 1
	if _shrugs == SHRUG_HITS:
		_discover("rivet_shrugged", "", ctx.player.ball_position())


# --- Foundry Cutter and its variants --------------------------------------------------

func _heading() -> Vector3:
	var ult = combat.ultimate
	if ult != null and ult._ride != null:
		return ult._ride.heading
	return combat._flat_aim()


# The lens faces forward: the aim's yaw is clamped CUTTER_CLAMP_DEG off the travel heading.
func beam_dir(aim: Vector3, heading := Vector3.ZERO) -> Vector3:
	var h := _flat(heading if heading != Vector3.ZERO else _heading()).normalized()
	var flat := _flat(aim)
	if flat.length() < 0.001:
		return aim.normalized() if aim.length_squared() > 0.0001 else h
	var angle := h.signed_angle_to(flat.normalized(), Vector3.UP)
	var limit := deg_to_rad(Weapons.CUTTER_CLAMP_DEG)
	var unit := aim.normalized()
	return h.rotated(Vector3.UP, clampf(angle, -limit, limit)) * Vector2(unit.x, unit.z).length() + Vector3.UP * unit.y


func beam_width(id: String) -> float:
	if id == "prism_cutter":
		return Weapons.PRISM_WIDTH + Weapons.PRISM_WIDTH_STEP * float(_class() - 1)
	return float(Weapons.CUTTER_WIDTH[_class() - 1])


func _beam_aim(from: Vector3, aim: Vector3, reach: float) -> Vector3:
	var space: PhysicsDirectSpaceState3D = ctx.root.get_world_3d().direct_space_state
	var resolved := Hitscan.aim(space, ctx.aim_origin(), aim, from, reach)
	var toward: Vector3 = resolved["point"] - from
	return beam_dir(toward if toward.length_squared() > 0.0001 else aim)


func _commit_beam(from: Vector3, dir: Vector3, length: float, width: float) -> Dictionary:
	var endpoint := from + dir * length
	var space: PhysicsDirectSpaceState3D = ctx.root.get_world_3d().direct_space_state
	var cover := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, endpoint, Hitscan.WORLD))
	if not cover.is_empty():
		endpoint = cover["position"]
	return ctx.player.yours({"origin": from, "direction": dir, "endpoint": endpoint, "width": width,
		"kind": "line", "rivet_shape": true, "from": from, "to": endpoint, "full_to": endpoint, "fill": 1.0,
		"cover": [cover["position"], cover["normal"]]} if not cover.is_empty() else {"origin": from, "direction": dir, "endpoint": endpoint, "width": width,
		"kind": "line", "rivet_shape": true, "from": from, "to": endpoint, "full_to": endpoint, "fill": 1.0})


# Every area hit selects from its committed record, including its terrain planes. The tests'
# copy is shallow: the record's cells are committed and never rewritten, and a deep copy of a
# level Breach's carve cost a tenth of its landing tick.
func select(shape: Dictionary) -> Array:
	selected_shapes.append(shape.duplicate())
	var picks: Array = []
	var boxes := _cell_boxes(shape)
	for enemy in _enemies():
		if _in_shape(shape, enemy.global_position, combat._hull(enemy), boxes):
			picks.append(enemy)
	var origin: Vector3 = shape["origin"]
	if shape["kind"] == "line":
		picks.sort_custom(func(a, b): return (a.global_position - origin).dot(shape["direction"]) < (b.global_position - origin).dot(shape["direction"]))
	else:
		picks.sort_custom(func(a, b): return a.global_position.distance_squared_to(origin) < b.global_position.distance_squared_to(origin))
	return picks


# Each closed cell's box, for skipping the cells a machine is nowhere near: a hit inside a
# cell or within hull of its faces is inside the box grown by hull. BOX_MARGIN covers the
# plane tolerance the containment test allows.
const BOX_MARGIN := 0.01


func _cell_boxes(shape: Dictionary) -> Array:
	var boxes: Array = []
	for cell in shape.get("cells", []):
		var box := AABB()
		var first := true
		for face in cell["faces"]:
			for v: Vector3 in face:
				box = AABB(v, Vector3.ZERO) if first else box.expand(v)
				first = false
		boxes.append(box.grow(BOX_MARGIN))
	return boxes


func _in_shape(shape: Dictionary, point: Vector3, hull: float, boxes: Array = []) -> bool:
	var to: Vector3 = point - (shape["origin"] as Vector3)
	if not shape.get("hull_forgiveness", true):
		hull = 0.0
	if shape.get("strict_angle", false):
		var up: Vector3 = shape["up"]
		var planar := to - up * to.dot(up)
		if planar.length() > float(shape["inner"]) and planar.normalized().dot(shape["direction"]) < cos(float(shape["half_angle"])):
			return false
	if shape["kind"] == "line":
		var dir: Vector3 = shape["direction"]
		var along := to.dot(dir)
		var side := (to - dir * along).length()
		if shape.has("cover") and (point - (shape["cover"][0] as Vector3)).dot(shape["cover"][1]) < -0.0001:
			return false
		return along >= -hull and along - hull <= (shape["endpoint"] as Vector3).distance_to(shape["origin"]) and side - hull <= float(shape["width"]) * 0.5
	for c in (shape["cells"] as Array).size():
		var cell: Dictionary = shape["cells"][c]
		if not boxes.is_empty() and not (boxes[c] as AABB).grow(hull).has_point(point):
			continue
		if _cell_intersects(cell, point, 0.0):
			return true
		if hull <= 0.0 or not _cell_intersects(cell, point, hull):
			continue
		var parts: Array = [cell]
		for shadow in shape.get("shadows", []):
			var contact: Dictionary = shadow.back()
			if (point - (contact["at"] as Vector3)).dot(contact["normal"]) >= -0.0001:
				continue
			var exposed: Array = []
			for part in parts:
				exposed.append_array(_subtract_shadow(part, shadow, true))
			parts = exposed
			if parts.is_empty():
				break
		if parts.any(func(part): return _cell_intersects(part, point, hull)):
			return true
	return false


func _cell_intersects(cell: Dictionary, point: Vector3, hull: float) -> bool:
	if (cell["faces"] as Array).is_empty():
		return false
	var inside := true
	for plane in cell["planes"]:
		if (point - (plane["at"] as Vector3)).dot(plane["normal"]) > 0.0001:
			if plane.get("solid", false):
				return false
			inside = false
	if inside:
		return true
	for face in cell["faces"]:
		for i in range(1, face.size() - 1):
			if point.distance_squared_to(_closest_triangle(point, face[0], face[i], face[i + 1])) <= hull * hull:
				return true
	return false


static func _closest_triangle(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var ab := b - a
	var ac := c - a
	var ap := p - a
	var d1 := ab.dot(ap)
	var d2 := ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0:
		return a
	var bp := p - b
	var d3 := ab.dot(bp)
	var d4 := ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3:
		return b
	var vc := d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		return a + ab * d1 / (d1 - d3)
	var cp := p - c
	var d5 := ab.dot(cp)
	var d6 := ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6:
		return c
	var vb := d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		return a + ac * d2 / (d2 - d6)
	var va := d3 * d6 - d5 * d4
	if va <= 0.0 and d4 - d3 >= 0.0 and d5 - d6 >= 0.0:
		return b + (c - b) * (d4 - d3) / ((d4 - d3) + (d5 - d6))
	var denominator := va + vb + vc
	if absf(denominator) < 0.000001:
		return Geometry3D.get_closest_point_to_segment(p, a, b)
	return a + ab * vb / denominator + ac * vc / denominator


func _clip_faces(faces: Array, at: Vector3, normal: Vector3) -> Array:
	var clipped: Array = []
	var rim: Array = []
	for face in faces:
		var polygon: Array = []
		for i in face.size():
			var a: Vector3 = face[i]
			var b: Vector3 = face[(i + 1) % face.size()]
			var da := (a - at).dot(normal)
			var db := (b - at).dot(normal)
			# Use the same coplanar classification for keeping vertices and crossing edges.
			da = 0.0 if absf(da) <= 0.0001 else da
			db = 0.0 if absf(db) <= 0.0001 else db
			if da <= 0.0:
				polygon.append(a)
			if (da <= 0.0) != (db <= 0.0):
				var cross := a.lerp(b, da / (da - db))
				polygon.append(cross)
				if not rim.any(func(v): return v.is_equal_approx(cross)):
					rim.append(cross)
		var boundary: Array = []
		for vertex in polygon:
			if boundary.is_empty() or not (boundary.back() as Vector3).is_equal_approx(vertex):
				boundary.append(vertex)
		if boundary.size() > 1 and (boundary[0] as Vector3).is_equal_approx(boundary.back()):
			boundary.pop_back()
		if boundary.size() >= 3:
			clipped.append(boundary)
	if rim.size() >= 3:
		var centre := Vector3.ZERO
		for v in rim:
			centre += v
		centre /= rim.size()
		var u: Vector3 = (rim[0] - centre).normalized()
		var v := normal.cross(u)
		rim.sort_custom(func(a, b): return atan2((a - centre).dot(v), (a - centre).dot(u)) < atan2((b - centre).dot(v), (b - centre).dot(u)))
		clipped.append(rim)
	return clipped


func _commit_cell(polygon: Array, up: Vector3, half_height: float) -> Dictionary:
	var top: Array = polygon.map(func(v): return v + up * half_height)
	var bottom: Array = polygon.map(func(v): return v - up * half_height)
	var centre := Vector3.ZERO
	for v in polygon:
		centre += v
	centre /= polygon.size()
	var faces: Array = [top, bottom]
	for i in polygon.size():
		var j: int = (i + 1) % polygon.size()
		faces.append([top[i], top[j], bottom[j], bottom[i]])
	var planes: Array = []
	for face in faces:
		var normal: Vector3 = ((face[1] as Vector3) - face[0]).cross((face[2] as Vector3) - face[0]).normalized()
		if normal.dot(centre - (face[0] as Vector3)) > 0.0:
			normal = -normal
		planes.append({"at": face[0], "normal": normal, "terrain": false})
	return _pack_cell(faces, planes)


func _pack_cell(faces: Array, planes: Array) -> Dictionary:
	var unique := {}
	for face in faces:
		for vertex in face:
			unique[vertex] = true
	var vertices: Array = unique.keys()
	var bounds := AABB()
	if not vertices.is_empty():
		bounds = AABB(vertices[0], Vector3.ZERO)
		for vertex in vertices:
			bounds = bounds.expand(vertex)
	return {"faces": faces, "planes": planes, "vertices": vertices, "bounds": bounds}


func _bounds_distance(bounds: AABB, plane: Dictionary) -> Vector2:
	var normal: Vector3 = plane["normal"]
	var centre: float = (bounds.get_center() - plane["at"]).dot(normal)
	var extent := bounds.size * 0.5
	var radius := absf(normal.x) * extent.x + absf(normal.y) * extent.y + absf(normal.z) * extent.z
	return Vector2(centre - radius, centre + radius)


# The cell's nearest and farthest signed distance from the plane: its box's when that settles
# which side it is on, else its vertices'. Negating the normal negates and swaps both exactly.
func _extent(cell: Dictionary, plane: Dictionary) -> Vector2:
	var interval := _bounds_distance(cell["bounds"], plane)
	if interval.x >= -0.0001 or interval.y <= 0.0001:
		return interval
	var low := INF
	var high := -INF
	for vertex in cell["vertices"]:
		var distance: float = (vertex - plane["at"]).dot(plane["normal"])
		low = minf(low, distance)
		high = maxf(high, distance)
	return Vector2(low, high)


func _clip_cell(cell: Dictionary, plane: Dictionary) -> Dictionary:
	var interval := _extent(cell, plane)
	var low := interval.x
	var high := interval.y
	# A coplanar remnant has no volume and must not become a hull-forgiveness face.
	if low >= -0.0001:
		return _pack_cell([], [])
	if high <= 0.0001:
		if plane.get("solid", false):
			var constrained := cell.duplicate()
			constrained["planes"] = cell["planes"] + [plane]
			return constrained
		return cell
	return _pack_cell(_clip_faces(cell["faces"], plane["at"], plane["normal"]), cell["planes"] + [plane])


# Subtract a convex shadow, retaining disjoint convex parts outside its half-spaces.
func _subtract_shadow(cell: Dictionary, shadow: Array, hull_boundary := false) -> Array:
	# Drawn volume stops at terrain first. Hull forgiveness also needs the silhouette caps.
	var planes: Array = shadow if hull_boundary else [shadow.back()] + shadow.slice(0, shadow.size() - 1)
	for plane in planes:
		if (not hull_boundary or not plane.get("solid", false)) and (_bounds_distance(cell["bounds"], plane).x >= -0.0001 or _all_outside(cell["vertices"], plane)):
			return [cell]
	var lit: Array = []
	var remaining := cell
	for index in planes.size():
		var plane: Dictionary = planes[index]
		var solid: bool = hull_boundary and bool(plane.get("solid", false))
		# Wholly inside a plane leaves nothing outside it and the rest unchanged; wholly outside
		# empties the rest. Both are what the two clips below would return.
		if not solid:
			var side := _extent(remaining, plane)
			if side.x >= -0.0001 and not hull_boundary:
				return [cell]
			if side.x < -0.0001 and side.y <= 0.0001:
				continue
		var outside := _clip_cell(remaining, {"at": plane["at"], "normal": -plane["normal"], "terrain": true, "solid": solid})
		if not (outside["faces"] as Array).is_empty():
			lit.append(outside)
		if not hull_boundary and _rest_inside(remaining, plane, planes.slice(index + 1)):
			return lit
		remaining = _clip_cell(remaining, {"at": plane["at"], "normal": plane["normal"], "terrain": true, "solid": solid})
		if (remaining["faces"] as Array).is_empty():
			if not hull_boundary:
				return [cell]
			break
	return lit


func _all_outside(vertices: Array, plane: Dictionary) -> bool:
	var at: Vector3 = plane["at"]
	var normal: Vector3 = plane["normal"]
	for v: Vector3 in vertices:
		if (v - at).dot(normal) < -0.0001:
			return false
	return true


# True when the part of cell inside plane would pass every later plane wholly inside it, so the
# loop above would only skip them and return lit: then that part, which nothing keeps, is not
# clipped (a level Breach's floor cut, the stand's whole carve, took two clips a part). The part's
# corners are at most the cell's corners inside plane and its edges' crossings, made as _clip_faces
# makes them; each later plane must hold them all, and a corner REST_DEPTH inside plane and inside
# that plane by the tolerance stays in the part, so the part cannot read as wholly outside it.
const REST_DEPTH := 0.05


func _rest_inside(cell: Dictionary, plane: Dictionary, later: Array) -> bool:
	var at: Vector3 = plane["at"]
	var normal: Vector3 = plane["normal"]
	var corners: Array = []
	var deep: Array = []
	for face in cell["faces"]:
		var count: int = face.size()
		for i in count:
			var a: Vector3 = face[i]
			var b: Vector3 = face[(i + 1) % count]
			var da := (a - at).dot(normal)
			var db := (b - at).dot(normal)
			da = 0.0 if absf(da) <= 0.0001 else da
			db = 0.0 if absf(db) <= 0.0001 else db
			if da <= 0.0:
				corners.append(a)
				if da < -REST_DEPTH:
					deep.append(a)
			if (da <= 0.0) != (db <= 0.0):
				corners.append(a.lerp(b, da / (da - db)))
	if deep.is_empty():
		return false
	for next: Dictionary in later:
		var next_at: Vector3 = next["at"]
		var next_normal: Vector3 = next["normal"]
		for v: Vector3 in corners:
			if (v - next_at).dot(next_normal) > 0.0001:
				return false
		var held := false
		for v: Vector3 in deep:
			if (v - next_at).dot(next_normal) < -0.0001:
				held = true
				break
		if not held:
			return false
	return true


func _face_shadow(origin: Vector3, face: Array) -> Array:
	var centre := Vector3.ZERO
	for v in face:
		centre += v
	centre /= face.size()
	var normal: Vector3 = ((face[1] as Vector3) - face[0]).cross((face[2] as Vector3) - face[0]).normalized()
	var facing := normal.dot(origin - (face[0] as Vector3))
	if absf(facing) <= 0.0001:
		return []
	if facing < 0.0:
		normal = -normal
	var contact := {"at": face[0], "normal": normal, "terrain": true, "solid": true}
	var planes: Array = []
	for i in face.size():
		normal = ((face[i] as Vector3) - origin).cross((face[(i + 1) % face.size()] as Vector3) - origin).normalized()
		if normal.dot(centre - origin) > 0.0:
			normal = -normal
		planes.append({"at": origin, "normal": normal, "terrain": true})
	# Partition the silhouette first; its contact plane cannot restrict exposed hulls outside it.
	planes.append(contact)
	return planes


# The park's convex wedge colliders carry points, rather than triangle faces. Parks place the
# same few wedges hundreds of times, and the face search is quartic in the points (about 100 ms a
# wedge), so the faces are kept by point list for the life of the process. Readers map them
# into world space and never write them. A wedge not kept yet is searched on the terrain
# worker (_terrain_entry), never on the main thread: the warm-up meeting a stage's new wedges
# held one physics tick for 400 to 900 ms on the 4080 (board #934, 13 Nov 2026).
static var _convex_cache := {}
static var _convex_lock := Mutex.new()
# One lock per point list being searched, so a warm-up that meets 200 placements of a new wedge
# searches it once: the other workers wait on that search and read the kept faces.
static var _convex_searching := {}
# Searches run, and those run on the main thread, for the hitch guard's counts.
static var convex_searches := 0
static var convex_searches_on_main := 0


static func _convex_faces(points: PackedVector3Array) -> Array:
	_convex_lock.lock()
	var faces = _convex_cache.get(points)
	var key_lock: Mutex = null
	if faces == null:
		key_lock = _convex_searching.get(points)
		if key_lock == null:
			key_lock = Mutex.new()
			_convex_searching[points] = key_lock
	_convex_lock.unlock()
	if faces != null:
		return faces
	key_lock.lock()
	_convex_lock.lock()
	faces = _convex_cache.get(points)
	_convex_lock.unlock()
	if faces == null:
		faces = _convex_faces_uncached(points)
		_convex_lock.lock()
		_convex_cache[points] = faces
		convex_searches += 1
		if OS.get_thread_caller_id() == OS.get_main_thread_id():
			convex_searches_on_main += 1
		_convex_searching.erase(points)
		_convex_lock.unlock()
	key_lock.unlock()
	return faces


static func _convex_kept(points: PackedVector3Array) -> bool:
	_convex_lock.lock()
	var kept := _convex_cache.has(points)
	_convex_lock.unlock()
	return kept


static func _convex_faces_uncached(points: PackedVector3Array) -> Array:
	var faces: Array = []
	var normals: Array = []
	var offsets: Array = []
	for a in points.size():
		for b in range(a + 1, points.size()):
			for c in range(b + 1, points.size()):
				var normal := (points[b] - points[a]).cross(points[c] - points[a]).normalized()
				if normal.length_squared() < 0.001:
					continue
				var low := INF
				var high := -INF
				for v in points:
					var distance := normal.dot(v - points[a])
					low = minf(low, distance)
					high = maxf(high, distance)
				if low < -0.0001 and high > 0.0001:
					continue
				if high > 0.0001:
					normal = -normal
				var offset := normal.dot(points[a])
				var duplicate := false
				for i in normals.size():
					if normal.is_equal_approx(normals[i]) and absf(offset - float(offsets[i])) < 0.0001:
						duplicate = true
				if duplicate:
					continue
				normals.append(normal)
				offsets.append(offset)
				var u := (points[b] - points[a]).normalized()
				var v := normal.cross(u)
				var projected := PackedVector2Array()
				for point in points:
					if absf(normal.dot(point) - offset) < 0.0001:
						projected.append(Vector2(u.dot(point - points[a]), v.dot(point - points[a])))
				var boundary := Geometry2D.convex_hull(projected)
				var face: Array = []
				for i in boundary.size() - 1:
					face.append(points[a] + u * boundary[i].x + v * boundary[i].y)
				faces.append(face)
	return faces


func _collider_faces(shape: Shape3D) -> Array:
	if shape is ConvexPolygonShape3D:
		return _convex_faces(shape.points)
	var triangles := PackedVector3Array()
	if shape is BoxShape3D:
		var mesh := BoxMesh.new()
		mesh.size = shape.size
		triangles = mesh.get_faces()
	elif shape is CylinderShape3D:
		var mesh := CylinderMesh.new()
		mesh.top_radius = shape.radius
		mesh.bottom_radius = shape.radius
		mesh.height = shape.height
		mesh.radial_segments = Indicator.SEGMENTS
		triangles = mesh.get_faces()
	elif shape is ConcavePolygonShape3D:
		triangles = shape.get_faces()
	else:
		push_error("Rivet terrain commitment requires faces for %s" % shape.get_class())
	var faces: Array = []
	for i in range(0, triangles.size(), 3):
		faces.append([triangles[i], triangles[i + 1], triangles[i + 2]])
	return faces


# Discover actual terrain faces across the whole volume, not sparse rays in each cell.
# Include the hull margin in the query so forgiveness cannot reach uncommitted cover.
func _commit_terrain(origin: Vector3, cells: Array, shadows: Array, hull: Array = []) -> Array:
	return _carve(origin, cells, shadows, hull, _terrain_near(origin, cells))


# Carves the cells by found, _terrain_near's faces for them.
func _carve(origin: Vector3, cells: Array, shadows: Array, hull: Array, found: Dictionary) -> Array:
	if found.has("unreadable"):
		# Still record the shadows of the faces found so far.
		_shade(origin, TerrainFaces.merge(found["faces"]), cells, shadows, hull)
		return []
	return _shade(origin, TerrainFaces.merge(found["faces"]), cells, shadows, hull)


# The terrain faces near the cells, with "unreadable" set when a shape there has none the carve
# can read.
func _terrain_near(origin: Vector3, cells: Array) -> Dictionary:
	var bounds := AABB(origin, Vector3.ZERO)
	for cell in cells:
		for face in cell["faces"]:
			for vertex in face:
				bounds = bounds.expand(vertex)
	var margin := 0.0
	for enemy in _enemies():
		margin = maxf(margin, combat._hull(enemy))
	bounds = bounds.grow(margin)
	var box := BoxShape3D.new()
	box.size = bounds.size
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform = Transform3D(Basis.IDENTITY, bounds.get_center())
	query.collision_mask = Hitscan.WORLD
	var space: PhysicsDirectSpaceState3D = ctx.root.get_world_3d().direct_space_state
	var excluded: Array[RID] = []
	var faces: Array = []
	while true:
		query.exclude = excluded
		var hits := space.intersect_shape(query)
		if hits.is_empty():
			break
		for hit in hits:
			var collider: CollisionObject3D = hit["collider"]
			if excluded.has(collider.get_rid()):
				continue
			excluded.append(collider.get_rid())
			for owner in collider.get_shape_owners():
				if collider.is_shape_owner_disabled(owner):
					continue
				var transform := collider.global_transform * collider.shape_owner_get_transform(owner)
				for i in collider.shape_owner_get_shape_count(owner):
					# The face boxes decide what is near; a debug mesh's box costs a park tile
					# 120 ms the first time.
					var entry := _terrain_entry(collider.shape_owner_get_shape(owner, i), transform)
					if entry.is_empty() or not terrain.readable(entry):
						return {"faces": faces, "unreadable": true}
					faces.append_array(terrain.faces_near(entry, bounds.grow(0.0001)))
	return {"faces": faces}


# The shape's cached world faces (TerrainFaces), or {} for a shape the carve cannot read.
func _terrain_entry(shape: Shape3D, transform: Transform3D) -> Dictionary:
	var entry := terrain.cached(shape, transform)
	if not entry.is_empty():
		return entry
	if shape is ConvexPolygonShape3D and not _convex_kept(shape.points):
		return terrain.request(shape, transform, _convex_faces.bind(shape.points))
	var local_faces = (shape as ConcavePolygonShape3D).get_faces() if shape is ConcavePolygonShape3D else _collider_faces(shape)
	if local_faces.is_empty():
		return {}
	return terrain.request(shape, transform, local_faces)


# Subtracts each face's shadow in face order, exactly as one _subtract_shadow pass per face
# would; a cell's parts depend on that cell alone, so each cell takes every face in turn. A
# shadow that a plane of a part, its box or the hull clears by a margin would leave that part
# unchanged, so it skips the clip. Every part lies inside the cells' first box, and the
# caller's hull planes are planes every cell lies behind. Shadows too thin for a margin skip by
# their reach instead (FRUSTUM_MARGIN).
func _shade(origin: Vector3, faces: Array, cells: Array, shadows: Array, hull: Array) -> Array:
	var cuts := _cuts(origin, faces, cells, shadows, hull)
	if cuts.is_empty():
		return cells
	var lit: Array = []
	for cell in cells:
		lit.append_array(_shade_cell(origin, _cell_cuts(cuts, cell), [cell]))
	return lit


# The faces' shadows that can change a cell, as [face, shadow, clearance, extent, frustum, span];
# every shadow is recorded in shadows.
func _cuts(origin: Vector3, faces: Array, cells: Array, shadows: Array, hull: Array) -> Array:
	var reach := AABB()
	for i in cells.size():
		reach = cells[i]["bounds"] if i == 0 else reach.merge(cells[i]["bounds"])
	var far := 0.0
	for k in 8:
		far = maxf(far, reach.get_endpoint(k).distance_to(origin))
	var cuts: Array = []
	for face in faces:
		var shadow := _face_shadow(origin, face)
		if shadow.is_empty():
			continue
		shadows.append(shadow)
		var clearance := _clearance(face, shadow)
		var extent := AABB(face[0], Vector3.ZERO)
		for v in face:
			extent = extent.expand(v)
		if clearance < INF and (_box_clears(reach, extent, origin, clearance) or _planes_clear(hull, origin, face, clearance)):
			continue
		var frustum := _frustum(origin, face, far)
		var span := AABB(frustum[0], Vector3.ZERO)
		for point in frustum:
			span = span.expand(point)
		span = span.grow(FRUSTUM_MARGIN)
		if not span.intersects(reach):
			continue
		cuts.append([face, shadow, clearance, extent, frustum, span])
	return cuts


func _cell_cuts(cuts: Array, cell: Dictionary) -> Array:
	var bounds: AABB = cell["bounds"]
	return cuts.filter(func(cut): return (cut[5] as AABB).intersects(bounds))


# Parts tested against a shadow so far: the late carve's measure of work done (LATE_WORK).
var _shade_work := 0


func _shade_cell(origin: Vector3, cuts: Array, parts: Array) -> Array:
	for cut in cuts:
		_shade_work += parts.size()
		var face: Array = cut[0]
		var clearance: float = cut[2]
		var lit: Array = []
		for part in parts:
			if clearance < INF and (_box_clears(part["bounds"], cut[3], origin, clearance) or _planes_clear(part["planes"], origin, face, clearance)):
				lit.append(part)
			elif not (cut[5] as AABB).intersects(part["bounds"]) or _frustum_outside(part["planes"], cut[4]):
				lit.append(part)
			else:
				lit.append_array(_subtract_shadow(part, cut[1]))
		parts = lit
	return parts


# Grazing terrain (a bumpy floor seen from just above it) gives shadows whose corners are too
# ill-conditioned for a clearance (MIN_DET), so those skip on reach instead. Every part lies
# within far of the origin, so the shadow that can meet it is the frustum between the face and
# the face pushed out along the origin's rays past far (scaled from its nearest point). A part
# whose box misses the frustum's box, or that has a plane with the whole frustum FRUSTUM_MARGIN
# outside it, keeps its volume, give or take the clip tolerance's sliver.
const FRUSTUM_MARGIN := 0.001


func _frustum(origin: Vector3, face: Array, far: float) -> Array:
	var near := INF
	for i in range(1, face.size() - 1):
		near = minf(near, origin.distance_to(_closest_triangle(origin, face[0], face[i], face[i + 1])))
	# 5% over, for float32 error in near when a face's plane passes close to the origin.
	var push := far / maxf(near, 0.000001) * 1.05 + 1.0
	var points: Array = []
	for v in face:
		points.append(v)
		points.append(origin + ((v as Vector3) - origin) * push)
	return points


func _frustum_outside(planes: Array, frustum: Array) -> bool:
	for plane in planes:
		var at: Vector3 = plane["at"]
		var normal: Vector3 = plane["normal"]
		var outside := true
		for point: Vector3 in frustum:
			if (point - at).dot(normal) < FRUSTUM_MARGIN:
				outside = false
				break
		if outside:
			return true
	return false


# Clipping keeps points up to SLACK past each plane (0.0001 tolerance plus float32 error), which
# loosens the shadow; a corner on three unit planes moves at most 3 * SLACK / |det| (Cramer's rule).
# A plane clears the shadow when every corner is that far, plus CLEAR_MARGIN, past it.
const SLACK := 0.0002
const CLEAR_MARGIN := 0.01
const MIN_DET := 0.001


func _clearance(face: Array, shadow: Array) -> float:
	var contact: Vector3 = shadow.back()["normal"]
	var count := face.size()
	var det := INF
	for i in count:
		var before: Vector3 = shadow[(i + count - 1) % count]["normal"]
		var after: Vector3 = shadow[i]["normal"]
		det = minf(det, absf(contact.dot(before.cross(after))))
	return CLEAR_MARGIN + 3.0 * SLACK / det if det >= MIN_DET else INF


# The shadow is every point origin + s * (v - origin) for v on the face and s >= 1. It lies past
# a plane when each face corner is the clearance past it and no corner's ray turns back toward it.
func _plane_clears(at: Vector3, normal: Vector3, origin: Vector3, face: Array, clearance: float) -> bool:
	for v in face:
		if (v - at).dot(normal) < clearance or (v - origin).dot(normal) < 0.0:
			return false
	return true


func _planes_clear(planes: Array, origin: Vector3, face: Array, clearance: float) -> bool:
	for plane in planes:
		if _plane_clears(plane["at"], plane["normal"], origin, face, clearance):
			return true
	return false


# The box's six planes, read from the face's own box (extent).
func _box_clears(box: AABB, extent: AABB, origin: Vector3, clearance: float) -> bool:
	var low := box.position
	var high := box.end
	var near := extent.position
	var far := extent.end
	return near.x >= maxf(high.x + clearance, origin.x) or far.x <= minf(low.x - clearance, origin.x) \
		or near.y >= maxf(high.y + clearance, origin.y) or far.y <= minf(low.y - clearance, origin.y) \
		or near.z >= maxf(high.z + clearance, origin.z) or far.z <= minf(low.z - clearance, origin.z)


func _commit_sector(origin: Vector3, dir: Vector3, reach: float, half: float, width: float, inner := 0.0) -> Dictionary:
	var sector := _sector_cells(origin, dir, reach, half, width, inner)
	var shadows: Array = []
	var cells := _commit_terrain(origin, sector["cells"], shadows, sector["hull"])
	return _sector_shape(sector, cells, shadows)


func _sector_cells(origin: Vector3, dir: Vector3, reach: float, half: float, width: float, inner := 0.0) -> Dictionary:
	var side := dir.cross(Vector3.UP).normalized()
	if side.length_squared() < 0.001:
		side = Vector3.RIGHT
	var up := side.cross(dir).normalized()
	var cells: Array = []
	var segments: int = ctx.player.indicator.SEGMENTS
	for i in segments:
		var a := dir.rotated(up, lerpf(-half, half, float(i) / segments))
		var b := dir.rotated(up, lerpf(-half, half, float(i + 1) / segments))
		var sa := a.cross(up) * width * 0.5
		var sb := b.cross(up) * width * 0.5
		var polygon: Array = [origin + sa, origin + a * reach + sa, origin + b * reach - sb, origin - sb] if width > 0.0 else [origin, origin + a * reach, origin + b * reach]
		cells.append(_commit_cell(polygon, up, maxf(width * 0.5, inner)))
	if inner > 0.0:
		for i in segments:
			var a := dir.rotated(up, TAU * float(i) / segments)
			var b := dir.rotated(up, TAU * float(i + 1) / segments)
			cells.append(_commit_cell([origin, origin + a * inner, origin + b * inner], up, inner))
	var slab := maxf(width * 0.5, inner)
	return {"origin": origin, "direction": dir, "length": reach, "half_angle": half, "width": width, "inner": inner, "up": up, "cells": cells,
		"hull": [{"at": origin + up * slab, "normal": up}, {"at": origin - up * slab, "normal": -up}]}


# The sector's committed record once its cells are carved.
func _sector_shape(sector: Dictionary, cells: Array, shadows: Array, centre := {}) -> Dictionary:
	if centre.is_empty():
		centre = _commit_beam(sector["origin"], sector["direction"], sector["length"], sector["width"])
	return ctx.player.yours({"kind": "rivet_volume", "rivet_shape": true, "origin": sector["origin"], "direction": sector["direction"],
		"length": sector["length"], "half_angle": sector["half_angle"], "width": sector["width"], "inner": sector["inner"], "up": sector["up"],
		"cells": cells, "shadows": shadows, "centre_endpoint": centre["endpoint"]})


func _draw_shape(layer: String, shape: Dictionary) -> void:
	volume_indicator.set_shape(layer, shape)


func _draw_beam(index: int, beam: Dictionary) -> void:
	beam_shapes.append(beam)
	ctx.player.indicator.set_shape("rivet_beam_%d" % index, beam)
	combat.effects.arc(beam["origin"], beam["endpoint"], ctx.player.class_color())


func _clear_beams() -> void:
	for i in Weapons.PRISM_BEAMS:
		ctx.player.indicator.clear("rivet_beam_%d" % i)
	beam_shapes = []


# One beam or wave hit. A Warden fills posture as gun bolts do, at half, under the set piece's
# cap; a boss takes half; a machine is cut with no knock.
func _beam_hit(enemy: Node3D, damage: float, from: Vector3) -> void:
	_cut[enemy.get_instance_id()] = true
	if _warden(enemy):
		combat._ult_hit(enemy, "runner", damage, from, false)
	elif _boss(enemy):
		combat.strike(enemy, "runner", damage * Ultimate.BOSS_MULT, "", "special")
	else:
		combat._hit(enemy, "runner", damage, enemy.global_position - from, 0.0, "", "special")


func _peak_beat(beat: int) -> bool:
	var ult = combat.ultimate
	return not ult._peaked and beat >= ceili(ult._beats / 2.0)


func tech(id: String, beat: int, ball: Vector3, aim: Vector3, heft: float) -> int:
	selected_shapes.clear()
	_clear_beams()
	_last_aim = aim
	if id == "juggernaut_drive":
		return _bow_wave(ball)
	# The middle beat is the peak's alone: it cuts there, once.
	if _peak_beat(beat):
		return 0
	var extra := int(_knob("ult_volley", 0))
	var hits := 0
	if id == "prism_cutter":
		var centre := _beam_aim(ball, aim, Weapons.PRISM_LENGTH)
		for i in Weapons.PRISM_BEAMS:
			var dir := centre.rotated(Vector3.UP, deg_to_rad(Weapons.PRISM_SPREAD_DEG * float(i - 1)))
			var beam := _commit_beam(ball, dir, Weapons.PRISM_LENGTH, beam_width(id))
			_draw_beam(i, beam)
			for enemy in select(beam).slice(0, Weapons.PRISM_PIERCE + extra):
				_beam_hit(enemy, Weapons.PRISM_DAMAGE * heft, ball)
				hits += 1
		return hits
	var d := _beam_aim(ball, aim, Weapons.CUTTER_LENGTH)
	var beam := _commit_beam(ball, d, Weapons.CUTTER_LENGTH, beam_width(id))
	_draw_beam(0, beam)
	for enemy in select(beam).slice(0, Weapons.CUTTER_PIERCE + extra):
		_beam_hit(enemy, Weapons.CUTTER_DAMAGE * heft, ball)
		hits += 1
	return hits


# Juggernaut Drive's beat: a chevron bow wave throws machines beside the path ahead outward.
func _bow_wave(ball: Vector3) -> int:
	var heading := _flat(_heading()).normalized()
	var side := Vector3(-heading.z, 0.0, heading.x)
	var cells: Array = []
	var shadows: Array = []
	for sign in [-1.0, 1.0]:
		var near: Vector3 = side * Weapons.DRIVE_WAVE_NEAR * sign
		var far: Vector3 = side * Weapons.DRIVE_WAVE_FAR * sign
		cells.append(_commit_cell([ball + near, ball + far, ball + far + heading * Weapons.DRIVE_WAVE_AHEAD, ball + near + heading * Weapons.DRIVE_WAVE_AHEAD], Vector3.UP, ctx.player.tuning.RADIUS))
	cells = _commit_terrain(ball, cells, shadows)
	var shape: Dictionary = ctx.player.yours({"kind": "rivet_volume", "rivet_shape": true, "origin": ball, "cells": cells, "shadows": shadows, "hull_forgiveness": false})
	_draw_shape("rivet_wave", shape)
	var thrown := 0
	for enemy in select(shape):
		if _warden(enemy) or _boss(enemy):
			continue
		var lateral: float = (enemy.global_position - ball).dot(side)
		var falloff := 1.0 - (absf(lateral) - Weapons.DRIVE_WAVE_NEAR) / (Weapons.DRIVE_WAVE_FAR - Weapons.DRIVE_WAVE_NEAR)
		enemy.knock(side * signf(lateral) + Vector3.UP * 0.3, Weapons.DRIVE_WAVE_KNOCK * falloff)
		enemy.flash()
		thrown += 1
	return thrown


func peak(id: String, at: Vector3) -> void:
	selected_shapes.clear()
	var heft: float = Ultimate.HEFT_MULT[_class() - 1]
	var hits := 0
	if id == "juggernaut_drive":
		var ult = combat.ultimate
		_shoulder = ult._beat_len if ult._beat_len > 0.0 else 0.35
		return
	if id == "prism_cutter":
		var d := _beam_aim(at, _peak_aim(), Weapons.CUTTER_LENGTH)
		var beam := _commit_beam(at, d, Weapons.CUTTER_LENGTH, Weapons.PRISM_FOCUS_WIDTH)
		_draw_beam(0, beam)
		for enemy in select(beam).slice(0, Weapons.PRISM_FOCUS_PIERCE):
			_beam_hit(enemy, Weapons.PRISM_FOCUS_DAMAGE * heft, at)
			hits += 1
	else:
		hits = full_cut(at, _beam_aim(at, _peak_aim(), Weapons.FULL_CUT_REACH), heft)
	if combat.ultimate != null and not combat.ultimate._record.is_empty():
		combat.ultimate._record["volley_hits"] = int(combat.ultimate._record.get("volley_hits", 0)) + hits


func _peak_aim() -> Vector3:
	return _last_aim if _last_aim != Vector3.ZERO else ctx.aim_forward()


# Full Cut: the beam widens and sweeps FULL_CUT_DEG, half to each side of the aim, out to
# FULL_CUT_REACH; every machine it crosses takes FULL_CUT_DAMAGE x heft once, no pierce cap.
# The carve tests up to about 19,000 parts against terrain shadows (133 ms in the cloud, a tick
# of 100 to 450 ms in a park), so it runs on a worker and the cut lands CUT_TICKS later (55 ms,
# the Breach's "Beat later"), on the same tick every time so a seed replays. The terrain is
# gathered here, on the peak tick, so the cut is the ground as it stood then. cut_ticks 0 carves
# and lands on the peak tick, as before (a test's switch).
const CUT_TICKS := LATE_TICKS
var cut_ticks := CUT_TICKS
# Cuts carving, oldest first: {task, due, sector, at, heft, record, out: {cells, shadows}}.
var _cuts_due: Array = []
# The worker's own kit, so its carve counts work apart from the main thread's Breach (_shade_work).
var _carver = null


func full_cut(at: Vector3, dir: Vector3, heft: float) -> int:
	carve_stats["full_cut"] += 1
	var sector := _sector_cells(at, dir, Weapons.FULL_CUT_REACH, deg_to_rad(Weapons.FULL_CUT_DEG * 0.5), Weapons.FULL_CUT_WIDTH)
	if cut_ticks <= 0:
		var shadows: Array = []
		var cells := _commit_terrain(at, sector["cells"], shadows, sector["hull"])
		return _land_cut(_sector_shape(sector, cells, shadows), at, heft)
	var found := _terrain_near(at, sector["cells"])
	if _carver == null:
		_carver = get_script().new()
	var out := {}
	var job := {"due": Engine.get_physics_frames() + cut_ticks, "sector": sector, "at": at, "heft": heft, "out": out,
		"record": combat.ultimate._record if combat.ultimate != null else {}}
	job["task"] = WorkerThreadPool.add_task(_carve_off.bind(_carver, at, sector["cells"], sector["hull"], found, out), true, "rivet full cut")
	_cuts_due.append(job)
	return 0


static func _carve_off(carver, origin: Vector3, cells: Array, hull: Array, found: Dictionary, out: Dictionary) -> void:
	var shadows: Array = []
	out["cells"] = carver._carve(origin, cells, shadows, hull, found)
	out["shadows"] = shadows


func _land_cut(shape: Dictionary, at: Vector3, heft: float) -> int:
	var hits := 0
	for enemy in select(shape):
		_beam_hit(enemy, Weapons.FULL_CUT_DAMAGE * heft, at)
		hits += 1
	_draw_shape("rivet_scar", shape)
	_scar_left = Weapons.FULL_CUT_SCAR
	return hits


# Lands each cut on its due tick, waiting for its carve when the worker is still on it.
func _step_cuts(now := Engine.get_physics_frames()) -> void:
	while not _cuts_due.is_empty() and now >= int(_cuts_due[0]["due"]):
		var job: Dictionary = _cuts_due.pop_front()
		WorkerThreadPool.wait_for_task_completion(job["task"])
		var out: Dictionary = job["out"]
		var hits := _land_cut(_sector_shape(job["sector"], out["cells"], out["shadows"]), job["at"], job["heft"])
		var record: Dictionary = job["record"]
		if not record.is_empty():
			record["volley_hits"] = int(record.get("volley_hits", 0)) + hits


# Drops every cut still carving, with its hits.
func _drop_cuts() -> void:
	for job in _cuts_due:
		WorkerThreadPool.wait_for_task_completion(job["task"])
	_cuts_due = []


# The Breach Skid reach: 1.5 x the class landing radius, plus ult_radius.
func breach_reach() -> float:
	return Weapons.BREACH_REACH_SCALE * float(Ultimate.LANDING_RADIUS[_class() - 1]) + float(_knob("ult_radius", 0.0))


# The Breach Skid: no plant. A forward cone along the path's heading hits for 60 x heft x chain,
# throws machines forward (x ult_pins) so they pin, exits flat at the banked speed and hands back
# a sprint charge. It counts as a slam for a burrower's marker and a drill crew's rig.
func landing(id: String, at: Vector3, heft: float, chain: float) -> Array:
	selected_shapes.clear()
	var heading := _flat(_heading()).normalized()
	var reach := breach_reach()
	var pins: float = float(_knob("ult_pins", 1.0))
	var damage: float = Ultimate.LANDING_DAMAGE * heft * chain
	ctx.break_props(at, combat.ultimate.landing_radius(), "ultimate")
	var late := _carve_late(id, at, heading, reach, pins, damage)
	last_landing = late
	var result: Array = [0, 0.0, "late"]
	if _shade_late(late, landing_work(bool(late["level"]))):
		result = _breach(_late_shape(late), at, heading, reach, pins, damage)
	else:
		_late.append(late)
	# Exit flat along the heading at the banked speed: the ride's release keeps its speed and
	# loses the fall (A2-CRITIC: no floor; the speed gift is Sable's alone).
	var ride = combat.ultimate._ride if combat.ultimate != null else null
	if ride != null:
		ride.mode = RideRail.LINE
		ride.velocity = ride.heading * ride.release_speed
	ctx.player.abilities.grant(AbilityState.MOVEMENT, Weapons.BREACH_SPRINT)
	if id == "juggernaut_drive":
		ctx.player.grant_immunity(Ultimate.RECOVER_SECONDS + Weapons.DRIVE_IMMUNE)
	if id in BEAM_PIECES and _cut.size() >= CUTTER_CARD_CUTS:
		_discover("rivet_foundry_cutter", "set_piece", at)
	var more: bool = combat.ultimate != null and combat.ultimate._leg < (combat.ultimate._plan["legs"] as Array).size()
	if more:
		_rammed = {}
		_cut = {}
		_shoulder = 0.0
	else:
		_clear_piece()
	return result


# The Breach Skid's hits on its carved sector: [hits, damage dealt].
func _breach(shape: Dictionary, at: Vector3, heading: Vector3, reach: float, pins: float, damage: float) -> Array:
	carve_stats["breach_hits"] += 1
	var hits := 0
	var dealt := 0.0
	shape["strict_angle"] = true
	for enemy in select(shape):
		if _warden(enemy) or _boss(enemy):
			dealt += combat._ult_hit(enemy, "slam", damage, at, true)
		else:
			if enemy.has_method("_on_slammed"):
				enemy._on_slammed(at, 1.0, 1.0)
			var falloff := clampf(1.0 - _flat(enemy.global_position - at).length() / reach, 0.0, 1.0)
			combat._hit(enemy, "slam", slam_force(damage), heading, Ultimate.LANDING_KNOCK * falloff * pins, "", "special", "slam")
			dealt += damage
		hits += 1
	_draw_shape("rivet_breach", shape)
	_scar_left = maxf(_scar_left, Weapons.FULL_CUT_SCAR)
	return [hits, dealt]


# The Breach Skid's carve shades its cells in order until it has tested LATE_WORK parts against
# shadows in a tick (about 30 us of shading each, in the cloud and on Andrew's 4080 alike). A light carve
# finishes on the landing tick and hits there. A heavy one (bumpy or curved ground) carries on a
# tick at a time and hits once it is done, and never before LATE_TICKS (about 55 ms) after the
# landing (Andrew's "Beat later" and "Spread every Breach", 2026-10-18). Work is counted, never
# timed, so a replay is the same on any machine. The cells' parts join in cell order, as _shade
# joins them, so the shape is the same as a carve made at once. LATE_WORK is sized from the 4080's
# whole share tick: 1.5 shares a frame must stay under 16.7 ms, so a share at most 11.1 ms. Its worst
# share tick was 11.4 ms at 200 parts (rows 23 and 27) and 19.1 ms at 290; 11.4 ms over 200 parts,
# the tick's fixed cost included, is 0.057 ms a part, so 182 holds about 10.4 ms (a share can pass
# its budget by part of a cell, at 200 as here). The p3 slope (1247 parts, 21 degrees) then hits 7
# ticks (78 ms) after landing, as it did at 200, inside Andrew's "Smooth, 0.11 s" (2026-10-18); the
# heaviest slopes stay over it (scrapkeep#137, row 27).
const LATE_TICKS := 5
const LATE_WORK := 182
# The landing tick also gathers the faces and cuts, about as much again as a share, so its
# share is smaller; flat ground (one part a cell, 96 cells) and a shallow bowl (158) still carve
# and hit there. A
# later carve's hits (selection and drawing) take a tick of their own after its last share.
# Both keep a carve tick inside the frame's headroom on Andrew's 4080 (coordinator, 2026-10-18).
const LANDING_WORK := 160
# Level ground (Andrew's ruling, 18 Oct 2026, coordinator comment 6260010878 on #149, option B: "a
# Breach on level park ground hits on the landing tick"; a 2 to 4 ms frame bump is allowed). A Breach
# is on level ground when the face it lands on is within LEVEL_GROUND_DEG of straight up. The
# park's ground is 2 m cells, never one plane, so such a landing also flattens its near-level faces
# into larger polygons (TerrainFaces.merge_level: normals within LEVEL_TOLERANCE_DEG, every corner
# within LEVEL_DEVIATION m of the region's plane) and its landing share is LEVEL_LANDING_WORK
# parts (the coordinator's ruling 3, option A, the stand-sized budget; it does not follow LATE_WORK). A level carve that fits hits on the landing
# tick; one that still needs more takes the late path. Andrew's stand: 859 parts become 101; of 80
# sampled level park sites, 72 % fit (scrapkeep#73-B).
# 5 degrees, against the park's 2 m cells (360,000 sampled, scrapkeep#73-B): 85 % are under 5, only
# 0.3 % lie between 5 and 6 and 14 % are over 10, so the line sits in a gap in the ground, above
# Andrew's stand (3.43) and the park's rolling 2 to 3.5 degrees, below every real slope. Steeper
# landings are untouched: the plain merge, LANDING_WORK, a share a tick, the hit after the last
# share and never before LATE_TICKS. Decided from the faces, never timed.
const LEVEL_GROUND_DEG := 5.0
const LEVEL_TOLERANCE_DEG := 2.0
const LEVEL_DEVIATION := 0.05
const LEVEL_LANDING_WORK := 400

# The latest Breach carve landing() made, for a timing run to read its level, shares and work.
var last_landing := {}

# The tick's work budget; a test lowers it to see the stages.
var late_work := LATE_WORK


# The parts a Breach may test on its landing tick: LANDING_WORK, or on level ground
# LEVEL_LANDING_WORK, in proportion when a test lowers late_work (a lowered late_work lowers both).
func landing_work(level: bool) -> int:
	if level:
		return maxi(1, roundi(float(late_work) * LEVEL_LANDING_WORK / LATE_WORK))
	return mini(late_work, LANDING_WORK)


# True when the face under `at` is within LEVEL_GROUND_DEG of straight up.
func level_ground(faces: Array, at: Vector3) -> bool:
	var normal := TerrainFaces.ground_normal(faces, at)
	return normal.y >= cos(deg_to_rad(LEVEL_GROUND_DEG))

# Breach carves waiting to hit, oldest first: {centre, start, due, sector, cell_cuts, next,
# shaded, lit, level, work, shadows, id, at, heading, reach, pins, damage, record}, with result once carved.
var _late: Array = []

# What the carve did, so a timing run can prove it fired (lesson 34): full_cut commits, Breach
# carves started, ones that finished on their first share (flat: the landing tick) or took more
# (slope), ones with nothing to cut, shares taken and hits delivered.
var carve_stats := {"full_cut": 0, "breach_started": 0, "breach_flat": 0, "breach_slope": 0, "breach_uncut": 0, "shares": 0, "breach_hits": 0}


func _carve_late(id: String, at: Vector3, heading: Vector3, reach: float, pins: float, damage: float) -> Dictionary:
	var sector := _sector_cells(at, heading, reach, acos(PlayerBall.SKID_CONE), 0.0, Weapons.BREACH_INNER)
	var cells: Array = sector["cells"]
	var found := _terrain_near(at, cells)
	var shadows: Array = []
	var level := level_ground(found["faces"], at)
	var merged: Array = TerrainFaces.merge_level(found["faces"], LEVEL_GROUND_DEG, LEVEL_TOLERANCE_DEG, LEVEL_DEVIATION) if level else TerrainFaces.merge(found["faces"])
	var cuts := _cuts(at, merged, cells, shadows, sector["hull"])
	var start := Engine.get_physics_frames()
	var late := {"centre": _commit_beam(at, heading, reach, 0.0), "start": start, "due": start + LATE_TICKS, "sector": sector,
		"cell_cuts": [], "next": 0, "shaded": -1, "lit": [], "shadows": shadows, "id": id, "at": at, "heading": heading,
		"reach": reach, "pins": pins, "damage": damage, "level": level, "record": combat.ultimate._record if combat.ultimate != null else {}}
	carve_stats["breach_started"] += 1
	late["shares"] = 0
	if found.has("unreadable"):
		late["result"] = []
		carve_stats["breach_uncut"] += 1
	elif cuts.is_empty():
		late["result"] = cells
		carve_stats["breach_uncut"] += 1
	else:
		for cell in cells:
			(late["cell_cuts"] as Array).append(_cell_cuts(cuts, cell))
	return late


# One tick's share of the carve, budget parts at most (late_work when negative); true once
# it is done.
func _shade_late(late: Dictionary, budget := -1) -> bool:
	if late.has("result"):
		return true
	if budget < 0:
		budget = late_work
	var cells: Array = late["sector"]["cells"]
	var cell_cuts: Array = late["cell_cuts"]
	var lit: Array = late["lit"]
	_shade_work = 0
	late["shares"] = int(late["shares"]) + 1
	carve_stats["shares"] += 1
	while int(late["next"]) < cells.size() and _shade_work < budget:
		var i: int = late["next"]
		lit.append_array(_shade_cell(late["at"], cell_cuts[i], [cells[i]]))
		late["next"] = i + 1
	late["work"] = int(late.get("work", 0)) + _shade_work
	if int(late["next"]) == cells.size():
		late["result"] = lit
		carve_stats["breach_flat" if int(late["shares"]) == 1 else "breach_slope"] += 1
	return late.has("result")


func _late_shape(late: Dictionary) -> Dictionary:
	return _sector_shape(late["sector"], late["result"], late["shadows"], late["centre"])


# Each waiting carve takes one share per tick after its landing tick.
func _step_late(now := Engine.get_physics_frames()) -> void:
	for late in _late:
		if now > int(late["start"]) and now > int(late["shaded"]) and not late.has("result"):
			late["shaded"] = now
			if _shade_late(late):
				late["carved"] = now
	while not _late.is_empty() and _late[0].has("result") and now >= int(_late[0]["due"]) and now > int(_late[0].get("carved", -1)):
		var late: Dictionary = _late.pop_front()
		var result := _breach(_late_shape(late), late["at"], late["heading"], late["reach"], late["pins"], late["damage"])
		if combat.ultimate != null:
			combat.ultimate.report_landing(late["record"], late["id"], late["at"], result)


# Drops every late carve and its hits. report: each still closes its set piece's landing, with
# no hits, so ultimate_landed fires once per strike.
func _drop_late(report := false) -> void:
	var dropped := _late
	_late = []
	if report and combat.ultimate != null:
		for late in dropped:
			combat.ultimate.report_landing(late["record"], late["id"], late["at"], [0, 0.0])


# Juggernaut Drive's flight: every machine whose hull passes within the corridor of the ball's
# centre is rammed once, knock half outward and half forward; machines never stop the ball.
func _step_piece(delta: float) -> void:
	_shoulder = maxf(0.0, _shoulder - delta)
	if _scar_left > 0.0:
		_scar_left -= delta
		if _scar_left <= 0.0:
			volume_indicator.clear("rivet_scar")
			volume_indicator.clear("rivet_breach")
	if _piece != "juggernaut_drive" or combat.ultimate == null or combat.ultimate.phase() != Ultimate.FLIGHT:
		return
	drive_step(ctx.player.ball_position())


func drive_reach() -> float:
	if _shoulder > 0.0:
		return Weapons.DRIVE_SHOULDER_REACH
	return Weapons.DRIVE_REACH + float(_knob("ult_volley", 0))


func drive_step(ball: Vector3) -> int:
	selected_shapes.clear()
	var heading := _flat(_heading()).normalized()
	var heft: float = Ultimate.HEFT_MULT[_class() - 1]
	var held = ctx.player.exceptions
	var rams := 0
	for enemy in _enemies():
		var to := _flat(enemy.global_position - ball)
		var closed_guard: bool = _warden(enemy) and not enemy.staggered()
		# A guard that closes on the ball keeps passing it until the ball is clear (BITE-PIN).
		if closed_guard and _excepted.has(enemy):
			held.release(enemy)
			_excepted.erase(enemy)
		if enemy is PhysicsBody3D and not closed_guard and not _excepted.has(enemy) and to.length() < Weapons.DRIVE_WAVE_AHEAD * 2.0:
			held.hold(enemy)
			_excepted.append(enemy)
	var shape := _commit_sector(ball, heading, drive_reach(), PI, 0.0, ctx.player.tuning.RADIUS)
	_draw_shape("rivet_ram", shape)
	for enemy in select(shape):
		var to: Vector3 = enemy.global_position - ball
		var id: int = enemy.get_instance_id()
		if _rammed.has(id):
			continue
		_rammed[id] = true
		var damage: float = Weapons.DRIVE_DAMAGE * heft * Weapons.DRIVE_RAM_MULT * (Weapons.DRIVE_SHOULDER_MULT if _shoulder > 0.0 else 1.0)
		var side := Vector3(-heading.z, 0.0, heading.x)
		var outward := side * (1.0 if to.dot(side) >= 0.0 else -1.0)
		if _warden(enemy):
			combat.strike(enemy, "ram", ram_force(damage), "", "special")
		elif _boss(enemy):
			combat.strike(enemy, "ram", ram_force(damage * Ultimate.BOSS_MULT), "", "special")
		else:
			combat._hit(enemy, "ram", ram_force(damage), (outward + heading).normalized(), Weapons.DRIVE_KNOCK * float(_knob("ult_pins", 1.0)), "", "special", "overdrive")
		rams += 1
	return rams


# Held by the ball until it is clear of each body, never dropped with the ball inside one.
func _release_exceptions() -> void:
	var held = ctx.player.exceptions if ctx != null and ctx.player != null else null
	for enemy in _excepted:
		if held != null:
			held.release(enemy)
	_excepted.clear()


# --- Discoveries ----------------------------------------------------------------------

# A pilot card takes a later physics tick than the framework card it extends (B6's rule); ""
# extends none and waits only for the next tick.
func _discover(id: String, after: String, at: Vector3) -> void:
	_cards[id] = {"after": after, "at": at, "queued": Engine.get_physics_frames()}


func _step_cards() -> void:
	for id in _cards.keys():
		var entry: Dictionary = _cards[id]
		var codex = combat._codex()
		var frame := Engine.get_physics_frames()
		var known: bool = String(entry["after"]) == "" or (codex != null and codex.known(entry["after"]))
		if frame > _card_frame and frame > int(entry["queued"]) and known:
			combat._discover(id, entry["at"])
			_cards.erase(id)
			_card_frame = frame
			break


# --- The tick -------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if ctx == null or ctx.flow == null or not ctx.flow.in_play():
		return
	step(delta)


func step(delta: float) -> void:
	_clock += delta
	_warm_terrain()
	_step_pulses(delta)
	_step_haul(delta)
	_step_preview()
	_step_piece(delta)
	_step_late()
	_step_cuts()
	_step_cards()


# Caches the static terrain around the ball on workers ahead of the carve, which otherwise
# waits for the build (TerrainFaces).
const WARM_EVERY := 45
const WARM_REACH := 60.0


func _exit_tree() -> void:
	_drop_late()
	_drop_cuts()
	terrain.finish()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_drop_cuts()
		if _carver != null:
			_carver.free()
			_carver = null


# Warm-up cycles run, for a hitch guard: while Rivet stands, terrain.builds should stop growing.
var warm_cycles := 0


func _warm_terrain() -> void:
	if Engine.get_physics_frames() % WARM_EVERY != 0 or ctx.player == null or not _rivet():
		return
	warm_cycle()


func warm_cycle() -> void:
	warm_cycles += 1
	terrain.prune()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE * WARM_REACH * 2.0
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform = Transform3D(Basis.IDENTITY, ctx.player.ball_position())
	query.collision_mask = Hitscan.WORLD
	var space: PhysicsDirectSpaceState3D = ctx.root.get_world_3d().direct_space_state
	var excluded: Array[RID] = []
	while true:
		query.exclude = excluded
		var hits := space.intersect_shape(query)
		if hits.is_empty():
			return
		for hit in hits:
			var collider: CollisionObject3D = hit["collider"]
			excluded.append(collider.get_rid())
			if collider.get_class() != "StaticBody3D":
				continue
			for owner in collider.get_shape_owners():
				if collider.is_shape_owner_disabled(owner):
					continue
				var transform := collider.global_transform * collider.shape_owner_get_transform(owner)
				for i in collider.shape_owner_get_shape_count(owner):
					_terrain_entry(collider.shape_owner_get_shape(owner, i), transform)


func _clear_piece() -> void:
	_piece = ""
	_last_aim = Vector3.ZERO
	_cut = {}
	_rammed = {}
	_shoulder = 0.0
	_release_exceptions()
	if ctx != null:
		_clear_beams()
		volume_indicator.clear("rivet_wave")
		volume_indicator.clear("rivet_ram")


func _clear() -> void:
	selected_shapes.clear()
	_drop_late(true)
	_drop_cuts()
	pulses.clear()
	if not haul.is_empty():
		_end_haul(false)
	last_punch = {}
	_clear_piece()
	_scar_left = 0.0
	if ctx != null:
		for layer in ["rivet_line", "rivet_arrival", "rivet_haul", "rivet_scar", "rivet_breach", "rivet_wave", "rivet_ram"]:
			ctx.player.indicator.clear(layer)
			volume_indicator.clear(layer)
