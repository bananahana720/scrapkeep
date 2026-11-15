extends AnimatableBody3D

const Palette := preload("res://src/core/palette.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")

# One strikeable piece of Brindle: the hull, a crane magnet, a vent cap or the eject
# scooter. It speaks combat's enemy protocol (src/combat/README.md on the combat
# branch: plating_now, plating_for, hit_mult, contact_part, on_struck, take_damage,
# set_tint) so ctx.spawner.strike resolves it with the one plating rule, and it speaks
# the spine's contact hooks (knock, flash) and the posture fight (BossContract.TARGET).
# It decides nothing: every answer comes from boss.gd, and every piece shares the
# boss's one posture bar and four chunks.

const SLATE := Color("5d6b78")
# A hit lifts each plated piece in its own tint, slate or amber, so the plating read (fight
# information) survives steady fire. A white flash at 1.5 drew all four plates near white
# under the ball's bolts (W1-48, PC film 0124).
const HIT_GLOW := 0.7
# A piece with no plating tint (a vent cap is charcoal) keeps the white pop; its own colour
# would not show.
const HIT_POP := 1.5

var boss
var role := "hull"
var point_id := ""
var kind := "brindle_hull"
# The upright capsule combat's bolts test: radius and half height around global_position.
var radius := 1.0
var half_height := 1.0
var tint_state := ""
# A wear-trail patch tags the body it hits for the length of the hit (wear_trail.gd), so
# a kill it makes procs no on-kill effect. boss.gd hands it to run_state on the defeat.
var last_damage_source := ""
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
# The glow the piece wears between hits (an open vent cap's hazard glow); a hit lifts over
# it and hands it back, so the first hit never switches a weak point dark.
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
	# boss.gd moves the ship, the parent, every tick; a synced body ignores a parent's motion
	# and stays near the arena centre, so each piece follows its node directly.
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


# Set by a piece whose body is drawn outside its own subtree (the Requisition's hull piece answers for
# the whole ship). A Callable returning the drawn bounds as a world AABB. player_fx reads it through
# screen_bound_box(), as it does a hostile warning's, instead of walking this piece's own meshes.
var body_bounds := Callable()


# The world box of what this piece stands for on screen; an empty box means "walk my meshes".
func screen_bound_box() -> AABB:
	return body_bounds.call() if body_bounds.is_valid() else AABB()


# On the enemy layer the ball's contacts reach combat; on the world layer the piece is
# scenery (the wrecked hull); with neither it is a ghost (the scooter in flight).
func set_solid(on: bool, as_world := false) -> void:
	set_collision_layer_value(3, on and not as_world)
	set_collision_layer_value(1, on and as_world)


func tint_with(material: StandardMaterial3D) -> void:
	_tint_materials.append(material)


func is_dead() -> bool:
	return boss == null or not boss.target_live(self)


# The crush seam: no piece of Brindle is ever crushed. His health is chunks that only a
# contact in a stagger removes, so a crush exception on him would end with the ball
# inside a body that never died.
func crushable() -> bool:
	return false


# The clash-preview seam: while the hull charges, only a ram can clash with its bow,
# so combat compares its plating against ram_punch_now() instead of punch_now().
func tint_verb() -> String:
	return "ram" if boss != null and role == "hull" and boss.charging() else ""


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


# --- The posture fight (BossContract.TARGET), all answered by boss.gd -----------------

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


# A hull boss's held phase banks hits toward its next bar (boss.gd banking); nothing else does.
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


# The glow between hits; 0 energy is none. Shown at once unless a hit is lit.
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
