extends "res://src/boss/stub_boss.gd"

const Worlds := preload("res://src/core/worlds.gd")
const Rules := preload("res://src/boss/boss_rules.gd")
const WakingFloors := preload("res://src/boss/waking_floors.gd")

# The Waking's module: the stub's posture Warden, fought floor by floor. Three floors stand
# stacked above the stub's pad, which is the pit; each shattered chunk telegraphs the highest
# live floor and drops it FLOOR_WARN seconds later, so the fight sinks a tier per phase and the
# last chunk, fought in the pit, is the win. waking_floors.gd owns the rule; this file owns
# the bodies, the drop timing and the Warden's seat.
const BOSS_ID := "waking"
# Floor k carries FLOOR_NAMES[k - 1], top down. Phases are capped at Rules.PHASE_NAMES.size().
const FLOOR_NAMES := ["Spoil", "Seam", "Bedrock"]
# Seconds between a floor's telegraph and its drop.
const FLOOR_WARN := 1.0

var floors: WakingFloors
# Floor number to its body, while the body stands.
var _floor_bodies := {}
var _center := Vector3.ZERO
# Floors queued to drop, highest first, and the one being telegraphed now.
var _drops: Array[int] = []
var _queued := 0
var _dropping := 0
var _drop_left := 0.0


func setup(ctx_ref) -> void:
	super(ctx_ref)
	name = "WakingBoss"


func enter_arena(entry_velocity: Vector3) -> void:
	super(entry_velocity)
	_center = pad.global_position + Vector3.UP * PAD_THICK * 0.5
	floors = WakingFloors.new(FLOOR_NAMES.slice(0, Rules.PHASE_NAMES.size()))
	for k in range(1, floors.floor_count() + 1):
		_floor_bodies[k] = _build_floor(k)
	_place_ball(_center + Vector3.UP * floors.floor_height(1), entry_velocity)
	_seat_warden()


func exit_arena() -> void:
	for body in _floor_bodies.values():
		_free_body(body)
	_floor_bodies.clear()
	_drops.clear()
	_queued = 0
	_dropping = 0
	_drop_left = 0.0
	super()


func _physics_process(delta: float) -> void:
	super(delta)
	if not active() or not is_instance_valid(warden) or floors == null:
		return
	floors.on_posture(warden.chunks_left())
	while _queued < mini(floors.shattered, floors.floor_count()):
		_queued += 1
		_drops.append(_queued)
	if _dropping == 0 and not _drops.is_empty():
		_dropping = _drops.pop_front()
		_drop_left = FLOOR_WARN
		ctx.events.boss_attack_telegraphed.emit(floors.floor_id(_dropping), FLOOR_WARN)
	if _dropping != 0:
		_drop_left -= delta
		if _drop_left <= 0.0:
			_free_body(_floor_bodies.get(_dropping))
			_floor_bodies.erase(_dropping)
			_dropping = 0
			_seat_warden()


func _build_floor(k: int) -> StaticBody3D:
	var saved := pad
	_build_pad(_center + Vector3.UP * floors.floor_height(k))
	var body := pad
	pad = saved
	body.name = "WakingFloor%d" % k
	return body


func _free_body(body) -> void:
	if is_instance_valid(body):
		body.collision_layer = 0
		body.queue_free()


func _seat_warden() -> void:
	if is_instance_valid(warden):
		var at: Vector3 = warden.global_position
		warden.global_position = Vector3(at.x, ground_height_at(at) + Warden.HALF_HEIGHT, at.z)


# The highest standing floor's top, else the pit's. floor_y and rescue_point follow it.
func _top() -> float:
	if not is_instance_valid(pad):
		return -INF
	for k in range(1, floors.floor_count() + 1 if floors != null else 1):
		if _floor_bodies.has(k):
			return _center.y + floors.floor_height(k)
	return super()


func ground_height_at(point: Vector3) -> float:
	if is_instance_valid(pad) and Vector2(point.x - _center.x, point.z - _center.z).length() > PAD_RADIUS:
		return super._top()
	return super(point)


func _row() -> Dictionary:
	return Worlds.BOSSES[BOSS_ID]


func music_state() -> Dictionary:
	var state := super()
	if not state.is_empty():
		state["id"] = String(_row().get("music", BOSS_ID))
		state["phase"] = clampi(floors.shattered + 1, 1, Rules.PHASE_NAMES.size())
	return state


func objective_text() -> String:
	if state == FIGHT and floors != null:
		return "%s, %s" % [String(_row().get("name", "The Waking")), floors.objective()]
	return super()
