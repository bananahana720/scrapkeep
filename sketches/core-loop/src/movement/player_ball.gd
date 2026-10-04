extends Node3D

const Tuning := preload("res://src/movement/tuning.gd")
const Rules := preload("res://src/movement/ball_rules.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const BallState := preload("res://src/movement/ball_state.gd")
const RigidBall := preload("res://src/movement/rigid_ball.gd")
const Intent := preload("res://src/movement/intent.gd")
const Palette := preload("res://src/core/palette.gd")
const Augments := preload("res://src/movement/augments.gd")
const AugmentKit := preload("res://src/movement/augment_kit.gd")
const Harpoon := preload("res://src/movement/harpoon.gd")
const Bindings := preload("res://src/core/bindings.gd")
const Contact := preload("res://src/movement/contact.gd")
const Indicator := preload("res://src/movement/indicator.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const ChainState := preload("res://src/combat/chain.gd")
const CombatRules := preload("res://src/combat/combat.gd")

# Rigid physics only (TADR-006; entry 6 kept it for its arcade weight). The ball owns
# movement and publishes each movement fact on the bus; what a collision does to an
# enemy's health is combat's, so a contact is handed on through struck().

const STOMP := "stomp"
const RAM := "ram"
const SLAM := "slam"
# The bow sensor reaches this far past the shell, so a crush is decided before contact.
const BOW_REACH := 1.0
# How long a crushed enemy is ignored by the ball's collider while it dies.
const CRUSH_PASS := 0.3
# A contact is a stomp when the ball was coming down faster than this onto an enemy
# below its centre.
const STOMP_SPEED := 3.0
# A held pull the sprint ignores says so at most this often, not every tick.
const CC_IGNORED_GAP_MS := 250
# The arc slam tags steep faces this close for this long, for a vault.
const FACE_TAG_REACH := 12.0
const FACE_TAG_SECONDS := 2.0
const FACE_TAG_RAYS := 16
# Rivet's skid pushes enemies in this cone ahead of the ball, and each one it reaches
# pays back this much sprint recharge.
const SKID_REACH := 10.0
const SKID_CONE := 0.35
const SKID_REFUND := 0.5
const AIM_CONE_LENGTH := 5.0
const AIM_CONE_HALF := 0.3
# How long a transient line state stands before the steady one is published again.
const DRY_FIRE_HOLD := 0.25
const LET_GO_HOLD := 0.15
const BROKE_HOLD := 0.3
const LANDS_HOLD := 0.1

signal shockwave(position: Vector3, strength: float)
# A physical contact the ball made, for combat to turn into damage. Local, not the bus:
# the bus fact is enemy_struck, which combat publishes once the hit is resolved.
signal struck(enemy: Node3D, kind: String, force: float)

var tuning
var events
var state := BallState.new()
var kit := AugmentKit.new()
var abilities = kit.abilities
# The run's upgrade picks (upgrade_tree.gd): offered at class select and each workshop.
var tree = kit.tree
# The class this ball is fitted as; null before a run (the kit is then the engineer's).
var class_def: Resource
# The skill-shot geometry, player-owned and drawn in the class colour.
var indicator: Node3D
var intent := Intent.new()
var source = Intent.Source.new()
var drive_basis := Basis.IDENTITY
var spawn_point := Vector3.ZERO
# Presentation turns this off when it draws its own squash and stretch.
var builtin_squash := true
# Asks combat whether a contact would kill outright: (enemy, kind, force) -> bool.
# game.gd wires it to ctx.spawner.would_crush once combat is set up.
var crush_check := Callable()
# Answers the heft the ball plays at; combat wires it to its heft(). 1.0 when unwired.
var heft_of := Callable()
# Answers the run's scrap mass alone, without parts; combat wires it. Unwired, mass reads 0.
var mass_of := Callable()
# E's first claim (world's interact system, claims(face_in_reach: bool) -> bool): true
# when an interactable takes this press, so it never also plants a pylon.
var interact_claim := Callable()
# The arc slam's tagged faces: [{point, left}].
var face_tags: Array = []
var _cc_ignored_at := {}
# Seconds of crowd-control immunity granted from outside the sprint (Unstoppable).
var immune_left := 0.0
# The landing each smash flavour adds to the shared slam.
var _smashes := {}
# The enemy a harpoon smash is landing on while that landing's strikes resolve; combat reads it.
var smash_landing: Node3D
# The harpoon chain; this player is its only writer (HOOK-CHAIN.md).
var chain := ChainState.new()
# The chain's multiplier while a smash landing resolves; 1.0 otherwise.
var _landing_mult := 1.0

var _rigid
# The draw rig. _visual_root follows the shown position and never rotates; _juice is
# free for presentation (squash, stretch, trails); _mesh rolls; _roll_mount rolls with
# the mesh for anything that should stick to the ball's surface, like accreted scrap.
var _visual_root: Node3D
var _juice: Node3D
var _mesh: MeshInstance3D
var _roll_mount: Node3D
var _wings: Node3D
var _wings_material: StandardMaterial3D
var _pylon: Node3D
var _plate: MeshInstance3D
var _roll := Basis.IDENTITY
var _frozen := false
var _was_hooked := false
# Ctrl's raw state last tick, and whether a body line has claimed the press still held.
var _brake_was_held := false
var _ctrl_claimed := false
# The line state last published (LINE_ROWS id), what it named, and how long a transient one
# still stands. _line_standing says a latch or smash was published and has not ended yet.
var _line_state := ""
var _line_target = null
var _line_anchor := Vector3.ZERO
var _line_hold := 0.0
var _line_standing := false
var _bow: Area3D
var _crushing := {}


func setup(tuning_ref, events_ref, spawn: Vector3) -> void:
	tuning = tuning_ref
	events = events_ref
	spawn_point = spawn

	_rigid = RigidBall.new()
	_rigid.name = "RigidBall"
	add_child(_rigid)
	_rigid.setup(tuning, state)
	_rigid.intent = intent
	_rigid.kit = kit
	# Seed the body before its first physics step: a pending teleport arrives too late
	# on the very first tick. Outside the tree only the local position can be set.
	if _rigid.is_inside_tree():
		_rigid.global_position = spawn_point
	else:
		_rigid.position = spawn_point
	_rigid.enemy_touched.connect(_on_enemy_touched)
	_rigid.slammed.connect(_on_slammed)
	_rigid.pylon_planted.connect(_on_pylon_planted)
	_rigid.pylon_ejected.connect(func(v: Vector3): events.dismounted.emit(v))
	_rigid.jumped.connect(func(air: bool): events.jumped.emit(air))
	_rigid.boosted.connect(func(dir: Vector3): events.boosted.emit(dir))
	_rigid.kit_fact.connect(_on_kit_fact)
	tree.events = events
	tree.picked.connect(_on_tree_picked)
	events.enemy_killed.connect(func(_kind: String, _at: Vector3, _scrap: int): kit.rewind_left = 0.0)
	events.player_died.connect(func(): kit.drop_line("reset"))
	_smashes = {"arc": _smash_arc, "skid": _smash_skid, "demo": _smash_demo}
	events.run_started.connect(func(class_id: String):
		fit_class(ClassDef.by_id(class_id))
		tree.open_checkpoint())
	# The workshop visits after stages 1 to 3 each open one more pick: world's bay opens
	# it on entry, or at the stage's clear when the bay was skipped (world.gd).
	events.stage_entered.connect(func(_stage: int, _retry: bool): abilities.refill())
	events.stage_content_cleared.connect(func(_reason: String): abilities.refill())
	_rigid.landed.connect(func(impact: float): events.landed.emit(impact))

	# Everything under the player is placed per frame in _process, which interpolation
	# must leave alone; only the body is ticked by physics and interpolated.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_rigid.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON

	_visual_root = Node3D.new()
	_visual_root.name = "Visual"
	add_child(_visual_root)
	_juice = Node3D.new()
	_juice.name = "Juice"
	_visual_root.add_child(_juice)
	_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = Tuning.RADIUS
	sphere.height = Tuning.RADIUS * 2.0
	sphere.radial_segments = 32
	sphere.rings = 16
	_mesh.mesh = sphere
	_mesh.material_override = Palette.ball_material()
	_juice.add_child(_mesh)
	_roll_mount = Node3D.new()
	_roll_mount.name = "RollMount"
	_mesh.add_child(_roll_mount)

	_build_bow()
	_build_augment_visuals()
	indicator = Indicator.new()
	indicator.name = "Indicator"
	add_child(indicator)
	_rigid.set_active(true)
	reset_to(spawn_point)


func body() -> RigidBody3D:
	return _rigid


# Kept for code copied from the mobility kit, which had two bodies.
func active_body() -> RigidBody3D:
	return _rigid


func ball_position() -> Vector3:
	return _rigid.global_position


# Where the ball is drawn this frame. With physics interpolation on (F3) that is the
# body's interpolated transform, so the visuals and the camera move every frame
# instead of stepping at the 90 Hz physics rate; with it off it is the raw position.
func shown_transform() -> Transform3D:
	if is_inside_tree() and get_tree().physics_interpolation:
		return _rigid.get_global_transform_interpolated()
	return _rigid.global_transform


func shown_position() -> Vector3:
	return shown_transform().origin


# Presentation hooks. The juice node is presentation's to transform and parent to;
# the spine never writes it. The roll mount turns with the ball's surface.
func juice_node() -> Node3D:
	return _juice


func roll_node() -> Node3D:
	return _roll_mount


func speed_tier() -> int:
	return state.tier


func speed_fraction() -> float:
	return SpeedTier.fraction(state.velocity.length(), tuning.f("cruise"))


func planar_velocity() -> Vector3:
	return Vector3(state.velocity.x, 0.0, state.velocity.z)


# A frozen ball takes no push: a killing blow's shove lands after the death has frozen
# it, and must not wait for the retry (FIXWAVE spine, the stale shove).
func add_external_accel(accel: Vector3) -> void:
	if _frozen:
		return
	_rigid.external_accel += accel


# Screens freeze the ball so a title or death screen never lets it roll off; unfreezing
# hands back exactly the velocity given, which is how a launch carries between stages.
# Freezing drops any push already handed over this tick.
func set_frozen(frozen: bool) -> void:
	_frozen = frozen
	_rigid.set_active(not frozen)
	if frozen:
		_rigid.external_accel = Vector3.ZERO


func frozen() -> bool:
	return _frozen


func reset_to(point: Vector3, velocity := Vector3.ZERO) -> void:
	state.reset()
	kit.clear_runtime()
	chain.clear_active()
	_roll = Basis.IDENTITY
	_was_hooked = false
	_brake_was_held = false
	_ctrl_claimed = false
	_line_state = ""
	_line_target = null
	_line_hold = 0.0
	_line_standing = false
	_rigid.external_accel = Vector3.ZERO
	_rigid.teleport(point, velocity)


# A ride, a launch, a deflect or a throw sets the velocity outright, and a harpoon line
# would fight it, so it lets go.
func set_velocity_now(velocity: Vector3) -> void:
	cut_line("launched")
	_rigid.set_velocity_now(velocity)


# Fits the class's movement kit, smash and ability slots. Everyone keeps jump, double
# jump, boost and the smash; only the class's own movement augments are on.
func fit_class(def: Resource) -> void:
	class_def = def
	tree.reset(def.id if def != null else "")
	abilities.fit(class_def)
	_refit()


# A pick lands on the live kit: its slot ops, then the movement kit and smash flavour
# the (maybe swapped) slots name. Nothing else about the slots is reset.
func _on_tree_picked(n: Dictionary) -> void:
	UpgradeTree.apply_pick(abilities, n)
	_refit()


# The movement kit the movement slot's row names, the smash flavour, the class colour.
func _refit() -> void:
	if class_def == null:
		kit.fit(Augments.DEFAULT_MOVEMENT, "")
	else:
		kit.fit(abilities.id_of(AbilityState.MOVEMENT), abilities.id_of(AbilityState.SMASH))
	abilities.movement_key = _burst_key()
	_paint_effects()


# Everything the player's own action lights (pylon plate, glide vane) glows in the
# class colour: class colour means yours (VISUAL-LANGUAGE section 2).
func _paint_effects() -> void:
	var color := class_color()
	_wings_material.albedo_color = Color(color, 0.75)
	_plate.material_override = Palette.solid(color, 1.2)


func class_color() -> Color:
	return class_def.color if class_def != null else ClassDef.SABLE_COLOR


# A skill-shot record dressed as yours: the class colour and the class's rim ticks.
func yours(shape: Dictionary) -> Dictionary:
	shape["color"] = class_color()
	shape["ticks"] = class_def.shape if class_def != null else "ring"
	return shape


func heft() -> float:
	return float(heft_of.call()) if heft_of.is_valid() else 1.0


# The one door for crowd control: a knock, the Warden's pulse and magnet, Brindle's
# shoves, and wave 3's pits, tethers and nets. Rivet's sprint ignores all of it and
# says so (true means it landed). An interrupting hit force-cancels every charging
# gauge with nothing spent and collapses the indicator; a steady pull (a magnet's tug)
# is still a stop the sprint ignores, but it does not wipe a charge every tick. The
# shove, an acceleration like add_external_accel's, is applied here.
func crowd_control(kind: String, shove := Vector3.ZERO, interrupts := true) -> bool:
	if _frozen:
		return false
	if kit.sprinting or immune_left > 0.0 or (kit.mounted and tree.knob("mount_cc_immune")):
		var now := SimClock.msec()
		if now - int(_cc_ignored_at.get(kind, -100000)) >= CC_IGNORED_GAP_MS:
			_cc_ignored_at[kind] = now
			events.cc_ignored.emit(kind)
		return false
	if interrupts:
		for id in abilities.cancel_gauges():
			events.gauge_cancelled.emit(id, kind)
		if kit.slingshot.cancel():
			events.gauge_cancelled.emit("slingshot", kind)
		indicator.collapse_all()
	if shove != Vector3.ZERO:
		add_external_accel(shove)
	return true


# Crowd control slides off for this long (Unstoppable's boosted window).
func grant_immunity(seconds: float) -> void:
	immune_left = maxf(immune_left, seconds)


# The stomp and rebound refresh, one rule so they never disagree: one air jump and one
# charge of the class movement ability (for Sable, the last face it kicked).
func refresh_air() -> void:
	state.air_actions = 1
	abilities.grant(AbilityState.MOVEMENT)
	kit.refresh_vault()


# The rope is a hard max-length constraint on the ball, so it is anchored where the
# ball is standing when it is fired, not where the camera ray started.
func grapple_to(point: Vector3, normal := Vector3.ZERO, body: Node3D = null) -> void:
	if not kit.on(Augments.GRAPPLE):
		return
	Augments.attach(kit, ball_position(), point, normal, body)
	events.grapple_fired.emit(point)
	if body != null:
		if body.has_method("flash"):
			body.flash()
		events.harpoon_bit.emit(body, point)
	_publish_chain(chain.link(body != null, state.grounded), body, point)


func release_grapple() -> void:
	kit.drop_line()


# A hostile hold that lands, or a ride or launch, cuts the harpoon line; `cause` is what the
# line_state_changed signal names, and the release cue is grapple_released.
func cut_line(cause := "hold") -> void:
	kit.drop_line(cause)


func grapple_range() -> float:
	return tuning.f("rope_range")


func _physics_process(delta: float) -> void:
	source.poll(intent)
	abilities.movement_key = _burst_key()
	_read_mass()
	_route_interact()
	_read_grammar()
	abilities.tick(delta)
	immune_left = maxf(0.0, immune_left - delta)
	if kit.mounted and tree.knob("mounted_recharge") > 1.0:
		abilities.refund(AbilityState.SPECIAL, delta * (tree.knob("mounted_recharge") - 1.0))
	state.tick_timers(delta)
	if intent.jump_pressed:
		state.jump_buffer = Tuning.JUMP_BUFFER
	_rigid.drive_basis = drive_basis
	state.refresh_tier(tuning.f("cruise"))
	if _was_hooked and not kit.hooked:
		events.grapple_released.emit()
	_was_hooked = kit.hooked
	_publish_line(delta)
	_tick_chain(delta)
	_recheck_bow()
	_tick_face_tags(delta)
	_mark_slots()


# The slot states the ability bar reads that no spend or gauge sets: the grapple is
# active while hooked, and the smash is an air move, so on the ground it is unavailable.
func _mark_slots() -> void:
	if kit.on(Augments.GRAPPLE) and kit.movement_id == Augments.GRAPPLE:
		abilities.slot(AbilityState.MOVEMENT).active = kit.hooked
	var smash = abilities.slot(AbilityState.SMASH)
	smash.active = kit.slamming or kit.plant_time > 0.0
	smash.available = smash.active or not state.grounded


func _charging() -> bool:
	var special = abilities.gauge(AbilityState.SPECIAL)
	return (special != null and special.charging) or kit.slingshot.charging


# Right mouse is the line for every pilot, except while the special or the slingshot charges:
# then its press cancels the charge and moves nothing. Shift is the one go verb of the
# pilot (Sable's boost, Rivet's sprint, Kest's blink) and Ctrl hauls the line in.
func _read_grammar() -> void:
	_read_shift()
	if intent.harpoon_pressed and _charging():
		intent.harpoon_pressed = false
		intent.cancel_pressed = true
	_read_ctrl()
	if _frozen or not kit.on(Augments.GRAPPLE):
		return
	if intent.harpoon_pressed and not kit.hooked:
		_press_harpoon()
	elif intent.harpoon_released and kit.hooked:
		_fling()
		release_grapple()
	# Rope Anchor: winching up to the wall with Ctrl plants the pylon there.
	if tree.knob("winch_mount") and kit.hooked and kit.winching and not kit.mounted \
			and ball_position().distance_to(kit.anchor) <= Augments.MIN_ROPE + 2.5:
		intent.mount_pressed = true


func _burst_key() -> String:
	return AbilityState.KEYS[AbilityState.MOVEMENT] if kit.movement_id == Augments.GRAPPLE else Bindings.label("boost")


# The pilot's class burst is on Shift (Rivet's sprint, Kest's blink); Sable's Shift is the
# boost. The keyboard fills shift_*; a scripted source fills boost_* and movement_* itself.
func _burst_pilot() -> bool:
	return kit.on(Augments.SPRINT) or kit.on(Augments.BLINK)


func _read_shift() -> void:
	if _burst_pilot():
		intent.movement_pressed = intent.movement_pressed or (intent.shift_pressed and Harpoon.burst_ready(kit))
		intent.movement_held = intent.movement_held or intent.shift_held
		intent.movement_released = intent.movement_released or intent.shift_released
		if intent.shift_pressed and not Harpoon.burst_ready(kit):
			_fail("boost", "busy" if Augments.holding(kit) else "uncharged")
	else:
		intent.boost_pressed = intent.boost_pressed \
				or (intent.shift_pressed and (state.boost_cooldown <= 0.0 or kit.plant_time > 0.0))
		if intent.shift_pressed and state.boost_cooldown > 0.0:
			_fail("boost", "cooldown")
		elif intent.shift_pressed and kit.mounted:
			_fail("boost", "busy")


func _fail(verb: String, reason: String) -> void:
	events.verb_failed.emit(verb, reason, ball_position())


# Whether pressing the verb would succeed on this tick: "harpoon" bites, "haul" commits a
# smash or winches, "boost" is Shift's verb for this pilot, "interact" is E where it would mount
# the pylon or an interactable would take the press, "jump" is Space where it would jump,
# air-jump or launch the slingshot.
func verb_ready(verb: String) -> bool:
	match verb:
		"harpoon":
			return not _frozen and kit.on(Augments.GRAPPLE) and not kit.hooked and not _charging() \
					and not Augments.holding(kit) and _harpoon_refusal() == "" and chain.miss_left <= 0.0
		"interact":
			if _frozen or kit.mounted:
				return false
			var taken: bool = interact_claim.is_valid() and interact_claim.call(kit.on(Augments.PYLON) and face_in_reach()) \
					and not mobility_started()
			return taken or mount_ready()
		"jump":
			if _frozen:
				return false
			if kit.mounted:
				return true
			return not Augments.holding(kit) and (state.grounded or state.coyote > 0.0 or state.air_actions > 0)
		"haul":
			return not _frozen and not Augments.holding(kit) and kit.hooked \
					and (not kit.on_body or kit.line_state == Augments.LINE_LATCHED)
		"boost":
			if _burst_pilot():
				return Harpoon.burst_ready(kit)
			return state.boost_cooldown <= 0.0 and not Augments.holding(kit)
	return false


# E would mount the pylon on this tick, and no interactable takes the press first.
func mount_ready() -> bool:
	return not _frozen and not kit.mounted and kit.on(Augments.PYLON) and kit.mount_block <= 0.0 and face_in_reach() \
			and (mobility_started() or not (interact_claim.is_valid() and interact_claim.call(true)))


func _harpoon_refusal() -> String:
	if kit.rewind_left > 0.0:
		return "rewinding"
	if kit.aim.get("state", Augments.AIM_NONE) == Augments.AIM_NONE:
		return "no_aim"
	return ""


func _press_harpoon() -> void:
	if chain.miss_left > 0.0:
		_fail("harpoon", "cooldown")
		return
	var reason := _harpoon_refusal()
	if reason == "":
		grapple_to(kit.aim["point"], kit.aim["normal"], kit.aim.get("body"))
		return
	if not kit.hooked:
		_emit_line("dry_fire", null, ball_position(), "", DRY_FIRE_HOLD)
		_publish_chain(chain.dry_fire(), null, ball_position())
	_fail("harpoon", reason)


# Ctrl hauls the line in. On a latched body it commits the smash; on the world it winches
# while held. While any line stands it is neither the brake nor the slam, until it is let
# go: a haul can never plant or brake inside the crowd it flew into.
func _read_ctrl() -> void:
	var edge: bool = intent.brake_held and not _brake_was_held
	_brake_was_held = intent.brake_held
	var on_body: bool = kit.hooked and kit.on_body
	kit.winching = kit.hooked and not on_body and intent.brake_held
	if edge and not _frozen:
		if on_body and kit.line_state == Augments.LINE_LATCHED:
			Augments.commit_smash(kit, tuning, _rigid.linear_velocity)
		elif on_body:
			_fail("haul", "committed")
	if kit.hooked:
		_ctrl_claimed = true
	if not intent.brake_held:
		_ctrl_claimed = false
	if _ctrl_claimed:
		intent.brake_held = false


func _emit_line(id: String, target: Node3D, at: Vector3, cause := "", hold := 0.0) -> void:
	_line_state = id
	_line_target = target
	_line_hold = hold
	events.line_state_changed.emit(id, target, at, cause)


# Chain events go straight to the bus: _emit_line would take over the steady line state
# that _publish_line tracks, and a chain fact is not a line state.
func _publish_chain(emitted: Array, target: Node3D, at: Vector3) -> void:
	for e in emitted:
		events.line_state_changed.emit(e["id"], target, at, e["cause"])


func _tick_chain(delta: float) -> void:
	_publish_chain(chain.tick(delta, state.grounded, kit.hooked), null, ball_position())


# Publishes how the line that stood has ended: a let-go or a break with its cause. A landing
# or a reset publishes nothing here.
func _publish_end() -> void:
	_line_standing = false
	var end: String = kit.line_end
	kit.line_end = ""
	if end != "landed" and end != "reset" and end != "":
		chain.let_go()
	if end == "let_go":
		_emit_line("let_go", _line_target_alive(), _line_anchor, "", LET_GO_HOLD)
	elif end != "landed" and end != "reset" and end != "":
		_emit_line("broke", _line_target_alive(), _line_anchor, end, BROKE_HOLD)


func _line_target_alive() -> Node3D:
	return _line_target if is_instance_valid(_line_target) else null


# Publishes each change of the line's state. A standing line is read from the kit; its end
# is read from kit.line_end, which the kit's own rules set when they cut it. A smash landing
# publishes itself (_finish_landing). A transient state holds for its own beat before the
# steady one comes back.
func _publish_line(delta: float) -> void:
	_line_hold = maxf(0.0, _line_hold - delta)
	if kit.hooked:
		if _line_standing and kit.line_end != "":
			_publish_end()
		var id := "smash_committed" if kit.line_state == Augments.LINE_SMASH \
				else ("latched_body" if kit.on_body else "latched_world")
		var target: Node3D = kit.anchor_body if kit.on_body else null
		if id != _line_state or target != _line_target:
			_emit_line(id, target, kit.anchor)
		_line_anchor = kit.anchor
		_line_standing = true
		kit.line_end = ""
		return
	if _line_standing:
		_publish_end()
	if _line_hold > 0.0:
		return
	var steady := "searching"
	var aimed = null
	if kit.rewind_left > 0.0:
		steady = "rewinding"
	elif not _frozen and kit.on(Augments.GRAPPLE) and _harpoon_refusal() == "":
		steady = "locked"
		aimed = kit.aim.get("body")
	var target: Node3D = aimed if is_instance_valid(aimed) else null
	if steady != _line_state or target != _line_target:
		_emit_line(steady, target, kit.aim.get("point", ball_position()))


# E is interact everywhere (LOOP-REDESIGN section 9): the interactable E has locked takes
# the press, else it stays Sable's mount at a face. A lock farther than the interact
# reach yields to a face she could mount, and a mobility move already under way (the
# hook in, a slam plant, the slingshot drawing) keeps E. Mounted, E always drops off.
func _route_interact() -> void:
	if not intent.mount_pressed or kit.mounted or mobility_started() or not interact_claim.is_valid():
		return
	if interact_claim.call(kit.on(Augments.PYLON) and face_in_reach()):
		intent.mount_pressed = false
		intent.interact_pressed = true


func mobility_started() -> bool:
	return (kit.hooked and kit.on(Augments.PYLON)) or kit.plant_time > 0.0 or kit.slingshot.charging


# The pylon's own test (augments.gd _mount_spot): a steep face within a ball's reach,
# or the wall the hook is in when the ball is close to it.
func face_in_reach() -> bool:
	var origin := ball_position()
	if kit.hooked and kit.on(Augments.GRAPPLE) and not kit.on_body and kit.anchor_normal != Vector3.ZERO \
			and absf(kit.anchor_normal.y) < Augments.FACE_MAX_TILT and origin.distance_to(kit.anchor) <= Augments.MOUNT_HOOK_REACH:
		return true
	if not is_inside_tree():
		return false
	var space := get_world_3d().direct_space_state
	var reach: float = Tuning.RADIUS + Augments.FACE_REACH
	for i in Augments.FACE_RAYS:
		var angle := TAU * float(i) / float(Augments.FACE_RAYS)
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + dir * reach, Augments.WORLD_MASK))
		if not hit.is_empty() and absf((hit["normal"] as Vector3).y) < Augments.FACE_MAX_TILT:
			return true
	return false


