extends Node3D

const Augments := preload("res://src/movement/augments.gd")
const Palette := preload("res://src/core/palette.gd")
const PhysicsLayers := preload("res://src/core/physics_layers.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const Devices := preload("res://src/core/devices.gd")
const PropMeshes := preload("res://src/presentation/craft_prop_meshes.gd")
const LIFE := Devices.ROWS[Devices.SABLE_STAKE]["lifetime"]
const CAP := Devices.SABLE_STAKE_CAP
const SENTRY_SECONDS := Devices.ROWS[Devices.SABLE_STAKE]["sentry_seconds"]
const SENTRY_REACH := 30.0

class Stake:
	extends StaticBody3D
	var left := LIFE
	var armed := false
	var serial := 0
	var device_id := 0

	func anchor_point(_hit: Vector3, _from := Vector3.ZERO) -> Vector3:
		return global_position

	func anchor_velocity() -> Vector3:
		return Vector3.ZERO

	func is_dead() -> bool:
		return armed and left <= 0.0

	func staggered() -> bool:
		return false

var ctx
var combat
var ultimate
var nodes: Array[Stake] = []
var planted := 0
var hooked := 0
var beat_log: Array = []
var sentry_log: Array = []
var _sentry_left := 0.0
var _sentry_clock := 0.0
var _sentry_beat := 0.35
var _heft := 1.0
var _body_mesh: ArrayMesh
var _ring_mesh: ArrayMesh
var _counter := 0
var note := Callable()


func setup(ctx_ref, combat_ref, ultimate_ref) -> void:
	ctx = ctx_ref
	combat = combat_ref
	ultimate = ultimate_ref
	name = "SableStakes"
	_body_mesh = _dressed(PropMeshes.sable_stake_body(), PropMeshes.salvage_wear_material(Palette.COPPER, Palette.BRASS.lightened(0.18), Palette.ARC, 0.56, 0.48, 1.35, "sable_stake", 1.2))
	_ring_mesh = _dressed(PropMeshes.sable_stake_ring(), Palette.unshaded(Palette.ARC))
	ctx.events.grapple_fired.connect(_on_hooked)
	ctx.events.stage_entered.connect(func(_stage: int, _retry: bool): fold())
	ctx.events.stage_content_cleared.connect(func(_reason: String): fold())
	ctx.events.player_died.connect(fold)
	ctx.events.run_started.connect(func(_class_id: String): fold())
	ctx.events.run_ended.connect(func(_won: bool): fold())


func fold() -> void:
	for stake in nodes.duplicate():
		_remove(stake)
	_sentry_left = 0.0
	_sentry_clock = 0.0


func begin() -> void:
	fold()
	planted = 0
	hooked = 0
	beat_log.clear()
	sentry_log.clear()


func _dressed(base: ArrayMesh, material: Material) -> ArrayMesh:
	var mesh: ArrayMesh = base.duplicate()
	mesh.surface_set_material(0, material)
	return mesh


func plant(at: Vector3) -> Stake:
	var placed: Dictionary = combat.devices.deploy(Devices.SABLE_STAKE, at)
	for id in placed["evicted"]:
		recall(int(id))
	if int(placed["id"]) == 0:
		return null
	var stake := Stake.new()
	stake.device_id = int(placed["id"])
	stake.tree_exiting.connect(func(): _forget(stake))
	_counter += 1
	stake.serial = _counter
	stake.name = "Stake%d" % _counter
	stake.collision_layer = PhysicsLayers.STAKE_MASK
	stake.collision_mask = PhysicsLayers.NONE
	stake.add_to_group(Augments.STAKE_GROUP)
	stake.add_to_group(Augments.ANCHOR_GROUP)
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.height = 0.9
	cylinder.radius = 0.3
	shape.shape = cylinder
	stake.add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.name = "PylonBody"
	mesh.mesh = _body_mesh
	stake.add_child(mesh)
	var ring := MeshInstance3D.new()
	ring.name = "EmitterCollar"
	ring.mesh = _ring_mesh
	ring.position.y = -0.38
	stake.add_child(ring)
	add_child(stake)
	stake.global_position = at
	nodes.append(stake)
	planted += 1
	ultimate.record()["stakes"] = planted
	return stake


func _forget(stake: Stake) -> void:
	combat.devices.remove(stake.device_id)
	nodes.erase(stake)


func _remove(stake: Stake) -> void:
	_forget(stake)
	stake.collision_layer = PhysicsLayers.NONE
	stake.queue_free()


func recall(device_id: int) -> void:
	for stake in nodes:
		if stake.device_id == device_id:
			_remove(stake)
			return


func arm() -> void:
	for stake in nodes:
		stake.armed = true
		stake.left = LIFE


func _on_hooked(_at: Vector3) -> void:
	var stake = ctx.player.kit.anchor_body
	if not is_instance_valid(stake) or not stake is Stake or not nodes.has(stake):
		return
	hooked += 1
	var rec: Dictionary = ultimate.record()
	rec["stakes_hooked"] = hooked
	ctx.run.set_meta("ultimate_record", rec)
	if ctx.run_log != null:
		ctx.run_log._close_ultimate()


func arc(at: Vector3, targets: int, damage: float, radius := 10.0) -> int:
	var picks: Array = combat.nearest_enemies(at, radius, targets)
	for enemy in picks:
		combat.effects.arc(at, enemy.global_position, Palette.ARC)
		combat._ult_hit(enemy, "arc", damage, at, false)
	return picks.size()


func beat(number: int, at: Vector3, heft_mult: float) -> int:
	_heft = heft_mult
	plant(at)
	var state: Dictionary = ultimate.leg_state()
	beat_log.append({"beat": number, "time": state["elapsed"], "expected": number * float(state["beat_length"])})
	_note("stake", number)
	return arc(at, ultimate.volley_targets(), 12.0 * heft_mult)


func relay() -> int:
	var hits := 0
	for i in nodes.size():
		hits += arc(nodes[i].global_position, 1, 12.0 * _heft)
		if i > 0:
			combat.effects.arc(nodes[i - 1].global_position, nodes[i].global_position, Palette.ARC)
	return hits


func start_sentries(beat_seconds: float, heft_mult: float) -> void:
	_sentry_left = SENTRY_SECONDS
	_sentry_clock = 0.0
	_sentry_beat = maxf(0.01, beat_seconds)
	_heft = heft_mult


func _physics_process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	for i in range(nodes.size() - 1, -1, -1):
		var stake := nodes[i]
		if not stake.armed:
			continue
		stake.left -= delta
		stake.scale = Vector3.ONE * (0.85 + 0.15 * clampf(stake.left / LIFE, 0.0, 1.0))
		if stake.left <= 0.0:
			_remove(stake)
	if _sentry_left <= 0.0:
		return
	_sentry_clock += minf(delta, _sentry_left)
	_sentry_left = maxf(0.0, _sentry_left - delta)
	while _sentry_clock + 0.00001 >= _sentry_beat:
		_sentry_clock -= _sentry_beat
		_sentry_volley()


func _sentry_volley() -> void:
	var picks: Array = []
	for stake in nodes:
		var target = combat._nearest(stake.global_position, SENTRY_REACH, [])
		if target != null:
			picks.append([stake.global_position.distance_to(target.global_position), stake, target])
	picks.sort_custom(func(a, b): return a[0] < b[0])
	var count := 0
	for row in picks.slice(0, ultimate.volley_targets()):
		var from: Vector3 = row[1].global_position
		var enemy: Node3D = row[2]
		var pattern: Resource = combat.pattern(Weapons.PYLON_TURRET)
		combat.bolts.fire({"origin": from, "dir": (enemy.global_position + Vector3.UP * 0.5 - from).normalized(),
			"speed": pattern.speed, "max_dist": SENTRY_REACH, "damage": 11.0 * _heft, "kind": "turret",
			"weapon_id": Weapons.PYLON_TURRET, "radius": pattern.bolt_radius, "knock": pattern.knock,
			"chain_jumps": 2, "chain_range": pattern.chain_range, "chain_falloff": pattern.chain_falloff,
			"color": Palette.ARC, "wave_amp": 0.0, "wave_hz": 0.0, "phase": 0.0, "source": "persistent_actor"})
		count += 1
	sentry_log.append(count)
	_note("sentry", sentry_log.size())


func _note(kind: String, number: int) -> void:
	if note.is_valid():
		note.call(kind, number)
