extends "res://src/combat/enemy.gd"

# A rogue fleet machine (Q-P25, Andrew 23 Oct: "fleet machines gone rogue"): one working
# machine per world that runs outside the Mind's reach (DECISIONS, "The Mind's reach"). Its
# command line is cut, and a local governor still runs its old job on a loop; the loop is
# the fight (docs/art/reference/hierarchy, "Off the foreman's books"). The rogue director (world/rogue_director.gd) drops one into each
# stage at a mini-boss site; fit_site() scales its reach and body to that ground.
#
#   stalk -> attack A -> vented window -> stalk -> attack B -> vented window -> ...
#
# Every attack commits its geometry first, winds up on the beat of the rogue's anthem, then
# strikes; only the committed shape hurts. After each strike the machine sticks vented: its
# plating drops to 0 and the core shows the live colour, the same grammar as the miniboss.
# Timings are counted in beats of the row's anthem bpm, so the attacks land on the music
# (map veto pass, 23 Oct: rhythm-locked attacks).
#
# The six attacks, two per machine (roll, ram, grapple and carve, principle 2):
# - sweep (gate crane): the hook block swings down a committed lane and back, a pendulum
#   that bats the ball sideways like a flipper.
# - drop (gate crane): the gate leaf falls on a ring committed where the ball is.
# - haul (haul skip): rams down a committed lane and back again, because it still runs its
#   route; it cannot be knocked while hauling.
# - dump (haul skip): tips its bucket, and tailings land on a ring committed ahead of it.
# - harpoon (cable tender): a mooring line fires down a committed lane and reels a ball it
#   catches in toward the tender.
# - whip (cable tender): the cables whip round it on a ring centred on itself, so a ball
#   reeled in by the harpoon has its wind-up to get out.

const Miniboss := preload("res://src/combat/miniboss.gd")

const SCRAP := 30
const WEIGHT := 5.0
const STALK_BEATS := 4.0
const WEAK_BEATS := 6.0
const WALK := 5.0
# fit_site: a 40 m site disc is full size; the islands' 20 m discs shrink it to the floor.
const SITE_FULL_M := 40.0
const SCALE_MIN := 0.6
const SCALE_MAX := 1.25

# One row per rogue. `attacks` alternate in order.
# `anthem` is its tune id (the music lane adds the TUNES row with the track); until then the
# miniboss tune plays. Sizes are metres at scale 1.
const ROWS := {
	"rogue_crane": {"world": 1, "name": "Gate Crane No. 14", "crew": "14", "anthem": "anthem-gate-crane", "bpm": 140.0,
		"hp": 640.0, "radius": 2.4, "half_height": 3.6, "attacks": ["sweep", "drop"]},
	"rogue_skip": {"world": 2, "name": "Haul Skip No. 31", "crew": "31", "anthem": "anthem-haul-skip", "bpm": 145.0,
		"hp": 700.0, "radius": 2.6, "half_height": 2.4, "attacks": ["haul", "dump"]},
	"rogue_tender": {"world": 3, "name": "Cable Tender No. 7", "crew": "7", "anthem": "anthem-cable-tender", "bpm": 150.0,
		"hp": 660.0, "radius": 2.3, "half_height": 3.0, "attacks": ["harpoon", "whip"]},
}

# Per attack: wind-up and strike in beats, the committed shape, damage and shove.
const ATTACKS := {
	"sweep": {"wind": 4.0, "strike": 2.0, "shape": "lane", "length": 26.0, "width": 4.0, "reach": 2.2, "damage": 20.0, "shove": 12.0},
	"drop": {"wind": 4.0, "strike": 1.0, "shape": "ring", "radius": 6.0, "damage": 24.0, "shove": 9.0},
	"haul": {"wind": 4.0, "strike": 4.0, "shape": "lane", "length": 28.0, "width": 4.4, "damage": 20.0, "shove": 10.0},
	"dump": {"wind": 4.0, "strike": 1.0, "shape": "ring", "radius": 7.0, "ahead": 8.0, "damage": 22.0, "shove": 8.0},
	"harpoon": {"wind": 3.0, "strike": 1.0, "shape": "lane", "length": 24.0, "width": 3.0, "damage": 10.0, "shove": 16.0},
	"whip": {"wind": 4.0, "strike": 1.0, "shape": "ring", "radius": 9.0, "damage": 22.0, "shove": 11.0},
}

enum State { STALK, WIND, STRIKE, WEAK }

var row := {}
var site_scale := 1.0
var state := State.STALK
var attack := ""
var attacks := 0
var weak_windows := 0
var hits_landed := 0

