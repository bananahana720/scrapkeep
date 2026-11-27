extends AnimatableBody3D

const Palette := preload("res://src/core/palette.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")

const SLATE := Color("5d6b78")
const HIT_GLOW := 0.7
const HIT_POP := 1.5

signal struck_impulse(direction: Vector3, strength: float)

var boss
var role := "hull"
var point_id := ""
var kind := "brindle_hull"
var radius := 1.0
var half_height := 1.0
var tint_state := ""
var last_damage_source := ""
var hp: float:
	get:
		return boss.hp if boss != null else 0.0
var max_hp: float:
	get:
		return boss.max_hp if boss != null else 1.0
var plating: float:
	get:
		return plating_now()

var _tint_materials: Array = []
var _flash := 0.0
var _rest_glow := Color.BLACK
var _rest_energy := 0.0
var _struck_seen := false
var _last_full := true
var _last_part := ""


func setup(boss_ref, role_name: String, id: String, body_size: Vector3, capsule: Vector2) -> void:
	boss = boss_ref
	role = role_name
	point_id = id
	kind = "brindle_%s" % role_name
	name = "Brindle_%s" % (id if id != "" else role_name)
	radius = capsule.x
	half_height = capsule.y
	sync_to_physics = false
	collision_layer = 0
	collision_mask = 0
	if body_size != Vector3.ZERO:
		set_solid(true)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = body_size
		shape.shape = box
		add_child(shape)
	add_to_group("enemy")


var body_boxes := Callable()


func screen_bound_boxes() -> Array:
	return body_boxes.call() if body_boxes.is_valid() else []


func set_solid(on: bool, as_world := false) -> void:
	set_collision_layer_value(3, on and not as_world)
	set_collision_layer_value(1, on and as_world)


func tint_with(material: StandardMaterial3D) -> void:
	_tint_materials.append(material)


func is_dead() -> bool:
	return boss == null or not boss.target_live(self)


func crushable() -> bool:
	return false


func tint_verb() -> String:
	return "ram" if boss != null and role == "hull" and boss.charging() else ""


func knock(direction: Vector3, force: float) -> void:
	if direction.length_squared() > 0.0001 and force > 0.0:
		struck_impulse.emit(direction.normalized(), clampf(force * 0.04, 0.25, 1.4))


func flash() -> void:
	_flash = 0.12
	struck_impulse.emit(Vector3.BACK, 0.55)


func plating_now() -> float:
	return boss.plating_for(self, "", "") if boss != null else 0.0


func plating_for(strike_kind: String, part: String) -> float:
	return boss.plating_for(self, strike_kind, part)


func hit_mult(strike_kind: String, part: String) -> float:
	return boss.hit_mult(self, strike_kind, part)


func weak_points() -> Array:
	return []


func fight() -> String:
	return boss.fight(self) if boss != null else "plating"


func posture() -> float:
	return boss.posture() if boss != null else 0.0


func staggered() -> bool:
	return boss != null and boss.staggered()


func stagger_left() -> float:
	return boss.stagger_left() if boss != null else 0.0


func chunks_left() -> int:
	return boss.chunks_left() if boss != null else 0


func glances() -> int:
	return boss.glances() if boss != null else 0


func chunk_cracked() -> bool:
	return boss != null and boss.chunk_cracked()


func banking() -> bool:
	return boss != null and boss.has_method("banking") and boss.banking()


func bank_cap() -> float:
	return boss.bank_cap() if boss != null and boss.has_method("bank_cap") else 0.0


func judge_hit(strike_kind: String, punch: float, smash: bool, tier: int) -> Dictionary:
	return boss.judge_hit(self, strike_kind, punch, smash, tier) if boss != null else {}


func contact_part(ball: Vector3, strike_kind: String) -> String:
	return boss.contact_part(self, ball, strike_kind)


func on_struck(strike_kind: String, part: String, result: Dictionary) -> void:
	_struck_seen = true
	_last_full = bool(result.get("full", true))
	_last_part = part
	boss.on_struck(self, strike_kind, part, result)


func take_damage(amount: float) -> float:
	var full := _last_full if _struck_seen else true
	var part := _last_part if _struck_seen else ""
	_struck_seen = false
	_last_full = true
	_last_part = ""
	flash()
	return boss.take_damage(self, amount, full, part) if boss != null else 0.0


func set_tint(state: String) -> void:
	if boss != null:
		state = boss.tint_for(self, state)
	if state == tint_state:
		return
	tint_state = state
	var color := Palette.AMBER if state == "amber" else SLATE
	for mat in _tint_materials:
		(mat as StandardMaterial3D).albedo_color = color


func telegraph() -> Node3D:
	return null


func set_rest_glow(color: Color, energy: float) -> void:
	_rest_glow = color
	_rest_energy = energy
	if _flash <= 0.0:
		_show_rest()


func _show_rest() -> void:
	for mat in _tint_materials:
		var m := mat as StandardMaterial3D
		m.emission_enabled = _rest_energy > 0.0
		m.emission = _rest_glow
		m.emission_energy_multiplier = _rest_energy


func _process(delta: float) -> void:
	if _flash <= 0.0:
		return
	_flash -= delta
	if _flash <= 0.0:
		_show_rest()
		return
	var tinted := tint_state != ""
	for mat in _tint_materials:
		var m := mat as StandardMaterial3D
		m.emission_enabled = true
		m.emission = m.albedo_color if tinted else Color.WHITE
		m.emission_energy_multiplier = FlashGuard.spike(0.0, HIT_GLOW if tinted else HIT_POP)
