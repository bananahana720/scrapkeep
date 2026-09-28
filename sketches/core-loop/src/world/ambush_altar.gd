extends "res://src/world/device.gd"

# An ambush altar, the opt-in fight family (LOOP-REDESIGN section 9): a copper post
# with a HAZARD-striped cap in a HAZARD ring on the ground. Hold E and a pack arrives
# now, round the ring; clear it inside SECONDS and it pays a bonus core. While it runs
# the prompt's gauge is the time left; once it is done, it is spent for the stage.
# Nothing here stops the ball: the post has no collider and the pack comes to you.

const SECONDS := 30.0
const RING := 10.0
const PACK := ["chaser", "chaser", "lobber"]

var running := false
var won := false
var pack: Array = []
var left := 0.0
var _ring: Node3D
var _cap: Node3D


func _init() -> void:
	family = "fight"


func build() -> void:
	var copper := Palette.solid(Palette.COPPER)
	cylinder(0.45, 3.2, Vector3.UP * 1.6, copper)
	_cap = box(Vector3(1.4, 0.6, 1.4), Vector3.UP * 3.5, Palette.striped(Palette.HAZARD, Palette.CHARCOAL))
	_ring = ground_ring(RING, Interactables.color(family))


func reach_point() -> Vector3:
	return global_position + Vector3.UP * 1.6


func ready_now() -> bool:
	return not spent and not running and ctx.spawner != null and ctx.spawner.has_method("spawn_enemy") and not ctx.calm


func gauge() -> float:
	return left / SECONDS if running else -1.0


func terms() -> String:
	return "core in %d s" % int(SECONDS)


func fire() -> bool:
	pack.clear()
	for i in PACK.size():
		var a := TAU * float(i) / PACK.size() + rotation.y
		var spot := global_position + Vector3(cos(a), 0.0, sin(a)) * RING
		var enemy = ctx.spawner.spawn_enemy(PACK[i], ctx.terrain.drop_point(spot.x, spot.z, 2.4))
		if enemy != null:
			pack.append(enemy)
	running = true
	left = SECONDS
	return true


func alive() -> int:
	var n := 0
	for enemy in pack:
		if is_instance_valid(enemy) and not (enemy.has_method("is_dead") and enemy.is_dead()):
			n += 1
	return n


func tick(delta: float) -> void:
	_cap.rotation.y += delta * (4.0 if running else 0.6)
	if not running:
		return
	left = maxf(0.0, left - delta)
	if alive() == 0:
		_end(true)
	elif left <= 0.0:
		_end(false)


func _end(cleared: bool) -> void:
	running = false
	spent = true
	won = cleared
	_ring.visible = false
	if cleared:
		ctx.run.add_core("ambush", reach_point())
	ctx.events.ambush_ended.emit(id, cleared, reach_point())
