extends Node

const ScrapField := preload("res://src/build/scrap_field.gd")
const RewardGates := preload("res://src/build/reward_gates.gd")
const Parts := preload("res://src/build/parts.gd")

# Writer B's module: parts, synergies, fabricators, reward gates, scrap and the element
# x material table. This is the spine's minimal stub. Scrap pickup counts through the
# run, kills drop scrap, and a charged beacon opens two roll-through gates that grant a
# placeholder stat part. B replaces this folder wholesale; see CONTRACTS.md.

const GATE_CHOICES := 2

var ctx
var scrap
var gates


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	name = "Build"
	scrap = ScrapField.new()
	scrap.name = "Scrap"
	ctx.root.add_child(scrap)
	scrap.setup()
	gates = RewardGates.new()
	gates.name = "RewardGates"
	ctx.root.add_child(gates)
	gates.setup(ctx.terrain)
	gates.chosen.connect(_on_gate_chosen)
	ctx.events.stage_entered.connect(_on_stage_entered)
	ctx.events.enemy_killed.connect(_on_enemy_killed)
	ctx.events.beacon_charge_changed.connect(_on_beacon_charge)
	ctx.events.part_gained.connect(func(_id: String, _source: String): Parts.apply_all(ctx.tuning, ctx.run.parts))


func _on_stage_entered(stage: int, _retry: bool) -> void:
	gates.close()
	scrap.lay_out(ctx.terrain, ctx.terrain.scrap_lines(stage), ctx.flow.stage_def()["scrap_density"], ctx.rng)
	Parts.apply_all(ctx.tuning, ctx.run.parts)


func _on_enemy_killed(_kind: String, at: Vector3, scrap_value: int) -> void:
	scrap.drop(at, scrap_value, ctx.rng)


func _on_beacon_charge(fraction: float) -> void:
	if fraction < 1.0 or gates.is_open():
		return
	var pool: Array = Parts.ids()
	var picks: Array = []
	while picks.size() < GATE_CHOICES and not pool.is_empty():
		picks.append(pool.pop_at(ctx.rng.randi_range(0, pool.size() - 1)))
	ctx.events.reward_offered.emit(gates.open(picks, ctx.player.ball_position(), _heading()))


func _on_gate_chosen(part_id: String) -> void:
	ctx.run.add_part(part_id, "gate")
	ctx.events.reward_chosen.emit(part_id)


# The ball's own line when it is moving, else where the camera looks.
func _heading() -> Vector3:
	var flat: Vector3 = ctx.player.planar_velocity()
	if flat.length() > 3.0:
		return flat.normalized()
	return -ctx.camera.yaw_basis().z


func _physics_process(delta: float) -> void:
	if ctx == null or not ctx.flow.in_play():
		return
	var ball: Vector3 = ctx.player.ball_position()
	for at in scrap.step(ball, delta):
		ctx.run.add_scrap(1, at)
	if gates.step(ball, _heading()):
		ctx.events.reward_offered.emit(gates.offers)
