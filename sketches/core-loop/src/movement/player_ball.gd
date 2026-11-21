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
const Grip := preload("res://src/movement/grip.gd")
const Bindings := preload("res://src/core/bindings.gd")
const Contact := preload("res://src/movement/contact.gd")
const Indicator := preload("res://src/movement/indicator.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const ChainState := preload("res://src/combat/chain.gd")
const Dunk := preload("res://src/combat/dunk.gd")
const Redline := preload("res://src/combat/redline.gd")
const CombatRules := preload("res://src/combat/combat.gd")
const ExceptionHold := preload("res://src/movement/exception_hold.gd")

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
# Inside this the skid hits whatever the heading (the ring around the ball).
const SKID_INNER := 1.5
const SKID_REFUND := 0.5
# Tarn's rend turns the slam's outward shove into an inward pull this strong, so the
# crowd lands in claw reach.
const REND_PULL := 0.8
# Gutter Heart (rend_drag): a machine no heavier than the ball slides to the crater centre over
# this long; a heavier one holds. Machines move, the ball's own motion is never touched.
const DRAG_SECONDS := 0.4
const AIM_CONE_LENGTH := 5.0
const AIM_CONE_HALF := 0.3
# An aim mark starts this far from the ball's centre, clear of the cage, so it never draws over the ball.
const AIM_CONE_CLEAR := 1.3
# How long a transient line state stands before the steady one is published again.
const DRY_FIRE_HOLD := 0.25
const LET_GO_HOLD := 0.15
const BROKE_HOLD := 0.3
const LANDS_HOLD := 0.1
# A line or mount on a piece's face counts as on the piece within this many metres when it breaks.
const SHATTER_MARGIN := 0.25

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
# Restores Tally's pressure by a count (the stamp landing); combat wires it to _grant_pressure.
var pressure_grant := Callable()
# A body a ram or crush just killed keeps flying as a hulk that bowls what is ahead of it
# (enemy, direction, knock); combat wires it to bowl_hulk. Unwired, a kill bowls nothing.
var hulk_launch := Callable()
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
# Gutter Heart slides in flight, by enemy instance id: {enemy, to, t}.
var _drags := {}
# The enemy a harpoon smash is landing on while that landing's strikes resolve; combat reads it.
var smash_landing: Node3D
# The harpoon chain; this player is its only writer (HOOK-CHAIN.md).
var chain := ChainState.new()
# The dunk charge (dunk.gd): this player stores it from an air slam and ticks its clock; combat
# spends it on a reel impact; the glow and the cue read its signals.
var dunk := Dunk.new()
# Heat on the shell (redline.gd, behind --heat): this player fills it from speed and skims and
# spends it on its own contacts; combat reads its taken scale; the shell, the sound and the pad
# read its signals.
var redline := Redline.new()
# The chain's multiplier while a smash landing resolves; 1.0 otherwise.
var _landing_mult := 1.0
# The skill bar's router (design-v3/SKILL-BAR.md section 1). set_piece_phase answers the
# ultimate's phase (idle, windup, flight, recover); the ultimate unit sets it, and unset it
# reads idle. line_load_of answers combat.line_load(); combat wires it.
var set_piece_phase := Callable()
var line_load_of := Callable()
# The release latch: after a snap back with left click still down, the weapon ignores left
# click until it comes up, so a held cast never rolls into weapon fire.
var _fire_latched := false
# Left click as the source polled it this tick, before the router moves it to slot 2 or 3. A
# cast's snap back lands after the router cleared fire_*, so the latch reads this.
var _click_held := false

var _rigid
# The draw rig. _visual_root follows the shown position and never rotates; _juice is
# free for presentation (squash, stretch, trails); _mesh rolls; _roll_mount rolls with
# the mesh for anything that should stick to the ball's surface, like accreted scrap.
var _visual_root: Node3D
var _pod_mount: Node3D
var _juice: Node3D
var _mesh: MeshInstance3D
var _roll_mount: Node3D
var _wings: Node3D
var _wings_material: StandardMaterial3D
var _pylon: Node3D
var _plate: MeshInstance3D
var _roll := Basis.IDENTITY
# Keep-spin (MOTION-SPEC row 210): a mid-air velocity set forces a floor-roll spin on the
# body, which the lattice would draw as a mid-air wheel and a snap. The body keeps that spin
# (its friction and torque feed translation, so it is physics), and the lattice instead
# carries its own spin through the set, drawn only. A grounded hand-off lets it go.
const SPIN_AIR_DAMP := 0.25
const SPIN_HELD_DAMP := 2.5
var _spin_on := false
var _spin_basis := Basis.IDENTITY
var _spin_omega := Vector3.ZERO
var _spin_set_tick := -10
var _spin_held := false
var _spin_freeze := false
var _spin_offset := Basis.IDENTITY
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
# The speed bank (SQ9, Tuning.BANK_ROWS): {row, t, bonus0, bonus} while one runs, else empty.
# bonus is the planar speed the bank has added and not yet taken back.
var speed_bank := {}
var _speed_bank_airborne := false
var _speed_bank_jumped := false
enum BankMove { NONE, JUMP, SLIDE, SLIDE_FLIGHT }
var _speed_bank_chosen := BankMove.NONE
var _speed_bank_move_held := false
var _speed_bank_brake_held := false
# The grounded rest before a roll start: ticks the ball has sat grounded below BANK_REST,
# and whether the brake held it on any of them.
var _speed_bank_rest_ticks := 0
var _speed_bank_rest_braked := false
var _bow_check_queued := false
var _crushing := {}
# Every collision exception the ball takes goes through here, so none ends with the ball inside.
var exceptions
# The stage's heft destructibles and the Callable that answers the run's heft class (bind_destructibles).
var _destructibles: Node = null
var _destructibles_class := Callable()


func setup(tuning_ref, events_ref, spawn: Vector3) -> void:
	tuning = tuning_ref
	events = events_ref
	spawn_point = spawn

	_rigid = RigidBall.new()
	_rigid.name = "RigidBall"
	add_child(_rigid)
	exceptions = ExceptionHold.new(_rigid, Tuning.RADIUS)
	_rigid.setup(tuning, state)
	_rigid.intent = intent
	_rigid.kit = kit
	_rigid.velocity_setting.connect(_keep_spin)
	_rigid.teleporting.connect(_spin_clear)
	_rigid.enemy_touched.connect(_on_enemy_touched)
	_rigid.slammed.connect(_on_rigid_slammed)
	_rigid.pylon_planted.connect(_on_pylon_planted)
	_rigid.pylon_ejected.connect(func(v: Vector3): events.dismounted.emit(v))
	_rigid.jumped.connect(func(air: bool): events.jumped.emit(air))
	_rigid.boosted.connect(func(dir: Vector3): events.boosted.emit(dir))
	_rigid.kit_fact.connect(_on_kit_fact)
	tree.events = events
	tree.picked.connect(_on_tree_picked)
	events.enemy_killed.connect(func(_kind: String, _at: Vector3, _scrap: int): kit.rewind_left = 0.0)
	events.player_died.connect(func(): kit.drop_line("reset"))
	events.player_died.connect(func(): dunk.clear("reset"))
	events.stage_content_cleared.connect(func(_reason: String): dunk.clear("reset"))
	events.player_died.connect(func(): redline.clear())
	events.stage_entered.connect(func(_stage: int, _retry: bool): redline.clear())
	events.near_miss.connect(func(_kind: String, at: Vector3): redline.skim(state.tier, at))
	redline.cooked_off.connect(_redline_blast)
	redline.detonated.connect(_redline_blast)
	_smashes = {"arc": _smash_arc, "skid": _smash_skid, "demo": _smash_demo, "rend": _smash_rend, "stamp": _smash_stamp}
	events.run_started.connect(func(class_id: String):
		fit_class(ClassDef.by_id(class_id))
		chain.reset()
		redline.set_mode(tuning.option("heat"))
		redline.reset_counts()
		tree.open_checkpoint())
	# The workshop visits after stages 1 to 3 each open one more pick: world's bay opens
	# it on entry, or at the stage's clear when the bay was skipped (world.gd).
	events.stage_entered.connect(func(_stage: int, _retry: bool): abilities.refill())
	events.stage_content_cleared.connect(func(_reason: String): abilities.refill())
	# The selection goes home on a cast and at every reset point (SKILL-BAR section 1).
	events.slot_cast.connect(func(_slot: String, _id: String, _at: Vector3): snap_slots("cast"))
	events.ultimate_started.connect(func(_id: String, _path: String, _from: Vector3, _to: Vector3, _seconds: float):
		snap_slots("ultimate"))
	events.stage_entered.connect(func(_stage: int, _retry: bool): snap_slots("reset"))
	events.stage_content_cleared.connect(func(_reason: String): snap_slots("reset"))
	events.player_died.connect(func(): snap_slots("reset"))
	events.run_ended.connect(func(_won: bool): snap_slots("reset"))
	events.world_fact.connect(func(kind: String, _at: Vector3):
		if kind in ["ride_chute", "ride_grapple_line", "ride_bowl", "ride_drop", "ride_ledge",
			"kicker_launch", "ride_glide_drop", "thermal_ride", "ride_hop", "crater_ride", "lift_fired"]:
			_clear_speed_bank())
	_rigid.landed.connect(func(impact: float): events.landed.emit(impact))
	_rigid.bumped.connect(func(at: Vector3, normal: Vector3, speed: float): events.bumped.emit(at, normal, speed))
	_rigid.jumped.connect(func(air: bool):
		if not air:
			_speed_bank_jumped = true
		_speed_bank_chosen = BankMove.JUMP
		_speed_bank_airborne = false)

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
	# Level sibling of Juice for the cockpit: takes the juice offset, never its basis.
	_pod_mount = Node3D.new()
	_pod_mount.name = "PodMount"
	_visual_root.add_child(_pod_mount)
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
	if is_inside_tree() and get_tree().physics_interpolation and not _rigid.placing:
		return _rigid.get_global_transform_interpolated()
	return _rigid.global_transform


func shown_position() -> Vector3:
	return shown_transform().origin


# Presentation hooks. The juice node is presentation's to transform and parent to;
# the spine never writes it. The roll mount turns with the ball's surface.
func juice_node() -> Node3D:
	return _juice


# Where HeroPod mounts: follows the juice position, ignores its squash and shell scale.
func pod_mount() -> Node3D:
	return _pod_mount


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
		_clear_speed_bank()
		_rigid.external_accel = Vector3.ZERO


func frozen() -> bool:
	return _frozen


func reset_to(point: Vector3, velocity := Vector3.ZERO) -> void:
	_bank_pending = {}
	_drags.clear()
	_clear_speed_bank()
	_speed_bank_move_held = false
	_speed_bank_brake_held = false
	_speed_bank_rest_ticks = 0
	_speed_bank_rest_braked = false
	state.reset()
	kit.clear_runtime()
	chain.clear_active()
	_roll = Basis.IDENTITY
	_spin_clear()
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
# would fight it, so it lets go. The set piece passes the cause "ultimate", which publishes
# no "broke" (SKILL-BAR section 4, line cut cause).
func set_velocity_now(velocity: Vector3, cause := "launched") -> void:
	cut_line(cause)
	_clear_speed_bank()
	_rigid.set_velocity_now(velocity)


# Runs from the body's velocity_setting signal, before every velocity set however it is made
# (a ride tick, a reel, a fling, a launch). Airborne, the lattice starts (or keeps) its own
# spin from the body's spin of this moment; a set on consecutive ticks is a held ride, which
# decays toward 0. Grounded, the hand-off ends the carry.
func _keep_spin() -> void:
	var tick := Engine.get_physics_frames()
	if state.grounded:
		_spin_end()
		return
	_spin_held = tick - _spin_set_tick <= 1
	_spin_set_tick = tick
	if _spin_on:
		return
	_spin_on = true
	# The seed reads the basis the draw reads, and settles a landing freeze this frame has not
	# drawn yet, so a grounded set then an airborne one inside a frame cannot overwrite it.
	_settle_offset(_body_basis())
	_spin_basis = (_body_basis() * _spin_offset).orthonormalized()
	_spin_omega = _rigid.angular_velocity


# A grounded hand-off: the lattice takes the body's spin at once. Its orientation is frozen
# as an offset from the body's, so nothing turns to catch up.
func _spin_end() -> void:
	if _spin_on:
		_spin_on = false
		_spin_freeze = true


# The body orientation the lattice is drawn against: the same (interpolated) one _process reads.
func _body_basis() -> Basis:
	return shown_transform().basis.orthonormalized()


func _settle_offset(body_basis: Basis) -> void:
	if _spin_freeze:
		_spin_freeze = false
		_spin_offset = (body_basis.inverse() * _spin_basis).orthonormalized()


func _spin_clear() -> void:
	_spin_on = false
	_spin_freeze = false
	_spin_offset = Basis.IDENTITY


# The basis the lattice draws: the body's times the frozen offset, unless a carried spin runs.
func _drawn_basis(body_basis: Basis, delta: float) -> Basis:
	body_basis = body_basis.orthonormalized()
	if _spin_on and state.grounded and Engine.get_physics_frames() - _spin_set_tick > 1:
		_spin_end()
	if _spin_on:
		var held := _spin_held and Engine.get_physics_frames() - _spin_set_tick <= 1
		_spin_omega *= exp(-(SPIN_HELD_DAMP if held else SPIN_AIR_DAMP) * delta)
		var w := _spin_omega.length()
		if w > 0.0001:
			_spin_basis = (Basis(_spin_omega / w, w * delta) * _spin_basis).orthonormalized()
		return _spin_basis
	_settle_offset(body_basis)
	return (body_basis * _spin_offset).orthonormalized()


# PC-SABLE: the hand-off bypasses RMB's Coil Hook fling. A committed smash keeps its
# pivot until the paid contact publishes harpoon_smashed.
var _bank_pending := {}
var bank_last := {}
var _bank_logging_deferred := false


func bank_geometry() -> Dictionary:
	var at := ball_position()
	var launch := Augments.bank_exit(state.velocity.length(), at - kit.anchor, drive_basis, kit)
	return _aim_cone(at, launch.normalized(), AIM_CONE_LENGTH * (1.0 + launch.length() / Augments.LAUNCH_CEILING), {"speed": launch.length()})


# The record of an aim mark: the line the ball would leave `at` along, `length` metres of it.
func _aim_cone(at: Vector3, dir: Vector3, length: float, more := {}) -> Dictionary:
	var shape := {"kind": "cone", "aim": true, "apex": at, "dir": dir, "length": length, "half_angle": AIM_CONE_HALF, "clear": AIM_CONE_CLEAR}
	shape.merge(more)
	return yours(shape)


func bank_shot() -> void:
	if kit.line_state == Augments.LINE_SMASH:
		_bank_pending = {"anchor": kit.anchor}
		return
	_bank_release(kit.anchor)


func _bank_release(anchor: Vector3) -> void:
	var incoming := state.velocity.length()
	var base := maxf(incoming, minf(Augments.LAUNCH_CEILING, maxf(incoming, 13.0) * 1.25 + 4.0))
	var launch := Augments.bank_exit(incoming, ball_position() - anchor, drive_basis, kit)
	Augments.mass_spend(kit, base)
	bank_last = {"entry": incoming, "exit": launch.length(), "dir": launch.normalized(), "pending_log": _bank_logging_deferred}
	kit.mounted = false
	kit.slingshot.cancel()
	set_velocity_now(launch, "bank")
	chain.let_go()
	events.dismounted.emit(launch)


# The set piece's landing pays the chain as a paid smash does: returns the multiplier and
# publishes the chain's end.
func pay_chain(at: Vector3) -> float:
	var paid: Dictionary = chain.pay()
	_publish_chain(paid["events"], null, at)
	return float(paid["mult"])


# True while the set piece rides (wind-up to recovery).
func in_set_piece() -> bool:
	if not set_piece_phase.is_valid():
		return false
	var phase := String(set_piece_phase.call())
	return phase != "idle" and phase != ""


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


# The stage's heft destructibles (world calls this on each stage entry, and with null at its end): the ball's
# blasts (slam, Redline) reach them with the class `class_of` answers, and a piece that breaks lets go of any
# line, mount or aim that stood on it the same tick.
func bind_destructibles(pieces: Node, class_of := Callable()) -> void:
	if is_instance_valid(_destructibles) and _destructibles.piece_shattered.is_connected(_on_piece_shattered):
		_destructibles.piece_shattered.disconnect(_on_piece_shattered)
	_destructibles = pieces
	_destructibles_class = class_of
	redline.blast_props = _break_props if pieces != null else Callable()
	if pieces != null:
		pieces.piece_shattered.connect(_on_piece_shattered)


func _break_props(at: Vector3, radius: float, source: String) -> void:
	if is_instance_valid(_destructibles):
		_destructibles.on_blast(at, radius, source, 1, int(_destructibles_class.call()) if _destructibles_class.is_valid() else -1)


# True when `point` lies in the piece that just broke (its own oriented box when the module can say, else the
# world box), grown by a quarter metre so a face the line or mount sat on still counts.
func _point_in_shattered(bounds: AABB, point: Vector3) -> bool:
	var id: String = _destructibles.last_shattered_id() if is_instance_valid(_destructibles) else ""
	if id != "":
		return _destructibles.contains_point(id, point, SHATTER_MARGIN)
	return bounds.grow(SHATTER_MARGIN).has_point(point)


# A world line, a pylon mount or a harpoon aim that rested on the piece cannot outlive it: the line is cut, the
# mount is dropped and the aim is cleared on the tick of the break, so a press the same tick finds no surface.
func _on_piece_shattered(bounds: AABB) -> void:
	if kit.hooked and not kit.on_body and _point_in_shattered(bounds, kit.anchor):
		cut_line("shattered")
	if kit.mounted and _point_in_shattered(bounds, kit.mount_face):
		kit.mounted = false
		kit.slingshot.cancel()
		kit.mount_block = Augments.MOUNT_COOLDOWN
		kit.dismount_velocity = Vector3.ZERO
		kit.dismount_fired = true
	if kit.aim.get("state", Augments.AIM_NONE) != Augments.AIM_NONE and kit.aim.get("body") == null and _point_in_shattered(bounds, kit.aim["point"]):
		kit.aim = Augments.no_aim()


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
	_clear_speed_bank()
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
	_clear_speed_bank()
	Augments.attach(kit, ball_position(), point, normal, body)
	kit.grip = Grip.of(body, heft(), tuning.pole_flail())
	events.grapple_fired.emit(point)
	if body != null:
		if body.has_method("flash"):
			body.flash()
		events.harpoon_bit.emit(body, point)
	_publish_chain(chain.link(body != null and not body.is_in_group(Augments.STAKE_GROUP)
		and not body.is_in_group(Augments.WORLD_ANCHOR_GROUP), state.grounded), body, point)


# A flail strike on another enemy is a chain link (POLES-FLAILS section 5; flail.gd).
func link_chain(body: Node3D) -> void:
	_publish_chain(chain.link(true, state.grounded), body, body.global_position)


func release_grapple() -> void:
	_clear_speed_bank()
	kit.drop_line()


# A hostile hold that lands, or a ride or launch, cuts the harpoon line; `cause` is what the
# line_state_changed signal names, and the release cue is grapple_released.
func cut_line(cause := "hold") -> void:
	_clear_speed_bank()
	kit.drop_line(cause)


func grapple_range() -> float:
	return tuning.f("rope_range")


func _physics_process(delta: float) -> void:
	exceptions.step(delta)
	_step_drags(delta)
	source.poll(intent)
	_route_slots(delta)
	abilities.movement_key = _burst_key()
	_read_mass()
	_route_interact()
	_read_grammar()
	abilities.tick(delta)
	immune_left = maxf(0.0, immune_left - delta)
	if kit.mounted and tree.knob("mounted_recharge") > 1.0:
		abilities.refund(AbilityState.SPECIAL, delta * (tree.knob("mounted_recharge") - 1.0))
	state.tick_timers(delta)
	_tick_speed_bank(delta)
	if intent.jump_pressed:
		state.jump_buffer = Tuning.JUMP_BUFFER
	_rigid.drive_basis = drive_basis
	state.refresh_tier(tuning.f("cruise"))
	if _was_hooked and not kit.hooked:
		events.grapple_released.emit()
	_was_hooked = kit.hooked
	_publish_line(delta)
	dunk.tick(delta)
	if redline.mode != Redline.OFF:
		redline.tick(delta, state.tier, ball_position(), state.velocity.length())
	_tick_chain(delta)
	_recheck_bow()
	_tick_face_tags(delta)
	_mark_slots()


func _clear_speed_bank() -> void:
	speed_bank = {}
	_speed_bank_airborne = false
	_speed_bank_jumped = false
	_speed_bank_chosen = BankMove.NONE


# Only a chosen jump or ground brake/slide can pay its next landing. External
# motion clears that eligibility. A fresh stick input from a free rest banks
# immediately: the ball sat grounded below BANK_REST before the press, and the brake
# held it on none of those ticks. A braked stop is a placed ball, so a timed launch
# from it (the dam sheet's foot) starts clean; a press before the first grounded rest
# after a reset is not a start from rest.
# Air pauses decay; a ground jump spends it using the original per-pilot curve.
func _tick_speed_bank(delta: float) -> void:
	var landed := false
	var jumped := _speed_bank_jumped
	_speed_bank_jumped = false
	var moving := intent.move.length_squared() >= 0.02
	var roll_start := moving and not _speed_bank_move_held
	var slide_start := intent.brake_held and not _speed_bank_brake_held
	_speed_bank_move_held = moving
	_speed_bank_brake_held = intent.brake_held
	var cruise: float = tuning.f("cruise")
	if _frozen or kit.hooked or Augments.holding(kit) or in_set_piece():
		_clear_speed_bank()
		_speed_bank_rest_ticks = 0
		_speed_bank_rest_braked = false
		return
	# The bank reads a gripped wall as the air it was before grip: planar speed on a climb is
	# near zero, and a rest there would let a roll start push the ball along the wall.
	var floored: bool = state.grounded and state.contact_normal.y > Tuning.MAX_SLOPE_DOT
	var planar := planar_velocity()
	var speed := planar.length()
	var free_rest := _speed_bank_rest_ticks > 0 and not _speed_bank_rest_braked
	if floored and speed <= Tuning.BANK_REST * cruise:
		_speed_bank_rest_ticks += 1
		_speed_bank_rest_braked = _speed_bank_rest_braked or intent.brake_held
	else:
		_speed_bank_rest_ticks = 0
		_speed_bank_rest_braked = false
	var probe_grounded := false
	for i in _rigid._probe.get_collision_count():
		if _rigid._probe.get_collision_normal(i).y > Tuning.MAX_SLOPE_DOT:
			probe_grounded = true
	# Grounding consumes the chosen flight even when the impact is too gentle to
	# publish landed. Jump changes state.grounded before the probe leaves ground.
	if _speed_bank_chosen != BankMove.NONE:
		if not probe_grounded:
			_speed_bank_airborne = true
		elif _speed_bank_airborne:
			landed = true
			_speed_bank_chosen = BankMove.NONE
			_speed_bank_airborne = false
	if _speed_bank_chosen == BankMove.SLIDE:
		if not floored:
			_speed_bank_chosen = BankMove.SLIDE_FLIGHT
		elif not intent.brake_held or speed <= Tuning.BANK_REST * cruise:
			_speed_bank_chosen = BankMove.NONE
	if slide_start and floored and speed >= Tuning.BANK_ARM * cruise:
		_speed_bank_chosen = BankMove.SLIDE
		_speed_bank_airborne = false
	roll_start = roll_start and free_rest and floored and not intent.brake_held and speed <= Tuning.BANK_REST * cruise
	if not speed_bank.is_empty() and jumped:
		var row: Dictionary = speed_bank["row"]
		var u: float = speed_bank["t"] / float(row["decay_s"])
		if u >= 1.0 - Tuning.BANK_WINDOW:
			_bank_push(planar, maxf(0.0, float(row["ratio"]) * cruise - speed))
		else:
			_bank_push(planar, -minf(float(speed_bank["bonus"]), maxf(0.0, speed - cruise)))
		speed_bank = {}
		return
	if speed_bank.is_empty():
		if not floored or not (roll_start or (landed and speed >= Tuning.BANK_ARM * cruise)):
			return
		var row := Tuning.bank_row(class_def.id if class_def != null else "")
		var bonus := float(row["ratio"]) * cruise - speed
		if bonus <= 0.0:
			return
		if roll_start:
			var heading := Rules.wish_direction(intent, drive_basis, state)
			var target := Vector3(heading.x, 0.0, heading.z).normalized() * float(row["ratio"]) * cruise
			var push := target - planar
			_bank_push(push, push.length())
		else:
			_bank_push(planar, bonus)
		var banked := minf(bonus, (float(row["ratio"]) - 1.0) * cruise)
		speed_bank = {"row": row, "t": 0.0, "bonus0": banked, "bonus": banked}
		return
	if not floored:
		return
	var row: Dictionary = speed_bank["row"]
	speed_bank["t"] += delta
	var left: float = float(speed_bank["bonus0"]) * Tuning.bank_share(row, speed_bank["t"] / float(row["decay_s"]))
	var give_back: float = float(speed_bank["bonus"]) - left
	speed_bank["bonus"] = left
	_bank_push(planar, -minf(give_back, maxf(0.0, speed - (cruise + left))))
	if speed_bank["t"] >= float(row["decay_s"]):
		_clear_speed_bank()


# Match the added spin to the contact plane as well as the planar impulse.
func _bank_push(planar: Vector3, dv: float) -> void:
	if absf(dv) < 0.0001 or planar.length_squared() < 0.0001:
		return
	var push := planar.normalized() * dv
	_rigid.apply_central_impulse(push * _rigid.mass)
	var axis := Rules.roll_axis(push, state.contact_normal if state.grounded else Vector3.UP)
	if axis != Vector3.ZERO:
		_rigid.angular_velocity += axis / Tuning.RADIUS
	state.velocity += push


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
	var line = abilities.gauge(AbilityState.LINE)
	return (special != null and special.charging) or (line != null and line.charging) or kit.slingshot.charging \
		or abilities.casting != AbilityState.UNSTARTED


# --- The skill bar's router (design-v3/SKILL-BAR.md sections 1 and 2) -------------------
# Runs right after the poll and before the grammar, on the player's physics tick, which runs
# ahead of combat's (the player is added to the tree first), so combat reads the routed
# fields on the same tick.
func _route_slots(delta: float) -> void:
	_click_held = intent.fire_held
	# The latch lasts only until the click comes up, whichever slot is picked meanwhile, so
	# a stale latch never eats a later click.
	if _fire_latched and not intent.fire_held:
		_fire_latched = false
		intent.fire_released = false
	if in_set_piece():
		_swallow_for_set_piece()
		return
	# The timeout runs before the click is routed: a click on the tick the pick goes stale is
	# the weapon's, never both a slot cast and a weapon shot.
	if abilities.tick_selection(delta, abilities.charging()):
		snap_slots("timeout", intent.fire_held and not intent.fire_pressed)
	if intent.slot_pick >= 0 and intent.slot_pick < AbilityState.BAR.size():
		_pick(AbilityState.BAR[intent.slot_pick])
	var picked: String = abilities.selected
	if picked == AbilityState.SPECIAL:
		intent.special_pressed = intent.special_pressed or intent.fire_pressed
		intent.special_held = intent.special_held or intent.fire_held
		intent.special_released = intent.special_released or intent.fire_released
		_clear_fire()
	elif picked == AbilityState.LINE:
		intent.line_pressed = intent.line_pressed or intent.fire_pressed
		intent.line_held = intent.line_held or intent.fire_held
		intent.line_released = intent.line_released or intent.fire_released
		_clear_fire()
	elif _fire_latched:
		_clear_fire()


# During the set piece only the roll (steering), Space (bail) and Q (recall) reach the ball.
func _swallow_for_set_piece() -> void:
	var move := intent.move
	var jump_pressed := intent.jump_pressed
	var jump_held := intent.jump_held
	var ultimate_pressed := intent.ultimate_pressed
	intent.clear()
	intent.move = move
	intent.jump_pressed = jump_pressed
	intent.jump_held = jump_held
	intent.ultimate_pressed = ultimate_pressed


func _clear_fire() -> void:
	intent.fire_pressed = false
	intent.fire_held = false
	intent.fire_released = false


# A number key. The home key, or the picked number again, is the undo: any gauge on the
# picked slot drops and the selection goes home. Another number drops whatever gauge charges
# (a picked slot's, or Kest's slot-1 sticky gauge) and picks the new slot if it is ready.
func _pick(slot: String) -> void:
	var held: String = abilities.selected
	if slot == AbilityState.WEAPON or slot == held:
		if held == AbilityState.WEAPON:
			return
		_drop_gauge(held, "cancel")
		snap_slots("deselect")
		return
	var swapped := false
	if held != AbilityState.WEAPON:
		swapped = _drop_gauge(held, "swap")
	else:
		for id in abilities.cancel_gauges():
			events.gauge_cancelled.emit(id, "swap")
			indicator.collapse_all()
	var refusal := "loaded" if slot == AbilityState.LINE and _line_loaded() else abilities.select(slot)
	if refusal != "":
		_fail("select", refusal)
		if swapped:
			snap_slots("swap")
		return
	events.slot_selected.emit(slot, "swap" if swapped else "pick")


# Drops a picked slot's charging gauge with nothing spent. True when one was charging.
func _drop_gauge(slot: String, reason: String) -> bool:
	var gauge = abilities.gauge(slot)
	if gauge == null or not gauge.cancel():
		# A slot with a cast time drops its running cast the same way (FIELDS-AND-CASTS section 4).
		if abilities.casting != slot or abilities.cancel_cast() == "":
			return false
	indicator.collapse(slot)
	events.gauge_cancelled.emit(abilities.id_of(slot), reason)
	return true


func _line_loaded() -> bool:
	return line_load_of.is_valid() and not (line_load_of.call() as Dictionary).is_empty()


# The one door for a snap back to slot 1 (SKILL-BAR section 1): publishes slot_selected with
# the reason when the selection moves, and latches left click if it is still down. The
# timeout passes its own reading: a click pressed on the timeout tick is fresh, not held.
func snap_slots(reason: String, latch := true) -> void:
	if not abilities.snap_back(reason):
		return
	if latch and (intent.fire_held or _click_held):
		_fire_latched = true
	events.slot_selected.emit(AbilityState.WEAPON, reason)


# Right mouse is the line for every pilot, except while the special or the slingshot charges:
# then its press cancels the charge and moves nothing. Shift is the one go verb of the
# pilot (Sable's boost, Rivet's sprint, Kest's blink) and Ctrl hauls the line in.
func _read_grammar() -> void:
	_read_shift()
	if intent.harpoon_pressed and _charging():
		intent.harpoon_pressed = false
		intent.cancel_pressed = true
		# A cancelled cast ends the intent: the pick goes home (SKILL-BAR section 1).
		snap_slots("cancel")
	_read_ctrl()
	if _frozen or not kit.on(Augments.GRAPPLE):
		return
	if intent.harpoon_pressed and not kit.hooked:
		_press_harpoon()
	elif intent.harpoon_released and kit.hooked:
		_fling()
		_pole_exit()
		release_grapple()
	# Rope Anchor: winching up to the wall with Ctrl plants the pylon there.
	if tree.knob("winch_mount") and kit.hooked and kit.winching and not kit.mounted \
			and ball_position().distance_to(kit.anchor) <= Augments.MIN_ROPE + 2.5:
		intent.mount_pressed = true


# The movement chip's key: Shift for every pilot. Sable's chip is her boost, since her movement
# row is the harpoon and the harpoon has no slot (SKILL-BAR section 1).
func _burst_key() -> String:
	return Bindings.label("boost")


# The pilot's class burst is on Shift (Rivet's sprint, Kest's blink, Tarn's claw pull, Tally's flywheel surge, the remembered cannon's recoil); Sable's Shift is the boost.
# The keyboard fills shift_*; a scripted source fills boost_* and movement_* itself.
func _burst_pilot() -> bool:
	return kit.on(Augments.SPRINT) or kit.on(Augments.BLINK) or kit.on(Augments.CLAW_PULL) or kit.on(Augments.SURGE) \
		or kit.on(Augments.RECOIL)


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
# smash (on a Warden line only inside its stagger) or winches, "boost" is Shift's verb for this pilot, "interact" is E where it would mount
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
					and (not kit.on_body or (kit.line_state == Augments.LINE_LATCHED and Augments.haul_open(kit)))
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
	if Augments.holding(kit):
		return "busy"
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
		if reason == "no_aim":
			_publish_chain(chain.dry_fire(), null, ball_position())
	_fail("harpoon", reason)


# Why Ctrl cannot commit the haul on this latched body line: a flail hangs behind the ball, a
# stake only holds the rope, and a Warden opens to the haul only inside its stagger.
func _haul_refusal() -> String:
	if kit.grip == "flail":
		return "flail"
	if is_instance_valid(kit.anchor_body) and kit.anchor_body.is_in_group(Augments.STAKE_GROUP):
		return "stake"
	return "unstaggered"


# A standing line owns Ctrl, so Ctrl is not the slam or the brake while this is true.
func line_stands() -> bool:
	return kit.hooked


# Ctrl hauls the line in. On a latched body it commits the smash; on the world it winches
# while held. While any line stands it is neither the brake nor the slam, until it is let
# go: a haul can never plant or brake inside the crowd it flew into.
func _read_ctrl() -> void:
	var edge: bool = intent.brake_held and not _brake_was_held
	_brake_was_held = intent.brake_held
	var on_body: bool = kit.hooked and kit.on_body
	kit.winching = kit.hooked and not on_body and intent.brake_held
	if edge and not _frozen:
		# Mounted or planted, the ball is held: a smash committed now would freeze under the
		# hold and then overwrite the slingshot's launch (verb_ready("haul") already says no).
		if on_body and kit.line_state == Augments.LINE_LATCHED and Augments.holding(kit):
			_fail("haul", "busy")
		elif on_body and kit.line_state == Augments.LINE_LATCHED and Augments.haul_open(kit):
			Augments.commit_smash(kit, tuning, _rigid.linear_velocity)
		elif on_body and kit.line_state == Augments.LINE_LATCHED:
			_fail("haul", _haul_refusal())
		elif on_body:
			_fail("haul", "committed")
	if line_stands():
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


# During the set piece the chain clock is frozen: no grace runs out and no landing ends it
# until the set piece's own landing pays it (SKILL-BAR section 4, landing strike).
func _tick_chain(delta: float) -> void:
	if in_set_piece():
		return
	_publish_chain(chain.tick(delta, state.grounded, kit.hooked), null, ball_position())


# Publishes how the line that stood has ended: a let-go or a break with its cause. A landing,
# a reset or the set piece's own cut (cause "ultimate") publishes nothing here.
const QUIET_ENDS := ["landed", "reset", "ultimate", "bank", ""]


func _publish_end() -> void:
	_line_standing = false
	var end: String = kit.line_end
	if end != "landed":
		_bank_pending = {}
	kit.line_end = ""
	if not end in QUIET_ENDS:
		chain.let_go()
	if end == "let_go":
		_emit_line("let_go", _line_target_alive(), _line_anchor, "", LET_GO_HOLD)
	elif not end in QUIET_ENDS:
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


# Letting go of a pole slingshots you on along the tangent (POLES-FLAILS section 4): a share
# of the speed across the line is added along it, never past the soft cap.
func _pole_exit() -> void:
	if not Augments.pole_line(kit):
		return
	var v: Vector3 = state.velocity
	var to_body: Vector3 = kit.anchor - ball_position()
	if to_body.length() < 0.01:
		return
	var share := Augments.POLE_EXIT_SABLE if class_def != null and class_def.id == "pylon_engineer" else Augments.POLE_EXIT
	_rigid.set_velocity_now(Augments.pole_exit(v, to_body.normalized(), share))


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


func _process(delta: float) -> void:
	var shown := shown_transform()
	_visual_root.global_position = shown.origin
	_visual_root.global_basis = Basis.IDENTITY
	_update_augment_visuals(shown.origin)
	_update_aim_cones(shown.origin)
	_roll = _drawn_basis(shown.basis, delta)
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


func _on_bow_entered(_body: Node3D) -> void:
	# Batch the server's unordered notifications before assigning seeded kill payouts.
	if not _bow_check_queued:
		_bow_check_queued = true
		_flush_bow.call_deferred()


func _flush_bow() -> void:
	_bow_check_queued = false
	_recheck_bow()


# Rechecked every tick for whatever is inside the bow, so an enemy the ball grows or
# speeds into outweighing mid-overlap is still rolled up.
func _recheck_bow() -> void:
	if _bow == null or _frozen or state.tier < SpeedTier.CRUISE:
		return
	var bodies := _bow.get_overlapping_bodies()
	bodies.sort_custom(func(a: Node, b: Node): return b.is_greater_than(a))
	for body in bodies:
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
	exceptions.hold(body)
	var closing := kit.line_closing
	var landing := _begin_landing(body)
	if landing:
		smash_landing = body
	struck.emit(body, RAM, _landing_force(RAM, speed))
	_bowl_if_killed(body, planar_velocity(), Contact.ram_knock(Augments.RAM_KNOCK, speed, heft(), _landing_mult))
	if landing:
		_finish_landing(body, closing)
	smash_landing = null
	get_tree().create_timer(CRUSH_PASS, false, true).timeout.connect(_end_crush.bind(id))


# Bound by id: the crushed enemy is usually freed by now, and a freed exception
# leaves the physics server with it. One that lives is let go once the ball is clear of it.
func _end_crush(id: int) -> void:
	_crushing.erase(id)
	var body := instance_from_id(id)
	if is_instance_valid(body) and body is PhysicsBody3D:
		exceptions.release(body)


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
# The slam's reach: the shared radius plus the build's flat area (Splash Skirt panels).
func slam_radius() -> float:
	return Augments.SLAM_RADIUS + tuning.add("area_radius")


static func slam_strength(speed: float, flatness := 1.0) -> float:
	return clampf(speed / 30.0, 0.4, 1.6) * flatness


# The shockwave carries the same flatness as the plant: a full thump on flat ground,
# next to nothing when the slam went into a launch.
# Every class slams the same way; the landing then takes the class's flavour.
# The body's own slam (cast in the air, landed on the ground) is the one that feeds the dunk
# charge: the shared slam first, then its damage, flavour and the pilot's colour stored. The
# harpoon's smash landing calls _on_slammed directly and stores nothing.
func _on_rigid_slammed(at: Vector3, speed: float, flatness: float) -> void:
	_on_slammed(at, speed, flatness)
	var strength := slam_strength(speed, flatness)
	if strength < 0.05:
		return
	dunk.store(Dunk.slam_damage(Augments.SLAM_KNOCK * strength, CombatRules.STRIKE_DAMAGE["slam"], heft()) * tuning.mod("dunk_store"),
		kit.smash_flavour, String(class_def.id) if class_def != null else "", class_color())


func _on_slammed(at: Vector3, speed: float, flatness: float) -> void:
	var strength := slam_strength(speed, flatness)
	events.slammed.emit(at, strength, flatness)
	if strength >= 0.05:
		shockwave.emit(at, strength)
		_break_props(at, slam_radius(), "slam")
		var hits := _push_enemies(at, slam_radius(), Augments.SLAM_KNOCK * strength, SLAM, Contact.heft_knock(heft()))
		if hits > 0:
			events.drop_landed.emit(hits)
			redline.spend(SLAM, at, Augments.SLAM_KNOCK * strength)
		else:
			events.missed_drop.emit()
	if _smashes.has(kit.smash_flavour):
		_smashes[kit.smash_flavour].call(at, speed)


func _smash_arc(at: Vector3, _speed: float) -> void:
	events.arc_slammed.emit(at, _tag_faces(at))


func _smash_skid(at: Vector3, speed: float) -> void:
	events.skid_smashed.emit(at, _skid_push(at, clampf(speed / 30.0, 0.4, 1.6)))


func _smash_demo(at: Vector3, _speed: float) -> void:
	events.demo_slammed.emit(at)


# The shared slam already struck these enemies; the rend only pulls, so no second strike.
func _smash_rend(at: Vector3, speed: float) -> void:
	if abilities.cap(AbilityState.SMASH, "mutation", "") == "rend_drag":
		_drag_in(at)
		return
	var strength := clampf(speed / 30.0, 0.4, 1.6)
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.has_method("is_dead") and enemy.is_dead():
			continue
		var inward: Vector3 = at - enemy.global_position
		if inward.length() > slam_radius():
			continue
		inward.y = 0.0
		inward = inward.normalized() if inward.length() > 0.01 else Vector3.FORWARD
		enemy.knock(inward + Vector3.UP * 0.2, Contact.heft_shove(Augments.SLAM_KNOCK * strength * REND_PULL, heft()))
		enemy.flash()


# Rend drag: every machine in the disc no heavier than the ball (Grip.heft_of, the weight rule of
# POLES-FLAILS) starts a slide to the centre; a heavier one took the slam and holds. One inward
# pull per landing, and nothing here reads or writes the ball's velocity.
func _drag_in(at: Vector3) -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.has_method("is_dead") and enemy.is_dead():
			continue
		var offset: Vector3 = at - enemy.global_position
		if offset.length() > slam_radius() or Grip.heft_of(enemy) > heft():
			continue
		_drags[enemy.get_instance_id()] = {"enemy": weakref(enemy), "to": at, "t": 0.0}
		enemy.flash()


# Closes each dragged machine's gap to the centre by the slide's share of this frame, so the
# shove of the shared slam cannot carry it off the line and it arrives at DRAG_SECONDS. A body
# the world blocks stops where it stands.
func _step_drags(delta: float) -> void:
	for id in _drags.keys():
		var drag: Dictionary = _drags[id]
		var enemy = drag["enemy"].get_ref()
		if enemy == null or (enemy.has_method("is_dead") and enemy.is_dead()):
			_drags.erase(id)
			continue
		var before: float = smoothstep(0.0, 1.0, drag["t"] / DRAG_SECONDS)
		drag["t"] = minf(float(drag["t"]) + delta, DRAG_SECONDS)
		var after: float = smoothstep(0.0, 1.0, drag["t"] / DRAG_SECONDS)
		var gap: Vector3 = drag["to"] - enemy.global_position
		gap.y = 0.0
		var step: Vector3 = gap * (after - before) / maxf(1.0 - before, 0.0001)
		if enemy is CharacterBody3D:
			enemy.move_and_collide(step)
		else:
			enemy.global_position += step
		if drag["t"] >= DRAG_SECONDS:
			_drags.erase(id)


# The shared slam already struck these enemies as "slam"; the stamp turns each one it
# reached into a pressure point and strikes nothing again.
func _smash_stamp(at: Vector3, _speed: float) -> void:
	var count := 0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.has_method("is_dead") and enemy.is_dead():
			continue
		if (enemy.global_position - at).length() <= slam_radius():
			count += 1
	if count > 0 and pressure_grant.is_valid():
		pressure_grant.call(count)


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


# Rivet's skid knocks what is ahead of the ball forward and refunds sprint per hit. reach and
# inner default to the Shockwave Skid's; the Breach Skid (rivet_kit.gd) reads the same cone
# through in_skid_cone at 1.5 x the class landing radius and a 2.5 m ring.
func _skid_push(at: Vector3, strength: float, reach := SKID_REACH, inner := SKID_INNER) -> int:
	var ahead := planar_velocity()
	ahead = ahead.normalized() if ahead.length() > 0.5 else Vector3.FORWARD
	var hits := 0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var to: Vector3 = enemy.global_position - at
		to.y = 0.0
		if not in_skid_cone(to, ahead, reach, inner):
			continue
		var falloff := 1.0 - to.length() / reach
		enemy.knock(ahead + Vector3.UP * 0.3, Contact.heft_shove(Augments.SLAM_KNOCK * strength * falloff * tree.knob("skid_pins"), heft()))
		enemy.flash()
		struck.emit(enemy, SLAM, Augments.SLAM_KNOCK * strength * falloff)
		abilities.refund(AbilityState.MOVEMENT, SKID_REFUND)
		hits += 1
	return hits


# The skid's cone: within reach and inside the inner ring, or within reach and ahead.
static func in_skid_cone(to: Vector3, ahead: Vector3, reach := SKID_REACH, inner := SKID_INNER) -> bool:
	var flat := Vector3(to.x, 0.0, to.z)
	if flat.length() > reach:
		return false
	return flat.length() <= inner or flat.normalized().dot(ahead) >= SKID_CONE


# The vault and slingshot aim cones and the arc slam's face tags, in the class colour.
func _update_aim_cones(at: Vector3) -> void:
	if abilities.selected == AbilityState.LINE and abilities.id_of(AbilityState.LINE) == "bank_shot" and kit.hooked:
		indicator.set_shape("bank", bank_geometry())
	else:
		indicator.clear("bank")
	if not kit.vault_aim.is_empty():
		indicator.set_shape("vault", _aim_cone(at, kit.vault_aim["dir"], AIM_CONE_LENGTH))
	else:
		indicator.clear("vault")
	if kit.mounted and not kit.slingshot_aim.is_empty():
		var fill: float = kit.slingshot_aim["fill"]
		indicator.set_shape("slingshot", _aim_cone(at, kit.slingshot_aim["dir"], AIM_CONE_LENGTH * (1.0 + fill), {"fill": fill}))
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


# A redline shell's blast (redline.gd detonated and cooked_off): every enemy inside its radius
# takes a slam at `force` with the slam's falloff, through the same push and strike path, so the
# ring drawn, the knock and the damage are one shape.
func _redline_blast(at: Vector3, force: float) -> void:
	if force <= 0.0:
		return
	shockwave.emit(at, 1.0)
	_push_enemies(at, Redline.BLAST_RADIUS, force, SLAM, Contact.heft_knock(heft()))


# knock_mult scales the shove only; the strike keeps force, so damage is unchanged.
func _push_enemies(at: Vector3, radius: float, force: float, kind: String, knock_mult := 1.0) -> int:
	var hits := 0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var away: Vector3 = enemy.global_position - at
		var reach := away.length()
		if reach > radius:
			continue
		away.y = 0.0
		away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
		var falloff := 1.0 - reach / radius
		# Heft adds throw up to the knock ceiling, never under the plain shove.
		enemy.knock(away + Vector3.UP * 0.5, minf(force * falloff * knock_mult, maxf(force * falloff, Contact.KNOCK_CEILING)))
		enemy.flash()
		hits += 1
		if kind != "":
			struck.emit(enemy, kind, force * falloff)
	return hits


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


# The public way for a module to report a contact the RigidBall never sees, such as a boss
# weak part outside the enemy group. The normal points from the body to the ball, full 3D, as
# RigidBall reports it, so a drop onto the body from above reads as a stomp. Omitted or zero, it is
# derived as RigidBall derives it; a given normal is normalized.
# `body` is untyped on purpose: a typed Node3D argument errors at the call when the body is freed.
func touch_body(body, normal := Vector3.ZERO) -> void:
	if not is_instance_valid(body) or not body is Node3D:
		return
	var n := normal.normalized() if normal.length() > 0.01 else Contact.normal_between(ball_position(), body.global_position)
	_on_enemy_touched(body, n)


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
		redline.spend(STOMP, ball_position(), _landing_force(STOMP, -before.y))
	elif _rebounds_off(enemy) and before.dot(normal) < -Contact.MIN_CLOSING:
		_rebound(enemy, normal, before, planar, away)
	elif SpeedTier.of(planar, tuning.tier_cruise()) >= SpeedTier.CRUISE:
		# Swarm drones keep the plain shove: the rack's scatter and refold timing sets the hive's posture pace.
		var shove: float = Augments.RAM_KNOCK * _landing_mult if enemy.get("swarm") != null else Contact.ram_knock(Augments.RAM_KNOCK, planar, heft(), _landing_mult)
		enemy.knock(away + Vector3.UP * 0.35, shove)
		enemy.flash()
		shockwave.emit(enemy.global_position, 1.0)
		# Planar speed, the same measure punch_now and the crush check use (one query).
		struck.emit(enemy, RAM, _landing_force(RAM, planar))
		_bowl_if_killed(enemy, away, shove)
		redline.spend(RAM, ball_position(), _landing_force(RAM, planar))
	if landing:
		_finish_landing(enemy, closing)
	smash_landing = null


# A ram that killed hands its shove to the hulk, which bowls on along the ball's travel.
func _bowl_if_killed(enemy: Node3D, direction: Vector3, shove: float) -> void:
	if not hulk_launch.is_valid() or not is_instance_valid(enemy) or not enemy.has_method("is_dead") or not enemy.is_dead():
		return
	var weight = enemy.get("weight")
	hulk_launch.call(enemy, Vector3(direction.x, 0.0, direction.z), shove / maxf(float(weight) if weight != null else 1.0, 0.1))


# The first contact of a committed haul lets the line go, so the ordinary contact (stomp,
# rebound or ram) resolves on a free ball, and starts the rewind before it: a kill or a
# stomp inside that contact re-seats the hook at once.
func _begin_landing(enemy: Node3D) -> bool:
	if Augments.landing_body(kit) != enemy:
		return false
	kit.drop_line("landed")
	kit.rewind_left = tuning.harpoon_rewind()
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
	if not _bank_pending.is_empty():
		var anchor: Vector3 = _bank_pending["anchor"]
		_bank_pending = {}
		_bank_logging_deferred = true
		_bank_release(anchor)
		_bank_logging_deferred = false
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
	if SpeedTier.of(planar, tuning.tier_cruise()) >= SpeedTier.CRUISE:
		struck.emit(enemy, RAM, _landing_force(RAM, planar))
		_bowl_if_killed(enemy, away, Contact.ram_knock(Augments.RAM_KNOCK, planar, heft(), _landing_mult))
		redline.spend(RAM, ball_position(), _landing_force(RAM, planar))
	events.enemy_rebounded.emit(enemy, out.length())
