extends Node3D

const Palette := preload("res://src/core/palette.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const WarningBound := preload("res://src/combat/warning_bound.gd")

# One committed attack area: a crane's sweep, a slag ring or a charge lane. It is laid
# once, when the attack commits, and the drawing and every hit test read the same
# numbers, so what the player sees is what can hit them (TADR-008). WARN lasts at
# least 1.0 s, or warn_floor for a cued follow-up (fight_phases.gd: its ratchet cue
# sounded CUE_LEAD earlier); a hit is possible only while LIVE and only where contains()
# is true.
#
# Its attack type draws it in the grammar combat's telegraphs share (threat_grammar.gd):
# a crane's sweep is a WAVE whose front stands at the magnet's real bearing, a slag ring
# is INSTANT, a charge is a LANE. A WAVE hazard is a sector sweep: its front is the
# offset front() returns, the same span x live_fraction() the boss's sweep test reads.

enum Shape { SECTOR, ANNULUS, LANE }
enum { WARN, LIVE, DONE }

# On the step the warning ends and the hazard starts to hurt: the lane's tear plays here.
signal went_live

const MIN_WARN := 1.0
const DRAW_LIFT := 0.08
const MOLTEN := Color("ff7a2e")
const RING_SEGMENTS := Threat.SEGMENTS

var attack_id := ""
var type := Threat.UNSET
var shape := Shape.ANNULUS
var state := WARN
var age := 0.0
var warn_seconds := MIN_WARN
# Set before commit: a cued follow-up lowers it to FightPhases.CUED_WARN and sets cued.
var warn_floor := MIN_WARN
var cued := false
var live_seconds := 1.0
# SECTOR and ANNULUS: the floor centre. LANE: where the lane starts.
var centre := Vector3.ZERO
var r_in := 0.0
var r_out := 0.0
# SECTOR: the sweep runs from a_from to a_to (radians about +y, atan2(z, x)).
var a_from := 0.0
var a_to := 0.0
# LANE: flat unit heading, how far it reaches behind the start, its length and half width.
var heading := Vector3.FORWARD
var back := 0.0
var length := 0.0
var half_width := 0.0
# How high above the ground under the ball the area reaches; a jump can clear it.
var reach := 3.0
# (point) -> float: the ground height under a point.
var ground := Callable()
# ANNULUS: (point) -> bool, true where the ring is quenched and safe.
var excluded := Callable()
# Brindle's hazards arrive tinted BRASS (the boss_attack_telegraphed row). Danger still
# draws in HAZARD; the brass becomes the owner's rim tick (VISUAL-LANGUAGE.md section 4).
# AMBER marks a spot that is not a threat (a drone pad).
var color := Palette.HAZARD
# Sound ids layered over the type's warn sound: the owner's timbre (Fleet or ancient)
# and a unit's mechanic tag (SOUND-STORY.md section 3). Set them right after commit;
# presentation reads them at the end of the frame the threat was declared.
var owner_voice := ""
var mechanic_tag := ""
# live_fraction() before the latest step, so a sweep can test only what it just crossed.
var prev_fraction := 0.0

var _painter
# ANNULUS: which of its drawn segments are open (quenched) right now.
var _open: Array[bool] = []
# The world box of everything the painter can draw (WarningBound), cut once, right after the
# first FULL paint: in _ready, or, for an annulus that starts with spans quenched, on the first
# step that leaves none quenched (later quenches only remove drawn spans, so the full paint's
# meshes hold every later one). Empty until then, so warning_rects walks the meshes. Only a
# hostile hazard gets one; the first read after a repainting step grows it (_grow_bound). The
# committed numbers never change after commit and nothing moves a hazard, so it is never recut.
var _bound := AABB()
# A step repainted since the box last took the meshes in; bound_merges counts the mesh walks
# that took (tests/warning_bound_containment_test.gd: idle steps cost none).
var _bound_stale := false
var bound_merges := 0


func commit_sector(id: String, threat_type: int, at: Vector3, band: Vector2, from_angle: float, to_angle: float, height: float,
		warn: float, live: float) -> void:
	shape = Shape.SECTOR
	attack_id = id
	centre = at
	r_in = band.x
	r_out = band.y
	a_from = from_angle
	a_to = to_angle
	reach = height
	_times(threat_type, warn, live)


func commit_annulus(id: String, threat_type: int, at: Vector3, band: Vector2, height: float, warn: float, live: float) -> void:
	shape = Shape.ANNULUS
	attack_id = id
	centre = at
	r_in = band.x
	r_out = band.y
	reach = height
	_times(threat_type, warn, live)


func commit_lane(id: String, threat_type: int, from: Vector3, dir: Vector3, behind: float, ahead: float, half: float,
		height: float, warn: float, live: float) -> void:
	shape = Shape.LANE
	attack_id = id
	centre = from
	heading = Vector3(dir.x, 0.0, dir.z).normalized()
	back = behind
	length = ahead
	half_width = half
	reach = height
	_times(threat_type, warn, live)


func _times(threat_type: int, warn: float, live: float) -> void:
	type = threat_type
	warn_seconds = maxf(warn_floor, warn)
	live_seconds = live
	name = "Hazard_%s" % attack_id


func _ready() -> void:
	if is_hostile():
		add_to_group(Threat.GROUP)
	if not Threat.valid(type):
		push_error("hazard %s committed without an attack type" % attack_id)
		return
	if type == Threat.Type.WAVE and shape != Shape.SECTOR:
		push_error("hazard %s: a WAVE hazard is a sector sweep" % attack_id)
		return
	_painter = Threat.Painter.new()
	_painter.ground = ground_at
	_painter.floor_y = centre.y
	_painter.lift = DRAW_LIFT
	add_child(_painter)
	if shape == Shape.ANNULUS:
		_open = _open_segments()
	_paint(true)
	_cut_bound()


func step(delta: float) -> void:
	prev_fraction = live_fraction()
	age += delta
	if state == WARN and age >= warn_seconds:
		state = LIVE
		went_live.emit()
		land()
	if state == LIVE and age >= warn_seconds + live_seconds:
		state = DONE
	var reshaped := false
	if shape == Shape.ANNULUS and is_inside_tree():
		var open := _open_segments()
		if open != _open:
			_open = open
			reshaped = true
	_paint(reshaped)
	if reshaped:
		_cut_bound()
	_grow_bound()


# ANNULUS: whether the drawing covers a point. A quenched span is left undrawn, so the
# crust under it shows through and no telegraph has to be painted over.
func draws(point: Vector3) -> bool:
	var r := _flat(point - centre).length()
	if shape != Shape.ANNULUS or r < r_in or r > r_out:
		return contains(point)
	var d := _flat(point - centre)
	var i := int(floor(wrapf(atan2(d.z, d.x), 0.0, TAU) / TAU * RING_SEGMENTS)) % RING_SEGMENTS
	return _open.size() != RING_SEGMENTS or not _open[i]


func _open_segments() -> Array[bool]:
	var open: Array[bool] = []
	var mid := (r_in + r_out) * 0.5
	for i in RING_SEGMENTS:
		var a := TAU * (i + 0.5) / RING_SEGMENTS
		open.append(excluded.is_valid() and excluded.call(centre + Vector3(cos(a), 0.0, sin(a)) * mid))
	return open


# LANE: how far along the lane, from its start, the thing that hurts has run while live (Brindle's
# hull nose), or -1 for a lane that hurts all along at once. Only the drawing and the dodge watch
# read it; contains() keeps the whole committed lane.
var lane_front := -1.0


func is_live() -> bool:
	return state == LIVE


func is_done() -> bool:
	return state == DONE


func seconds_until_live() -> float:
	return maxf(0.0, warn_seconds - age)


# 0 at the start of LIVE, 1 at its end.
func live_fraction() -> float:
	return clampf((age - warn_seconds) / maxf(0.001, live_seconds), 0.0, 1.0)


# WAVE: how far the sweep's front has turned from a_from, in radians; -1 while it warns.
func front() -> float:
	if state == WARN:
		return -1.0
	return absf(a_to - a_from) * live_fraction()


# The landing on the step the warning ends (FX-05, as Telegraph.land does for a crew mark): the
# ink crack ring and dust kick, and an INSTANT's solid flash, drawn from descriptor(), the
# numbers contains() reads. Nothing for a harmless mark, a wave's sweep (its front is its
# landing) or a hazard outside the tree.
func land() -> void:
	if not is_inside_tree() or not is_hostile():
		return
	var floor: bool = _painter != null
	Threat.flash(get_parent(), descriptor(), centre.y, DRAW_LIFT, _painter.ground if floor else Callable(),
		_painter.ground_many if floor else Callable())


func finish() -> void:
	state = DONE


func ground_at(point: Vector3) -> float:
	return ground.call(point) if ground.is_valid() else centre.y


# The committed geometry. Every hit this area makes is inside it.
func contains(point: Vector3) -> bool:
	var above := point.y - ground_at(point)
	if above > reach or above < -2.0:
		return false
	match shape:
		Shape.SECTOR:
			var r := _flat(point - centre).length()
			if r < r_in or r > r_out:
				return false
			var u := sweep_offset(point)
			return u >= -_angle_margin(r) and u <= absf(a_to - a_from) + _angle_margin(r)
		Shape.ANNULUS:
			var r := _flat(point - centre).length()
			if r < r_in or r > r_out:
				return false
			return not (excluded.is_valid() and excluded.call(point))
		Shape.LANE:
			var local := _flat(point - centre)
			var along := local.dot(heading)
			return along >= -back and along <= length and absf(local.dot(side())) <= half_width
	return false


# SECTOR: how far along the sweep a point sits, in radians from a_from.
func sweep_offset(point: Vector3) -> float:
	var d := _flat(point - centre)
	var angle := atan2(d.z, d.x)
	var dir := signf(a_to - a_from) if a_to != a_from else 1.0
	return wrapf((angle - a_from) * dir, -PI, PI)


# A ball of radius 1 m touches the sector a little before its centre enters it.
func _angle_margin(r: float) -> float:
	return 1.0 / maxf(r, 1.0)


# LANE: the flat axis across the lane.
func side() -> Vector3:
	return Vector3.UP.cross(heading).normalized()


func lane_along(point: Vector3) -> float:
	return _flat(point - centre).dot(heading)


func lane_lateral(point: Vector3) -> float:
	return _flat(point - centre).dot(side())


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


# The committed numbers the drawing reads: the same fields contains() reads.
func descriptor() -> Dictionary:
	var d := {"type": type, "tone": Palette.HAZARD if color == Palette.BRASS else color, "centre": centre, "reach": reach, "progress": clampf(age / warn_seconds, 0.0, 1.0),
		"live": state == LIVE}
	match shape:
		Shape.SECTOR:
			d.merge({"form": "radial", "r_in": r_in, "r_out": r_out, "a0": a_from, "a1": a_to})
		Shape.ANNULUS:
			d.merge({"form": "radial", "r_in": r_in, "r_out": r_out, "a0": 0.0, "a1": TAU, "open": _open,
				# Classic only: under haze a hostile live slag takes fill_tint's dark scorched core (one live
				# look for every INSTANT, ATTACK-READS.md B02). Nothing else reads live_tone; quenched
				# holes are left out of the geometry, so they stay clear.
				"live_tone": color.lerp(MOLTEN, 0.5)})
		Shape.LANE:
			d.merge({"form": "lane", "dir": heading, "back": back, "length": length, "half_width": half_width})
			if lane_front >= 0.0:
				d["front_m"] = lane_front
	if color == Palette.BRASS:
		d["owner"] = Palette.BRASS
	if type == Threat.Type.WAVE:
		d["front"] = front()
	return d


func threat_kind() -> String:
	return Threat.kind(type)


func is_hostile() -> bool:
	return color == Palette.BRASS or Threat.stance(color) == "hostile"


func threat_at() -> Vector3:
	return centre


func painter():
	return _painter


# The conservative world box of everything this hazard's painter draws at any progress: the
# full footprint, the fence up to `reach`, the lift, a sweep's chevrons ahead of its front
# (WarningBound). It is cut in _ready. A read after a step also takes the painter's current
# meshes in (see _grow_bound), so the cache only grows. The box is empty (AABB()) before the
# painter is built and once the hazard is DONE. finish() sets DONE without a repaint, so the
# painter is hidden only on the next step; until then the caller's mesh walk still finds its
# meshes, which is conservative.
func screen_bound_box() -> AABB:
	if _painter == null or state == DONE:
		return AABB()
	if _bound_stale and not WarningBound.test_skip_hazard_merge:
		_bound_stale = false
		bound_merges += 1
		_bound = _bound.merge(WarningBound.mesh_box(_painter))
	return _bound


# The motion marks are repainted every step, on ground the first paint did not sample (a fill
# ring's inner edge, a sweep's spoke and chevrons, a lane's run strip). A step only marks the
# box stale; screen_bound_box() takes the meshes' box in when it is read, so the box holds every
# mesh drawn up to the read and a step that nobody reads after costs nothing.
func _grow_bound() -> void:
	if _bound.size != Vector3.ZERO:
		_bound_stale = true


func _cut_bound() -> void:
	if _bound.size != Vector3.ZERO or _painter == null or not is_hostile() or _open.has(true):
		return
	_bound = WarningBound.box(descriptor(), WarningBound.mesh_box(_painter))


# Static layers redraw only when the shape changes (a quench opens or closes a span);
# the moving front, brackets or running fill and the fill's tint follow every step.
func _paint(reshaped: bool) -> void:
	if _painter == null:
		return
	_painter.visible = state != DONE
	var d := descriptor()
	if reshaped:
		_painter.paint(Threat.marks(d, false), Threat.STATIC_LAYERS)
	_painter.paint(Threat.marks(d, true), Threat.MOTION_LAYERS)
	_painter.tint("fill", Threat.fill_tint(d))
