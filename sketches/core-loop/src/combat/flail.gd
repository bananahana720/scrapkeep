extends Node

const Grip := preload("res://src/movement/grip.gd")
const Groups := preload("res://src/core/groups.gd")
const PhysicsLayers := preload("res://src/core/physics_layers.gd")
const Augments := preload("res://src/movement/augments.gd")
const DamageDoor := preload("res://src/combat/damage_door.gd")
const Roster := preload("res://src/combat/roster.gd")
const ActiveBase := preload("res://src/combat/actives/active_base.gd")

const HANG := 5.0
const YANK_SPEED := 16.0
const HITS := 3
const SELF_COST := 0.25
const THROW_OPEN := 1.25
const HIT_GAP := 0.4
const HOLD_MAX := 2.5
const THROW_FLIGHT := 1.2
const TOUCH := 0.6
const BASE_DAMAGE := 18.0
const KNOCK := 14.0
const MIN_SPEED_SCALE := 0.5
const BUDGET_GROUP := "attack_budget"

var ctx
var combat
var body: Node3D = null
var flailed := 0
var thrown := 0
var strikes := 0

var _held := 0.0
var _hits := 0
var _last_hit := {}
var _linked := {}
var _layer := 0
var _flying: Array = []
var _clock := 0.0
var _budgeted := false


func setup(ctx_ref, combat_ref) -> void:
	ctx = ctx_ref
	combat = combat_ref


func holding(node: Node3D) -> bool:
	return body != null and node == body


func _physics_process(delta: float) -> void:
	if ctx == null or ctx.player == null:
		return
	_clock += delta
	var player = ctx.player
	var kit = player.kit
	if body != null and (not is_instance_valid(body) or _dead(body) or not kit.hooked or kit.anchor_body != body):
		_let_go(player)
	if body == null and _flail_line(kit) and player.intent.harpoon_held:
		_take(kit.anchor_body)
	if body != null:
		_held += delta
		_carry(delta, player)
		_swing(player)
		if _held >= HOLD_MAX or _hits >= HITS:
			player.release_grapple()
			_let_go(player)
	_fly(delta)


static func _flail_line(kit) -> bool:
	return kit.hooked and kit.on_body and kit.grip == Grip.FLAIL and kit.line_state == Augments.LINE_LATCHED \
			and is_instance_valid(kit.anchor_body)


static func _dead(node) -> bool:
	return node.has_method("is_dead") and node.is_dead()


func _take(node: Node3D) -> void:
	body = node
	flailed += 1
	_held = 0.0
	_hits = 0
	_last_hit.clear()
	if ctx.player.chain.combo == 0:
		_linked.clear()
	_flying = _flying.filter(func(f): return f["body"] != node)
	_cancel_attack(node)
	node.set_physics_process(false)
	_budgeted = node.is_in_group(BUDGET_GROUP)
	if _budgeted:
		node.remove_from_group(BUDGET_GROUP)
	if node is CollisionObject3D:
		_layer = node.collision_layer
		node.collision_layer = PhysicsLayers.NONE
	if node is CharacterBody3D:
		node.velocity = Vector3.ZERO


static func _cancel_attack(node: Node3D) -> void:
	var phase = node.get("phase")
	if phase != null and int(phase) != 0 and node.has_method("_stagger"):
		node._stagger()
	elif node.has_method("_end_attack") and node.get("state") != null and (int(node.get("state")) in [1, 2] \
			or (node.has_method("state_name") and node.state_name() == "call")):
		node._end_attack(0)
	elif node.has_method("_clear_telegraph"):
		node._clear_telegraph()


func _carry(delta: float, player) -> void:
	var ball: Vector3 = player.ball_position()
	var v: Vector3 = player.state.velocity
	var flat := Vector3(v.x, 0.0, v.z)
	var back: Vector3 = -flat.normalized() if flat.length() > 2.0 else (body.global_position - ball).normalized()
	if back.length() < 0.5:
		back = Vector3.BACK
	var goal := ball + back * HANG
	var step := maxf(YANK_SPEED, v.length() + 10.0) * delta
	body.global_position = body.global_position.move_toward(goal, step)


func _swing(player) -> void:
	var scale := maxf(MIN_SPEED_SCALE, player.state.velocity.length() / player.tuning.tier_cruise())
	for other in get_tree().get_nodes_in_group(Groups.ENEMY):
		if other == body or DamageDoor.dead(other):
			continue
		if not _touching(body, other):
			continue
		var id: int = other.get_instance_id()
		if _clock - float(_last_hit.get(id, -INF)) < HIT_GAP:
			continue
		_last_hit[id] = _clock
		_strike(other, scale)
		_hits += 1
		if not _linked.has(id) and not player.state.grounded:
			_linked[id] = true
			player.link_chain(other)
		if body.has_method("take_damage") and body.get("max_hp") != null:
			body.last_damage_source = "flail"
			body.take_damage(float(body.max_hp) * SELF_COST)
		if _dead(body):
			body = null
			return
		if _hits >= HITS:
			return


func _strike(other: Node3D, scale: float) -> void:
	var heft := Roster.heft_of(body)
	var damage := BASE_DAMAGE * (heft if heft != INF else 1.0) * scale
	strikes += 1
	combat.flail_hit(other, damage, body.global_position, KNOCK * scale)


static func _touching(a: Node3D, b: Node3D) -> bool:
	var reach := ActiveBase.enemy_girth(a, 1.0) + ActiveBase.enemy_girth(b, 1.0) + TOUCH
	return a.global_position.distance_to(b.global_position) <= reach


func _let_go(player) -> void:
	var node := body
	body = null
	if node == null or not is_instance_valid(node):
		return
	node.set_physics_process(true)
	if _dead(node):
		return
	if node is CollisionObject3D:
		node.collision_layer = _layer
	if _budgeted:
		node.add_to_group(BUDGET_GROUP)
	var v: Vector3 = player.state.velocity
	if node.has_method("knock") and v.length() > 0.5:
		var w = node.get("weight")
		node.knock(v, v.length() * (float(w) if w != null else 1.0))
	if node.get("stun_left") != null:
		node.stun_left = maxf(float(node.stun_left), THROW_OPEN)
	if node.get("_rest") != null:
		node._rest = maxf(float(node._rest), THROW_OPEN)
	thrown += 1
	if v.length() <= 0.5:
		return
	_flying.append({"body": node, "left": THROW_FLIGHT, "hit": {}, "scale": maxf(MIN_SPEED_SCALE, v.length() / player.tuning.tier_cruise())})


func _fly(delta: float) -> void:
	var keep: Array = []
	for f in _flying:
		var node = f["body"]
		f["left"] -= delta
		if f["left"] <= 0.0 or DamageDoor.dead(node):
			continue
		for other in get_tree().get_nodes_in_group(Groups.ENEMY):
			if other == node or other == body or not is_instance_valid(other) or f["hit"].has(other.get_instance_id()):
				continue
			if other.has_method("is_dead") and other.is_dead():
				continue
			if _touching(node, other):
				f["hit"][other.get_instance_id()] = true
				var heft := Roster.heft_of(node)
				strikes += 1
				combat.flail_hit(other, BASE_DAMAGE * (heft if heft != INF else 1.0) * float(f["scale"]), node.global_position, KNOCK)
		keep.append(f)
	_flying = keep