# Mass-S: under --world-one-builds a pilot who took the depth-1 pick has the mass launch verb.
# q is heft turned back into mass (the run's mass at 1/450 heft each; a class IV heft of 3.2
# is 990) and read only; sampling it spends nothing, and the kit never lets it near steering.
func _read_mass() -> void:
	kit.mass_on = tuning != null and tuning.world_one() and tree.knob("mass_launch")
	var mass := maxf(0.0, float(mass_of.call())) if kit.mass_on and mass_of.is_valid() else 0.0
	kit.mass_q = clampf(mass / Augments.MASS_FULL, 0.0, 1.0)


# Coil Hook: letting go of the rope throws you on along your swing.
func _fling() -> void:
	var fling: float = tree.knob("grapple_fling")
	if not kit.hooked or fling <= 0.0:
		return
	var v: Vector3 = state.velocity
	var dir := v.normalized() if v.length() > 0.5 else -drive_basis.z
	var flung := v + dir * fling
	if kit.mass_on:
		flung += dir * Augments.mass_spend(kit, flung.length())
	_rigid.set_velocity_now(flung)


func _process(_delta: float) -> void:
	var shown := shown_transform()
	_visual_root.global_position = shown.origin
	_visual_root.global_basis = Basis.IDENTITY
	_update_augment_visuals(shown.origin)
	_update_aim_cones(shown.origin)
	_roll = shown.basis.orthonormalized()
	_mesh.basis = (_squash_basis() if builtin_squash else Basis.IDENTITY) * _roll


