extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Pattern := preload("res://src/combat/pattern.gd")
const Weapons := preload("res://src/combat/weapons.gd")

# The pattern system parts transform. Pure layout checks first: a transformer changes
# how many bolts a volley throws and at what angles, stat tiers scale the numbers,
# the caps hold whatever stacks, and the base pattern is never mutated. Then the same
# thing through a live game: a part registered by id changes the volley the weapon
# actually fires, and a stage retry that restores the part list restores the pattern.

const FORWARD := Vector3(0.3, 0.1, -1.0)

var _game
var _source := Intent.Scripted.new()
var _failures := 0
var _step := 0
var _clock := 0.0
var _bolts_before := 0


func _initialize() -> void:
	_pure_checks()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(check: String, ok: bool, detail: String) -> void:
	print("[%s] %s -> %s" % [check, detail, "PASS" if ok else "FAIL"])
	if not ok:
		_failures += 1


static func _angle_deg(a: Vector3, b: Vector3) -> float:
	return rad_to_deg(a.normalized().angle_to(b.normalized()))


# The roll of a direction about the forward axis, in degrees, for comparing arms.
static func _roll_deg(dir: Vector3, forward: Vector3) -> float:
	var fwd := forward.normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	var up := right.cross(fwd).normalized()
	var flat := dir - fwd * dir.dot(fwd)
	return rad_to_deg(atan2(flat.dot(up), flat.dot(right)))


func _pure_checks() -> void:
	var base: Resource = Weapons.base(Weapons.RAPID_LASER)
	var plain: Array = base.directions(FORWARD, 0)
	_report("base", plain.size() == 1 and _angle_deg(plain[0], FORWARD) < 0.01,
		"rapid laser throws %d bolt, %.3f deg off the aim line" % [plain.size(), _angle_deg(plain[0], FORWARD)])

	var cross: Resource = base.transformed(["cross_split"])
	var dirs: Array = cross.directions(FORWARD, 0)
	var offs := []
	var rolls := []
	for i in range(1, dirs.size()):
		offs.append(_angle_deg(dirs[i], FORWARD))
		rolls.append(_roll_deg(dirs[i], FORWARD))
	var even := true
	for i in range(1, rolls.size()):
		var gap := fposmod(rolls[i] - rolls[i - 1], 360.0)
		even = even and absf(gap - 90.0) < 0.5
	var arms_ok := offs.size() == 4
	for off in offs:
		arms_ok = arms_ok and absf(off - 7.0) < 0.05
	_report("cross_count", dirs.size() == 5 and _angle_deg(dirs[0], FORWARD) < 0.01,
		"cross split throws %d bolts (needs 5), centre %.3f deg off the aim line" % [dirs.size(), _angle_deg(dirs[0], FORWARD)])
	_report("cross_angles", arms_ok and even,
		"arms at %s deg off-axis (needs 7), rolls %s deg (needs 90 apart)" % [_fmt(offs), _fmt(rolls)])

	var spiral: Resource = base.transformed(["cross_split", "spiral_wave"])
	var v0: Array = spiral.directions(FORWARD, 0)
	var v1: Array = spiral.directions(FORWARD, 1)
	var turn := fposmod(_roll_deg(v1[1], FORWARD) - _roll_deg(v0[1], FORWARD), 360.0)
	_report("spiral", absf(turn - spiral.spin_deg) < 0.5 and spiral.wave_amp > 0.0 and _angle_deg(v1[0], FORWARD) < 0.01,
		"spiral turns the cross %.1f deg per volley (spin %.1f), wave %.2f m, centre stays on the aim line" % [turn, spiral.spin_deg, spiral.wave_amp])

	var double: Resource = base.transformed(["cross_split", "cross_split"])
	_report("stack", double.volley_size() == 8 and double.arms == 7,
		"two cross splits: %d arms, %d bolts a volley (needs 7 and 8)" % [double.arms, double.volley_size()])

	var tiers: Resource = base.transformed(["damage_tier", "rate_tier", "range_tier"])
	var tiers_ok := is_equal_approx(tiers.damage, base.damage * 1.25) and is_equal_approx(tiers.rate, base.rate * 1.2) \
		and is_equal_approx(tiers.range_m, base.range_m * 1.25)
	_report("tiers", tiers_ok, "damage %.2f -> %.2f, rate %.1f -> %.1f, range %.1f -> %.1f"
		% [base.damage, tiers.damage, base.rate, tiers.rate, base.range_m, tiers.range_m])

	var many := []
	for i in 12:
		many.append("cross_split")
		many.append("rate_tier")
		many.append("spiral_wave")
	var capped: Resource = base.transformed(many)
	var caps_ok: bool = capped.volley_size() <= Pattern.MAX_VOLLEY and capped.rate <= Pattern.MAX_RATE \
		and capped.wave_amp <= Pattern.MAX_WAVE and capped.directions(FORWARD, 3).size() <= Pattern.MAX_VOLLEY
	_report("caps", caps_ok, "36 stacked transformers: %d bolts a volley (cap %d), rate %.1f (cap %.0f), wave %.2f m (cap %.1f)"
		% [capped.volley_size(), Pattern.MAX_VOLLEY, capped.rate, Pattern.MAX_RATE, capped.wave_amp, Pattern.MAX_WAVE])

	var untouched: bool = base.arms == 1 and base.count == 1 and is_equal_approx(base.damage, Weapons.BASE[Weapons.RAPID_LASER]["damage"])
	_report("pure", untouched, "transforming never mutates the base pattern (arms %d, damage %.1f)" % [base.arms, base.damage])


