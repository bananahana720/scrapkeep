extends Node3D

const Director := preload("res://src/world/event_director.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const Schema := preload("res://src/world/park/park_schema.gd")
const Rows := preload("res://src/core/event_kinds.gd")
const ActivityView := preload("res://src/world/activity_view.gd")
const FOG_ALPHA := 0.14

class Map extends RefCounted:
	var park := {}

var director
var committed := {}
var active := false
var announced := false
var damage_per_s := 0.0
var _seed := 0
var _centre := Vector3.ZERO
var _size := Vector3.ZERO
var _safe_radius := 0.0
var _visual: MeshInstance3D
var _material: ShaderMaterial
var _safe_view: Node3D
var facts: Array = []


func setup(at: Vector3, size: Vector3, safe_radius: float, damage: float, seed_value: int) -> void:
	_centre = at
	_size = size
	_safe_radius = safe_radius
	damage_per_s = damage
	_seed = seed_value
	_visual = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = _size
	_visual.mesh = box
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec2 safe_at;
uniform float safe_radius;
uniform vec4 tint : source_color;
varying vec3 world_at;
void vertex() { world_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
  ALBEDO = tint.rgb;
  ALPHA = length(world_at.xz - safe_at) > safe_radius ? tint.a : 0.0;
}
"""
	_material = ShaderMaterial.new()
	_material.shader = shader
	_visual.material_override = _material
	add_child(_visual)
	_visual.global_position = _centre + Vector3.UP * _size.y * 0.5
	_visual.visible = false


func begin(round_number: int) -> void:
	stop()
	var safe := _centre + Vector3((round_number - 2) * _safe_radius, 0, 0)
	committed = {"site": {"at": [_centre.x, _centre.z], "size": [_size.z, _size.y, _size.x], "yaw_deg": 0.0},
		"safe_at": safe, "safe_radius": _safe_radius, "floor_y": _centre.y, "height": _size.y}
	var map := Map.new()
	map.park = {"map": "pocket", "park_rows": [committed.site.merged({"id": "fog", "y": _centre.y})],
		"event_rows": [event_row()], "weather_rows": [],
		"routes": [{"id": "main", "from": "drop_in", "to": "landmark", "via": []}]}
	director = Director.new(_seed + round_number, {}, map, 0.0, func(_x, _z): return _centre.y)
	director.register_family("natural", _event)
	_material.set_shader_parameter("safe_at", Vector2(safe.x, safe.z))
	_material.set_shader_parameter("safe_radius", committed.safe_radius)
	_safe_view = ActivityView._ring(committed.safe_radius, Rows.color("event_ended"))
	add_child(_safe_view)
	_safe_view.global_position = safe
	_safe_view.visible = false


func event_row() -> Dictionary:
	return {"id": "pocket_veil", "kind": "lightning", "family": "natural", "site": "fog",
		"trigger": {"on": "clock_tier", "value": 1}, "weight": 1.0,
		"telegraph": {"lead_s": Schema.LEAD_HAZARD_S, "form": "lightning_charge", "on_bar": false},
		"live_s": 0.0, "effect": {"fog": committed.duplicate(true)},
		"route_change": {"closes": [], "opens": []}, "hold_clear_m": 0.0,
		"cooldown_s": 0.0, "once": true,
		"music_cue": {"telegraph": "riser_natural", "land": "drop_natural"}}


func _event(action: String, row: Dictionary, _context: Dictionary) -> void:
	match action:
		"telegraph":
			committed = row.effect.fog
			announced = true
			_safe_view.visible = true
		"land":
			active = true
			var tint: Color = Rows.world_row("lightning_landed").color
			tint.a = FOG_ALPHA
			_material.set_shader_parameter("tint", tint)
			_visual.visible = true
		"end":
			active = false
			_visual.visible = false


func advance(delta: float, ball: Vector3) -> Array:
	if director == null:
		return []
	var result: Array = director.advance(delta, ball, Vector3.ZERO, {"clock_tier": 1})
	facts.append_array(result)
	return result


func damage_at(ball: Vector3) -> float:
	if not active or committed.is_empty():
		return 0.0
	if ball.y < float(committed.floor_y) or ball.y > float(committed.floor_y) + float(committed.height):
		return 0.0
	var flat := Vector2(ball.x, ball.z)
	if not ParkMap.footprint_contains(committed.site, flat):
		return 0.0
	var safe: Vector3 = committed.safe_at
	if flat.distance_to(Vector2(safe.x, safe.z)) <= float(committed.safe_radius):
		return 0.0
	return damage_per_s


func stop() -> void:
	if director != null:
		facts.append_array(director.end_all())
	director = null
	active = false
	announced = false
	if _visual != null:
		_visual.visible = false
	if is_instance_valid(_safe_view):
		_safe_view.queue_free()
	_safe_view = null
