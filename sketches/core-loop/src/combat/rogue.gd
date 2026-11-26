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
#   that bats the ball sideways like a flipper. It leads a ball that holds a line
#   (PackPressure.lead_aim), aimed where the hook meets the ball's roll.
# - drop (gate crane): the gate leaf falls on a ring committed where the ball will be when it
#   lands, if the ball holds its line, else where the ball is.
# - haul (haul skip): rams down a committed lane and back again, because it still runs its
#   route; it cannot be knocked while hauling.
# - dump (haul skip): tips its bucket, and tailings land on a ring committed ahead of it.
# - harpoon (cable tender): a mooring line fires down a committed lane and reels a ball it
#   catches in toward the tender.
# - whip (cable tender): the cables whip round it on a ring centred on itself, so a ball
#   reeled in by the harpoon has its wind-up to get out.

const Miniboss := preload("res://src/combat/miniboss.gd")
const PackPressure := preload("res://src/combat/pack_pressure.gd")
const Tuning := preload("res://src/movement/tuning.gd")

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
	"rogue_crane": {"world": 1, "name": "Gate Crane No. 14", "crew": "14", "anthem": "anthem-gate-crane", "anthem_heavy": "anthem-gate-crane-heavy", "bpm": 140.0,
		"hp": 640.0, "radius": 2.4, "half_height": 3.6, "attacks": ["sweep", "drop"]},
	"rogue_skip": {"world": 2, "name": "Haul Skip No. 31", "crew": "31", "anthem": "anthem-haul-skip", "anthem_heavy": "anthem-haul-skip-heavy", "bpm": 145.0,
		"hp": 700.0, "radius": 2.6, "half_height": 2.4, "attacks": ["haul", "dump"]},
	"rogue_tender": {"world": 3, "name": "Cable Tender No. 7", "crew": "7", "anthem": "anthem-cable-tender", "anthem_heavy": "anthem-cable-tender-heavy", "bpm": 150.0,
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

# The sculpted bodies (design-v3/rogues/BRIEFS.md): one GLB per machine on the miniboss
# contract, <prefix>Hull/Armour/Core with slots fleet_paint/part_state/core_state, rigid pose
# bones named <bone><Part>, -Z facing, origin at the collider centre. A missing or malformed
# GLB falls back to the primitive body. `moving` lists the bones each machine's work drives;
# `reach` is how far forward the hook or harpoon hangs at rest, in model metres.
const MODELS := {
	"rogue_crane": {"path": "res://assets/models/rogues/gate_crane.glb", "prefix": "GateCrane", "bone": "Crane",
		"moving": ["Hook", "Leaf"], "reach": 6.9},
	"rogue_skip": {"path": "res://assets/models/rogues/haul_skip.glb", "prefix": "HaulSkip", "bone": "Skip",
		"moving": ["Bucket", "Wheel0", "Wheel1", "Wheel2", "Wheel3"], "reach": 0.0},
	"rogue_tender": {"path": "res://assets/models/rogues/cable_tender.glb", "prefix": "CableTender", "bone": "Tender",
		"moving": ["Spool", "Harpoon"], "reach": 6.0},
}
const MODEL_PARTS := {"Hull": "fleet_paint", "Armour": "part_state", "Core": "core_state"}
const MODEL_BONES := ["Body", "Governor", "PlateLeft", "PlateRight"]
const PLATE_OPEN := 1.0
const WHEEL_RADIUS := 0.63
const GOVERNOR_SPIN := 7.0

# Phase two (Andrew 19:02Z 23 Oct: mini-bosses have two phases, and phase two ratchets up).
# Below half health the machine turns: for TURN_SECONDS it shakes its governor up to speed,
# takes no damage and commits nothing (the transition beat, Andrew 19:11Z). Then it winds up
# faster, never under ChallengeDials.TELL_FLOOR, and its first attack chains into its second
# with no vented window: the crane bats the ball into the leaf's ring, the skip dumps where
# its haul ends, the tender whips the ball its harpoon reeled in. The chained attack is
# sound-cued: attack_cued sounds CUE_LEAD before its geometry commits. The turn publishes
# fight_phase_changed, and the anthem moves to the heavier variant id (`anthem_heavy`) on the
# next downbeat once that pack exists. These numbers mirror the shared fight-phase framework
# (combat/fight_phases.gd: MINI_TURN, TRANSITION_SECONDS, CUE_LEAD, CUED_TOTAL); the bus
# signals are guarded until it lands.
const PHASE_TWO_AT := 0.5
const PHASE_TWO_WIND := 0.75
const TURN_SECONDS := 2.0
const CUE_LEAD := 0.5
const CUED_TOTAL := CUE_LEAD + ChallengeDials.TELL_FLOOR
# Each attack's ATTACK_ROWS id, for the cue.
const ATTACK_IDS := {"sweep": "E34", "drop": "E35", "haul": "E36", "dump": "E37", "harpoon": "E38", "whip": "E39"}

enum State { STALK, WIND, STRIKE, WEAK, TURN, CUE }

var row := {}
var phase := 1
# The wind scale the current attack committed with: a phase change mid-wind-up waits for the
# next attack, so a committed wind-up never shortens.
var _attack_wind := 1.0
var site_scale := 1.0
var state := State.STALK
var attack := ""
var attacks := 0
# The ATTACK_ROWS id of the hit hit_player is emitting, for the RUN OVER cause line.
var landed_attack := ""
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
var _rig: Skeleton3D
var _bones := {}
var _out := 0.0
var _open := 0.0
var _spin := 0.0
var _roll := 0.0
var _tip := 0.0
var _lift := 0.0
var _last := Vector3.INF
# Each machine's lane and ring leads in seconds, read by its WindupRows row (E34 to E39):
# a lane hurts from its strike, a ring as it fills through wind and strike.
var wind_lane := 0.0
var wind_ring := 0.0

static var _model_warned := {}


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
	_set_leads()
	_build_body()
	_fit(1.0)


func _set_leads() -> void:
	for name in row.attacks:
		var beats: Dictionary = ATTACKS[name]
		var wind := float(beats.wind) * beat()
		if phase >= 2:
			wind = maxf(ChallengeDials.TELL_FLOOR, wind * PHASE_TWO_WIND)
		if String(beats.shape) == "ring":
			wind_ring = wind + float(beats.strike) * beat()
		else:
			wind_lane = wind


# The phase hook: phase 2 ratchets the machine up (see PHASE_TWO_AT). Entering a phase it is
# already in does nothing.
func enter_phase(next: int) -> void:
	if next <= phase:
		return
	phase = next
	_set_leads()
	_clear_telegraph()
	_out = 0.0
	if _hook != null:
		_hook.position = _hook_rest
	_enter(State.TURN)
	if is_instance_valid(_reaction_bus) and _reaction_bus.has_signal("fight_phase_changed"):
		_reaction_bus.fight_phase_changed.emit(kind, phase, 2)


# The turn takes no damage; the hit that crosses half health turns it.
func take_damage(amount: float) -> float:
	if state == State.TURN:
		return 0.0
	var removed := super.take_damage(amount)
	if not _dead and phase == 1 and hp <= max_hp * PHASE_TWO_AT:
		enter_phase(2)
	return removed


func _wind_scale() -> float:
	return PHASE_TWO_WIND if phase >= 2 else 1.0


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
	return String(row.anthem_heavy if phase >= 2 else row.anthem)


func state_name() -> String:
	return ["stalk", "wind", "strike", "weak", "turn", "cue"][state]


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
				_finish_strike()
		State.WEAK:
			_move(delta, Vector3.ZERO)
			if _clock >= WEAK_BEATS * beat():
				_enter(State.STALK)
		State.TURN:
			_move(delta, Vector3.ZERO)
			if _clock >= TURN_SECONDS:
				_enter(State.STALK)
		State.CUE:
			_move(delta, Vector3.ZERO)
			if _clock >= CUE_LEAD:
				_begin_attack(to_ball)


# A ring fills through its wind-up and strike and lands as it fills, as the miniboss's slam does.
func _is_ring() -> bool:
	return String(ATTACKS[attack].shape) == "ring"


func _seconds(part: String) -> float:
	var seconds := float(ATTACKS[attack][part]) * beat()
	if part == "wind" and _attack_wind < 1.0:
		seconds = maxf(ChallengeDials.TELL_FLOOR, seconds * _attack_wind)
	return seconds


# In phase two the first attack chains into the second; the second always vents.
func _finish_strike() -> void:
	if phase >= 2 and attack == String(row.attacks[0]):
		_clear_telegraph()
		_out = 0.0
		if _hook != null:
			_hook.position = _hook_rest
		var next := String(row.attacks[_next])
		if is_instance_valid(_reaction_bus) and _reaction_bus.has_signal("attack_cued"):
			_reaction_bus.attack_cued.emit(kind, ATTACK_IDS[next], CUED_TOTAL)
		_enter(State.CUE)
		if _core != null:
			_show_core()
		return
	_open_weak_window()


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
	_attack_wind = _wind_scale()
	var reach := 4.0
	match attack:
		"sweep":
			var swing := 2.0 * _size("length") / _seconds("strike")
			var aim := PackPressure.lead_aim(target, global_position, _seconds("wind"), swing, _size("reach") + 1.0, radius + Tuning.RADIUS) - global_position
			aim.y = 0.0
			_commit_lane(Threat.Type.LANE, global_position, aim if aim.length() > 0.5 else heading, _size("length"), _size("width"), reach)
		"haul", "harpoon":
			_commit_lane(Threat.Type.LANE, global_position, heading, _size("length"), _size("width"), reach)
		"drop":
			var at := PackPressure.lead_aim(target, global_position, _seconds("wind") + _seconds("strike"), 0.0, 0.0, radius + Tuning.RADIUS)
			_commit_ring(Threat.Type.PROJECTILE, at, _size("radius"), reach)
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
			_out = out
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
			_out = 1.0 - absf(1.0 - 2.0 * t)
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
	landed_attack = String(ATTACK_IDS.get(attack, ""))
	hit_player.emit(float(ATTACKS[attack].damage), direction * float(ATTACKS[attack].shove) + Vector3.UP * 4.0)


func _open_weak_window() -> void:
	_clear_telegraph()
	if _hook != null:
		_hook.position = _hook_rest
	_out = 0.0
	weak_windows += 1
	_enter(State.WEAK)


func _fill(value: float) -> void:
	var shown := telegraph()
	if shown != null:
		shown.set_progress(value)


# --- Body ---------------------------------------------------------------------------
# The sculpted GLB when it loads, else a primitive body (briefs in design-v3/rogues/BRIEFS.md).
# The primitive keeps its working silhouette, the crew number and HIRED stamp it was issued (principle 7,
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
	if _build_model():
		return
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


# The GLB's crew number, HIRED stamp, governor and cut line are baked into the hull, so the
# model adds no stamps or primitive parts.
func _build_model() -> bool:
	var scene := _model_scene(kind)
	if scene == null:
		return false
	var model: Dictionary = MODELS[kind]
	_base_color = Color.WHITE
	_material = Palette.solid(Color.WHITE)
	_material.vertex_color_use_as_albedo = true
	# No rim mask: the plates carry the plating colour on their albedo only.
	var plate_material := _plate_material(mask_texture([Color.BLACK], 1))
	_body.add_child(scene)
	_rig = scene.find_child("Skeleton3D", true, false) as Skeleton3D
	for part in MODEL_BONES + model.moving:
		_bones[part] = _rig.find_bone(String(model.bone) + part)
	for part in MODEL_PARTS:
		var mi := scene.find_child(String(model.prefix) + part, true, false) as MeshInstance3D
		match part:
			"Hull": mi.material_override = _material
			"Armour": mi.material_override = plate_material
			"Core":
				_core = mi
				mi.material_override = _core_material
	return true


static func _model_scene(model_kind: String) -> Node3D:
	var model: Dictionary = MODELS[model_kind]
	var path := String(model.path)
	var packed := load(path) as PackedScene if ResourceLoader.exists(path) else null
	var scene := packed.instantiate() as Node3D if packed != null else null
	if scene != null and _model_ok(scene, model):
		return scene
	if scene != null:
		scene.free()
	if not _model_warned.has(model_kind):
		push_warning("rogue: missing or malformed " + path + "; using primitive fallback")
		_model_warned[model_kind] = true
	return null


static func _model_ok(scene: Node3D, model: Dictionary) -> bool:
	var rig := scene.find_child("Skeleton3D", true, false) as Skeleton3D
	if rig == null:
		return false
	for part in MODEL_BONES + model.moving:
		if rig.find_bone(String(model.bone) + part) < 0:
			return false
	for part in MODEL_PARTS:
		var mi := scene.find_child(String(model.prefix) + part, true, false) as MeshInstance3D
		if mi == null or mi.mesh == null or mi.mesh.get_surface_count() != 1:
			return false
		var material := mi.mesh.surface_get_material(0)
		if material == null or material.resource_name != MODEL_PARTS[part] or (part != "Core" and mi.skin == null):
			return false
	return true


func _bone(part: String, offset: Vector3, turn := Quaternion.IDENTITY) -> void:
	var index: int = _bones[part]
	_rig.set_bone_pose_position(index, _rig.get_bone_rest(index).origin + offset)
	_rig.set_bone_pose_rotation(index, turn)


# The attack poses (ATTACK_ROWS E34 to E39) are this bone work: e34_hook_swing_out and
# e38_harpoon_run_out run the hook or harpoon down its lane, e35_leaf_hoist lifts the gate
# leaf through the wind-up and drops it, e36_skip_route_brace rolls the wheels down the haul,
# e37_bucket_tip tips the bucket, and e39_spool_wind spins the spool up for the whip.
# The work drives the bones: the hatch plates swing out from their outer hinges in the vented
# window, the governor spins while it runs the job, and each machine's tool does the attack's
# work. Visual only: the committed telegraph alone decides a hit.
func _pose_model(delta: float, blend: float) -> void:
	var weak := state == State.WEAK
	_open = lerpf(_open, PLATE_OPEN if weak else 0.0, blend)
	_bone("PlateLeft", Vector3.ZERO, Quaternion(Vector3.UP, -_open))
	_bone("PlateRight", Vector3.ZERO, Quaternion(Vector3.UP, _open))
	# The turn: the governor races and the hatch rattles as the machine takes its new pace.
	var turning := state == State.TURN
	if turning:
		_open = 0.25 + 0.15 * sin(_clock * 40.0)
		_bone("PlateLeft", Vector3.ZERO, Quaternion(Vector3.UP, -_open))
		_bone("PlateRight", Vector3.ZERO, Quaternion(Vector3.UP, _open))
	_spin = fmod(_spin + GOVERNOR_SPIN * delta * (0.3 if weak else (4.0 if turning else 1.0)), TAU)
	_bone("Governor", Vector3.ZERO, Quaternion(Vector3.UP, _spin))
	var shown := telegraph()
	var length: float = shown.length if shown != null and shown.shape == Telegraph.Shape.LANE else 0.0
	var reach := -maxf(0.0, _out * length / site_scale - float(MODELS[kind].reach))
	var fill := clampf(_clock / maxf(_seconds("wind"), 0.0001), 0.0, 1.0) if state == State.WIND else 0.0
	match kind:
		"rogue_crane":
			_bone("Hook", Vector3(0.0, 0.0, reach))
			var lift := 0.0
			if attack == "drop":
				lift = 1.2 * fill if state == State.WIND else (-1.4 if state == State.STRIKE else 0.0)
			_lift = lerpf(_lift, lift, blend)
			_bone("Leaf", Vector3(0.0, _lift, 0.0))
		"rogue_skip":
			var moved := global_position - _last if _last.is_finite() else Vector3.ZERO
			moved.y = 0.0
			_roll = fmod(_roll + moved.dot(-global_basis.z) / (WHEEL_RADIUS * site_scale), TAU)
			for wheel in ["Wheel0", "Wheel1", "Wheel2", "Wheel3"]:
				_bone(wheel, Vector3.ZERO, Quaternion(Vector3.RIGHT, -_roll))
			var tipped := attack == "dump" and state != State.STALK
			_tip = lerpf(_tip, (-0.7 * (fill if state == State.WIND else 1.0)) if tipped else 0.0, blend)
			_bone("Bucket", Vector3.ZERO, Quaternion(Vector3.RIGHT, _tip))
		"rogue_tender":
			_bone("Harpoon", Vector3(0.0, 0.0, reach))
			var reel := 3.0 if attack == "harpoon" and state == State.STRIKE else 1.0
			if attack == "whip" and state != State.STALK and state != State.WEAK:
				reel = 1.0 + 3.0 * (fill if state == State.WIND else 1.0)
			_roll = fmod(_roll + GOVERNOR_SPIN * 0.4 * reel * delta, TAU)
			_bone("Spool", Vector3.ZERO, Quaternion(Vector3.RIGHT, _roll))
	_last = global_position


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
	if _rig != null:
		_pose_model(delta, blend)
	for entry in _plates:
		var plate: MeshInstance3D = entry["node"]
		var side: float = entry["side"]
		var rest: Vector3 = entry["rest"]
		plate.position = plate.position.lerp(rest + Vector3(side * (0.9 if weak else 0.0), 0.0, 0.0), blend)
		plate.rotation.y = lerpf(plate.rotation.y, side * (0.9 if weak else 0.0), blend)
	_show_core()
	# A null or freed target leaves the facing where it is (F008).
	if not is_instance_valid(target):
		return
	# Vented, it holds still, so the ball can roll round to the hatch.
	if state == State.STALK or (state == State.WIND and attack != "whip"):
		var to := _flat_to_ball()
		var shown := telegraph()
		if state == State.WIND and shown != null:
			to = shown.dir if shown.shape == Telegraph.Shape.LANE else shown.global_position - global_position
			to.y = 0.0
		if to.length() > 0.5:
			rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-8.0 * delta))


