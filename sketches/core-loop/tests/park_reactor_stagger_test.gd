# smoke: solo timeout=60s
extends SceneTree
const Reactor = preload("res://src/combat/warden_reactor.gd")
const Run = preload("res://src/core/run_state.gd")
const T = preload("res://tests/support/t.gd")
var t = T.new("park_reactor_stagger_test")

# The dam Warden breaks only to a sheet ram (owner ruling; unit BS1). A non-sheet hit that fills
# the posture bar opens a stagger and shatters nothing, with the sheet dry or live; the positive
# control is a sheet ram from the same bar, which shatters.
const PLATING := 40.0
const START := 90.0

class Body extends RefCounted:
	var touching: Array = []
	func get_colliding_bodies() -> Array: return touching
class Ball extends RefCounted:
	var rigid := Body.new()
	var heft_of: Callable
	func _init() -> void: heft_of = Callable(self, "heft")
	func heft() -> float: return Run.HEFT_CLASS_AT[2]
	func body(): return rigid
class Mount extends RefCounted:
	var mount_driver = Reactor.new()
	var target := Ball.new()
	func family_point() -> String: return "core"

func _initialize() -> void: _run.call_deferred()

func _posture(mount: Mount):
	var posture = Reactor.DamPosture.new({})
	posture.mounted_warden = weakref(mount)
	posture.posture = START
	return posture

func _hit(kind: String, frame: int) -> Dictionary:
	return {"kind": kind, "punch": PLATING * 1.5, "plating": PLATING, "smash": false, "tier": 1, "charging": false,
		"frame": frame, "hp": 400.0, "max_hp": 400.0, "point": "core"}

func _run() -> void:
	_checks()
	quit(t.verdict())

func _checks() -> void:
	var cases := [["ram, sheet dry", "ram", false, false], ["stomp, sheet dry", "stomp", false, false],
		["ram, sheet live but not entered this cycle", "ram", true, false], ["weapon hit, sheet dry", "shot", false, false]]
	for row in cases:
		var mount := Mount.new()
		var driver = mount.mount_driver
		driver.gates_opened = 3
		driver.sheet_left = Reactor.SHEET_SECONDS if row[2] else 0.0
		driver.entered_sheet_cycle = 3 if row[3] else 2
		mount.target.rigid.touching = [mount]
		var posture = _posture(mount)
		if row[1] == "shot":
			posture.posture = Reactor.DamPosture.FULL - 0.5
		var result: Dictionary = posture.judge(_hit(row[1], 10))
		posture.apply(result, 10)
		t.check("a non-sheet hit that fills the bar opens a stagger: " + row[0], posture.staggered and posture.posture >= posture.FULL,
			"staggered %s, posture %.1f, result %s" % [posture.staggered, posture.posture, result])
		t.check("and does not shatter: " + row[0], not result.get("shatter", false) and not result.get("sheet_ram", false) \
			and posture.chunks == posture.CHUNKS and posture.shatter_frame < 0 and float(result.get("dealt", 0.0)) == 0.0,
			"result %s, chunks %d, shatter frame %d" % [result, posture.chunks, posture.shatter_frame])
		mount.target.rigid.touching.clear()
	# Positive control: the same bar and a ram inside a live sheet the ball entered this cycle.
	var mount := Mount.new()
	var driver = mount.mount_driver
	driver.gates_opened = 3
	driver.sheet_left = Reactor.SHEET_SECONDS
	driver.entered_sheet_cycle = 3
	mount.target.rigid.touching = [mount]
	var posture = _posture(mount)
	posture.posture = Reactor.DamPosture.FULL - 1.0
	var result: Dictionary = posture.judge(_hit("ram", 10))
	posture.apply(result, 10)
	t.check("control: a sheet ram that fills the bar shatters", result.get("sheet_ram", false) and result.get("shatter", false) \
		and float(result.get("dealt", 0.0)) == 400.0 and posture.shatter_frame == 10 and not posture.staggered, str(result))
	mount.target.rigid.touching.clear()
