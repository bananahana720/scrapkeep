extends Node3D

const Palette := preload("res://src/core/palette.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const WarningBound := preload("res://src/combat/warning_bound.gd")

# A committed telegraph: the one piece of geometry an enemy attack both draws and
# damages with. The attack decides its shape and its attack type once, at commit, and
# the hit test later asks this node's contains(); nothing else decides whether the
# player was hit. That is "damage and telegraphs consume the same committed geometry"
# (AGENTS.md, TADR-008).
#
# Shapes: a ring on the ground (a slam, a shell's blast or a wave's reach), a lane along
# the ground (a lunge or a charge) or a wedge fanning out from a point (the Warden's
# magnet pull). The attack type decides how it draws (threat_grammar.gd): a WAVE ring runs
# a front outward; every other ground hit fills from its centre out to its outline and is
# full on the hit tick, a PROJECTILE's under a thin dashed flight arc. All reach `reach_up`
# metres above the ground under the ball, so jumping or gliding over one dodges it: a read
# the player can act on at speed.
#
# Readability: every telegraph draws in HAZARD, with no depth test, at a render priority
# above every player effect (Bolts.PRIORITY, Effects.PRIORITY), so our own bolts, arcs
# and blasts can never paint over the next threat (principle 4).

const PRIORITY := Threat.PRIORITY
const LIFT := 0.2

# When the warning runs out (progress reaches 1, by step() or the owner): the lane's tear plays here.
signal went_live

enum Shape { RING, LANE, WEDGE }

var type := Threat.UNSET
var shape := Shape.RING
var center := Vector3.ZERO
var radius := 0.0
var dir := Vector3.FORWARD
var half_angle := 0.0
var length := 0.0
var width := 0.0
var reach_up := 3.5
# An aerial band: the ring stands at `center.y` in the air and reaches reach_up above it, a
# fixed height band instead of the ground under the point. Drawn and hit-tested the same way.
var aerial := false
var terrain
var progress := 0.0
# WAVE: seconds since commit, the warning before the front leaves, and its speed.
var age := 0.0
var warn_seconds := 0.0
var speed := 0.0
# PROJECTILE: where the flight starts and how high it arcs (Threat.flight_point).
var launch := Vector3.ZERO
var bump := 0.0
var has_flight := false
# Only the air can answer this mark (the netcaster's net); haze keeps it off the live ground scorch.
var air_only := false
# HAZARD for every enemy threat. A ring the player owns (a batted shell) draws in AMBER,
# and a harmless field (the Warden's lift) in bone, Palette.SAND (Threat.stance).
var color := Palette.HAZARD
# Sound ids layered over the type's warn sound: the owner's timbre (Fleet or ancient)
# and a unit's mechanic tag (SOUND-STORY.md section 3). Set them right after commit;
# presentation reads them at the end of the frame the threat was declared.
var owner_voice := ""
var mechanic_tag := ""

var _painter
var _flashed := false
# Whether the warning's end is the hit (FX-05). An owner whose hits come later sets it false and
# calls land() at each hit itself (the jolt layer's pulses), so no landing marks a moment that
# cannot hurt.
var lands_on_live := true
# LANE: a crew body that runs its lane after the warning goes live (the chaser's lunge, the
# miniboss's charge). run_body() says how far along the lane, from its start, the body's centre is
# and how close it must come to hurt; only the drawing and the dodge watch's way-out read it, so the
# danger mark and the way-out paint stay up until the body reaches the ball. -1 reach: no running body.
var _body_m := 0.0
var _body_reach := -1.0
# Driven: the motion marks were built once and each frame only moves them (E1). Every type
# except a wave is driven; a wave is driven only when it is full and its area layer is not
# "motion" (Threat.can_drive), so a partial wave or a motion wave is repainted instead.
var _driven := false
var _fill_tint := Color(-1.0, -1.0, -1.0, -1.0)
# The world box of everything the painter can draw, at any progress (WarningBound), and the
# centre it was cut for. Computed in _build and again when the flight is set.
var _bound := AABB()
var _bound_centre := Vector3.ZERO
# A non-driven repaint since the box last took the meshes in (a partial wave or a motion
# wave, the marks Threat.can_drive leaves undriven); bound_merges counts the mesh walks that took.
var _bound_stale := false
var bound_merges := 0


static func ring(parent: Node, terrain_ref, threat_type: int, at: Vector3, ring_radius: float, reach := 3.5,
		tint := Palette.HAZARD) -> Node3D:
	var node: Node3D = load("res://src/combat/telegraph.gd").new()
	node.type = threat_type
	node.color = tint
	node.shape = Shape.RING
	node.terrain = terrain_ref
	node.radius = ring_radius
	node.reach_up = reach
	node.center = Vector3(at.x, ground_under(terrain_ref, at), at.z)
	parent.add_child(node)
	node._build()
	return node


# A ring hung in the air: its footprint floats at `band_bottom.y` and reaches `band_height`
# above it. contains() tests the point against that band, so the mark shows where it hurts.
static func aerial_ring(parent: Node, terrain_ref, threat_type: int, band_bottom: Vector3, ring_radius: float,
		band_height: float, tint := Palette.HAZARD) -> Node3D:
	var node: Node3D = load("res://src/combat/telegraph.gd").new()
	node.type = threat_type
	node.color = tint
	node.shape = Shape.RING
	node.terrain = terrain_ref
	node.radius = ring_radius
	node.reach_up = band_height
	node.aerial = true
	node.center = band_bottom
	parent.add_child(node)
	node._build()
	return node


# A ring whose danger is a front leaving the centre `warn` seconds after commit at
# `wave_speed` m/s; the owner calls step() every tick. Only the front hurts.
static func wave(parent: Node, terrain_ref, at: Vector3, wave_radius: float, wave_speed: float, warn: float,
		reach := 3.5) -> Node3D:
	var node: Node3D = load("res://src/combat/telegraph.gd").new()
	node.type = Threat.Type.WAVE
	node.shape = Shape.RING
	node.terrain = terrain_ref
	node.radius = wave_radius
	node.speed = wave_speed
	node.warn_seconds = warn
	node.reach_up = reach
	node.center = Vector3(at.x, ground_under(terrain_ref, at), at.z)
	parent.add_child(node)
	node._build()
	return node


static func lane(parent: Node, terrain_ref, threat_type: int, from: Vector3, heading: Vector3, lane_length: float,
		lane_width: float, reach := 3.5) -> Node3D:
	var node: Node3D = load("res://src/combat/telegraph.gd").new()
	node.type = threat_type
	node.shape = Shape.LANE
	node.terrain = terrain_ref
	var flat := Vector3(heading.x, 0.0, heading.z)
	node.dir = flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD
	node.length = lane_length
	node.width = lane_width
	node.reach_up = reach
	node.center = Vector3(from.x, ground_under(terrain_ref, from), from.z)
	parent.add_child(node)
	node._build()
	return node


# A fan of `half_angle_deg` either side of `heading`, out to `wedge_radius` from `apex`.
static func wedge(parent: Node, terrain_ref, threat_type: int, apex: Vector3, heading: Vector3, wedge_radius: float,
		half_angle_deg: float, reach := 3.5) -> Node3D:
	var node: Node3D = load("res://src/combat/telegraph.gd").new()
	node.type = threat_type
	node.shape = Shape.WEDGE
	node.terrain = terrain_ref
	var flat := Vector3(heading.x, 0.0, heading.z)
	node.dir = flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD
	node.radius = wedge_radius
	node.half_angle = deg_to_rad(half_angle_deg)
	node.reach_up = reach
	node.center = Vector3(apex.x, ground_under(terrain_ref, apex), apex.z)
	parent.add_child(node)
	node._build()
	return node


# The ground under a point. Combat's ground (ground.gd) answers at the point itself, so
# in the arena a telegraph stands on the boss floor; a plain terrain answers by x and z.
static func ground_under(terrain_ref, point: Vector3) -> float:
	if terrain_ref.has_method("height_at"):
		return terrain_ref.height_at(point)
	return terrain_ref.height(point.x, point.z)


# The hit test every attack uses. The height is measured from the ground under the
# point, so a ring on a slope still means what it shows. A wave hurts only on its front.
func contains(point: Vector3) -> bool:
	var ground: float = center.y if aerial else (ground_under(terrain, point) if terrain != null else center.y)
	var above := point.y - ground
	if above > reach_up or above < (0.0 if aerial else -2.0):
		return false
	var flat := Vector3(point.x - center.x, 0.0, point.z - center.z)
	if shape == Shape.RING:
		if type == Threat.Type.WAVE:
			var front := front_radius()
			return front >= 0.0 and flat.length() <= radius and absf(flat.length() - front) <= Threat.WAVE_EDGE
		return flat.length() <= radius
	if shape == Shape.WEDGE:
		var out := flat.length()
		return out <= radius and (out < 0.01 or flat.dot(dir) >= out * cos(half_angle))
	var along := flat.dot(dir)
	if along < 0.0 or along > length:
		return false
	return (flat - dir * along).length() <= width * 0.5


func end_point() -> Vector3:
	return center + dir * length


# WAVE: how far the front has run, speed x the time since it left; -1 while it arms.
func front_radius() -> float:
	if type != Threat.Type.WAVE or age < warn_seconds:
		return -1.0
	return speed * (age - warn_seconds)


func is_spent() -> bool:
	return type == Threat.Type.WAVE and front_radius() - Threat.WAVE_EDGE > radius


func step(delta: float) -> void:
	age += delta
	set_progress(age / maxf(warn_seconds, 0.001))


# PROJECTILE: the flight the landing waits for, drawn as a thin dashed arc onto the landing.
func set_flight(from: Vector3, arc_bump: float) -> void:
	launch = from
	bump = arc_bump
	has_flight = true
	_paint_motion()
	_repaint()
	_cut_bound()


func set_progress(value: float) -> void:
	var armed := progress < 1.0
	progress = clampf(value, 0.0, 1.0)
	_repaint()
	if armed and progress >= 1.0:
		went_live.emit()
	if progress >= 1.0 and not _flashed:
		_flashed = true
		if lands_on_live:
			land()


# The landing now (Threat.flash): an INSTANT's solid flash, and the ink crack ring and dust kick of
# any hostile ground mark but a wave (FX-05), on the mark's own ground. set_progress calls it once,
# on the tick the warning ends; an owner whose hit comes at another moment (a thrown bola or disc
# arriving, each pulse of a held field) calls it at that moment instead. Nothing for a mark that
# is not hostile or not in the tree.
func land() -> void:
	if not is_inside_tree() or not is_hostile():
		return
	var floor: bool = _painter != null
	Threat.flash(get_parent(), descriptor(), center.y, LIFT, _painter.ground if floor else Callable(), _painter.ground_many if floor else Callable())


# The owner's one call per tick: its body's centre is `along` metres down the lane and hurts a ball
# within `reach` of it (the same distance its own hit test uses). contains() and the damage are untouched.
func run_body(along: float, reach: float) -> void:
	_body_m = along
	_body_reach = reach


# The committed numbers the drawing reads: the same fields contains() reads.
func descriptor() -> Dictionary:
	var d := {"type": type, "tone": color, "centre": center, "reach": reach_up, "progress": progress, "live": progress >= 1.0}
	match shape:
		Shape.RING:
			d.merge({"form": "radial", "r_in": 0.0, "r_out": radius, "a0": 0.0, "a1": TAU})
		Shape.WEDGE:
			var mid := atan2(dir.z, dir.x)
			d.merge({"form": "radial", "r_in": 0.0, "r_out": radius, "a0": mid - half_angle, "a1": mid + half_angle, "pull": true})
		Shape.LANE:
			d.merge({"form": "lane", "dir": dir, "back": 0.0, "length": length, "half_width": width * 0.5})
			if _body_reach >= 0.0:
				d["body_m"] = _body_m
				d["body_reach"] = _body_reach
	if aerial:
		d["aerial"] = true
	if type == Threat.Type.WAVE:
		d["front"] = front_radius()
	if has_flight:
		d["launch"] = launch
		d["bump"] = bump
	if air_only:
		d["air"] = true
	return d


func threat_kind() -> String:
	return Threat.kind(type)


func is_hostile() -> bool:
	return Threat.stance(color) == "hostile"


func threat_at() -> Vector3:
	return center


func painter():
	return _painter


# The conservative world box of everything this mark's painter draws at any progress: the
# footprint at progress 1, the fence up to reach_up, the lift, a wave's final extent and a
# projectile's flight trace (WarningBound). It is cut at commit. A read after a non-driven
# repaint also takes the painter's current meshes in, so the cache only grows. The box is
# empty (AABB()) when it cannot promise: nothing is built, or the mark was carried off its
# committed centre (the Warden's mounting moves a pulse ring's center after commit). The
# caller then walks the meshes.
func screen_bound_box() -> AABB:
	if _painter == null or center != _bound_centre:
		return AABB()
	if _bound_stale:
		_bound_stale = false
		bound_merges += 1
		_bound = _bound.merge(WarningBound.mesh_box(_painter))
	return _bound


# Only a hostile mark joins Threat.GROUP, so only a hostile mark is read by warning_rects and
# gets a box; the others keep an empty one. The y range reads the painter's meshes, which are
# all built by now (static layers, driven layers at full extent).
func _cut_bound() -> void:
	if _painter == null or not is_hostile():
		return
	_bound_centre = center
	_bound = WarningBound.box(descriptor(), WarningBound.mesh_box(_painter))


func _build() -> void:
	add_to_group("telegraph")
	if is_hostile():
		add_to_group(Threat.GROUP)
	global_position = center + Vector3.UP * LIFT
	if not Threat.valid(type):
		push_error("telegraph committed without an attack type")
		return
	var d := descriptor()
	_driven = Threat.can_drive(d)
	_painter = Threat.Painter.new()
	_painter.floor_y = center.y
	if aerial:
		var flat_y := center.y
		_painter.ground = func(_point: Vector3) -> float: return flat_y
	elif terrain != null:
		_painter.ground = func(point: Vector3) -> float: return ground_under(terrain, point)
		if terrain.has_method("heights"):
			_painter.ground_many = terrain.heights
	_painter.lift = LIFT
	_painter.driven = _driven
	_painter.centre = center
	_painter.heading = Vector2(dir.x, dir.z)
	_painter.motion_class = {Threat.Type.WAVE: "swept", Threat.Type.LANE: "run"}.get(type, "fill")
	_painter.area_class = "reach" if type == Threat.Type.PROJECTILE else "area"
	add_child(_painter)
	_painter.paint(Threat.marks(d, false), Threat.STATIC_LAYERS)
	_paint_motion()
	_repaint()
	_cut_bound()


# A driven telegraph builds its motion marks here, at commit and when its flight is set;
# nothing else rebuilds a mesh for the life of the node.
func _paint_motion() -> void:
	if _painter != null and _driven:
		_painter.paint(Threat.driven_marks(descriptor()), Threat.MOTION_LAYERS)


func _repaint() -> void:
	if _painter == null:
		return
	var d := descriptor()
	if _driven:
		_painter.drive(Threat.drive(d))
	else:
		_painter.paint(Threat.marks(d, true), Threat.MOTION_LAYERS)
		# Repainted marks stand on ground the build did not sample; screen_bound_box() takes
		# their meshes in when it is read.
		_bound_stale = _bound_stale or _bound.size != Vector3.ZERO
	var fill := Threat.fill_tint(d)
	if fill != _fill_tint:
		_fill_tint = fill
		_painter.tint("fill", fill)


static func material(alpha: float, tint := Palette.HAZARD) -> StandardMaterial3D:
	var mat := Palette.unshaded(Color(tint, alpha))
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.render_priority = PRIORITY
	return mat