var _clock := 0.0
var _next := 0
var _home := Vector3.ZERO
var _hits_this_strike := 0
var _shape: CollisionShape3D
var _body: Node3D
var _hook: Node3D
var _hook_rest := Vector3.ZERO
var _core: MeshInstance3D
var _core_material: StandardMaterial3D
var _plates: Array = []


func setup(target_ref, terrain_ref, root_ref, live_ref: Callable, threat: float, spec_ref := {}) -> void:
	_setup_common(target_ref, terrain_ref, root_ref, live_ref, spec_ref)
	kind = String(spec.get("kind", "rogue_crane"))
	if not ROWS.has(kind):
		push_warning("rogue: unknown kind '%s', using rogue_crane" % kind)
		kind = "rogue_crane"
	row = ROWS[kind]
	_set_health(float(row.hp) * threat)
	plating = spec.get("plating", Miniboss.DEFAULT_PLATING)
	scrap_value = SCRAP
	weight = WEIGHT
	_build_body()
	_fit(1.0)


# Scales reach and body to the site's disc, so a rogue on an islands shelf fits the shelf.
func fit_site(radius_m: float) -> void:
	_fit(clampf(radius_m / SITE_FULL_M, SCALE_MIN, SCALE_MAX))


func _fit(value: float) -> void:
	site_scale = value
	radius = float(row.radius) * value
	half_height = float(row.half_height) * value
	var capsule := _shape.shape as CapsuleShape3D
	capsule.radius = radius
	capsule.height = maxf(half_height * 2.0, radius * 2.0 + 0.01)
	_body.scale = Vector3.ONE * value


func beat() -> float:
	return 60.0 / float(row.bpm)


func anthem() -> String:
	return String(row.anthem)


func state_name() -> String:
	return ["stalk", "wind", "strike", "weak"][state]


func is_weak() -> bool:
	return state == State.WEAK


func plating_now() -> float:
	return 0.0 if state == State.WEAK else plating


func knock(direction: Vector3, force: float) -> void:
	# A haul runs the lane it committed: it cannot be knocked off it between commit and return.
	if attack == "haul" and (state == State.WIND or state == State.STRIKE):
		return
	super.knock(direction, force)


func _physics_process(delta: float) -> void:
	_update_flash(delta)
	_pose(delta)
	if not _in_play() or not is_instance_valid(target):
		_move(delta, Vector3.ZERO)
		return
	_clock += delta
	var to_ball := _flat_to_ball()
	match state:
		State.STALK:
			_move(delta, to_ball.normalized() * WALK if to_ball.length() > radius + 4.0 else Vector3.ZERO)
			if _clock >= STALK_BEATS * beat() and is_on_floor():
				_begin_attack(to_ball)
		State.WIND:
			_move(delta, Vector3.ZERO)
			_fill(_clock / (_seconds("wind") + (_seconds("strike") if _is_ring() else 0.0)))
			if _clock >= _seconds("wind"):
				_enter(State.STRIKE)
				_hits_this_strike = 0
		State.STRIKE:
			if _is_ring():
				_fill((_seconds("wind") + _clock) / (_seconds("wind") + _seconds("strike")))
			_strike(delta)
			if _clock >= _seconds("strike"):
				_open_weak_window()
		State.WEAK:
			_move(delta, Vector3.ZERO)
			if _clock >= WEAK_BEATS * beat():
				_enter(State.STALK)


# A ring fills through its wind-up and strike and lands as it fills, as the miniboss's slam does.
func _is_ring() -> bool:
	return String(ATTACKS[attack].shape) == "ring"


func _seconds(part: String) -> float:
	return float(ATTACKS[attack][part]) * beat()


func _size(key: String) -> float:
	return float(ATTACKS[attack][key]) * site_scale


func _enter(next: int) -> void:
	state = next
	_clock = 0.0


func _begin_attack(to_ball: Vector3) -> void:
	attacks += 1
	attack = String(row.attacks[_next])
	_next = (_next + 1) % row.attacks.size()
	var heading := to_ball if to_ball.length() > 0.5 else -global_basis.z
	heading = heading.normalized()
	_home = global_position
	var ball := _ball()
	var reach := 4.0
	match attack:
		"sweep", "haul", "harpoon":
			_commit_lane(Threat.Type.LANE, global_position, heading, _size("length"), _size("width"), reach)
		"drop":
			_commit_ring(Threat.Type.PROJECTILE, ball, _size("radius"), reach)
		"dump":
			var ahead := minf(_size("ahead"), to_ball.length())
			_commit_ring(Threat.Type.PROJECTILE, global_position + heading * ahead, _size("radius"), reach)
		"whip":
			_commit_ring(Threat.Type.INSTANT, global_position, _size("radius"), reach)
	_enter(State.WIND)