func _squash_basis() -> Basis:
	var amount := clampf(state.impact / 26.0, 0.0, 0.42)
	if amount <= 0.001:
		return Basis.IDENTITY
	var align := _align_up(state.contact_normal)
	var scale := Basis.from_scale(Vector3(1.0 + amount * 0.55, 1.0 - amount, 1.0 + amount * 0.55))
	return align * scale * align.inverse()


static func _align_up(normal: Vector3) -> Basis:
	var up := normal.normalized()
	var right := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	right = (right - up * right.dot(up)).normalized()
	return Basis(right, up, right.cross(up))


# The Katamari moment: fodder the ball now outweighs is rolled straight through. The
# sensor sees it a metre early, combat confirms the hit would kill, and the collider
# ignores that enemy while it dies, so the pass costs no speed, knock or hit-stop.
func _build_bow() -> void:
	_bow = Area3D.new()
	_bow.name = "Bow"
	_bow.collision_layer = 0
	_bow.collision_mask = 0
	_bow.set_collision_mask_value(3, true)
	_bow.monitorable = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = Tuning.RADIUS + BOW_REACH
	shape.shape = sphere
	_bow.add_child(shape)
	_rigid.add_child(_bow)
	_bow.body_entered.connect(_on_bow_entered)


func _on_bow_entered(body: Node3D) -> void:
	_try_crush(body)


