extends Node

const Tuning := preload("res://src/movement/tuning.gd")
const Redline := preload("res://src/combat/redline.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const DamageNumbers := preload("res://src/presentation/damage_numbers.gd")
# How far above an enemy's origin its damage number starts (world units).
const NUMBER_LIFT := 1.6
const SimClock := preload("res://src/core/sim_clock.gd")
const Parts := preload("res://src/build/parts.gd")
const RewardGates := preload("res://src/build/reward_gates.gd")
const ItemGen := preload("res://src/build/item_gen.gd")
const Palette := preload("res://src/core/palette.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const Contact := preload("res://src/movement/contact.gd")
const Augments := preload("res://src/movement/augments.gd")

# Feel: squash and stretch, camera punches and kicks, hit-stop, the pylon's plant and
# eject, and (v3 W11) how a hit, a kill, a pickup, a dodge and a hit taken land. Every
# effect answers something that happened, reads the committed fact off the bus and never
# decides an outcome (TADR-008). How hard each fact lands is its EventKinds.JUICE row.
# Punches are short and the camera never leaves the ball, so juice never hides the next
# threat; kicks and squashes are camera and shell only, never the ball's velocity.

# Hit-stop (v3 W11): every landed hit stops for its damage band (the enemy_struck row:
# base + per damage point, clamped), crits and weak points multiply, a ram, stomp or
# slam adds. The hits of one frame coalesce into one stop, stops start STOP_GAP_MS
# apart and spend at most STOP_BUDGET_MS a second, so rapid fire and a Katamari
# roll-up tick instead of stutter. A deflected hit clanks and never stops. The spine
# caps a stop at 60 ms and refuses to stack; Engine.time_scale never touches velocity.
const SettingsStore := preload("res://src/ui/settings_store.gd")
# A reduced-motion hit-edge flash keeps this share of its alpha; the store owns the number.
const REDUCED_FLASH: float = SettingsStore.REDUCED_FLASH
const SPINE_CAP_MS := 60.0
# The most shake presentation asks of the camera on any frame, before the viewer's Screen
# shake row scales it. Every juice shake goes through request_shake, so stacked hits, blasts
# and any future row share this one ceiling. A start value (ror2/characters-and-feel: shake
# is capped per frame so a crowded fight stays readable); the crit row's 0.22 and the
# blast's 0.35 pass untouched.
const SHAKE_CAP := 0.5
# Hit-stop belongs to the attacker's own strike, so only these facts may freeze time. The
# list is closed: a fact naming the ball's motion, a roll, a dodge past an attack, a reward
# card or a beacon asks for a stop that is logged at zero and never sent, and so does any
# new fact nobody has listed (ror2/characters-and-feel: no hitstop on ball rolling;
# BIBLE: momentum is sacred). "test" and "comfort" are the names the presentation tests
# send straight to the budget.
const STRIKE_STOP_FACTS := ["enemy_struck", "boss_weak_point_hit", "multi_kill", "harpoon_bit", "test", "comfort"]
const STOP_FLOOR_MS := 4.0
const STOP_TRIM_FLOOR_MS := 8.0
# The harpoon biting a body stops time this long (LEGIBILITY section 3). A world latch sends none.
const BITE_STOP_MS := 40.0
const CONTACT_KINDS := ["ram", "stomp", "slam"]
# KNOCKBACK-FEEL: a ball contact's stop and shake follow its throw (Contact.ram_knock), not
# its damage, so a heft V slam lands bigger than a heft II one instead of both sitting at
# the damage cap. A throw of THROW_LO m/s (a cruise bump) or less asks for the low end, the
# knock ceiling for the high end; the spine's 60 ms cap and SHAKE_CAP still bound both. The
# throw only ever adds: a hit never stops or shakes less than its damage asked for, so a
# cruise bump lands as it did and only harder throws land harder.
const THROW_LO := 11.0
const THROW_STOP_MS := [22.0, 58.0]
const THROW_SHAKE := [0.2, 0.5]
# Bursts per frame, so a blast through a crowd costs a handful of emitters, not one each.
const MAX_BURSTS := 6
# The outline stays the collision ball's size at every heft class (DECISIONS "Fixed outline"):
# heft reads as panels, caps, modules and accretion chunks, never as whole-ball scale. The
# shell still springs (pickup pulses) but its resting target is 1.0 at every class.
const SHELL_PER_CLASS := 0.0
const SHELL_RATE := 9.0
# A pickup kicks the shell's spring outward this fast per unit of pulse: a heft gain.
const PULSE_SPEED := 9.0
# Pickups that land together add their kicks, and with no ceiling a brute's pile swelled the ball
# to twice its size (the PC's reel, 10 Nov 2026). Two limits hold any pile to a swell of a fifth
# and leave one pickup as it was: the spring never moves faster than PULSE_MAX of pulse, and a
# kick fades as the shell nears SHELL_SWING from rest on the kick's side.
const PULSE_MAX := 0.22
const SHELL_SWING := 0.15

# The squash spring: underdamped, so a landing squashes, overshoots into a stretch and
# settles in about a quarter second. Snappy on the hit, fluid on the way out.
const SPRING := 420.0
const DAMPING := 17.0
const MAX_SQUASH := 0.45
# The springs integrate in steps no longer than this, so one long frame (a stage load,
# a stall under a scaled time_scale) cannot blow them up: the squash spring's explicit
# step goes unstable near 0.1 s. At most MAX_SPRING_STEPS per frame.
const SPRING_STEP := 1.0 / 120.0
const MAX_SPRING_STEPS := 64

# Pad rumble (systems audit pass C; loops.md found no vibration call anywhere in src/). The
# hands' half of a fact, one row per fact: the weak (fast, light) and strong (slow, heavy)
# motor shares, 0 to 1, and how long. A row's strength scales by the caller's share (a ram by
# its throw, a hit taken by its damage). Start values for a PC pad check, not a feel verdict.
# Rumble follows the Screen shake comfort row until the settings form carries its own, so a
# player who stills the screen stills the pad too.
const RUMBLE := {
	"near_miss": {"weak": 0.6, "strong": 0.0, "ms": 60},
	"harpoon_bit": {"weak": 0.35, "strong": 0.1, "ms": 50},
	"ram": {"weak": 0.25, "strong": 0.55, "ms": 100},
	"slammed": {"weak": 0.2, "strong": 0.75, "ms": 150},
	"landed": {"weak": 0.0, "strong": 0.4, "ms": 80},
	"carved": {"weak": 0.35, "strong": 0.15, "ms": 70},
	"bumped": {"weak": 0.2, "strong": 0.6, "ms": 90},
	"player_hit": {"weak": 0.45, "strong": 0.7, "ms": 170},
	"multi_kill": {"weak": 0.4, "strong": 0.3, "ms": 90},
	"boss_weak_point_hit": {"weak": 0.5, "strong": 0.65, "ms": 120},
	"heft_class_changed": {"weak": 0.15, "strong": 0.5, "ms": 220},
	"beacon_unsealed": {"weak": 0.3, "strong": 0.85, "ms": 320},
	# The loops prototypes (docs/design/loops.md). Heat: a skim's tick, the redline buzz held
	# through the cook-off wait (redline.gd COOK_OFF_S), the blast's thump. Called Shot: a firm tap
	# at the call, a long thump on a met break.
	"heat_skim": {"weak": 0.6, "strong": 0.0, "ms": 60},
	"heat_redline": {"weak": 0.25, "strong": 0.0, "ms": Redline.COOK_OFF_S * 1000.0},
	"heat_blast": {"weak": 0.4, "strong": 1.0, "ms": 180},
	"shot_called": {"weak": 0.0, "strong": 0.5, "ms": 80},
	"call_met": {"weak": 0.0, "strong": 1.0, "ms": 250},
}
# A request weaker than the one still running is dropped, so a crowd of small facts never
# blurs the big one under them.
const RUMBLE_FLOOR := 0.05
# A carve's release plays at pitch 1 at the 14 m/s cruise, higher off a faster ride.
const CARVE_PITCH_SPEED := 14.0

var ctx
var player
var camera
# Siblings presentation hands over: audio for the crit ping, the multi-kill beat and the
# throw; vfx for the bursts, the chain pips and the edge flash. Either may be null.
var audio
var vfx
# [hook, fact] for every camera or time effect fired, for the tests and the notes.
var hook_log: Array = []
# [requested_seconds, sent_seconds or 0 when gated, fact, msec] for every hit-stop asked for.
var hit_stop_log: Array = []
# Swap for a recorder in tests; defaults to the spine's ctx.hit_stop.
var hit_stop_sink: Callable
# Resolves a strike the way combat does (ctx.spawner.resolve: dealt, punch, the plating
# the hit met, its part, whether it broke through). Without it a hit lands for its force.
var resolve_of: Callable
# The body plating of an enemy (ctx.spawner.plating_of), so a part softer than the body
# reads as a weak point.
var plating_of: Callable
# The HUD's damage-number layer (DamageNumbers.add), set by the HUD: key, value, world point,
# type, team, crit. A number is raised from the same hit the burst is drawn from, so the two
# share the crit decision and the colour table (SR6).
var number_sink: Callable
var shell := 1.0
# The viewer's comfort, from the pause menu: 1 is full, 0 is none.
var stop_scale := 1.0
var shake_scale := 1.0
# Multi-kill groups this run: [size, msec] each time a group reached 2, 4 or 8.
var multi_log: Array = []
# The last RUMBLE_LOG_CAP pad rumbles asked for: [fact, weak, strong, seconds, sent]. Tests and
# the census read it.
var rumble_log: Array = []
const RUMBLE_LOG_CAP := 512

var _squash := 0.0
var _squash_velocity := 0.0
var _axis := Vector3.UP
var _plant_t := -1.0
var _pylon_parts := {}
var _pylon_transform := Transform3D.IDENTITY
var _ghosts: Array = []
var _shell_velocity := 0.0
var _heft_class := 1
var _stops: Array = []
var _hits: Array = []
var _kills: Array = []
var _blasts: Array = []
var _flush_queued := false
var _multi_size := 0
var _multi_last := -100000
var _rumble_until := -1
var _rumble_weak := 0.0
var _rumble_strong := 0.0
var _rumble_fact := ""


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	name = "Juice"
	player = ctx.player
	camera = ctx.camera
	player.builtin_squash = false
	hit_stop_sink = ctx.hit_stop
	var events = ctx.events
	events.landed.connect(_on_landed)
	events.slammed.connect(_on_slammed)
	events.jumped.connect(_on_jumped)
	events.dashed.connect(_on_dashed)
	events.boosted.connect(_on_boosted)
	events.launched.connect(_on_launched)
	events.mounted.connect(_on_mounted)
	events.dismounted.connect(_on_dismounted)
	events.enemy_struck.connect(_on_enemy_struck)
	events.enemy_killed.connect(_on_killed)
	events.scrap_collected.connect(_on_scrap)
	events.player_hit.connect(_on_player_hit)
	events.shot_fired.connect(_on_shot)
	events.stage_entered.connect(func(_stage: int, _retry: bool): _reset())
	# Arena entry and the arena retry restore state without a stage_entered.
	for signal_name in ["stage_content_cleared", "boss_arena_entered"]:
		if events.has_signal(signal_name):
			var argc := SignalWire.arg_count(events, signal_name)
			events.connect(signal_name, _reset.unbind(argc) if argc > 0 else _reset)
	events.run_started.connect(func(_class_id: String): _heft_class = 1)
	_wire_loop_rumble(events)
	# A shut yard lifts the camera over its rim (chase_camera.gd "locked" row) until it opens.
	events.world_fact.connect(func(kind: String, at: Vector3):
		if camera != null and kind == "arena_locked":
			camera.set_lock(at)
		elif camera != null and kind == "arena_unlocked":
			camera.set_lock(null))
	# A yard also ends on these flow states with no arena_unlocked (stage_locks.gd _on_flow_changed).
	events.flow_changed.connect(func(state: String):
		if camera != null and state in ["gates", "launch", "summary", "title", "victory"]:
			camera.set_lock(null))
	if ctx.spawner != null and ctx.spawner.has_method("resolve"):
		resolve_of = Callable(ctx.spawner, "resolve")
	if ctx.spawner != null and ctx.spawner.has_method("plating_of"):
		plating_of = Callable(ctx.spawner, "plating_of")
	var charges = ctx.spawner.get("sticky") if ctx.spawner != null else null
	if charges != null and charges.has_signal("stuck"):
		charges.stuck.connect(_on_stuck)
	wire_optional()


func wire_optional() -> void:
	var events = ctx.events
	SignalWire.listen(events, "beacon_unsealed", _on_unsealed)
	SignalWire.listen(events, "heft_class_changed", _on_heft_class)
	SignalWire.listen(events, "heft_class_dropped", _on_heft_class)
	SignalWire.listen(events, "boss_weak_point_hit", _on_weak_point)
	SignalWire.listen(events, "enemy_rebounded", _on_rebounded)
	SignalWire.listen(events, "near_miss", _on_near_miss)
	SignalWire.listen(events, "scrap_lost", _on_scrap_lost)
	SignalWire.listen(events, "sticky_detonated", _on_detonated)
	SignalWire.listen(events, "rocket_jumped", _on_rocket_jumped)
	SignalWire.listen(events, "part_gained", _on_part)
	SignalWire.listen(events, "core_gained", _on_core)
	SignalWire.listen(events, "quick_break", _on_quick_break)
	SignalWire.listen(events, "harpoon_bit", _on_harpoon_bit)
	SignalWire.listen(events, "carved", _on_carved)
	SignalWire.listen(events, "bumped", _on_bumped)
	SignalWire.listen(events, "enemy_walled", _on_walled)


func _on_harpoon_bit(_enemy: Node3D, _at: Vector3) -> void:
	request_hit_stop(BITE_STOP_MS / 1000.0, "harpoon_bit")
	rumble("harpoon_bit")


# A carve let go: the grind's release in the ears and a tap in the hands, louder for a longer
# ride. The sparks while it rides are player_fx's; this is the moment it ends.
func _on_carved(_at: Vector3, seconds: float, speed: float) -> void:
	var share := clampf(seconds / 1.2, 0.4, 1.0)
	if audio != null:
		audio.play("carved", lerpf(-4.0, 0.0, share), clampf(speed / CARVE_PITCH_SPEED, 0.85, 1.25))
	rumble("carved", share)


# How far `speed` sits between a collision row's min_speed (0) and full_speed (1).
static func collision_share(row: Dictionary, speed: float) -> float:
	return clampf((speed - float(row["min_speed"])) / (float(row["full_speed"]) - float(row["min_speed"])), 0.0, 1.0)


static func _span(pair: Array, share: float) -> float:
	return lerpf(float(pair[0]), float(pair[1]), share)


# The ball hit a wall, cliff or structure side: a thud lower and louder with speed, the shell
# flattened against the face, the camera kicked into it, dust and chips off the face, and from
# shake_from up a shake and the pad. Camera, shell and sound only; the ball's bounce is physics'.
func _on_bumped(at: Vector3, normal: Vector3, speed: float) -> void:
	var row := EventKinds.juice("bumped")
	var share := collision_share(row, speed)
	squash(lerpf(0.12, float(row["squash"]), share), normal)
	_camera("kick", "bumped", -normal, float(row["kick"]) * share)
	if audio != null:
		audio.play("bumped", _span(row["db"], share), _span(row["pitch"], share))
	if vfx != null:
		vfx.play_fx("bumped", at, Color.TRANSPARENT, "", normal)
	if share >= float(row["shake_from"]):
		request_shake(float(row["shake"]) * share, 0.18, "bumped")
	rumble("bumped", maxf(share, 0.35))


# A thrown enemy stopped by a wall: its thud and dust where it struck, and a small shake when it
# struck near the ball. The stagger is the enemy's own (enemy.gd _wall_slam).
func _on_walled(_enemy: Node3D, at: Vector3, normal: Vector3, speed: float) -> void:
	var row := EventKinds.juice("enemy_walled")
	var share := collision_share(row, speed)
	if audio != null:
		audio.play("enemy_walled", _span(row["db"], share), _span(row["pitch"], share))
	if vfx != null:
		vfx.play_fx("enemy_walled", at, Color.TRANSPARENT, "", normal)
	if player != null and at.distance_to(player.shown_position()) <= float(row["near_m"]):
		request_shake(float(row["shake"]) * share, 0.15, "enemy_walled")


# The ball ran into a park prop (park_props.gd prop_kicked): its knock or clank, higher for a light one
# thrown, and a puff of dust where it stood. Sound and dust only; the prop's own move is prop_kicks.gd's.
func on_prop_kicked(at: Vector3, mode: String, speed: float, tags: Array) -> void:
	var row: Dictionary = EventKinds.juice("prop_kicked")[mode]
	var share := clampf((speed - 4.0) / 26.0, 0.0, 1.0)
	var metal := "machine" in tags or "sign" in tags
	var sound := String(row["metal"] if metal else row["sound"])
	if audio != null and sound != "":
		audio.play("prop_kicked", float(row["db"]) + 4.0 * share, _span(row["pitch"], share), "SFX", sound)
	if vfx != null:
		vfx.burst("dust", at - Vector3.UP * 0.4, EventKinds.color("landed"), int(row["dust"]))


func _reset() -> void:
	# A retry restores mass, so the shell follows the restored class.
	if ctx.run.has_method("heft_class"):
		_heft_class = int(ctx.run.heft_class())
	if camera != null:
		camera.set_lock(null)
	_squash = 0.0
	_squash_velocity = 0.0
	_plant_t = -1.0
	_hits.clear()
	_kills.clear()
	_blasts.clear()
	_multi_size = 0
	for ghost in _ghosts:
		if is_instance_valid(ghost["node"]):
			ghost["node"].queue_free()
	_ghosts.clear()


# The pause menu's comfort rows: "shake" scales every camera punch, kick and shake (the
# camera applies it), "hitstop" every stop and the dodge tick.
func set_comfort(id: String, level: float) -> void:
	level = clampf(level, 0.0, 1.0)
	match id:
		"shake":
			shake_scale = level
			if camera != null:
				camera.motion_scale = level
		"hitstop":
			stop_scale = level


# Reduced motion: the camera holds still and the hit-edge flash drops to a quarter; its notch
# toward the source stays at full strength (edge_flash.gd), so the direction still reads.
# Telegraph motion is not read here, so it keeps its timing.
func set_reduced_motion(on: bool) -> void:
	if camera != null:
		camera.reduced_motion = on
	if vfx != null and vfx.edge != null:
		vfx.edge.flash_scale = REDUCED_FLASH if on else 1.0


func comfort(id: String) -> float:
	return shake_scale if id == "shake" else stop_scale


# --- Squash and stretch -------------------------------------------------------------

func squash(amount: float, axis: Vector3) -> void:
	_squash = clampf(amount, -MAX_SQUASH, MAX_SQUASH)
	_squash_velocity = 0.0
	if axis.length_squared() > 0.01:
		_axis = axis.normalized()


# A pop of the shell's spring: positive swells (heft gained), negative shrinks (lost).
func pulse(amount: float) -> void:
	var room := clampf(1.0 - signf(amount) * (shell - shell_target()) / SHELL_SWING, 0.0, 1.0)
	_shell_velocity = clampf(_shell_velocity + amount * room * PULSE_SPEED, -PULSE_MAX * PULSE_SPEED, PULSE_MAX * PULSE_SPEED)


func _on_landed(impact: float) -> void:
	squash(clampf(impact / 26.0, 0.0, 0.42), player.state.contact_normal)
	rumble("landed", clampf((impact - 10.0) / 16.0, 0.0, 1.0))
	if impact > 18.0:
		_camera("kick", "landed", Vector3.DOWN, impact * 0.012)


func _on_jumped(air: bool) -> void:
	squash(-0.22 if air else -0.28, Vector3.UP)


func _on_slammed(_at: Vector3, strength: float, _flatness: float) -> void:
	if strength < 0.05:
		return
	squash(0.3 + 0.2 * minf(strength, 1.0), player.state.contact_normal)
	rumble("slammed", minf(strength, 1.0))
	_camera("kick", "slammed", Vector3.DOWN, 0.35 + 0.35 * minf(strength, 1.5))
	# A zoom-in thump: the world leans toward the impact for a beat.
	_camera("punch_fov", "slammed", Vector3.ZERO, -4.0 * minf(strength, 1.5), 0.25)


func _process(delta: float) -> void:
	if player == null:
		return
	# The springs run on scaled time, so a hit-stop freezes the squash mid-frame too.
	step_springs(delta)
	var juice: Node3D = player.juice_node()
	var basis := _axis_scale(_axis, _squash)
	# A gentle stretch along the travel line, scaled by speed.
	var flat: Vector3 = player.planar_velocity()
	if flat.length() > 1.0:
		basis = _axis_scale(flat.normalized(), -0.1 * player.speed_fraction()) * basis
	juice.basis = basis.scaled(Vector3.ONE * shell)
	# Keep the contact point planted while squashed, and a grown shell resting on the
	# ground rather than sunk into it.
	var ground: Vector3 = player.state.contact_normal if player.state.grounded else Vector3.UP
	juice.position = -_axis * Tuning.RADIUS * clampf(_squash, -0.3, MAX_SQUASH) * 0.9 * shell + ground * Tuning.RADIUS * (shell - 1.0)
	# The cockpit rides the same offset but never the squash or shell basis.
	var mount: Node3D = player.pod_mount() if player.has_method("pod_mount") else null
	if mount != null:
		mount.position = juice.position
	_animate_pylon(delta)
	if vfx != null and audio != null:
		vfx.set_chain(audio.kill_streak.length if audio.kill_streak.live(Time.get_ticks_msec()) else 0, audio.kill_streak.rung)


# One frame of the squash and shell springs.
func step_springs(delta: float) -> void:
	var steps := clampi(ceili(delta / SPRING_STEP), 1, MAX_SPRING_STEPS)
	var h := delta / float(steps)
	var target := shell_target()
	for _i in steps:
		var accel := -SPRING * _squash - DAMPING * _squash_velocity
		_squash_velocity += accel * h
		_squash += _squash_velocity * h
		# The shell: an underdamped spring toward the heft class's size.
		var shell_accel := SHELL_RATE * SHELL_RATE * (target - shell) - 2.0 * 0.45 * SHELL_RATE * _shell_velocity
		_shell_velocity += shell_accel * h
		shell += _shell_velocity * h


# Squashes by amount along axis and bulges the other two to keep the volume.
static func _axis_scale(axis: Vector3, amount: float) -> Basis:
	var up := axis.normalized()
	var right := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	right = (right - up * right.dot(up)).normalized()
	var align := Basis(right, up, right.cross(up))
	var side := 1.0 + amount * 0.5
	return align * Basis.from_scale(Vector3(side, 1.0 - amount, side)) * align.transposed()


func squash_amount() -> float:
	return _squash


# --- Camera -------------------------------------------------------------------------

func _on_dashed(direction: Vector3) -> void:
	_camera("punch_fov", "dashed", direction, 7.0, 0.3)
	squash(-0.18, direction)


func _on_boosted(direction: Vector3) -> void:
	_camera("punch_fov", "boosted", direction, 5.0, 0.3)
	squash(-0.14, direction)


func _on_launched(velocity: Vector3) -> void:
	_camera("punch_fov", "launched", velocity, 16.0, 1.0)
	_camera("kick", "launched", -velocity, 0.6)
	squash(-0.3, velocity)


func _on_dismounted(velocity: Vector3) -> void:
	_eject_ghost()
	if velocity.length() < 1.0:
		return
	_camera("punch_fov", "dismounted", velocity, clampf(4.0 + velocity.length() * 0.2, 4.0, 10.0), 0.35)
	squash(-0.25, velocity)


# --- Hits ---------------------------------------------------------------------------
# A strike is collected for the end of the frame, where every hit of the frame lands as
# one stop, one shake and a handful of bursts.

func _on_enemy_struck(enemy: Node3D, kind: String, force: float) -> void:
	var result := {"dealt": force, "punch": force, "full": true, "part": "", "plating": 0.0}
	if resolve_of.is_valid() and is_instance_valid(enemy):
		# enemy_struck goes out before the damage, so this is the hit as combat met it.
		result = resolve_of.call(enemy, kind, force)
	if not bool(result.get("full", true)):
		return
	var at: Vector3 = player.shown_position()
	if is_instance_valid(enemy) and enemy.is_inside_tree():
		at = enemy.global_position
	var dealt := float(result.get("dealt", force))
	var key := str(enemy.get_instance_id()) if is_instance_valid(enemy) else ""
	# A hit a plate takes whole removes nothing: the plate's pop is its read, and no number rises.
	var absorbed := bool(result.get("absorbed", false))
	if kind == "synergy":
		# A synergy's shockwave is the build's doing, not a landing: no stop, no burst, no
		# weak-point read. Its figure still shows.
		if not absorbed:
			_raise_number(key, dealt, at, kind, false)
		return
	var body_plating := float(plating_of.call(enemy)) if plating_of.is_valid() and is_instance_valid(enemy) else -INF
	var crit := DamageNumbers.is_crit(result, body_plating)
	var impact := EventKinds.impact(_impact_key(enemy, kind))
	_hits.append({"at": at + Vector3.UP * 0.6, "contact": _contact_point(enemy, at + Vector3.UP * 0.6), "damage": dealt, "crit": crit, "heavy": impact["stop"] == "heavy", "kind": kind,
		"stop": impact["stop"] != "none", "shake": float(impact["shake"]), "key": key, "world": at, "throw": _throw_of(kind, force), "absorbed": absorbed})
	_queue_flush()


func _raise_number(key: String, dealt: float, at: Vector3, kind: String, crit: bool) -> void:
	if number_sink.is_valid():
		number_sink.call(key, dealt, at + Vector3.UP * NUMBER_LIFT, DamageNumbers.type_of_kind(kind), "player", crit)


# Where the hit met the body: on its skin along the line to the ball, not at its middle.
func _contact_point(enemy: Node3D, centre: Vector3) -> Vector3:
	var to_ball: Vector3 = player.shown_position() - centre
	var reach := minf(float(enemy.get("radius")) if is_instance_valid(enemy) and enemy.get("radius") != null else 0.0, to_ball.length() * 0.5)
	return centre + to_ball.normalized() * reach


# A blast publishes enemy_struck under a gun kind, so the row comes from the record combat
# holds for the strike being published (last_impact) when it names this enemy, else from
# the kind.
func _impact_key(enemy: Node3D, kind: String) -> String:
	var last = ctx.spawner.get("last_impact") if ctx != null and ctx.spawner != null else null
	if last is Dictionary and not last.is_empty() and is_instance_valid(enemy) and int(last.get("enemy", 0)) == enemy.get_instance_id():
		return String(last["key"])
	return kind


# How hard a ball contact throws, in m/s, the way the ball shoves it; -1 for any other hit.
func _throw_of(kind: String, force: float) -> float:
	if not kind in CONTACT_KINDS:
		return -1.0
	var heft := 1.0
	if ctx != null and ctx.spawner != null and ctx.spawner.has_method("heft"):
		heft = float(ctx.spawner.heft())
	if kind == "slam":
		return minf(force * Contact.heft_knock(heft), maxf(force, Contact.KNOCK_CEILING))
	return Contact.ram_knock(Augments.RAM_KNOCK, force, heft)


# A contact's stop and shake at its throw: 0 at THROW_LO, 1 at the knock ceiling.
static func throw_share(throw: float) -> float:
	return clampf((throw - THROW_LO) / (Contact.KNOCK_CEILING - THROW_LO), 0.0, 1.0)


static func throw_stop_ms(throw: float, crit := false) -> float:
	var ms := lerpf(THROW_STOP_MS[0], THROW_STOP_MS[1], throw_share(throw))
	if crit:
		ms *= float(EventKinds.juice("enemy_struck")["crit"]["stop_mult"])
	return minf(ms, SPINE_CAP_MS)


# The stop a hit asks for, in ms, before the frame coalesces and the gate spaces it.
static func stop_ms_for(damage: float, crit := false, heavy := false) -> float:
	var row := EventKinds.juice("enemy_struck")
	var ms := clampf(float(row["stop_ms"]) + float(row["stop_per_damage"]) * maxf(damage, 0.0), float(row["stop_min_ms"]), float(row["stop_cap_ms"]))
	if crit:
		ms *= float(row["crit"]["stop_mult"])
	if heavy:
		ms += float(row["heavy"]["stop_add_ms"])
	return minf(ms, SPINE_CAP_MS)


func _queue_flush() -> void:
	if not _flush_queued:
		_flush_queued = true
		flush.call_deferred()


# Lands everything the frame collected. Deferred, so the streaks audio bumped this frame
# are current and every hit of one blast is in; tests call it directly.
func flush() -> void:
	_flush_queued = false
	# A blast's punch grows with the enemies it caught this frame.
	var caught := _hits.filter(func(h: Dictionary): return h["kind"] == "sticky").size()
	var b_row := EventKinds.juice("sticky_detonated")
	# A cloaked charge is a crit (sticky_detonated says so), though its damage was
	# multiplied before combat resolved it.
	if _blasts.any(func(b: Array): return b[1]):
		for hit in _hits:
			if hit["kind"] == "sticky":
				hit["crit"] = true
	for blast in _blasts:
		_camera("punch_fov", "sticky_detonated", Vector3.ZERO,
			minf(float(b_row["punch_fov"]) + float(b_row["punch_per_enemy"]) * caught, float(b_row["punch_cap"])), 0.3)
	_blasts.clear()
	_flush_hits()
	_flush_kills()


func _flush_hits() -> void:
	if _hits.is_empty():
		return
	var row := EventKinds.juice("enemy_struck")
	var stop := 0.0
	var shake := 0.0
	var heavy := false
	var crit := false
	var contact := Vector3.ZERO
	for i in _hits.size():
		var hit: Dictionary = _hits[i]
		var throw := float(hit.get("throw", -1.0))
		if hit["stop"]:
			stop = maxf(stop, maxf(stop_ms_for(hit["damage"], hit["crit"], hit["heavy"]), throw_stop_ms(throw, hit["crit"]) if throw >= 0.0 else 0.0))
			if hit["crit"]:
				shake = maxf(shake, float(row["crit"]["shake"]))
		shake = maxf(shake, maxf(hit["shake"], lerpf(THROW_SHAKE[0], THROW_SHAKE[1], throw_share(throw)) if throw >= 0.0 else 0.0))
		crit = crit or hit["crit"]
		if hit["heavy"]:
			heavy = true
			contact = hit["at"]
		if vfx != null and i < MAX_BURSTS:
			vfx.play_fx("enemy_struck", hit["contact"], DamageNumbers.effect_colour(DamageNumbers.type_of_kind(hit["kind"]), "player", hit["crit"]), "crit" if hit["crit"] else "")
		if not hit.get("absorbed", false):
			_raise_number(hit["key"], hit["damage"], hit["world"], hit["kind"], hit["crit"])
	if stop > 0.0:
		stop += EventKinds.STOP_PER_EXTRA_HIT_MS * mini(_hits.size() - 1, 5)
	if crit and audio != null:
		audio.play("enemy_struck", 0.0, 1.0, "SFX", String(row["crit"]["sound"]))
	if heavy:
		_thump(contact, float(row["heavy"]["kick"]), int(row["heavy"]["dust"]), "enemy_struck")
		var throw_max := 0.0
		for hit in _hits:
			throw_max = maxf(throw_max, float(hit.get("throw", -1.0)))
		rumble("ram", lerpf(0.45, 1.0, throw_share(throw_max)))
	if camera != null and shake > 0.0:
		request_shake(shake, 0.2, "enemy_struck")
	_hits.clear()
	if stop > 0.0:
		request_hit_stop(stop / 1000.0, "enemy_struck")


# The ram's weight: the camera kicked along the ball's travel, dust at the contact and
# the shell squashed into the hit. Camera and shell only; the ball keeps its speed.
func _thump(at: Vector3, kick: float, dust: int, fact: String) -> void:
	var travel: Vector3 = player.planar_velocity()
	var along: Vector3 = travel.normalized() if travel.length() > 0.5 else (at - player.shown_position()).normalized()
	_camera("kick", fact, along, kick)
	squash(0.28, along)
	if vfx != null:
		vfx.burst("dust", at - Vector3.UP * 0.5, EventKinds.color("landed"), dust)


# The bowling-ball rebound: the heavy thump, whatever the strike did.
func _on_rebounded(enemy: Node3D, _speed: float) -> void:
	var row := EventKinds.juice("enemy_rebounded")
	var at: Vector3 = enemy.global_position if is_instance_valid(enemy) and enemy.is_inside_tree() else player.shown_position()
	_thump(at, float(row["kick"]), int(row["dust"]), "enemy_rebounded")
	if camera != null:
		request_shake(float(row["shake"]), 0.2, "enemy_rebounded")


# A weak point cracked: a crit's stop and a small kick.
func _on_weak_point(_point_id: String) -> void:
	_camera("kick", "boss_weak_point_hit", Vector3.DOWN, 0.25)
	rumble("boss_weak_point_hit")
	request_hit_stop(stop_ms_for(30.0, true) / 1000.0, "boss_weak_point_hit")


func _on_unsealed(_stage: int) -> void:
	var row := EventKinds.juice("beacon_unsealed")
	_camera("punch_fov", "beacon_unsealed", Vector3.ZERO, float(row["punch_fov"]), 0.6)
	rumble("beacon_unsealed")
	# A beacon is not a strike: the ask is logged at zero and never sent (STRIKE_STOP_FACTS).
	request_hit_stop(0.0, "beacon_unsealed")


# --- Kills --------------------------------------------------------------------------

func _on_killed(_kind: String, at: Vector3, _value: int) -> void:
	_kills.append(at)
	_queue_flush()


func _flush_kills() -> void:
	if _kills.is_empty():
		return
	var row := EventKinds.juice("enemy_killed")
	if vfx != null:
		for at in _kills:
			vfx.kill_pop(at)
	var now := SimClock.msec()
	var before := _multi_size if now - _multi_last <= int(row["multi_ms"]) else 0
	_multi_size = before + _kills.size()
	_multi_last = now
	_kills.clear()
	# One ram or blast that takes several: an extra beat at 2, 4 and 8.
	for mark in [2, 4, 8]:
		if before < mark and _multi_size >= mark:
			multi_log.append([mark, now])
			request_hit_stop(float(row["multi_stop_ms"]) / 1000.0, "multi_kill")
			rumble("multi_kill", minf(0.5 + mark / 8.0, 1.0))
			_camera("punch_fov", "multi_kill", Vector3.ZERO, -2.0 - mark * 0.5, 0.3)
			if audio != null:
				# A second, louder pop: percussion has no ladder (SOUND-BIBLE rule 7).
				audio.play("enemy_killed", 2.0, 1.0, "SFX", "kill_pop")
			if vfx != null:
				vfx.glyph("enemy_killed", player.shown_position(), 1.0, 3.0 + mark, 0.35, Vector3.UP, "ring")


# --- Pickups ------------------------------------------------------------------------

# Each piece swells the shell a little, more as the streak climbs.
func _on_scrap(_amount: int, _at: Vector3, _total: int) -> void:
	var row := EventKinds.juice("scrap_collected")
	var rung: int = audio.scrap_streak.rung if audio != null else 0
	pulse(minf(float(row["pulse"]) * (1.0 + 0.2 * rung), float(row["pulse_cap"])))


func _on_scrap_lost(_amount: int, _at: Vector3, _total: int, _cause: String) -> void:
	pulse(float(EventKinds.juice("scrap_lost")["pulse"]))
	squash(0.3, Vector3.UP)


# A part: a fountain in its element's colour (else its rarity's) off the ball, so what it
# will do flares before you read its name.
func _on_part(part_id: String, _source: String) -> void:
	if vfx == null:
		return
	var row := EventKinds.juice("part_gained")
	vfx.burst("fountain", player.shown_position() + Vector3.UP * 0.8, part_tint(part_id), int(row["fountain"]))
	pulse(0.12)


# The pickup fountain's colour: the element's when the part has one, else the rung's, and a
# common part flashes sandstone, not its mint rung colour, because mint flashes mean live.
static func part_tint(part_id: String) -> Color:
	var def: Resource = Parts.def(part_id)
	if def == null:
		return EventKinds.color("part_gained")
	var rung := ItemGen.resolve_rarity(String(def.rarity))
	var tint: Color = Palette.SANDSTONE if rung in ["", "common"] else RewardGates.rarity_color(rung)
	return EventKinds.juice("part_gained")["element"].get(String(def.element), tint)


func _on_core(_source: String, at: Vector3, _count: int) -> void:
	if vfx != null:
		vfx.burst("fountain", at + Vector3.UP * 0.6, EventKinds.color("core_gained"), int(EventKinds.juice("core_gained")["fountain"]))


# A quick Warden break's extra arch: an amber fountain from its crossbar and a pulse of the shell.
func _on_quick_break(_stage: int, _seconds: float, at: Vector3) -> void:
	pulse(0.12)
	if vfx != null:
		var row := EventKinds.juice("quick_break")
		vfx.burst("fountain", at + Vector3.UP * float(row["rise"]), EventKinds.color("quick_break"), int(row["fountain"]))


# --- Dodges and hits taken ------------------------------------------------------------

# The dodge: a short slow-mo tick, a zoom-in and the chevron over the ball.
func _on_near_miss(_kind: String, at: Vector3) -> void:
	var row := EventKinds.juice("near_miss")
	# A dodge keeps the ball's momentum: the ask is logged at zero and never sent (STRIKE_STOP_FACTS).
	request_hit_stop(0.0, "near_miss")
	_camera("punch_fov", "near_miss", Vector3.ZERO, float(row["punch_fov"]), 0.25)
	rumble("near_miss")
	if vfx != null:
		var travel: Vector3 = player.planar_velocity()
		vfx.glyph("near_miss", at + Vector3.UP * 1.8, 0.6, 1.4, 0.35, travel if travel.length() > 0.5 else Vector3.ZERO, "", Color(0, 0, 0, 0), "P2")
		vfx.glyph("near_miss", at, 1.0, 4.0, 0.3, Vector3.UP, "ring", Color(0, 0, 0, 0), "P2")


# A hit taken: the screen edge toward the source flashes and the shell winces. Never a camera shake: it would hide whether the hit was dodged.
func _on_player_hit(amount: float, source: String) -> void:
	var row := EventKinds.juice("player_hit")
	hook_log.append(["edge_flash", "player_hit"])
	squash(float(row["squash"]), Vector3.ZERO)
	rumble("player_hit", clampf(0.5 + amount / 30.0, 0.5, 1.0))
	# The number and the flash keep the player_hit juice row's HAZARD for either source.
	var team := DamageNumbers.team_of_source(source)
	if number_sink.is_valid():
		number_sink.call("player", amount, player.shown_position() + Vector3.UP * 1.4, "kinetic", team, false)
	if vfx == null:
		return
	var from = null
	var last: Dictionary = ctx.spawner.get("last_player_hit") if ctx.spawner != null and ctx.spawner.get("last_player_hit") != null else {}
	if not last.is_empty() and Engine.get_physics_frames() - int(last.get("frame", -100)) <= 2:
		from = last["from"]
	vfx.edge_flash(_screen_direction(from), DamageNumbers.effect_colour("kinetic", team), float(row["edge_alpha"]) * clampf(0.6 + amount / 25.0, 0.6, 1.0), float(row["edge_s"]))


# Where a world point sits from the screen's centre, as a unit 2D direction (x right, y
# down); zero when unknown, which flashes every edge.
func _screen_direction(from) -> Vector2:
	if from == null or camera == null or camera.cam == null:
		return Vector2.ZERO
	var local: Vector3 = camera.cam.global_basis.inverse() * ((from as Vector3) - camera.cam.global_position)
	var flat := Vector2(local.x, -local.y if local.z < 0.0 else local.z)
	return flat.normalized() if flat.length() > 0.01 else Vector2.ZERO


# --- Your own shots, throws and blasts ------------------------------------------------

func _on_shot(weapon_id: String, from: Vector3, to: Vector3) -> void:
	var row := EventKinds.juice("shot_fired")
	var feel: Dictionary = row["weapons"].get(weapon_id, {})
	var aim := (to - from)
	if aim.length() < 0.01:
		return
	aim = aim.normalized()
	if float(feel.get("kick", 0.0)) > 0.0:
		_camera("kick", "shot_fired", -aim, float(feel["kick"]))
	# Recoil never cuts a bigger squash short, so rapid fire cannot flatten a landing.
	if float(feel.get("recoil", 0.0)) > absf(_squash):
		squash(float(feel["recoil"]), aim)
	if weapon_id == "sticky_charge" and audio != null:
		var throw: Dictionary = row["throw"]
		audio.play("shot_fired", float(throw["db"]), float(throw["pitch"]), "SFX", String(throw["sound"]))


func _on_stuck(at: Vector3) -> void:
	var stick: Dictionary = EventKinds.juice("shot_fired")["stick"]
	if audio != null:
		audio.play("shot_fired", -2.0, float(stick["pitch"]), "SFX", String(stick["sound"]))
	if vfx != null:
		vfx.play_fx("sticky_stuck", at, EventKinds.color("sticky_detonated"))


func _on_detonated(at: Vector3, crit: bool) -> void:
	var row := EventKinds.juice("sticky_detonated")
	var color := EventKinds.color("sticky_detonated")
	_blasts.append([at, crit])
	_queue_flush()
	if camera != null:
		request_shake(float(row["shake"]), 0.25, "sticky_detonated")
	if vfx != null:
		vfx.glyph("sticky_detonated", at + Vector3.UP * 0.8, 1.0, 4.0, 0.18, Vector3.ZERO, "flash")
		vfx.glyph("sticky_detonated", at + Vector3.UP * 0.2, 1.0, 9.0, 0.4, Vector3.UP, "ring")
		vfx.burst("debris", at + Vector3.UP * 0.4, color, int(row["debris"]))
		vfx.burst("dust", at, EventKinds.color("landed"), int(row["dust"]))
	# A blast beside you rocks the camera and the shell away from it; the ball's velocity
	# is the rocket jump's business alone.
	var away: Vector3 = player.shown_position() - at
	if away.length() < float(row["near_m"]):
		var dir := away.normalized() if away.length() > 0.1 else Vector3.UP
		_camera("kick", "sticky_detonated", dir, float(row["near_kick"]))
		squash(0.3, dir)


func _on_rocket_jumped(_at: Vector3, _speed: float) -> void:
	var row := EventKinds.juice("rocket_jumped")
	_camera("kick", "rocket_jumped", Vector3.DOWN, float(row["kick"]))
	_camera("punch_fov", "rocket_jumped", Vector3.UP, float(row["punch_fov"]), 0.5)
	squash(-float(row["squash"]), Vector3.UP)


# A new heft class: the ball pops and the panels slam in (the outline does not grow).
func _on_heft_class(heft_class: int, _heft: float) -> void:
	if heft_class > _heft_class:
		squash(0.32, Vector3.UP)
		rumble("heft_class_changed")
		hook_log.append(["class_up", "heft_class_changed"])
	_heft_class = heft_class


func shell_target() -> float:
	return 1.0 + SHELL_PER_CLASS * (_heft_class - 1)


func _camera(hook: String, fact: String, direction: Vector3, amount: float, time := 0.3) -> void:
	hook_log.append([hook, fact])
	if camera == null:
		return
	match hook:
		"punch_fov":
			camera.punch_fov(amount, time)
		"kick":
			camera.kick(direction, amount)


# The one way presentation asks the pad to rumble: the fact's RUMBLE row at `share` of its
# strength, scaled by the Screen shake comfort row, sent to every connected pad. A request no
# stronger than the one still running is logged unsent. Outside play (a menu, a pause) it is
# logged unsent too. With no pad connected it only logs.
func rumble(fact: String, share := 1.0) -> void:
	var row: Dictionary = RUMBLE.get(fact, {})
	if row.is_empty():
		return
	var scale := clampf(share, 0.0, 1.0) * shake_scale
	var weak := float(row["weak"]) * scale
	var strong := float(row["strong"]) * scale
	var seconds := float(row["ms"]) / 1000.0
	# The motors run on real time, so a hit-stop must not stretch the running window.
	var now := Time.get_ticks_msec()
	var running := now < _rumble_until
	if rumble_log.size() >= RUMBLE_LOG_CAP:
		rumble_log.pop_front()
	var in_play: bool = ctx == null or ctx.flow == null or ctx.flow.in_play()
	if not in_play or maxf(weak, strong) < RUMBLE_FLOOR or (running and weak <= _rumble_weak and strong <= _rumble_strong):
		rumble_log.append([fact, weak, strong, seconds, false])
		return
	_rumble_weak = weak
	_rumble_strong = strong
	_rumble_until = now + int(row["ms"])
	_rumble_fact = fact
	rumble_log.append([fact, weak, strong, seconds, true])
	for device in Input.get_connected_joypads():
		Input.start_joy_vibration(device, weak, strong, seconds)


# The fact whose rumble is still running, or "".
func rumbling() -> String:
	return _rumble_fact if Time.get_ticks_msec() < _rumble_until else ""


# Stops the pad when `fact` is the rumble still running.
func _stop_rumble(fact: String) -> void:
	if _rumble_fact != fact or Time.get_ticks_msec() >= _rumble_until:
		return
	_rumble_until = 0
	_rumble_weak = 0.0
	_rumble_strong = 0.0
	_rumble_fact = ""
	for device in Input.get_connected_joypads():
		Input.stop_joy_vibration(device)


# The loops' pad facts (Heat on the shell, Called Shot), through the same rows as every other.
func _wire_loop_rumble(events) -> void:
	var redline = player.get("redline")
	if redline != null:
		redline.skimmed.connect(func(_at: Vector3): rumble("heat_skim"))
		redline.redlined.connect(func(): rumble("heat_redline"))
		redline.detonated.connect(func(_at: Vector3, _force: float): rumble("heat_blast"))
		redline.cooked_off.connect(func(_at: Vector3, _force: float): rumble("heat_blast"))
		# The redline buzz ends with redline: a stage change or a death cools the shell without a blast.
		redline.changed.connect(func(_value: float, band: int):
			if band < 3:
				_stop_rumble("heat_redline"))
	events.world_fact.connect(func(kind: String, _at: Vector3):
		if kind == "shot_called" or kind == "call_met":
			rumble(kind))


# The one way presentation asks the camera to shake, so every shake shares SHAKE_CAP. The
# camera scales the capped amount by the viewer's Screen shake row.
func request_shake(amount: float, time: float, _fact: String) -> void:
	if camera == null:
		return
	camera.shake(minf(amount, SHAKE_CAP), time)


# The one way presentation asks for a freeze, so every stop shares one budget. Gated by
# the spacing and the short and long budgets, and
# scaled by the viewer's Hit-stop setting; a stop over the budget is trimmed to fit.
func request_hit_stop(seconds: float, fact: String) -> void:
	var now := SimClock.msec()
	if not STRIKE_STOP_FACTS.has(fact):
		hit_stop_log.append([seconds, 0.0, fact, now])
		return
	var wanted := minf(seconds * 1000.0, SPINE_CAP_MS) * stop_scale
	_stops = _stops.filter(func(stop: Array): return now - int(stop[0]) < 1000)
	var spent := 0.0
	var recent := 0.0
	for stop in _stops:
		spent += float(stop[1])
		if now - int(stop[0]) < EventKinds.STOP_WINDOW_MS:
			recent += float(stop[1])
	var sent := minf(wanted, minf(EventKinds.STOP_BUDGET_MS - spent, EventKinds.STOP_WINDOW_BUDGET_MS - recent))
	var spaced := _stops.is_empty() or now - int(_stops.back()[0]) - float(_stops.back()[1]) >= EventKinds.STOP_GAP_MS
	var in_play: bool = ctx.flow == null or ctx.flow.in_play()
	if not in_play or not spaced or wanted < STOP_FLOOR_MS or sent < minf(wanted, STOP_TRIM_FLOOR_MS):
		hit_stop_log.append([seconds, 0.0, fact, now])
		return
	_stops.append([now, sent])
	hit_stop_log.append([seconds, sent / 1000.0, fact, now])
	hook_log.append(["hit_stop", fact])
	if hit_stop_sink.is_valid():
		hit_stop_sink.call(sent / 1000.0)


# Forgets the stops already spent, for a test that measures from a clean slate.
func reset_stops() -> void:
	_stops.clear()


# --- The pylon ------------------------------------------------------------------------
# The spine draws the pylon and places it every frame; presentation animates its two
# parts: the post drives into the face with an overshoot and the plate flashes out.

func _on_mounted(_at: Vector3, banked_speed: float) -> void:
	_plant_t = 0.0
	_camera("punch_fov", "mounted", Vector3.ZERO, -3.0, 0.2)
	squash(0.25 + minf(banked_speed / 60.0, 0.15), player.kit.mount_normal)


func _pylon() -> Dictionary:
	if not _pylon_parts.is_empty():
		return _pylon_parts
	var pylon: Node3D = player.pylon_node()
	if pylon == null:
		return {}
	for child in pylon.get_children():
		if child is MeshInstance3D and child.mesh is CylinderMesh:
			var part := "post" if (child.mesh as CylinderMesh).height > 0.5 else "plate"
			_pylon_parts[part] = {"node": child, "rest": child.transform, "height": (child.mesh as CylinderMesh).height}
	return _pylon_parts


func _animate_pylon(delta: float) -> void:
	var parts := _pylon()
	if parts.is_empty():
		return
	var pylon: Node3D = player.pylon_node()
	if pylon.visible:
		_pylon_transform = pylon.global_transform
	for ghost in _ghosts.duplicate():
		ghost["t"] += delta / 0.16
		var node: Node3D = ghost["node"]
		if ghost["t"] >= 1.0:
			node.queue_free()
			_ghosts.erase(ghost)
			continue
		var s := 1.0 - ease(ghost["t"], 0.4)
		node.scale = Vector3(1.0, maxf(0.01, s), 1.0)
	if _plant_t < 0.0:
		return
	_plant_t += delta
	var t := clampf(_plant_t / 0.16, 0.0, 1.0)
	# Out of the face with a 12% overshoot, then home.
	var drive := 1.0 + 0.12 * sin(t * PI) if t > 0.45 else lerpf(0.15, 1.12, t / 0.45)
	if parts.has("post"):
		var post: Dictionary = parts["post"]
		var node: MeshInstance3D = post["node"]
		var rest: Transform3D = post["rest"]
		node.transform = Transform3D(rest.basis.scaled(Vector3(1.0, drive, 1.0)), Vector3(rest.origin.x, post["height"] * 0.5 * drive, rest.origin.z))
	if parts.has("plate"):
		var plate: Dictionary = parts["plate"]
		var flare := lerpf(1.7, 1.0, ease(t, 0.3))
		(plate["node"] as MeshInstance3D).transform = Transform3D(plate["rest"].basis.scaled(Vector3(flare, 1.0, flare)), plate["rest"].origin)
	if t >= 1.0:
		_plant_t = -1.0
		_restore_pylon()


func _restore_pylon() -> void:
	for part in _pylon_parts.values():
		(part["node"] as Node3D).transform = part["rest"]


# The eject: the spine hides the pylon the moment you leave it, so a ghost of the post
# snaps back into the face behind you.
func _eject_ghost() -> void:
	var parts := _pylon()
	_plant_t = -1.0
	_restore_pylon()
	if not parts.has("post") or ctx.root == null:
		return
	var source: MeshInstance3D = parts["post"]["node"]
	var holder := Node3D.new()
	holder.name = "PylonEject"
	ctx.root.add_child(holder)
	holder.global_transform = _pylon_transform
	var ghost := MeshInstance3D.new()
	ghost.mesh = source.mesh
	ghost.material_override = source.material_override
	ghost.transform = parts["post"]["rest"]
	holder.add_child(ghost)
	_ghosts.append({"node": holder, "t": 0.0})