func _strike(delta: float) -> void:
	var shape := telegraph()
	if shape == null:
		_open_weak_window()
		return
	var t := clampf(_clock / _seconds("strike"), 0.0, 1.0)
	match attack:
		"sweep":
			_move(delta, Vector3.ZERO)
			# Out to the lane's end and back: a pendulum, at the far end at half time.
			var out := 1.0 - absf(1.0 - 2.0 * t)
			var hook: Vector3 = _home + shape.dir * shape.length * out
			if _hook != null:
				_hook.global_position = Vector3(hook.x, _hook.global_position.y, hook.z)
			var flat := _ball() - hook
			flat.y = 0.0
			if _hits_this_strike == 0 and flat.length() <= _size("reach") + 1.0 and shape.contains(_ball()):
				var side: Vector3 = shape.dir.cross(Vector3.UP).normalized()
				_land(side * signf(side.dot(flat) if absf(side.dot(flat)) > 0.01 else 1.0))
		"haul":
			# Down the lane over the first half, back to where it started over the second.
			var out := 1.0 - absf(1.0 - 2.0 * t)
			var want: Vector3 = _home + shape.dir * shape.length * out
			var step := want - global_position
			step.y = 0.0
			_move(delta, step / maxf(delta, 0.0001))
			var leg := 0 if t < 0.5 else 1
			if _hits_this_strike <= leg and _flat_to_ball().length() <= radius + 1.6 and shape.contains(_ball()):
				_hits_this_strike = leg
				_land(shape.dir * (1.0 if leg == 0 else -1.0))
		"harpoon":
			_move(delta, Vector3.ZERO)
			if _hits_this_strike == 0 and shape.contains(_ball()):
				var home := -_flat_to_ball()
				_land(home.normalized() if home.length() > 0.1 else Vector3.ZERO)
		_:
			_move(delta, Vector3.ZERO)
			# A ring resolves once, on the strike's last tick: the leaf, the tailings or the
			# cables land where the ring was committed.
			if _hits_this_strike == 0 and t >= 1.0 - delta / maxf(_seconds("strike"), 0.0001):
				_hits_this_strike = 1
				if shape.contains(_ball()):
					var away := _ball() - shape.global_position
					away.y = 0.0
					_land(away.normalized() if away.length() > 0.1 else Vector3.ZERO)


func _land(direction: Vector3) -> void:
	if not attack in ["drop", "dump", "whip"]:
		_hits_this_strike += 1
	hits_landed += 1
	hit_player.emit(float(ATTACKS[attack].damage), direction * float(ATTACKS[attack].shove) + Vector3.UP * 4.0)


func _open_weak_window() -> void:
	_clear_telegraph()
	if _hook != null:
		_hook.position = _hook_rest
	weak_windows += 1
	_enter(State.WEAK)


func _fill(value: float) -> void:
	var shown := telegraph()
	if shown != null:
		shown.set_progress(value)


# --- Body ---------------------------------------------------------------------------
# Primitive bodies until the sculpted ones land (briefs in design-v3/rogues/BRIEFS.md). Each
# keeps its working silhouette, the crew number and HIRED stamp it was issued (principle 7,
# "All hands"), the brass governor that runs it and the cut command line that freed it. The
# core is the service hatch the work opens: the vented window.