# Rechecked every tick for whatever is inside the bow, so an enemy the ball grows or
# speeds into outweighing mid-overlap is still rolled up.
func _recheck_bow() -> void:
	if _bow == null or _frozen or state.tier < SpeedTier.CRUISE:
		return
	for body in _bow.get_overlapping_bodies():
		_try_crush(body)


func _try_crush(body: Node3D) -> void:
	if _frozen or not body.is_in_group("enemy") or state.tier < SpeedTier.CRUISE or not crush_check.is_valid():
		return
	var id := body.get_instance_id()
	if _crushing.has(id):
		return
	var speed := planar_velocity().length()
	if not crush_check.call(body, RAM, speed):
		return
	_crushing[id] = true
	if kit.sprinting:
		kit.sprint_left += tree.knob("crush_refund")
	_rigid.add_collision_exception_with(body)
	var closing := kit.line_closing
	var landing := _begin_landing(body)
	struck.emit(body, RAM, _landing_force(RAM, speed))
	if landing:
		_finish_landing(body, closing)
	get_tree().create_timer(CRUSH_PASS, false, true).timeout.connect(_end_crush.bind(id))


# Bound by id: the crushed enemy is usually freed by now, and a freed exception
# leaves the physics server with it.
func _end_crush(id: int) -> void:
	_crushing.erase(id)
	var body := instance_from_id(id)
	if is_instance_valid(body) and body is PhysicsBody3D:
		_rigid.remove_collision_exception_with(body)


