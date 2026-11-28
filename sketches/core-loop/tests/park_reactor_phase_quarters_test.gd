# smoke: solo timeout=60s
extends SceneTree
const Reactor = preload("res://src/combat/warden_reactor.gd")
const BossPosture = preload("res://src/core/boss_posture.gd")
const T = preload("res://tests/support/t.gd")
var t = T.new("park_reactor_phase_quarters_test")

# The dam Warden's sheet ram breaks all four chunks in one hit, so its fight phases read the bar's
# quarters (warden_reactor.gd phase_chunks_left; red team w19 watch 3: powerhouse_boiler, trigger
# chunk_2, was announced in 0 of 45 dam runs because chunk_2 landed on the break's frame). A Warden
# on the generic rule keeps reading its real chunks.

class Stub extends RefCounted:
	var _posture
	var mount_driver = Reactor.new()
	func chunks_left() -> int: return _posture.chunks

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var dam := Stub.new()
	dam._posture = Reactor.DamPosture.new({})
	dam._posture.mounted_warden = weakref(dam)
	var rows := [[0.0, 4], [24.9, 4], [25.0, 3], [49.9, 3], [50.0, 2], [66.7, 2], [75.0, 1], [99.0, 1]]
	for row in rows:
		dam._posture.posture = row[0]
		t.eq("dam bar at %.1f reads %d chunks left" % [row[0], row[1]], dam.mount_driver.phase_chunks_left(dam), row[1])
	dam._posture.posture = dam._posture.FULL
	t.eq("a full bar that has not broken reads 1 chunk left", dam.mount_driver.phase_chunks_left(dam), 1)
	dam._posture.posture = 0.0
	dam._posture.chunks = 0
	t.eq("the break reads 0 chunks left, whatever the bar", dam.mount_driver.phase_chunks_left(dam), 0)
	# A grown ball's sheet rams pay a third of the bar each (MOUNTED_POSTURE sheet_ram_breaks 3), so the
	# second ram crosses half and pulses chunk_2 before the third breaks it.
	dam._posture.chunks = BossPosture.CHUNKS
	dam._posture.posture = 2.0 * BossPosture.FULL / float(Reactor.MOUNTED_POSTURE["sheet_ram_breaks"])
	t.check("a grown ball's second sheet ram reaches chunk_2", dam.mount_driver.phase_chunks_left(dam) <= 2,
		"%d left at %.1f" % [dam.mount_driver.phase_chunks_left(dam), dam._posture.posture])
	var generic := Stub.new()
	generic._posture = BossPosture.new({})
	generic._posture.posture = 80.0
	generic._posture.chunks = 3
	t.eq("a generic-rule Warden reads its real chunks, not its bar", generic.mount_driver.phase_chunks_left(generic), 3)
	quit(t.verdict())
