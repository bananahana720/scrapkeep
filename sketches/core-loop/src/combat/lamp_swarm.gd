extends "res://src/combat/counter.gd"

const SpeedTier := preload("res://src/movement/speed_tier.gd")

# The lamp swarm (DESIGN-V2 section 10, World 2): one crew rig carrying a formation of
# three lure lamps. Warn blooms a WAVE ring. While the bloom is live, a ball inside it
# that is under cruise speed is steered toward the lamps by a damage-free shove; a ball
# at cruise or faster is not touched, so boosting straight through is the counter. A ram
# at cruise or faster scatters the lamps and ends the attack; a slower ram does not.
# The lure never deals damage and never holds: hit_player(0.0, shove) only bends the line.

const HP := 35.0
const LAMP_COUNT := 3
const LAMP_RING := 1.3
const LAMP_HEIGHT := 1.6
const LAMP_RADIUS := 0.3
const BLOOM_RADIUS := 9.0
const BLOOM_SPEED := 6.0
const BLOOM_REACH := 3.0
const LURE := 6.0
const SCATTER_SPEED := 7.0

var lamps: Array = []
var blooms := 0
var lured_ticks := 0
var scatters := 0
var _flung := false
var _fling: Array = []


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = 4
	weight = 1.0
	warn_seconds = 0.9
	live_seconds = 3.0
	rest_seconds = 3.5
	attack_range = 20.0
	keep_near = 10.0


func _build_tool() -> void:
	for i in LAMP_COUNT:
		var lamp := SphereMesh.new()
		lamp.radius = LAMP_RADIUS
		lamp.height = LAMP_RADIUS * 2.0
		lamps.append(_accent(lamp, Palette.HAZARD, 2.0, _lamp_rest(i)))
	_fling.resize(LAMP_COUNT)
	_fling.fill(Vector3.ZERO)


func _lamp_rest(index: int) -> Vector3:
	var angle := TAU * float(index) / float(LAMP_COUNT)
	return Vector3(cos(angle) * LAMP_RING, LAMP_HEIGHT, sin(angle) * LAMP_RING)


func _commit(_to_ball: Vector3) -> Node3D:
	_clear_telegraph()
	_telegraph = Telegraph.wave(world_root, terrain, global_position, BLOOM_RADIUS, BLOOM_SPEED, warn_seconds, BLOOM_REACH)
	_facts_begin(_telegraph)
	return _telegraph


func _go_live() -> void:
	blooms += 1
	var tele := telegraph()
	if tele != null:
		tele.age = warn_seconds


func _live(delta: float) -> bool:
	var tele := telegraph()
	if tele == null:
		return false
	tele.step(delta)
	if tele.is_spent():
		return false
	var player = _player()
	if player == null:
		return true
	var to: Vector3 = global_position - _real_ball()
	to.y = 0.0
	if to.length() <= BLOOM_RADIUS and player.speed_tier() < SpeedTier.CRUISE:
		lured_ticks += 1
		hit_player.emit(0.0, to.normalized() * LURE * delta)
	return true


func on_struck(kind_hit: String, _part: String, _result: Dictionary) -> void:
	var player = _player()
	if kind_hit != "ram" or phase == Phase.ROAM or player == null or player.speed_tier() < SpeedTier.CRUISE:
		return
	scatters += 1
	broken_by = "scattered"
	_flung = true
	for i in lamps.size():
		var out: Vector3 = lamps[i].position
		out.y = 0.0
		_fling[i] = out.normalized() * SCATTER_SPEED + Vector3.UP * 3.0


func _pose() -> void:
	if not _flung:
		return
	var delta := get_physics_process_delta_time()
	for i in lamps.size():
		_fling[i] += Vector3.DOWN * 9.8 * delta
		lamps[i].position += _fling[i] * delta


func _on_end() -> void:
	_flung = false
	for i in lamps.size():
		lamps[i].position = _lamp_rest(i)
