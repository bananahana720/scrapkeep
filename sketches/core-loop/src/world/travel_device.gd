extends "res://src/world/device.gd"


var banked := 0.0
var on_fire := Callable()
var ready_check := Callable()
var destination := "the shelf"
var _lane: Node3D


func _init() -> void:
	family = "travel"


func setup_travel(ctx_ref, system_ref, device_id: String, roll_ref, fire_callable: Callable) -> void:
	roll = roll_ref
	on_fire = fire_callable
	setup(ctx_ref, system_ref, {"id": device_id})


func build() -> void:
	_lane = Node3D.new()
	add_child(_lane)
	var mat := Palette.solid(Interactables.color(family), 1.2)
	var heading: Vector3 = roll.heading
	var side := Vector3(-heading.z, 0.0, heading.x)
	for k in 6:
		var back: float = -roll.length + 1.0 + k * 2.0
		for s in [-1.0, 1.0]:
			var at: Vector3 = heading * back + side * s * roll.half_width
			var dash := box(Vector3(0.3, 0.08, 1.2), at + Vector3.UP * (ground_y(at) + 0.05), mat, false, _lane)
			dash.rotation.y = atan2(heading.x, heading.z)
	var bar := box(Vector3(roll.mouth_radius * 2.0, 0.1, 0.4), Vector3.UP * 0.06, mat, false, _lane)
	bar.rotation.y = atan2(heading.x, heading.z)


func reach_point() -> Vector3:
	return roll.mouth + Vector3.UP


func ready_now() -> bool:
	return not spent and (not ready_check.is_valid() or ready_check.call())


func terms() -> String:
	return "to " + destination


func fire() -> bool:
	var v: Vector3 = ctx.player.state.velocity
	banked = Vector2(v.x, v.z).length()
	if on_fire.is_valid():
		on_fire.call(ctx.player.ball_position(), v)
	return true