static func _fmt(values: Array) -> String:
	var parts := PackedStringArray()
	for v in values:
		parts.append("%.1f" % v)
	return "[" + ", ".join(parts) + "]"


func _physics_process(delta: float) -> bool:
	if _game.flow == null:
		return false
	var combat = _game.ctx.spawner
	match _step:
		0:
			_game.ctx.calm = true
			_game.player.source = _source
			_game.flow.press_start()
			_game.flow.choose_class(1)
			_game.camera.pitch = 0.3
			_step = 1
		1:
			# A part id B might use, registered to two transformers.
			combat.register_part("test_prism", ["cross_split", "chain_arc"])
			_game.run.add_part("test_prism", "gate")
			var laser: Resource = combat.pattern(Weapons.RAPID_LASER)
			var caster: Resource = combat.pattern(Weapons.ARC_CASTER)
			_report("part_api", laser.volley_size() == 5 and caster.chain_jumps == 2,
				"part 'test_prism' -> %s: laser volley %d (needs 5), caster chain jumps %d (needs 2)"
					% [combat.active_transformers(), laser.volley_size(), caster.chain_jumps])
			_bolts_before = combat.bolts.fired
			_source.press = {"fire_pressed": true}
			_source.hold = {"fire_held": true}
			_step = 2
			_clock = 0.0
		2:
			_clock += delta
			if _clock < 0.05:
				return false
			_source.hold = {}
			var shot: Dictionary = combat.last_shot
			_report("fired", shot.get("bolts", 0) == 5 and combat.bolts.fired - _bolts_before >= 5,
				"the live weapon fired a %d-bolt volley, %d bolts in all" % [shot.get("bolts", 0), combat.bolts.fired - _bolts_before])
			_game.camera.pitch = 0.3
			_game.flow.retry_stage()
			_step = 3
		3:
			var after: Resource = combat.pattern(Weapons.RAPID_LASER)
			_report("retry", _game.run.parts.is_empty() and after.volley_size() == 1,
				"retry restored parts %s and the laser volley to %d bolt" % [_game.run.parts, after.volley_size()])
			return _finish()
	return false


func _finish() -> bool:
	var ok := _failures == 0
	print("combat_pattern_test: %s" % ("PASS" if ok else "FAIL"))
	_game.free()
	quit(0 if ok else 1)
	return true
