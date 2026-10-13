# smoke: solo timeout=90s
extends SceneTree
const SheetTest = preload("res://tests/park_reactor_sheet_test.gd")
const Reactor = preload("res://src/combat/warden_reactor.gd")
const Tuning = preload("res://src/movement/tuning.gd")
const T = preload("res://tests/support/t.gd")
var t = T.new("park_reactor_return_test")
func _initialize() -> void:
	var mount = SheetTest.Mount.new()
	mount.target.tuning = Tuning.new()
	var sheet = Reactor.new()
	sheet.sheet_left = Reactor.SHEET_SECONDS
	sheet.sheet_dir = Vector3.FORWARD
	var gravity: float = mount.target.tuning.f("gravity")
	for along in [Reactor.SHEET_TOP, Reactor.SHEET_TOP * 0.5]:
		mount.target.at = mount.home + sheet.sheet_dir * along
		mount.target.at.y = Tuning.RADIUS
		mount.target.rigid.linear_velocity = -sheet.sheet_dir * mount.target.tuning.f("cruise")
		sheet.riding = false
		var rise: float = mount.family_point_at().y - mount.target.at.y
		var maximum_lift := sqrt(2.0 * gravity * rise)
		sheet._ride(mount, 1.0 / Engine.physics_ticks_per_second)
		var velocity: Vector3 = mount.target.rigid.linear_velocity
		t.check("late reacquisition cannot launch above core from " + str(along), velocity.y > 0.0 and velocity.y <= maximum_lift + 0.0001, "got %s, ballistic bound %s" % [velocity.y, maximum_lift])
		t.near("late reacquisition preserves entry speed from " + str(along), Vector2(velocity.x, velocity.z).length(), mount.target.tuning.f("cruise"))
	mount.target.at = mount.home + sheet.sheet_dir * Reactor.SHEET_TOP
	mount.target.at.y = Tuning.RADIUS
	var jump: float = sqrt(2.0 * gravity * (mount.family_point_at().y - Tuning.RADIUS)) + mount.target.tuning.f("jump_speed")
	mount.target.rigid.linear_velocity = -sheet.sheet_dir * mount.target.tuning.f("cruise") + Vector3.UP * jump
	sheet._ride(mount, 1.0 / Engine.physics_ticks_per_second)
	t.near("lift bound never brakes an existing upward jump", mount.target.rigid.linear_velocity.y, jump)
	mount.free()
	quit(t.verdict())
