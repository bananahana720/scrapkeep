extends SceneTree

const PlayerBall := preload("res://src/movement/player_ball.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const SpeedTier := preload("res://src/core/speed_tier.gd")
const T := preload("res://tests/support/t.gd")

# The physics server may report simultaneous overlaps in any order. Record the
# seeded payouts at the crush boundary while keeping the real bow and its overlap set.
class Recorder extends PlayerBall:
	var payouts := {}
	var order: Array[String] = []
	var rng := RandomNumberGenerator.new()
	func _try_crush(body: Node3D) -> void:
		if not body.is_in_group("enemy") or payouts.has(String(body.name)):
			return
		order.append(String(body.name))
		payouts[String(body.name)] = rng.randi()
	func reset_record() -> void:
		payouts.clear()
		order.clear()
		rng.seed = 11

var t := T.new("crush_order_repeat_test")
var player: Recorder
var bodies: Array[StaticBody3D] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var events := GameEvents.new()
	root.add_child(events)
	player = Recorder.new()
	root.add_child(player)
	player.setup(Tuning.new(), events, Vector3.ZERO)
	player.set_physics_process(false)
	player.body().freeze = true
	player.body().collision_mask = 1
	for i in 3:
		var body := StaticBody3D.new()
		body.name = "Enemy%d" % i
		body.collision_layer = 4
		body.collision_mask = 0
		body.add_to_group("enemy")
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.3
		shape.shape = sphere
		body.add_child(shape)
		root.add_child(body)
		body.position = Vector3(i * 0.4 - 0.4, 0.0, 0.0)
		bodies.append(body)
	for i in 4:
		await physics_frame
	await process_frame
	t.check("real bow overlaps all three enemies", player._bow.get_overlapping_bodies().size() == 3)
	player.state.tier = SpeedTier.CRUISE
	var baseline := {}
	for arrival in [[0, 1, 2], [2, 1, 0], [1, 2, 0]]:
		player.reset_record()
		for index in arrival:
			player._on_bow_entered(bodies[index])
		await process_frame
		await process_frame
		t.check("each enemy resolved once %s" % [arrival], player.order.size() == 3)
		if baseline.is_empty():
			baseline = player.payouts.duplicate()
		t.check("seeded payouts repeat for arrivals %s" % [arrival], player.payouts == baseline,
			"order %s, payouts %s, baseline %s" % [player.order, player.payouts, baseline])
		player.reset_record()
		player._recheck_bow()
		t.check("physics sweep uses the same payout order", player.payouts == baseline)
	quit(t.verdict())