func _build_augment_visuals() -> void:
	_wings = Node3D.new()
	var wing_material := Palette.unshaded(Color(class_color(), 0.75))
	_wings_material = wing_material
	for side in [-1.0, 1.0]:
		var fin := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(2.6, 0.12, 1.5)
		fin.mesh = box
		fin.material_override = wing_material
		fin.position = Vector3(side * 1.7, 0.2, 0.2)
		fin.rotation = Vector3(0.0, 0.0, side * -0.25)
		_wings.add_child(fin)
	_wings.visible = false
	add_child(_wings)

	# A scrap post: the pylon the pilot drives into the face, the ball riding its end.
	_pylon = Node3D.new()
	_pylon.name = "Pylon"
	var post := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.16
	cyl.bottom_radius = 0.26
	cyl.height = Augments.MOUNT_OFFSET
	post.mesh = cyl
	post.material_override = Palette.solid(Color(0.58, 0.52, 0.44))
	post.position = Vector3(0.0, Augments.MOUNT_OFFSET * 0.5, 0.0)
	_pylon.add_child(post)
	var plate := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.7
	disc.bottom_radius = 0.7
	disc.height = 0.12
	plate.mesh = disc
	plate.material_override = Palette.solid(class_color(), 1.2)
	_plate = plate
	_pylon.add_child(plate)
	_pylon.visible = false
	add_child(_pylon)


