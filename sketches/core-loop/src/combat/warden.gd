extends "res://src/combat/enemy.gd"

# The fastest the body may read as moving while mounted, m/s.
const MOUNT_SPEED_MAX: float = preload("res://src/movement/contact.gd").SOFT_CAP_SPEED
const ChaseCamera := preload("res://src/movement/chase_camera.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const WardenLook := preload("res://src/combat/warden_look.gd")
const WardenKit := preload("res://src/combat/warden_kit.gd")
const Roster := preload("res://src/combat/roster.gd")
const Habits := preload("res://src/combat/habits.gd")
const BossPosture := preload("res://src/combat/boss_posture.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const Augments := preload("res://src/movement/augments.gd")
const MonsterHeft := preload("res://src/combat/monster_heft.gd")

# The Warden: one per stage, an immobile clamp at the base of the beacon mast. Breaking
# it is the stage's one MUST (DEMO-SPEC). It never moves, never pins, never pushes you
# sideways. Every Warden fights on posture (boss_posture.gd): hits fill a posture bar, a
# full bar staggers the Warden for STAGGER_SECONDS and opens its core, and only a contact
# on the open core removes health, one chunk of four per stagger. Plating is the stage's
# number, read by the posture rule for its glance line. The plating fight (caps, magnet,
# mind brace, shred, the 20% chip) was retired once every Warden fought on posture.
#
# - The pulse. While you are inside its reach (the beacon ring), it charges for
#   PULSE_TELEGRAPH seconds every PULSE_CYCLE, showing a ring the size of its reach and
#   a small core ring. Then it pulses: a ball the reach ring contains gains PULSE_LIFT
#   m/s straight up for one tick, horizontal speed untouched, and a ball the core ring
#   contains also takes PULSE_DAMAGE. The pulse pauses in a stagger and a charge in
#   flight is cancelled.
# - The family kit (DESIGN-V2 section 11) is the shared clamp's look: reactor vents on the
#   pulse, the swarm keeps a guard rack of drones that pays GUARD_RACK_POSTURE once for
#   the cruise-or-faster ram that scatters it (reform and respawn on GUARD_RESPAWN), the
#   mind's lens follows you and opens on a stagger.
# - The variant (a stage row's "warden_variant", through fleet.dress) changes one thing
#   per family; "" changes nothing. meltdown (reactor): every vent pulse leaves a slag
#   lane toward the ball that burns a grounded ball, and the core window lasts
#   MELTDOWN_WINDOW times longer. brood (swarm): the guard is a lamp_swarm once that
#   enemy is built, else the drone rack. choir (mind): the open lens moves among three
#   seats every ADAPT_CYCLE and a stagger braces against the ball's top habit, as a
#   Mind hand does. The point keeps the name "lens"; drawing three lenses is
#   warden_kit's job and is not done here.
# - The harpoon anchor (PARK.md section 7, unit KF1). Three hardpoints take the bite and
#   a line on one rides as a world line that follows the body (augments.gd anchor_line),
#   never dropping inside the minimum rope. The mounting is the stage's (MOUNTINGS, by
#   family and variant). The spec's "hardpoints" is a count, as in the park row
#   (park_schema.gd WARDEN_FIELDS): the first n of HARDPOINTS; "hardpoint_offsets" names
#   them outright. A per-kind driver (spec "mount_driver" or set_mount_driver)
#   moves the body from its home, and the rope carries the ball at anchor_velocity. Once
#   per pulse cycle the lined hardpoint flares through the charge and the pulse shrugs the
#   line off, shrug_delay seconds late (the island's swing); the ball keeps its velocity.
#   A stagger cancels the charge, so every hardpoint holds through it.
#   A Warden is an anchor only when its spec says "harpoon_anchor": true (unit KF1b; the
#   park loader sets it beside landmark.warden, whose "anchor" is a position, so the key
#   differs); the authored boss arenas' Wardens are not, so their fights are unchanged. Ctrl on an anchor line hauls only inside the stagger
#   (Augments.haul_open). The flare is picked once per charge, and the shrug cuts only the
#   flaring hardpoint's line; the flare goes out when that line does.
# - The per-kind hook (KF1, widened 2026-10-11 for KF2 to KF4). The driver must answer
#   mount_offset(warden, clock) -> Vector3 and may answer step(warden, delta) every physics
#   tick after the body moved, idle(warden) on a tick the fight is not in play (no step runs then),
#   charge_allowed(warden) -> bool before a charge starts (false
#   lets the pulse clock run and starts no charge), on_charge(warden, seconds), on_pulse(warden,
#   lifted), on_stagger(warden, open), on_chunk_lost(warden, left) and on_exit(warden) as the
#   Warden leaves the tree (a kill or a stage unload), so a driver frees what it drew outside
#   the Warden; each is called only
#   when the driver has it. A park Warden (spec "harpoon_anchor": true) that names no
#   "mount_driver" loads res://src/combat/warden_<family>.gd when that file exists, so a
#   kind's file attaches itself to every park Warden of its kind and to none of the authored
#   boss arenas (KF2 to KF4 write those files; _kind_driver below). A driver may also answer
#   lane_origin(warden) -> Vector3, where a meltdown slag lane is laid from (KF2c); without it the
#   lane starts at the body, and the windup, strike and recover facts publish "at" the lane's origin.

# The counter-pulse's hit, apart from hit_player so the combat layer records it as "warden_counter".
signal counter_hit(amount: float, shove: Vector3)

const HALF_HEIGHT := 1.6
const RADIUS := 2.8
const DEFAULT_REACH := 30.0
const PULSE_CYCLE := 6.0
const PULSE_TELEGRAPH := 2.0
const PULSE_LIFT := 10.0
const PULSE_DAMAGE := 10.0
# The least rest between a pulse and the next charge however far the cycle has ratcheted (cycle_now).
const REST_FLOOR := 1.0
const CORE_RADIUS := 6.0
const LIFT_REACH_UP := 8.0
const GUARD_RESPAWN := 10.0
const GUARD_OFFSET := 9.0
const GUARD_RACK_POSTURE := 25.0
# The most posture a held Warden shows: floors to 99 on the bar, below the stagger line.
const HOLD_CAP := BossPosture.FULL - 0.5
const FAMILY_POINT_RADIUS := 1.3
const FAMILY_REACH := 3.2
const FAMILY_POINTS := {Roster.REACTOR: "core", Roster.SWARM: "queen", Roster.MIND: "lens"}
const CONTACT_KINDS := ["stomp", "slam"]
const VARIANTS := ["", "meltdown", "brood", "choir"]
const VARIANT_FAMILIES := {"meltdown": Roster.REACTOR, "brood": Roster.SWARM, "choir": Roster.MIND}
const MELTDOWN_WINDOW := 1.5
const SLAG_LENGTH := 14.0
const SLAG_WIDTH := 4.0
const SLAG_SECONDS := 6.0
const SLAG_WARN := 1.0
const SLAG_DAMAGE := 4.0
# A ball in the air at most this high over a burning lane is jumping it (the codex's slag_hop).
const SLAG_HOP_HEIGHT := 8.0
const ADAPT_CYCLE := 8.0
const CHOIR_RADIUS := 1.6
const CHOIR_BRACE_MULT := 1.6
# The mounting each kind and variant fights from (PARK.md section 7 table); a row's
# "mounting" overrides it.
const MOUNTINGS := {"reactor:": "dam_face", "reactor:meltdown": "flume", "swarm:": "headframe",
		"swarm:brood": "sinkhole", "mind:": "under_island", "mind:choir": "spires"}
# Under the island the line drops when the swing stops, 1.2 s after the pulse (wardens/mind.md
# section 10, call 1); every other mounting drops it on the pulse.
const SHRUG_DELAYS := {"under_island": 1.2}
# The crown and the two flanks, from the body's centre; a mounting row may place its own.
# A bite closer than this to the body's centre is a lock's, which names no side.
const CENTRE_BITE := 0.5
const HARDPOINTS := [Vector3(0.0, HALF_HEIGHT, 0.0), Vector3(RADIUS, 0.0, 0.0), Vector3(-RADIUS, 0.0, 0.0)]

# Variant values already warned about, so a bad row warns once, not once per Warden.
static var warned_variants := {}
# The family driver scripts start loading on a worker when the first Warden is set up, so a later
# world's first Warden finds its script compiled: a main-thread load() of warden_swarm.gd was 20 ms
# of the Dig's entry tick (cloud, 13 Nov 2026).
static var _drivers_requested := false

var stage := 1
var reach := DEFAULT_REACH
var pulses := 0
# Counter-pulse rings committed (dial warden.counter_damage_by_stage); 0 at the defaults.
var counters := 0
# Whether the last pulse's reach ring contained the ball (and so lifted it).
var last_pulse_lifted := false
var min_pulse_telegraph := INF
var family := Roster.REACTOR
var fleet
var guard
var family_opens := 0
var variant := ""
# meltdown: [{from, dir, length, width, left, age, phase, instance, node}], newest last.
var slag_lanes: Array = []
# choir: the lens seat open now (0..2) and the strike kinds the stagger braces against.
var open_lens := 0
var braced_kinds: Array = []
# The harpoon anchor: the mounting id, the hardpoints as offsets from the body, the shrug's
# lateness, the per-kind driver ({mount_offset(warden, clock) -> Vector3} or null), where
# the body stands with no offset, how fast the mounting moves it, and the shrugs so far.
var mounting := ""
var hardpoints: Array = []
var pulse_radius := DEFAULT_REACH
var shrug_delay := 0.0
var mount_driver = null
var home := Vector3.ZERO
var mount_velocity := Vector3.ZERO
var shrugs := 0
var harpoon_anchor := false

var _pulse_clock := 0.0
var _lost_peak := 0
# The chunks lost when this pulse cycle started (cycle_now).
var _cycle_lost := 0
var _charging := false
var _charge_time := 0.0
var _core_ring: Node3D
# The counter-pulse (off at counter damage 0): seconds into this stagger, whether this stagger's
# counter is already committed, and its ring and charge.
var _stagger_time := 0.0
var _counter_spent := false
var _counter_ring: Node3D
var _counter_time := 0.0
var _since_pulse := INF
var _look: Node3D
var _kit: Node3D
var _guard_wait := 0.0
var _charge_len := PULSE_TELEGRAPH
var _posture: BossPosture
var _armed := 0.0
# How many on_struck calls are inside _apply_posture with a judged result (see _apply_posture). A depth, not a
# flag, so a strike nested inside another strike's posture cannot clear the outer one's mark.
var _judged := 0
var _guard_scatter_frame := -1
var _guard_paid_scatters := 0
var _slag_burn := 0.0
var _lens_clock := 0.0
var _mount_clock := 0.0
# The hardpoint flaring for this charge (-1 for none) and the seconds left on a late shrug.
var _flaring := -1
var _shrug_left := -1.0
# Whether this charge has picked its flare, so a re-bite after the flared line went cannot
# flare a second hardpoint late in the same charge.
var _flare_picked := false
# The hardpoint the current line bit (anchor_point), -1 before any bite.
var _bitten := -1


func setup(target_ref, terrain_ref, root_ref, live_ref: Callable, _threat: float, spec_ref := {}) -> void:
	_setup_common(target_ref, terrain_ref, root_ref, live_ref, spec_ref)
	_request_drivers()
	kind = "warden"
	stage = spec.get("stage", 1)
	reach = spec.get("reach", DEFAULT_REACH)
	pulse_radius = DEFAULT_REACH if spec.get("park_landmark", false) else reach
	family = spec.get("family", Roster.warden_family(stage))
	variant = _read_variant(String(spec.get("variant", "")))
	mounting = String(spec.get("mounting", MOUNTINGS.get(family + ":" + variant, "")))
	hardpoints = hardpoints_for(spec)
	shrug_delay = float(spec.get("shrug_delay", SHRUG_DELAYS.get(mounting, 0.0)))
	mount_driver = _driver_or_null(spec.get("mount_driver"))
	set_harpoon_anchor(anchor_from(spec))
	if mount_driver == null and harpoon_anchor and not spec.has("mount_driver"):
		mount_driver = _kind_driver()
	var numbers: Dictionary = spec.get("posture", {})
	if variant == "meltdown" and not numbers.has("stagger_seconds"):
		numbers = numbers.duplicate()
		numbers["stagger_seconds"] = BossPosture.STAGGER_SECONDS * MELTDOWN_WINDOW
	_posture = BossPosture.new(numbers)
	faction = family
	fleet = spec.get("fleet")
	if family == Roster.SWARM and fleet != null:
		fleet.events().enemy_struck.connect(_on_guard_struck)
	plating = spec.get("plating", 30.0)
	_set_health(spec.get("hp", 400.0))
	scrap_value = 30 * stage
	weight = 1000.0
	radius = RADIUS
	half_height = HALF_HEIGHT
	if spec.get("park_landmark", false) and spec.has("anchor"):
		var anchor: Array = spec["anchor"]
		global_position = Vector3(float(anchor[0]), float(anchor[1]), float(anchor[2]))
	else:
		global_position = Vector3(global_position.x, terrain.height(global_position.x, global_position.z) + HALF_HEIGHT, global_position.z)
	home = global_position
	_build_body()


func state_name() -> String:
	return "charging" if _charging else "idle"


func knock(_direction: Vector3, _force: float) -> void:
	pass


func seconds_since_pulse() -> float:
	return _since_pulse


func plating_for(hit_kind: String, part: String) -> float:
	if part == family_point() and family_open():
		return 0.0
	if family_open() and hit_kind in braced_kinds:
		return plating * CHOIR_BRACE_MULT
	return plating


func _read_variant(value: String) -> String:
	if value == "":
		return ""
	if value in VARIANTS and VARIANT_FAMILIES[value] == family:
		return value
	if not warned_variants.has(value):
		warned_variants[value] = true
		push_warning("warden: variant '%s' does not fit a %s Warden, reading it as ''" % [value, family])
	return ""


func weak_points() -> Array:
	var points := []
	if family_open():
		points.append({"id": family_point(), "at": family_point_at(), "radius": FAMILY_POINT_RADIUS})
	return points


# --- The family kit (v2 W7) ---------------------------------------------------------

# The kit's weak point, named by family, open for the length of a stagger.
func family_point() -> String:
	return FAMILY_POINTS.get(family, "core")


func family_point_at() -> Vector3:
	var at: Vector3 = global_position + (_kit.point_offset() if _kit != null else Vector3.UP * 4.0)
	if variant == "choir":
		at += (Vector3.RIGHT * CHOIR_RADIUS).rotated(Vector3.UP, open_lens * TAU / 3.0)
	return at


func family_open() -> bool:
	return _posture.staggered


# Swaps in a mounted posture, carrying the current one's script variables over.
func replace_posture(next) -> void:
	for property in _posture.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			next.set(property.name, _posture.get(property.name))
	next.mounted_warden = weakref(self)
	_posture = next


func on_guard_scattered(swarm, _at: Vector3) -> void:
	if swarm == guard and family == Roster.SWARM:
		_guard_scatter_frame = Engine.get_physics_frames()


# Both ball contacts and weapon knocks scatter before enemy_struck. Only the ram
# on that scatter's frame pays the rack, never a later hit on following drones.
func _on_guard_struck(enemy: Node3D, hit_kind: String, force: float) -> void:
	if hit_kind != "ram" or guard == null or not is_instance_valid(enemy):
		return
	if enemy.get("swarm") != guard or not guard.following() \
			or _guard_scatter_frame != Engine.get_physics_frames() or guard.scatters <= _guard_paid_scatters:
		return
	if SpeedTier.of(force, target.tuning.tier_cruise()) < SpeedTier.CRUISE:
		return
	_guard_paid_scatters = guard.scatters
	_apply_posture(judge_hit("guard_rack", 0.0, false, 0))


func _step_guard(delta: float) -> void:
	if fleet == null:
		return
	if guard != null and not guard.alive().is_empty():
		return
	# The first tick the brood's lamp guard is down; the respawn wait starts full.
	if guard != null and variant == "brood" and guard_kind() == "lamp_swarm" and _guard_wait >= GUARD_RESPAWN:
		fleet.discover("brood_dark", global_position)
	_guard_wait -= delta
	if _guard_wait > 0.0:
		return
	_guard_wait = GUARD_RESPAWN
	var out := flat_to_ball()
	var at := global_position + (out.normalized() if out.length() > 0.1 else Vector3.FORWARD) * GUARD_OFFSET
	guard = fleet.spawn_guard(global_position, terrain.drop_point(at.x, at.z, 1.4), guard_kind())
	_guard_scatter_frame = -1
	_guard_paid_scatters = 0


func guard_kind() -> String:
	if variant == "brood" and fleet != null and fleet.makes("lamp_swarm"):
		return "lamp_swarm"
	return "swarm_remnant"


func contact_part(ball: Vector3, hit_kind: String) -> String:
	if family_open() and family != Roster.MIND and hit_kind in CONTACT_KINDS \
			and Vector2(ball.x - global_position.x, ball.z - global_position.z).length() <= FAMILY_REACH:
		return family_point()
	return ""


func on_struck(hit_kind: String, part: String, result: Dictionary) -> void:
	if variant == "choir" and family_open() and not braced_kinds.is_empty() and not hit_kind in braced_kinds and fleet != null:
		fleet.discover("choir_switch", family_point_at())
	var weak_judge = spec.get("weak_judge")
	if weak_judge is Callable and weak_judge.is_valid() and not staggered():
		result = weak_judge.call(result, part, hit_kind)
	# The judge has answered: _apply_posture must not ask it again.
	_judged += 1
	_apply_posture(result)
	_judged -= 1


func _physics_process(delta: float) -> void:
	_update_flash(delta)
	_pose(delta)
	if not _in_play() or target == null:
		_hook("idle", [self])
		return
	_since_pulse += delta
	_step_mounting(delta)
	_hook("step", [self, delta])
	var inside := _flat_to_ball().length() <= reach
	_step_posture(delta)
	if family == Roster.SWARM:
		_step_guard(delta)
	_step_pulse(delta, inside)
	_step_shrug(delta)
	_step_slag(delta)
	_step_choir(delta)


# meltdown: a lane fills over SLAG_WARN, then burns a grounded ball it contains until it
# ages out. The lane publishes one attack (windup, strike, recover) as the W01 row, since
# the roster lookup in enemy.gd finds no row for a Warden; it keeps its own instance
# because the Warden's pulse owns the single _atk slot.
func _step_slag(delta: float) -> void:
	for lane in slag_lanes.duplicate():
		lane["left"] = float(lane["left"]) - delta
		lane["age"] = float(lane["age"]) + delta
		if lane["phase"] == PHASE_WINDUP:
			if is_instance_valid(lane["node"]):
				lane["node"].set_progress(float(lane["age"]) / SLAG_WARN)
			if float(lane["age"]) >= SLAG_WARN:
				_slag_phase(lane, PHASE_STRIKE)
		if float(lane["left"]) <= 0.0:
			_slag_phase(lane, PHASE_RECOVER)
			if is_instance_valid(lane["node"]):
				lane["node"].queue_free()
			slag_lanes.erase(lane)
	if slag_lanes.is_empty() or staggered() or target == null:
		_slag_burn = 0.0
		return
	var ball_state = target.get("state")
	if ball_state != null and not ball_state.on_floor() and fleet != null and _over_slag(_ball()):
		fleet.discover("slag_hop", _ball())
	if ball_state == null or not ball_state.on_floor() or not _slag_burns(_ball()):
		_slag_burn = 0.0
		return
	# One hit per SLAG_DAMAGE burned, so the burn is SLAG_DAMAGE a second without a hit
	# (and its interrupt) every tick.
	_slag_burn += SLAG_DAMAGE * delta
	if _slag_burn >= SLAG_DAMAGE:
		_slag_burn -= SLAG_DAMAGE
		hit_player.emit(SLAG_DAMAGE * ChallengeDials.stage_mult("warden.slag_damage", stage), Vector3.ZERO)


# True where a lane's footprint lies, by the lane node's own hit test, whether or not it
# has finished filling.
func in_slag(point: Vector3) -> bool:
	for lane in slag_lanes:
		var node = lane["node"]
		if is_instance_valid(node) and node.contains(Vector3(point.x, node.ground_under(node.terrain, point), point.z)):
			return true
	return false


# True where a lane that has finished filling contains the point.
func _slag_burns(point: Vector3) -> bool:
	for lane in slag_lanes:
		if lane["phase"] == PHASE_STRIKE and is_instance_valid(lane["node"]) and lane["node"].contains(point):
			return true
	return false


# True where a ball in the air hangs over a burning lane, low enough to be jumping it.
func _over_slag(point: Vector3) -> bool:
	for lane in slag_lanes:
		var node = lane["node"]
		if lane["phase"] != PHASE_STRIKE or not is_instance_valid(node):
			continue
		var ground: float = node.ground_under(node.terrain, point)
		if point.y - ground <= SLAG_HOP_HEIGHT and node.contains(Vector3(point.x, ground, point.z)):
			return true
	return false


func _slag_phase(lane: Dictionary, phase: String) -> void:
	if lane["phase"] == phase:
		return
	lane["phase"] = phase
	if phase == PHASE_STRIKE and not _dead:
		_strike_frames = STRIKE_FRAMES
	var node = lane["node"]
	var geometry: Dictionary = node.descriptor() if is_instance_valid(node) else {}
	attack_phase.emit({"instance": lane["instance"], "row": "W01", "owner": kind, "phase": phase,
		"committed": not geometry.is_empty(), "progress": 1.0 if phase != PHASE_WINDUP else 0.0,
		"geometry": geometry, "at": lane["from"]})


func _leave_slag() -> void:
	var origin := global_position
	if mount_driver != null and mount_driver.has_method("lane_origin"):
		origin = mount_driver.lane_origin(self)
	var out := Vector3.ZERO
	if target != null:
		var ball: Vector3 = target.ball_position()
		out = Vector3(ball.x - origin.x, 0.0, ball.z - origin.z)
	var dir := out.normalized() if out.length() > 0.1 else Vector3.FORWARD
	var node := Telegraph.lane(world_root, terrain, Threat.Type.LANE, origin, dir, SLAG_LENGTH, SLAG_WIDTH)
	node.set_progress(0.0)
	_attack_serial += 1
	var lane := {"from": origin, "dir": dir, "length": SLAG_LENGTH, "width": SLAG_WIDTH,
			"left": SLAG_SECONDS, "age": 0.0, "phase": "", "instance": _attack_serial, "node": node}
	slag_lanes.append(lane)
	_slag_phase(lane, PHASE_WINDUP)


# choir: the open lens moves to the next seat every ADAPT_CYCLE while the Warden stands.
func _step_choir(delta: float) -> void:
	if variant != "choir" or staggered():
		return
	_lens_clock += delta
	while _lens_clock >= ADAPT_CYCLE:
		_lens_clock -= ADAPT_CYCLE
		open_lens = (open_lens + 1) % 3


# --- The harpoon anchor (PARK.md section 7, unit KF1) ---------------------------------

# Where hardpoint `index` is now, in the world.
func hardpoint_at(index: int) -> Vector3:
	return global_position + (hardpoints[index] as Vector3)


# Where the line rides: the bitten hardpoint. At the bite (Augments.attach passes the line's
# origin `from`) a shot on the body takes the hardpoint nearest the bite; a lock bites the
# body's centre (harpoon.gd _lock), so it takes the hardpoint facing the ball. Later calls
# (Augments._follow) keep that hardpoint. A committed haul still homes on the bite itself.
func anchor_point(point: Vector3, from = null) -> Vector3:
	if from is Vector3:
		var bite := point - global_position
		_bitten = _nearest_hardpoint(bite if bite.length() > CENTRE_BITE else (from as Vector3) - global_position)
	if _bitten < 0 or _bitten >= hardpoints.size():
		_bitten = _nearest_hardpoint(point - global_position)
	return hardpoint_at(_bitten)


# How fast the anchor moves this tick; the rope carries the ball at it (Augments._ride_anchor).
func anchor_velocity() -> Vector3:
	return mount_velocity


# The hook's last view of the stagger and the chunk count, so on_stagger and on_chunk_lost
# fire once per change, on the frame of the hit or the tick that closed the stagger.
var _hook_staggered := false
var _hook_chunks := -1


# Calls the driver's optional `method` with `args` when it has one (see the header).
func _hook(method: String, args: Array) -> void:
	if mount_driver != null and mount_driver.has_method(method):
		mount_driver.callv(method, args)


# Whether the driver lets a charge start now; a driver without the method always does.
func _charge_allowed() -> bool:
	if mount_driver == null or not mount_driver.has_method("charge_allowed"):
		return true
	return mount_driver.charge_allowed(self) == true


func _hook_posture() -> void:
	if _hook_chunks < 0:
		_hook_chunks = _posture.chunks
	if _posture.staggered != _hook_staggered:
		_hook_staggered = _posture.staggered
		_hook("on_stagger", [self, _hook_staggered])
	if _posture.chunks < _hook_chunks:
		_hook_chunks = _posture.chunks
		_hook("on_chunk_lost", [self, _hook_chunks])
	_hook_chunks = _posture.chunks


static func _driver_path(fam: String) -> String:
	return "res://src/combat/warden_%s.gd" % fam


static func _request_drivers() -> void:
	if _drivers_requested:
		return
	_drivers_requested = true
	for fam in Roster.WARDEN_FAMILIES:
		var path := _driver_path(fam)
		if ResourceLoader.exists(path) and not ResourceLoader.has_cached(path):
			ResourceLoader.load_threaded_request(path)


# The kind's own driver file, once KF2 to KF4 have written it; no file is no driver.
func _kind_driver():
	var path := _driver_path(family)
	if not ResourceLoader.exists(path):
		return null
	var script = load(path)
	if not script is GDScript:
		return null
	return _driver_or_null(script.new())


# The per-kind hook: an object with mount_offset(warden, clock) -> Vector3, the body's
# offset from home at that mounting clock; null stands the body at home.
func set_mount_driver(driver) -> void:
	mount_driver = _driver_or_null(driver)
	_mount_clock = 0.0


# Whether a spec opts this Warden in as a harpoon anchor: only a literal true does.
static func anchor_from(spec_in: Dictionary) -> bool:
	var value = spec_in.get("harpoon_anchor", false)
	return value is bool and value


func set_harpoon_anchor(on: bool) -> void:
	harpoon_anchor = on
	if on:
		add_to_group(Augments.ANCHOR_GROUP)
	elif is_in_group(Augments.ANCHOR_GROUP):
		remove_from_group(Augments.ANCHOR_GROUP)


# Park data reaches the spec as JSON, so a driver is kept only if it can answer mount_offset.
static func _driver_or_null(driver):
	if is_instance_valid(driver) and driver.has_method("mount_offset"):
		return driver
	return null


# The hardpoint the ball's line is on, or -1.
func lined_hardpoint() -> int:
	var kit = target.get("kit") if target != null else null
	if kit == null or not kit.hooked or not kit.on_body or kit.anchor_body != self:
		return -1
	# A committed haul homes on its bite, off the hardpoints, so the shrug leaves it be.
	if kit.line_state != Augments.LINE_LATCHED or _bitten >= hardpoints.size():
		return -1
	return _bitten


# How brightly the lined hardpoint flares: the charge's fill, then full while a late shrug
# waits; 0 when nothing flares. Read by the look.
func shrug_flare() -> float:
	if _flaring < 0:
		return 0.0
	return 1.0 if _shrug_left >= 0.0 else maxf(charge_fraction(), 0.01)


func flaring_hardpoint() -> int:
	return _flaring


# The hardpoint offsets a spec asks for: "hardpoint_offsets" if given, else the first
# "hardpoints" (a count, 1 to 3) of HARDPOINTS. Never empty. JSON brings offsets as arrays
# of three numbers; those become Vector3 and any other entry is dropped.
static func hardpoints_for(spec_in: Dictionary) -> Array:
	var count_in = spec_in.get("hardpoints", HARDPOINTS.size())
	var count := HARDPOINTS.size()
	if count_in is int or count_in is float:
		count = clampi(int(count_in), 1, HARDPOINTS.size())
	var offsets_in = spec_in.get("hardpoint_offsets", HARDPOINTS.slice(0, count))
	var offsets: Array = []
	if offsets_in is Array:
		for entry in offsets_in:
			var point = _offset_of(entry)
			if point != null:
				offsets.append(point)
	if offsets.is_empty():
		return HARDPOINTS.duplicate()
	return offsets


static func _offset_of(entry):
	if entry is Vector3:
		return entry
	if entry is Array and entry.size() == 3:
		for n in entry:
			if not (n is int or n is float):
				return null
		return Vector3(float(entry[0]), float(entry[1]), float(entry[2]))
	return null


func _nearest_hardpoint(offset: Vector3) -> int:
	var best := 0
	for i in hardpoints.size():
		if offset.distance_to(hardpoints[i]) < offset.distance_to(hardpoints[best]):
			best = i
	return best


var _mount_home := Vector3.INF


# The mounting moves the body from home; the pulse rings committed this charge go with it.
func _step_mounting(delta: float) -> void:
	if mount_driver == null or delta <= 0.0:
		mount_velocity = Vector3.ZERO
		return
	_mount_clock += delta
	var offset = mount_driver.mount_offset(self, _mount_clock)
	if not offset is Vector3:
		mount_velocity = Vector3.ZERO
		return
	var before := global_position
	global_position = home + offset
	var shift := global_position - before
	# The first tick of a mounting, or one after home moved, jumps the body from wherever it stood
	# to the mount: that jump is a placement, not motion, and read as velocity it would fling a
	# ball latched on the anchor line (augments.gd _ride) by offset x 90 m/s.
	var placed := _mount_home != home or _mount_clock <= delta
	_mount_home = home
	# An authored offset that jumps mid-mounting is a placement too; no real mount moves faster
	# than the contact soft cap, and a faster read would fling a latched ball the same way.
	mount_velocity = Vector3.ZERO if placed else (shift / delta).limit_length(MOUNT_SPEED_MAX)
	var flat := Vector3(shift.x, 0.0, shift.z)
	if flat.length_squared() > 0.0:
		_carry_ring(telegraph(), flat)
		_carry_ring(_core_ring, flat)


func _carry_ring(ring: Node3D, flat: Vector3) -> void:
	if not is_instance_valid(ring):
		return
	ring.center += flat
	ring.global_position += flat


# A late shrug counts down after its pulse; a stagger cancels it. The flare goes out, and
# no shrug comes, once the flaring hardpoint's line is gone.
func _step_shrug(delta: float) -> void:
	if _flaring >= 0 and lined_hardpoint() != _flaring:
		_flaring = -1
		_shrug_left = -1.0
	if _shrug_left < 0.0 or staggered():
		return
	_shrug_left -= delta
	if _shrug_left <= 0.0:
		_shrug()


# The pulse shrugs the line off the flaring hardpoint. The ball keeps its velocity: the line
# is cut, nothing else, and the pulse's lift has already been given.
func _shrug() -> void:
	var flared := _flaring
	_flaring = -1
	_shrug_left = -1.0
	if flared < 0 or lined_hardpoint() != flared or not target.has_method("cut_line"):
		return
	target.cut_line("shrugged")
	shrugs += 1


# The pulse cycle runs while you are in reach; once charging starts it is committed and
# lands even if you leave, but only a ball its rings contain feels it.
func _step_pulse(delta: float, inside: bool) -> void:
	if staggered():
		_step_counter(delta)
		return
	_end_counter()
	if _charging:
		_charge_time += delta
		if _flaring < 0 and not _flare_picked:
			_flaring = lined_hardpoint()
			_flare_picked = _flaring >= 0
		var ring := telegraph()
		if ring != null:
			ring.set_progress(_charge_time / _charge_len)
		if is_instance_valid(_core_ring):
			_core_ring.set_progress(_charge_time / _charge_len)
		if _charge_time >= _charge_len:
			_pulse()
		return
	if not inside:
		return
	_pulse_clock += delta
	if _pulse_clock >= cycle_now() - pulse_telegraph(stage) and _charge_allowed():
		_charging = true
		_charge_time = 0.0
		_charge_len = pulse_telegraph(stage)
		_flaring = lined_hardpoint()
		_flare_picked = _flaring >= 0
		_commit_ring(Threat.Type.INSTANT, global_position, pulse_radius, LIFT_REACH_UP, Palette.SAND)
		_core_ring = Telegraph.ring(world_root, terrain, Threat.Type.INSTANT, global_position, CORE_RADIUS)
		_core_ring.owner_voice = String(Roster.faction(family)["voice"]) if family != Roster.MIND else ""
		if family == Roster.REACTOR and fleet != null:
			fleet.events().vent_charging.emit(global_position, _charge_len)
		_hook("on_charge", [self, _charge_len])


# Counter-pulse (challenge dial warden.counter_damage_by_stage > 0): once per stagger, counter_delay
# seconds in, the core ring is committed again and charges for counter_telegraph seconds. If it lands
# with the ball inside it hits for the counter damage and lifts like the pulse. A stagger that ends first
# cancels it. It leaves the stagger, the posture and the pulse clock alone.
func _step_counter(delta: float) -> void:
	if counter_damage(stage) <= 0.0 and not is_instance_valid(_counter_ring):
		return
	_stagger_time += delta
	if is_instance_valid(_counter_ring):
		_counter_time += delta
		var charge := counter_telegraph(stage)
		_counter_ring.set_progress(_counter_time / charge)
		if _counter_time >= charge:
			if not _dead:
				_strike_frames = STRIKE_FRAMES
			if _counter_ring.contains(_ball()):
				target.crowd_control("warden_counter", Vector3.UP * PULSE_LIFT / get_physics_process_delta_time())
				counter_hit.emit(counter_damage(stage), Vector3.ZERO)
			_cancel_counter()
		return
	if _counter_spent or _stagger_time < counter_delay(stage):
		return
	_counter_spent = true
	_counter_time = 0.0
	counters += 1
	_counter_ring = Telegraph.ring(world_root, terrain, Threat.Type.INSTANT, global_position, CORE_RADIUS)
	_counter_ring.owner_voice = String(Roster.faction(family)["voice"]) if family != Roster.MIND else ""
	if family == Roster.REACTOR and fleet != null:
		fleet.events().vent_charging.emit(global_position, counter_telegraph(stage))


# The stagger is over (or never was): drop an unlanded ring and re-arm for the next stagger.
func _end_counter() -> void:
	_cancel_counter()
	_stagger_time = 0.0
	_counter_spent = false


func _cancel_counter() -> void:
	if is_instance_valid(_counter_ring):
		_counter_ring.queue_free()
	_counter_ring = null


static func counter_damage(at_stage := 0) -> float:
	return ChallengeDials.by_stage_or("warden.counter_damage_by_stage", at_stage, 0.0)


# Never under the boss tell floor, whatever the dial says.
static func counter_telegraph(at_stage := 0) -> float:
	return maxf(ChallengeDials.TELL_FLOOR, ChallengeDials.by_stage_or("warden.counter_telegraph_by_stage", at_stage, 0.8))


static func counter_delay(at_stage := 0) -> float:
	return ChallengeDials.by_stage_or("warden.counter_delay_by_stage", at_stage, 1.0)


# Challenge dial warden.pulse_cycle_mult: the pulse cycle never drops under the boss tell floor,
# and the telegraph is PULSE_TELEGRAPH, never longer than the cycle. at_stage is the Warden's stage
# for warden.pulse_cycle_by_stage; the default 0 (a caller with no Warden) reads that list as 1.0.
static func pulse_cycle(at_stage := 0) -> float:
	return ChallengeDials.floored(PULSE_CYCLE, ChallengeDials.stage_mult("warden.pulse_cycle", at_stage))


# The most chunks this Warden has lost at once, by the count its fight phases read (phase_chunks_left).
# It never goes back: the dam's bar can drain, and its fight does not relax with it.
func chunks_lost() -> int:
	_lost_peak = maxi(_lost_peak, BossPosture.CHUNKS - phase_chunks_left())
	return _lost_peak


# The pulse cycle this Warden runs now (W1-67): the stage's cycle times the stage's ratchet
# (challenge dial warden.pulse_ratchet_by_stage) once per chunk lost, as the fight phases count
# chunks (phase_chunks_left, so the dam's sheet counts its bar's quarters). The count is read when
# the pulse clock starts a cycle (_cycle_lost), so a chunk lost mid-cycle tightens the next cycle,
# never the one running, and the charge it starts keeps its whole tell. The rest between pulses
# never drops under REST_FLOOR, or under a mount driver's own rest_floor (the dam's sheet runs out).
func cycle_now() -> float:
	var base := pulse_cycle(stage)
	var rest := REST_FLOOR
	if mount_driver != null and mount_driver.has_method("rest_floor"):
		rest = maxf(rest, mount_driver.rest_floor(self))
	var ratchet := ChallengeDials.by_stage_or("warden.pulse_ratchet_by_stage", stage, 1.0)
	return maxf(minf(base, pulse_telegraph(stage) + rest), base * pow(ratchet, _cycle_lost))


static func pulse_telegraph(at_stage := 0) -> float:
	return minf(PULSE_TELEGRAPH, pulse_cycle(at_stage))


func _pulse() -> void:
	var ball := _ball()
	var ring := telegraph()
	last_pulse_lifted = ring != null and ring.contains(ball)
	if last_pulse_lifted:
		target.crowd_control("warden_pulse", Vector3.UP * PULSE_LIFT / get_physics_process_delta_time())
	# The core ring's landing (it reached progress 1 this tick): the body wears the release flash.
	if is_instance_valid(_core_ring) and not _dead:
		_strike_frames = STRIKE_FRAMES
	if is_instance_valid(_core_ring) and _core_ring.contains(ball):
		hit_player.emit(PULSE_DAMAGE * ChallengeDials.stage_mult("warden.pulse_damage", stage), Vector3.ZERO)
	if _flaring >= 0:
		_shrug_left = shrug_delay
		if shrug_delay <= 0.0:
			_shrug()
	pulses += 1
	if family == Roster.REACTOR:
		if fleet != null:
			fleet.events().vent_erupted.emit(global_position)
		if variant == "meltdown":
			_leave_slag()
	min_pulse_telegraph = minf(min_pulse_telegraph, _charge_time)
	_since_pulse = 0.0
	_charging = false
	_pulse_clock = 0.0
	_cycle_lost = chunks_lost()
	_clear_telegraph()
	if is_instance_valid(_core_ring):
		_core_ring.queue_free()
	_core_ring = null
	_hook("on_pulse", [self, last_pulse_lifted])


func _exit_tree() -> void:
	super._exit_tree()
	_cancel_counter()
	_hook("on_exit", [self])
	if is_instance_valid(_core_ring):
		_core_ring.queue_free()
	for lane in slag_lanes:
		if is_instance_valid(lane["node"]):
			lane["node"].queue_free()


func _build_body() -> void:
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = RADIUS
	cylinder.height = HALF_HEIGHT * 2.0
	shape.shape = cylinder
	add_child(shape)
	# Everything seen is in warden_look.gd and collides with nothing; this node keeps the
	# collider above and every number the fight uses.
	_look = WardenLook.new()
	add_child(_look)
	_look.build(self, HALF_HEIGHT)
	_kit = WardenKit.new()
	add_child(_kit)
	_kit.build(self, family)
	_base_color = Palette.CHARCOAL
	_material = _look.body_material
	fit_camera_shell()


# The widest camera drum that a ball touching the contact cylinder leaves clear of the arm's probe: the ball's centre
# sits RADIUS + the ball's radius from the axis, and a cast that starts inside a shape skips it. The drawn body may stand
# up to about 0.4 m outside the drum on its widest parts.
static func camera_shell_reach() -> float:
	return RADIUS + Tuning.RADIUS - ChaseCamera.PROBE_RADIUS - 0.05


# A camera-only drum round what the Warden draws now, so the lens never sits inside its body. The contact
# cylinder and the weak-point sphere are damage geometry and stay as they are. Sized from the drawn meshes
# (those still on a render layer, outside the floating badge), so the primitive look, the clamp base and a
# hero body each get their own: built with the look, refitted by hero_assets once it has dressed the body.
func fit_camera_shell() -> void:
	# The mind hangs and sprawls (a 12 m reach), so no cylinder fits it; a shell that big would wall off the air
	# round it. The camera meets it as it did before.
	if family == Roster.MIND:
		var old := get_node_or_null("CameraShell")
		if old != null:
			old.queue_free()
		return
	var inverse := global_transform.affine_inverse()
	var badge := _look.get_node_or_null("Badge")
	var box := AABB()
	var any := false
	for view in find_children("*", "MeshInstance3D", true, false):
		var mesh := view as MeshInstance3D
		if mesh.mesh == null or mesh.layers == 0 or not mesh.is_visible_in_tree() or (badge != null and badge.is_ancestor_of(mesh)):
			continue
		var local: AABB = inverse * mesh.global_transform * mesh.get_aabb()
		box = local if not any else box.merge(local)
		any = true
	var shell := get_node_or_null("CameraShell")
	if not any:
		if shell != null:
			shell.queue_free()
		return
	var radius := 0.0
	for corner in 8:
		var point: Vector3 = box.get_endpoint(corner)
		radius = maxf(radius, maxf(absf(point.x), absf(point.z)))
	radius = minf(radius, camera_shell_reach())
	if shell == null:
		shell = ChaseCamera.camera_body()
		shell.name = "CameraShell"
		shell.add_child(CollisionShape3D.new())
		add_child(shell)
	var drum := CylinderShape3D.new()
	drum.radius = radius
	drum.height = box.size.y
	(shell.get_child(0) as CollisionShape3D).shape = drum
	shell.position = Vector3(0.0, box.get_center().y, 0.0)


func _pose(_delta: float) -> void:
	pass


func _process(delta: float) -> void:
	if _look != null:
		_look.update(delta)
	if _kit != null:
		_kit.update(delta)


# --- Read by the look --------------------------------------------------------------

func charge_fraction() -> float:
	return clampf(_charge_time / _charge_len, 0.0, 1.0) if _charging else 0.0


func flat_to_ball() -> Vector3:
	return _flat_to_ball() if target != null else Vector3.ZERO


# --- The posture fight (boss_posture.gd) --------------------------------------------

func fight() -> String:
	return "posture"


func posture() -> float:
	return _posture.posture


func staggered() -> bool:
	return _posture.staggered


func stagger_left() -> float:
	return _posture.stagger_left


func chunks_left() -> int:
	return _posture.chunks


# The chunks the park's fight phases read as left (world.gd pulses chunk_N from them). A mount driver
# whose rule breaks every chunk in one hit (the dam's sheet rams) reports posture quarters instead.
func phase_chunks_left() -> int:
	if mount_driver != null and mount_driver.has_method("phase_chunks_left"):
		return mount_driver.phase_chunks_left(self)
	return chunks_left()


# Hits the rule counted as glances so far.
func glances() -> int:
	return _posture.glances


func chunk_cracked() -> bool:
	return _posture.cracked


# What the rule says a hit does. The judge meets the plating this kind and part meet
# (plating_for: the choir brace, the open point), so combat.resolve passes the part (F004).
func judge_hit(hit_kind: String, punch: float, smash: bool, tier: int, part := "") -> Dictionary:
	_posture.set_monster(monster_build())
	var result := _posture.judge({"kind": hit_kind, "punch": punch, "plating": plating_for(hit_kind, part), "smash": smash, "tier": tier,
			"charging": _charging, "frame": Engine.get_physics_frames(), "hp": hp, "max_hp": max_hp, "point": family_point()})
	if hit_kind == "guard_rack":
		# A rack is posture pressure, not a contact on the core. Keep judge/apply's
		# stagger and shatter-frame boundaries while fixing its gain independently of heft.
		result["gain"] = GUARD_RACK_POSTURE if not staggered() and Engine.get_physics_frames() != _posture.shatter_frame else 0.0
		result["glance"] = false
		result["full"] = true
	return result


# The run's heft: from the fleet's run, else from a spec "heft" Callable (an arena Warden has no
# fleet: the stub boss hands one in), else 0.0, so a Warden with no heft source is never a monster.
func pilot_heft() -> float:
	var run = fleet.ctx.run if fleet != null and fleet.ctx != null else null
	if run != null and run.has_method("heft"):
		return float(run.heft())
	var source = spec.get("heft")
	if source is Callable and source.is_valid():
		return float(source.call())
	return 0.0


# The heft a pilot must be strictly above to be a monster build here: the spec's "monster_heft", else
# the library's top-bucket maximum for this fight's stage (MonsterHeft), else INF (never a monster).
func monster_threshold() -> float:
	var given = spec.get("monster_heft")
	if given is float or given is int:
		return float(given)
	var run = fleet.ctx.run if fleet != null and fleet.ctx != null else null
	if run != null and "stage" in run:
		return MonsterHeft.threshold_for_stage(int(run.stage))
	if spec.has("stage"):
		return MonsterHeft.threshold_for_stage(int(spec["stage"]))
	return INF


func monster_build() -> bool:
	return pilot_heft() > monster_threshold()


func _apply_posture(result: Dictionary) -> void:
	# A boss at weak-point dial 1 (spec "weak_judge_all") judges every posture hit, including one that skips
	# on_struck (the ultimate's set piece, ultimate.gd warden_posture). Off, this is never reached.
	if spec.get("weak_judge_all", false) and _judged == 0 and not _posture.staggered:
		var weak_judge = spec.get("weak_judge")
		if weak_judge is Callable and weak_judge.is_valid():
			result = weak_judge.call(result, "", "")
	# A boss module's phase-minimum hold (stub_boss.gd hold_active): the hit lands in full but the bar
	# stops at HOLD_CAP, so no stagger starts before the hold ends. A hit that would have gained still
	# restarts the drain clock, so a pressed bar stays full.
	var hold = spec.get("posture_hold")
	if hold is Callable and hold.is_valid() and not _posture.staggered and hold.call():
		result = result.duplicate()
		if float(result.get("gain", 0.0)) > 0.0:
			_posture.idle = 0.0
		result["gain"] = clampf(float(result.get("gain", 0.0)), 0.0, maxf(0.0, HOLD_CAP - _posture.posture))
		result["crack"] = false
		result["shatter"] = false
	# A park Warden's clamp (world/stage_locks.gd): shut, a hit lands and gains nothing, so the bar
	# stays where it is and no stagger opens the core until the clamp lets go.
	var gate = spec.get("posture_gate")
	if gate is Callable and gate.is_valid() and not _posture.staggered and gate.call():
		result = result.duplicate()
		result["gain"] = 0.0
		result["crack"] = false
		result["shatter"] = false
	var before := _posture_signature()
	var was_staggered := _posture.staggered
	var chunks_before: int = _posture.chunks
	_posture.apply(result, Engine.get_physics_frames())
	if _posture.chunks < chunks_before:
		_armed = float(result["dealt"])
		if fleet != null:
			fleet.discover("warden_shatter", global_position)
	if _posture.staggered and not was_staggered:
		_begin_stagger()
	_publish_posture(before)
	_hook_posture()


func _step_posture(delta: float) -> void:
	var before := _posture_signature()
	_posture.step(delta)
	if not _posture.staggered:
		braced_kinds = []
	_publish_posture(before)
	_hook_posture()


func _begin_stagger() -> void:
	_end_counter()
	_flaring = -1
	_shrug_left = -1.0
	_charging = false
	_charge_time = 0.0
	_pulse_clock = 0.0
	_cycle_lost = chunks_lost()
	_clear_telegraph()
	if is_instance_valid(_core_ring):
		_core_ring.queue_free()
	_core_ring = null
	family_opens += 1
	if variant == "choir" and fleet != null:
		var habit: String = fleet.habits.top()
		if habit != "":
			var brace: Dictionary = Habits.BRACES[habit]
			braced_kinds = brace["kinds"]
			fleet.mind_adapt(habit, String(brace["icon"]), family_point_at())
	if fleet != null:
		fleet.events().weak_point_opened.emit(family_point(), family_point_at(), _posture.stagger_seconds)


func _posture_signature() -> Array:
	return [floori(_posture.posture), _posture.staggered, _posture.chunks, _posture.cracked]


func _publish_posture(before: Array) -> void:
	if fleet != null and _posture_signature() != before:
		fleet.events().posture_changed.emit(self, _posture.posture, _posture.staggered)


# Health falls only by what the last shattering strike armed.
func take_damage(_amount: float) -> float:
	var armed := _armed
	_armed = 0.0
	return super.take_damage(armed)


func set_tint(_state: String) -> void:
	super.set_tint("")


func integrity() -> float:
	return clampf(hp / max_hp, 0.0, 1.0) if max_hp > 0.0 else 0.0