# The core's size and colour for the state. The cue's beat calls it as it begins, so the twin shows on
# the same tick as the sound and not one physics tick later (_pose runs before the state machine).
func _show_core() -> void:
	var weak := state == State.WEAK
	var pulse := 1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.018) if weak else 1.0
	_core.scale = Vector3.ONE * (1.5 * pulse if weak else (1.3 if state == State.CUE else 1.0))
	_core.material_override = _weak_material() if weak else (_cue_material() if state == State.CUE else _core_material)


var _weak: StandardMaterial3D
var _cue: StandardMaterial3D


# The cue's twin (attack_cued, brass in event_kinds): over the CUE_LEAD beat the core burns brass
# and swells, so a muted player sees the chained strike coming. It is brass, not the vented
# window's live colour, so it never reads as a chance to hit.
func _cue_material() -> StandardMaterial3D:
	if _cue == null:
		_cue = Palette.solid(Palette.BRASS, 1.0)
	_cue.emission_energy_multiplier = FlashGuard.spike(1.2, 4.0)
	return _cue


func cue_showing() -> bool:
	return state == State.CUE and _core != null and _core.material_override == _cue


func _weak_material() -> StandardMaterial3D:
	if _weak == null:
		_weak = Palette.solid(Palette.live(), 1.0)
	_weak.emission_energy_multiplier = FlashGuard.spike(1.2, 4.0)
	return _weak