# The pylon node, so presentation can animate the plant and eject without owning it.
func pylon_node() -> Node3D:
	return _pylon


func _update_augment_visuals(at: Vector3) -> void:
	_pylon.visible = kit.mounted
	if kit.mounted:
		_pylon.global_transform = Transform3D(_align_up(kit.mount_normal), kit.mount_face)

	_wings.visible = kit.gliding
	if kit.gliding:
		_wings.global_position = at
		var heading := Vector3(state.velocity.x, 0.0, state.velocity.z)
		if heading.length() > 0.5:
			_wings.global_basis = Basis.looking_at(heading.normalized(), Vector3.UP)


# The strength the bus carries for a slam that lands at `speed` m/s: 1.0 at 30 m/s, never
# under 0.4 or over 1.6, scaled by how flat the ground was.
static func slam_strength(speed: float, flatness := 1.0) -> float:
	return clampf(speed / 30.0, 0.4, 1.6) * flatness


# The shockwave carries the same flatness as the plant: a full thump on flat ground,
# next to nothing when the slam went into a launch.
# Every class slams the same way; the landing then takes the class's flavour.
func _on_slammed(at: Vector3, speed: float, flatness: float) -> void:
	var strength := slam_strength(speed, flatness) * _landing_mult
	events.slammed.emit(at, strength, flatness)
	if strength >= 0.05:
		shockwave.emit(at, strength)
		_push_enemies(at, Augments.SLAM_RADIUS, Augments.SLAM_KNOCK * strength, SLAM)
	if _smashes.has(kit.smash_flavour):
		_smashes[kit.smash_flavour].call(at, speed)


