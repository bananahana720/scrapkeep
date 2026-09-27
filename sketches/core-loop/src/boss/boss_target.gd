extends AnimatableBody3D

const Palette := preload("res://src/core/palette.gd")

# One strikeable piece of Brindle: the hull, a crane magnet, a vent cap or the eject
# scooter. It speaks combat's enemy protocol (src/combat/README.md on the combat
# branch: plating_now, plating_for, hit_mult, contact_part, on_struck, take_damage,
# set_tint) so ctx.spawner.strike resolves it with the one plating rule, and it speaks
# the spine's contact hooks (knock, flash). It decides nothing: every answer comes from
# boss.gd, and every piece shares the boss's one HP pool.

const SLATE := Color("5d6b78")

var boss
var role := "hull"
var point_id := ""
var kind := "brindle_hull"
# The upright capsule combat's bolts test: radius and half height around global_position.
var radius := 1.0
var half_height := 1.0
var tint_state := ""
# Read by combat's integrity_of and tint loop; all three come from the boss.
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
	sync_to_physics = true
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


# On the enemy layer the ball's contacts reach combat; on the world layer the piece is
# scenery (the wrecked hull); with neither it is a ghost (the scooter in flight).
func set_solid(on: bool, as_world := false) -> void:
	set_collision_layer_value(3, on and not as_world)
	set_collision_layer_value(1, on and as_world)


func tint_with(material: StandardMaterial3D) -> void:
	_tint_materials.append(material)


func is_dead() -> bool:
	return boss == null or not boss.target_live(self)


func knock(_direction: Vector3, _force: float) -> void:
	pass


func flash() -> void:
	_flash = 0.12


func plating_now() -> float:
	return boss.plating_for(self, "", "") if boss != null else 0.0


func plating_for(strike_kind: String, part: String) -> float:
	return boss.plating_for(self, strike_kind, part)


func hit_mult(strike_kind: String, part: String) -> float:
	return boss.hit_mult(self, strike_kind, part)


func weak_points() -> Array:
	return []


func contact_part(ball: Vector3, strike_kind: String) -> String:
	return boss.contact_part(self, ball, strike_kind)


func on_struck(strike_kind: String, part: String, result: Dictionary) -> void:
	_struck_seen = true
	_last_full = bool(result.get("full", true))
	_last_part = part
	boss.on_struck(self, strike_kind, part, result)


# A spawner without on_struck (the wave-1 stub) has no plating; its hits count as full.
func take_damage(amount: float) -> float:
	var full := _last_full if _struck_seen else true
	var part := _last_part if _struck_seen else ""
	_struck_seen = false
	_last_full = true
	_last_part = ""
	flash()
	return boss.take_damage(self, amount, full, part) if boss != null else 0.0


func set_tint(state: String) -> void:
	if state == tint_state:
		return
	tint_state = state
	var color := Palette.AMBER if state == "amber" else SLATE
	for mat in _tint_materials:
		(mat as StandardMaterial3D).albedo_color = color


func telegraph() -> Node3D:
	return null


func _process(delta: float) -> void:
	if _flash <= 0.0:
		return
	_flash -= delta
	var lit := _flash > 0.0
	for mat in _tint_materials:
		var m := mat as StandardMaterial3D
		m.emission_enabled = lit
		m.emission = Color.WHITE
		m.emission_energy_multiplier = 1.5
