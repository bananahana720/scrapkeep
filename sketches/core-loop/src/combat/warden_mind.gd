extends RefCounted

signal island_tilted(degrees: float, away: Vector3)
signal took_off(from_perch: int, to_perch: int)
signal landed(perch: int)
signal knocked_down(at: Vector3)
signal attack_cue(attack: String, seconds: float)
signal attack_landed(attack: String)

const TILT_DEGREES := 10.0
const PIVOT_HEIGHT := 118.0
const SWING_OUT := 1.2
const SWING_BACK := 2.8
const LENS_DROP := 10.0
const ISLAND_SINK := 2.0
const FALTER_SECONDS := 0.5
const FLIGHT_SECONDS := 3.0
const ARC_RISE := 9.0
const KNOCK_SECONDS := 1.0
const CLIMB_SECONDS := 2.0
const BOWL_DROP := 30.0
const PERCH_OFFSETS := [Vector3.ZERO, Vector3(39.0, 0.0, -67.5), Vector3(-39.0, 0.0, -67.5)]
const ROWS := {
	"pulse": {"charge": 2.0, "recovery": 0.0, "cooldown": 4.0},
	"tilt": {"charge": 2.0, "recovery": SWING_OUT + SWING_BACK, "cooldown": 0.0},
	"knock_down": {"charge": KNOCK_SECONDS, "recovery": 4.0 + CLIMB_SECONDS, "cooldown": 0.0},
}

var island_tilt_deg := 0.0
var tilt_away := Vector3.ZERO
var island_sink := 0.0
var lens_drop := 0.0
var phase := "perched"
var perch := 0
var perch_clock := 0.0
var perch_offsets: Array = PERCH_OFFSETS.duplicate()
var floor_offset := -BOWL_DROP

var _mounting := ""
var _ready := false
var _clock := 0.0
var _charging := false
var _swing_at := -1.0
var _falter := 0.0
var _falter_target := 0.0
var _base_hardpoints: Array = []
var _placed: Array = []
var _cycle := 8.0
var _phase_t := 0.0
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _target_perch := 0
var _offset := Vector3.ZERO
var _room := LENS_DROP


func mount_offset(warden, clock: float) -> Vector3:
	var delta := maxf(0.0, clock - _clock)
	_clock = clock
	if not _ready:
		_read(warden)
	match _mounting:
		"under_island":
			_offset = _island(warden, delta)
		"spires":
			_offset = _spires(warden, delta)
		_:
			_offset = Vector3.ZERO
	return _offset


func charge_allowed(_warden) -> bool:
	return _mounting != "spires" or phase == "perched"


func on_charge(_warden, seconds: float) -> void:
	_charging = true
	attack_cue.emit("pulse", seconds)
	if _mounting == "under_island":
		attack_cue.emit("tilt", seconds)


func on_pulse(warden, _lifted: bool) -> void:
	_charging = false
	attack_landed.emit("pulse")
	if _mounting != "under_island":
		return
	var out: Vector3 = warden.flat_to_ball()
	out.y = 0.0
	tilt_away = -out.normalized() if out.length() > 0.1 else Vector3.BACK
	_swing_at = _clock
	island_tilted.emit(TILT_DEGREES, tilt_away)
	attack_landed.emit("tilt")


func on_stagger(warden, open: bool) -> void:
	_charging = false
	if _mounting == "under_island":
		_falter_target = 1.0 if open else 0.0
	elif _mounting == "spires":
		if open and (phase == "flight" or phase == "climb"):
			var floor_y := maxf(floor_offset, _ground_offset(warden, _offset))
			_begin("knocked", _offset, Vector3(_offset.x, floor_y, _offset.z))
			attack_cue.emit("knock_down", KNOCK_SECONDS)
		elif not open and (phase == "knocked" or phase == "down"):
			_target_perch = _nearest_perch(_offset)
			_begin("climb", _offset, perch_offsets[_target_perch])


func _read(warden) -> void:
	_ready = true
	_mounting = String(warden.mounting)
	_cycle = float(warden.ADAPT_CYCLE)
	var spec: Dictionary = warden.spec if warden.spec is Dictionary else {}
	var path = spec.get("path", [])
	var first = null
	if path is Array and path.size() >= 2:
		var points: Array = []
		for entry in path:
			var point = _point(entry)
			if point == null:
				points.clear()
				break
			points.append(point)
		if points.size() >= 2:
			first = points[0]
			perch_offsets = points.map(func(p): return p - points[0])
	var bowl = spec.get("bowl_floor")
	if bowl is int or bowl is float:
		floor_offset = float(bowl) - (first.y if first is Vector3 else float(warden.home.y))
	_room = maxf(0.0, -_ground_offset(warden, Vector3.ZERO))