func _smash_arc(at: Vector3, _speed: float) -> void:
	events.arc_slammed.emit(at, _tag_faces(at))


func _smash_skid(at: Vector3, speed: float) -> void:
	events.skid_smashed.emit(at, _skid_push(at, clampf(speed / 30.0, 0.4, 1.6)))


func _smash_demo(at: Vector3, _speed: float) -> void:
	events.demo_slammed.emit(at)


# Sable's arc slam marks every steep face within FACE_TAG_REACH for a vault.
func _tag_faces(at: Vector3) -> int:
	face_tags.clear()
	var space: PhysicsDirectSpaceState3D = _rigid.get_world_3d().direct_space_state
	var from := at + Vector3.UP * 1.0
	for i in FACE_TAG_RAYS:
		var angle := TAU * float(i) / float(FACE_TAG_RAYS)
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + dir * FACE_TAG_REACH, Augments.WORLD_MASK))
		if hit.is_empty() or absf((hit["normal"] as Vector3).y) >= Augments.FACE_MAX_TILT:
			continue
		face_tags.append({"point": hit["position"] + (hit["normal"] as Vector3) * 0.1, "left": FACE_TAG_SECONDS})
	return face_tags.size()


func _tick_face_tags(delta: float) -> void:
	for tag in face_tags:
		tag["left"] -= delta
	face_tags = face_tags.filter(func(tag): return tag["left"] > 0.0)


# Rivet's skid knocks what is ahead of the ball forward and refunds sprint per hit.
func _skid_push(at: Vector3, strength: float) -> int:
	var ahead := planar_velocity()
	ahead = ahead.normalized() if ahead.length() > 0.5 else Vector3.FORWARD
	var hits := 0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var to: Vector3 = enemy.global_position - at
		to.y = 0.0
		if to.length() > SKID_REACH or (to.length() > 1.5 and to.normalized().dot(ahead) < SKID_CONE):
			continue
		var falloff := 1.0 - to.length() / SKID_REACH
		enemy.knock(ahead + Vector3.UP * 0.3, Augments.SLAM_KNOCK * strength * falloff * tree.knob("skid_pins"))
		enemy.flash()
		struck.emit(enemy, SLAM, Augments.SLAM_KNOCK * strength * falloff)
		abilities.refund(AbilityState.MOVEMENT, SKID_REFUND)
		hits += 1
	return hits


# The vault and slingshot aim cones and the arc slam's face tags, in the class colour.
func _update_aim_cones(at: Vector3) -> void:
	if not kit.vault_aim.is_empty():
		indicator.set_shape("vault", yours({"kind": "cone", "apex": at, "dir": kit.vault_aim["dir"],
			"length": AIM_CONE_LENGTH, "half_angle": AIM_CONE_HALF}))
	else:
		indicator.clear("vault")
	if kit.mounted and not kit.slingshot_aim.is_empty():
		var fill: float = kit.slingshot_aim["fill"]
		indicator.set_shape("slingshot", yours({"kind": "cone", "apex": at, "dir": kit.slingshot_aim["dir"],
			"length": AIM_CONE_LENGTH * (1.0 + fill), "half_angle": AIM_CONE_HALF, "fill": fill}))
	else:
		indicator.clear("slingshot")
	if face_tags.is_empty():
		indicator.clear("faces")
	else:
		indicator.set_shape("faces", yours({"kind": "marks", "points": face_tags.map(func(tag): return tag["point"])}))


# A kit rule's fact goes on the bus; a dropped slingshot charge also collapses its cone.
func _on_kit_fact(kind: String, args: Array) -> void:
	if kind == "gauge_cancelled":
		indicator.collapse("slingshot")
	if kind == "vault_kicked" and tree.knob("vault_tags"):
		_tag_faces(ball_position())
	events.callv("emit_signal", [kind] + args)


func _on_pylon_planted(at: Vector3, banked_speed: float) -> void:
	events.mounted.emit(at, banked_speed)
	shockwave.emit(at, 0.7)
	_push_enemies(at, Augments.MOUNT_REPEL_RADIUS, Augments.MOUNT_REPEL_KNOCK * tree.knob("plant_repel"), "")