func _build_body() -> void:
	_shape = CollisionShape3D.new()
	_shape.shape = CapsuleShape3D.new()
	add_child(_shape)
	_base_color = Palette.BRASS
	_material = Palette.solid(_base_color)
	_body = Node3D.new()
	_body.name = "RogueBody"
	_visual_parent().add_child(_body)
	_core_material = Palette.solid(Palette.VERDIGRIS)
	var plate_material := _plate_material()
	var h := float(row.half_height)
	var r := float(row.radius)
	match kind:
		"rogue_crane":
			_box(Vector3(r * 1.6, 0.8, r * 1.6), Vector3(0.0, -h + 0.4, 0.0), _material)
			_cylinder(0.45, h * 1.8, Vector3(0.0, 0.0, 0.0), _material)
			_box(Vector3(0.7, 0.6, 7.0), Vector3(0.0, h - 0.3, -2.6), _material)
			_hook = _box(Vector3(1.4, 1.2, 1.4), Vector3(0.0, h - 2.6, -5.6), Palette.solid(Palette.CHARCOAL))
			_hook_rest = _hook.position
			_cylinder(0.06, 1.8, Vector3(0.0, h - 1.3, -5.6), Palette.solid(Palette.CABLE))
			_core = _sphere(0.9, Vector3(0.0, h - 0.6, 1.6))
		"rogue_skip":
			_box(Vector3(r * 1.7, h * 1.1, r * 1.9), Vector3(0.0, 0.1, 0.0), _material)
			for side in [-1.0, 1.0]:
				for end in [-1.0, 1.0]:
					var wheel := _cylinder(0.55, 0.4, Vector3(side * r * 0.9, -h + 0.55, end * r * 0.6), Palette.solid(Palette.CHARCOAL))
					wheel.rotation.z = PI * 0.5
			_core = _sphere(0.8, Vector3(0.0, 0.3, r * 1.0))
		_:
			var drum := _cylinder(r * 0.8, r * 1.5, Vector3(0.0, 0.2, 0.0), _material)
			drum.rotation.z = PI * 0.5
			for side in [-1.0, 1.0]:
				_box(Vector3(0.4, h * 1.2, 0.4), Vector3(side * r * 0.7, -h * 0.5, 0.0), _material)
			_box(Vector3(0.4, 0.4, 5.0), Vector3(0.0, h * 0.6, -2.4), _material)
			_core = _sphere(0.7, Vector3(0.0, 0.2, -r * 0.85))
	for side in [-1.0, 1.0]:
		var plate := _box(Vector3(r * 0.9, h * 0.9, 0.3), _core.position + Vector3(side * 0.7, 0.0, -0.6 if kind != "rogue_crane" else 0.6), plate_material)
		_plates.append({"node": plate, "side": side, "rest": plate.position})
	# The governor's flyballs on top, and the command line's cut end hanging beside them.
	var brass := Palette.solid(Palette.BRASS)
	for side in [-1.0, 1.0]:
		var flyball := SphereMesh.new()
		flyball.radius = 0.3
		flyball.height = 0.6
		_part(flyball, Vector3(side * 0.45, h + 0.5, 0.6), brass)
	_cylinder(0.08, 0.9, Vector3(0.0, h + 0.3, 0.6), brass)
	_cylinder(0.12, 1.4, Vector3(r * 0.6, h - 0.3, 0.9), Palette.solid(Palette.RUST))
	_stamp("No. " + String(row.crew), Vector3(r * 0.9 + 0.05, 0.4, 0.0), 64)
	_stamp("HIRED", Vector3(r * 0.9 + 0.05, -0.4, 0.0), 40)


func _box(size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _part(mesh, at, material)


func _cylinder(cylinder_radius: float, height: float, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = cylinder_radius
	mesh.bottom_radius = cylinder_radius
	mesh.height = height
	return _part(mesh, at, material)


func _sphere(sphere_radius: float, at: Vector3) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = sphere_radius
	mesh.height = sphere_radius * 2.0
	return _part(mesh, at, _core_material)


func _part(mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	_body.add_child(instance)
	return instance


func _stamp(text: String, at: Vector3, size: int) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.01
	label.modulate = Palette.LEDGER
	label.outline_modulate = Palette.CHARCOAL
	label.position = at
	label.rotation.y = PI * 0.5
	_body.add_child(label)


# The window reads three ways, as the miniboss's does: the plates swing open (shape), the
# core swells in the live colour (colour and size), and it pulses (motion).
func _pose(delta: float) -> void:
	if _core == null:
		return
	var weak := state == State.WEAK
	var blend := 1.0 - exp(-14.0 * delta)
	for entry in _plates:
		var plate: MeshInstance3D = entry["node"]
		var side: float = entry["side"]
		var rest: Vector3 = entry["rest"]
		plate.position = plate.position.lerp(rest + Vector3(side * (0.9 if weak else 0.0), 0.0, 0.0), blend)
		plate.rotation.y = lerpf(plate.rotation.y, side * (0.9 if weak else 0.0), blend)
	var pulse := 1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.018) if weak else 1.0
	_core.scale = Vector3.ONE * (1.5 * pulse if weak else 1.0)
	_core.material_override = _weak_material() if weak else _core_material
	# A null or freed target leaves the facing where it is (F008).
	if not is_instance_valid(target):
		return
	if state == State.STALK or state == State.WEAK or (state == State.WIND and attack != "whip"):
		var to := _flat_to_ball()
		var shown := telegraph()
		if state == State.WIND and shown != null:
			to = shown.dir if shown.shape == Telegraph.Shape.LANE else shown.global_position - global_position
			to.y = 0.0
		if to.length() > 0.5:
			rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-8.0 * delta))


var _weak: StandardMaterial3D


func _weak_material() -> StandardMaterial3D:
	if _weak == null:
		_weak = Palette.solid(Palette.live(), 1.0)
	_weak.emission_energy_multiplier = FlashGuard.spike(1.2, 4.0)
	return _weak