func _ground_offset(warden, offset: Vector3) -> float:
	var at: Vector3 = warden.home + offset
	if warden.terrain == null or not warden.terrain.has_method("height"):
		return -INF
	return float(warden.terrain.height(at.x, at.z)) + float(warden.HALF_HEIGHT) - float(warden.home.y)


static func _point(entry):
	if entry is Vector3:
		return entry
	if entry is Array and entry.size() == 3:
		for n in entry:
			if not (n is int or n is float):
				return null
		return Vector3(float(entry[0]), float(entry[1]), float(entry[2]))
	return null


func _island(warden, delta: float) -> Vector3:
	island_tilt_deg = _tilt()
	var angle := deg_to_rad(island_tilt_deg)
	var swing := tilt_away * PIVOT_HEIGHT * sin(angle) + Vector3.UP * PIVOT_HEIGHT * (1.0 - cos(angle))
	_falter = move_toward(_falter, _falter_target, delta / FALTER_SECONDS)
	var eased := smoothstep(0.0, 1.0, _falter)
	lens_drop = minf(LENS_DROP, _room) * eased
	island_sink = minf(ISLAND_SINK, _room) * eased
	_knuckles(warden, lens_drop - island_sink)
	return swing + Vector3.DOWN * lens_drop


func _tilt() -> float:
	if _swing_at < 0.0:
		return 0.0
	var t := _clock - _swing_at
	if t < SWING_OUT:
		return TILT_DEGREES * sin(PI * 0.5 * t / SWING_OUT)
	if t < SWING_OUT + SWING_BACK:
		return TILT_DEGREES * 0.5 * (1.0 + cos(PI * (t - SWING_OUT) / SWING_BACK))
	_swing_at = -1.0
	return 0.0


func _knuckles(warden, lift: float) -> void:
	if warden.hardpoints != _placed:
		_base_hardpoints = warden.hardpoints.duplicate()
	if _base_hardpoints.is_empty():
		return
	var placed: Array = []
	for point in _base_hardpoints:
		placed.append((point as Vector3) + Vector3.UP * lift)
	warden.hardpoints = placed
	_placed = placed


func _spires(warden, delta: float) -> Vector3:
	var staggered: bool = warden.staggered()
	if not staggered and (phase == "perched" or phase == "flight"):
		perch_clock += delta
	match phase:
		"perched":
			if perch_clock >= _cycle and not _charging and not staggered:
				var to := (perch + 1) % perch_offsets.size()
				took_off.emit(perch, to)
				_target_perch = to
				perch_clock = 0.0
				_begin("flight", perch_offsets[perch], perch_offsets[to])
			return perch_offsets[perch]
		"flight":
			_phase_t += delta
			var s := clampf(_phase_t / FLIGHT_SECONDS, 0.0, 1.0)
			if s >= 1.0:
				return _land()
			return _from.lerp(_to, smoothstep(0.0, 1.0, s)) + Vector3.UP * ARC_RISE * 4.0 * s * (1.0 - s)
		"knocked":
			_phase_t += delta
			var s := clampf(_phase_t / KNOCK_SECONDS, 0.0, 1.0)
			if s >= 1.0:
				phase = "down"
				knocked_down.emit(warden.home + _to)
				attack_landed.emit("knock_down")
				return _to
			return _from.lerp(_to, s * s)
		"down":
			return _to
		"climb":
			_phase_t += delta
			var s := clampf(_phase_t / CLIMB_SECONDS, 0.0, 1.0)
			if s >= 1.0:
				perch_clock = 0.0
				return _land()
			return _from.lerp(_to, smoothstep(0.0, 1.0, s))
	return _offset


func _begin(next: String, from: Vector3, to: Vector3) -> void:
	phase = next
	_phase_t = 0.0
	_from = from
	_to = to


func _land() -> Vector3:
	phase = "perched"
	perch = _target_perch
	landed.emit(perch)
	return perch_offsets[perch]


func _nearest_perch(offset: Vector3) -> int:
	var best := 0
	for i in perch_offsets.size():
		if _flat(offset - perch_offsets[i]).length() < _flat(offset - perch_offsets[best]).length():
			best = i
	return best


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func flying() -> bool:
	return phase != "perched"