func _push_enemies(at: Vector3, radius: float, force: float, kind: String) -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var away: Vector3 = enemy.global_position - at
		var reach := away.length()
		if reach > radius:
			continue
		away.y = 0.0
		away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
		var falloff := 1.0 - reach / radius
		enemy.knock(away + Vector3.UP * 0.5, force * falloff)
		enemy.flash()
		if kind != "":
			struck.emit(enemy, kind, force * falloff)


# The motion the ball had going into a contact: of the velocities recently handed to the
# solver, the one closing fastest on the enemy. The live velocity is already the bounce.
func pre_contact_velocity(toward: Vector3) -> Vector3:
	var best: Vector3 = state.velocity
	var closing := -INF
	for velocity in _rigid.recent_velocities:
		var c: float = velocity.dot(toward)
		if c > closing:
			closing = c
			best = velocity
	return best


func _on_enemy_touched(enemy: Node3D, normal: Vector3) -> void:
	if _crushing.has(enemy.get_instance_id()):
		return
	var closing := kit.line_closing
	var landing := _begin_landing(enemy)
	if landing:
		smash_landing = enemy
	var to_enemy := enemy.global_position - ball_position()
	var before := pre_contact_velocity(to_enemy.normalized() if to_enemy.length() > 0.01 else Vector3.DOWN)
	var planar := Vector2(before.x, before.z).length()
	var away := Vector3(to_enemy.x, 0.0, to_enemy.z)
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	if before.y < -STOMP_SPEED and normal.y > 0.3:
		# The one mechanic worth keeping from the orchard: a descending rebound
		# gives the air jump back, so bouncing is a way to keep a line going.
		refresh_air()
		kit.rewind_left = 0.0
		state.impact = maxf(state.impact, -before.y)
		set_velocity_now(Vector3(before.x, tuning.f("jump_speed") * 0.95, before.z))
		enemy.knock(away * 0.6 + Vector3.DOWN * 0.2, 7.0 * _landing_mult)
		shockwave.emit(enemy.global_position, 0.6)
		struck.emit(enemy, STOMP, _landing_force(STOMP, -before.y))
	elif _rebounds_off(enemy) and before.dot(normal) < -Contact.MIN_CLOSING:
		_rebound(enemy, normal, before, planar, away)
	elif SpeedTier.of(planar, tuning.f("cruise")) >= SpeedTier.CRUISE:
		enemy.knock(away + Vector3.UP * 0.35, Augments.RAM_KNOCK * _landing_mult)
		enemy.flash()
		shockwave.emit(enemy.global_position, 1.0)
		# Planar speed, the same measure punch_now and the crush check use (one query).
		struck.emit(enemy, RAM, _landing_force(RAM, planar))
	if landing:
		_finish_landing(enemy, closing)
	smash_landing = null


# The first contact of a committed haul lets the line go, so the ordinary contact (stomp,
# rebound or ram) resolves on a free ball, and starts the rewind before it: a kill or a
# stomp inside that contact re-seats the hook at once.
func _begin_landing(enemy: Node3D) -> bool:
	if not kit.hooked or kit.line_state != Augments.LINE_SMASH or kit.anchor_body != enemy:
		return false
	kit.drop_line("landed")
	kit.rewind_left = tuning.f("harpoon_rewind")
	var paid: Dictionary = chain.pay()
	_landing_mult = paid["mult"]
	_publish_chain(paid["events"], enemy, ball_position())
	return true


# A landing contact's force, raised so the damage combat derives from it is the chain's
# multiplier times the plain landing (combat's rows are linear in force: a + force * b).
func _landing_force(kind: String, force: float) -> float:
	if _landing_mult == 1.0 or not CombatRules.STRIKE_DAMAGE.has(kind):
		return force
	var row: Array = CombatRules.STRIKE_DAMAGE[kind]
	return (_landing_mult * (row[0] + force * row[1]) - row[0]) / row[1]


# What the haul adds to that contact: the smash's shockwave, pins and this pilot's
# flavour at the speed the line closed at, then the fact. The struck body already took the
# landing contact; the shockwave strikes it again.
func _finish_landing(enemy: Node3D, closing: float) -> void:
	_on_slammed(ball_position(), closing, 1.0)
	var landed_on: Node3D = enemy if is_instance_valid(enemy) else null
	events.harpoon_smashed.emit(landed_on, ball_position(), closing)
	_emit_line("smash_lands", landed_on, ball_position(), "", LANDS_HOLD)
	_landing_mult = 1.0


# Only a body that says what it weighs can bounce you; a boss piece without a weight
# keeps the plain ram.
func _rebounds_off(enemy: Node3D) -> bool:
	var weight = enemy.get("weight")
	if kit.sprinting and tree.knob("sprint_no_rebound"):
		return false
	return weight != null and Contact.rebounds(float(weight), heft(), kit.sprinting)


# The bowling-ball rebound off something at least your weight: the incoming velocity
# reflected with restitution, one refresh, and the ram still lands if you were rolling
# fast enough for one.
func _rebound(enemy: Node3D, normal: Vector3, before: Vector3, planar: float, away: Vector3) -> void:
	var out := Contact.rebound_velocity(before, normal, tuning.f("jump_speed"))
	set_velocity_now(out)
	refresh_air()
	state.impact = maxf(state.impact, -before.dot(normal))
	enemy.knock(away + Vector3.UP * 0.2, 6.0 * _landing_mult)
	enemy.flash()
	shockwave.emit(enemy.global_position, 0.8)
	if SpeedTier.of(planar, tuning.f("cruise")) >= SpeedTier.CRUISE:
		struck.emit(enemy, RAM, _landing_force(RAM, planar))
	events.enemy_rebounded.emit(enemy, out.length())
