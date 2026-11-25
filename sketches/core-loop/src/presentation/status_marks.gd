extends Node

const EventKinds := preload("res://src/core/event_kinds.gd")
const PlayerFx := preload("res://src/presentation/player_fx.gd")


const SHOWN_SECONDS := 0.5
const COOLDOWN_SECONDS := 1.0
const MARK_HEIGHT := 2.4
const SIZE_FROM := 0.5
const SIZE_TO := 1.0

var ctx
var vfx
var drawn := 0

var _clock := 0.0
var _last := {}
var _wound := {}


func setup(ctx_ref, vfx_ref) -> void:
	ctx = ctx_ref
	vfx = vfx_ref
	name = "StatusMarks"
	add_to_group(PlayerFx.MARKS_GROUP)
	if ctx.events.has_signal("enemy_spawned") and not ctx.events.is_connected("enemy_spawned", _on_spawned):
		ctx.events.connect("enemy_spawned", _on_spawned)


func _physics_process(delta: float) -> void:
	_clock += delta


func marked(enemy: Node3D) -> bool:
	var id := enemy.get_instance_id()
	return _last.has(id) and _clock - float(_last[id]) < SHOWN_SECONDS


func _on_spawned(enemy: Node3D, _kind: String) -> void:
	if enemy.has_signal("attack_phase"):
		enemy.attack_phase.connect(_on_phase.bind(enemy))
	enemy.tree_exiting.connect(_forget.bind(enemy.get_instance_id()))


func _forget(id: int) -> void:
	_last.erase(id)
	_wound.erase(id)


func _on_phase(facts: Dictionary, enemy: Node3D) -> void:
	var phase: String = facts.get("phase", "")
	if phase == "windup" and is_instance_valid(enemy):
		_wound[enemy.get_instance_id()] = int(enemy.knocks)
		return
	if phase != "cancelled":
		return
	if not is_instance_valid(enemy) or not enemy.is_inside_tree() or enemy.is_dead() or enemy.is_queued_for_deletion():
		return
	var id := enemy.get_instance_id()
	if not _wound.has(id) or int(enemy.knocks) <= int(_wound[id]):
		return
	_wound.erase(id)
	if _last.has(id) and _clock - float(_last[id]) < COOLDOWN_SECONDS:
		return
	_last[id] = _clock
	var row := EventKinds.state_row("interrupted")
	var slot: Dictionary = vfx.glyph("interrupted", enemy.global_position + Vector3.UP * MARK_HEIGHT, SIZE_FROM, SIZE_TO, SHOWN_SECONDS,
		Vector3.ZERO, String(row["shape"]), EventKinds.state_color("interrupted"))
	if not slot.is_empty():
		drawn += 1
