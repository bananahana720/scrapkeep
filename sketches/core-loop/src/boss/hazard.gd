extends Node3D

const BossAttacks := preload("res://src/boss/boss_attacks.gd")
const Palette := preload("res://src/core/palette.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const WarningBound := preload("res://src/combat/warning_bound.gd")

enum Shape { SECTOR, ANNULUS, LANE }
enum { WARN, LIVE, DONE }

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
var warn_floor := MIN_WARN
var cued := false
var live_seconds := 1.0
var centre := Vector3.ZERO
var r_in := 0.0
var r_out := 0.0
var a_from := 0.0
var a_to := 0.0
var heading := Vector3.FORWARD
var back := 0.0
var length := 0.0
var half_width := 0.0
var reach := 3.0
var ground := Callable()
var excluded := Callable()
var color := Palette.HAZARD
var owner_voice := ""
var mechanic_tag := ""
var prev_fraction := 0.0

var _painter
var _open: Array[bool] = []
var _bound := AABB()
var _bound_stale := false
var bound_merges := 0


static func from_def(d: Dictionary) -> Node3D:
	var h := new()
	match d["shape"]:
		"lane":
			h.commit_lane(d["id"], d["type"], d["from"], d["dir"], d["behind"], d["ahead"], d["half"], d["height"], d["warn"], d["live"])
		"sector":
			h.commit_sector(d["id"], d["type"], d["at"], d["band"], d["from_angle"], d["to_angle"], d["height"], d["warn"], d["live"])
		"annulus":
			h.commit_annulus(d["id"], d["type"], d["at"], d["band"], d["height"], d["warn"], d["live"])
	return h


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


func draws(point: Vector3) -> bool:
	var r := BossAttacks.flat(point - centre).length()
	if shape != Shape.ANNULUS or r < r_in or r > r_out:
		return contains(point)
	var d := BossAttacks.flat(point - centre)
	var i := int(floor(wrapf(atan2(d.z, d.x), 0.0, TAU) / TAU * RING_SEGMENTS)) % RING_SEGMENTS
	return _open.size() != RING_SEGMENTS or not _open[i]


func _open_segments() -> Array[bool]:
	var open: Array[bool] = []
	var mid := (r_in + r_out) * 0.5
	for i in RING_SEGMENTS:
		var a := TAU * (i + 0.5) / RING_SEGMENTS
		open.append(excluded.is_valid() and excluded.call(centre + Vector3(cos(a), 0.0, sin(a)) * mid))
	return open


var lane_front := -1.0


func is_live() -> bool:
	return state == LIVE


func is_done() -> bool:
	return state == DONE


func seconds_until_live() -> float:
	return maxf(0.0, warn_seconds - age)


func live_fraction() -> float:
	return clampf((age - warn_seconds) / maxf(0.001, live_seconds), 0.0, 1.0)


func front() -> float:
	if state == WARN:
		return -1.0
	return absf(a_to - a_from) * live_fraction()


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


func contains(point: Vector3) -> bool:
	var above := point.y - ground_at(point)
	if above > reach or above < -2.0:
		return false
	match shape:
		Shape.SECTOR:
			var r := BossAttacks.flat(point - centre).length()
			if r < r_in or r > r_out:
				return false
			var u := sweep_offset(point)
			return u >= -_angle_margin(r) and u <= absf(a_to - a_from) + _angle_margin(r)
		Shape.ANNULUS:
			var r := BossAttacks.flat(point - centre).length()
			if r < r_in or r > r_out:
				return false
			return not (excluded.is_valid() and excluded.call(point))
		Shape.LANE:
			var local := BossAttacks.flat(point - centre)
			var along := local.dot(heading)
			return along >= -back and along <= length and absf(local.dot(side())) <= half_width
	return false


func sweep_offset(point: Vector3) -> float:
	var d := BossAttacks.flat(point - centre)
	var angle := atan2(d.z, d.x)
	var dir := signf(a_to - a_from) if a_to != a_from else 1.0
	return wrapf((angle - a_from) * dir, -PI, PI)


func _angle_margin(r: float) -> float:
	return 1.0 / maxf(r, 1.0)


func side() -> Vector3:
	return Vector3.UP.cross(heading).normalized()


func lane_along(point: Vector3) -> float:
	return BossAttacks.flat(point - centre).dot(heading)


func lane_lateral(point: Vector3) -> float:
	return BossAttacks.flat(point - centre).dot(side())


func descriptor() -> Dictionary:
	var d := {"type": type, "tone": Palette.HAZARD if color == Palette.BRASS else color, "centre": centre, "reach": reach, "progress": clampf(age / warn_seconds, 0.0, 1.0),
		"live": state == LIVE}
	if state == LIVE:
		d["live_age"] = maxf(age - warn_seconds, 0.0)
	match shape:
		Shape.SECTOR:
			d.merge({"form": "radial", "r_in": r_in, "r_out": r_out, "a0": a_from, "a1": a_to})
		Shape.ANNULUS:
			d.merge({"form": "radial", "r_in": r_in, "r_out": r_out, "a0": 0.0, "a1": TAU, "open": _open,
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


func screen_bound_box() -> AABB:
	if _painter == null or state == DONE:
		return AABB()
	if _bound_stale and not WarningBound.test_skip_hazard_merge:
		_bound_stale = false
		bound_merges += 1
		_bound = _bound.merge(WarningBound.mesh_box(_painter))
	return _bound


func _grow_bound() -> void:
	if _bound.size != Vector3.ZERO:
		_bound_stale = true


func _cut_bound() -> void:
	if _bound.size != Vector3.ZERO or _painter == null or not is_hostile() or _open.has(true):
		return
	_bound = WarningBound.box(descriptor(), WarningBound.mesh_box(_painter))


func _paint(reshaped: bool) -> void:
	if _painter == null:
		return
	_painter.visible = state != DONE
	var d := descriptor()
	if reshaped:
		_painter.paint(Threat.marks(d, false), Threat.STATIC_LAYERS)
	_painter.paint(Threat.marks(d, true), Threat.MOTION_LAYERS)
	_painter.tint("fill", Threat.fill_tint(d))
