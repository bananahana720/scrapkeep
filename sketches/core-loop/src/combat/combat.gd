extends Node

const Chaser := preload("res://src/combat/chaser.gd")
const Lobber := preload("res://src/combat/lobber.gd")
const Miniboss := preload("res://src/combat/miniboss.gd")
const Warden := preload("res://src/combat/warden.gd")
const Vault := preload("res://src/combat/vault.gd")
const CodexEntries := preload("res://src/combat/codex_entries.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const Projectile := preload("res://src/combat/projectile.gd")
const Hitscan := preload("res://src/combat/hitscan.gd")
const Pattern := preload("res://src/combat/pattern.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const Bolts := preload("res://src/combat/bolts.gd")
const Effects := preload("res://src/combat/effects.gd")
const Palette := preload("res://src/core/palette.gd")
const Ground := preload("res://src/combat/ground.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Sticky := preload("res://src/combat/sticky.gd")
const Sight := preload("res://src/combat/sight.gd")

# Writer A's module: the two class kits, the pattern system parts transform, enemies
# with committed telegraphs, the miniboss, damage and drops, and the shoulder view
# while mounted. It is ctx.spawner. README.md in this folder is the contract other
# modules read (spawner kinds, pattern transformer ids, the part registration call).
#
# The loop each physics tick, only while the flow is in play:
# 1. The shoulder view follows the mount: shoulder_target is 1 exactly while mounted.
# 2. Held fire throws one volley per weapon interval. The volley is aimed with the
#    shared aim query (hitscan.gd), laid out by the weapon's Pattern, and published
#    once as shot_fired(weapon, muzzle, the point the centre bolt is sent to).
# 3. The special is a hold-gauge-release shot (DESIGN-V2 section 4), dispatched by the
#    class row's special_id through _specials: Sable's detonation gauge, Rivet's
#    overdrive blast, Kest's detonation line. Hold draws the committed geometry on the
#    player's indicator; release fires exactly that geometry, with FORGIVENESS allowed
#    past its edge in the hit test. Planting a pylon as Sable still fires a free
#    discharge powered by the banked speed (the turret's opening burst).
# 4. Bolts and sticky charges step; a hit is resolved once through strike().
# 5. Knocked enemies that fly into others pin them (the bowling-ball contact's pins).
# 6. Every plated enemy is tinted amber if punch_now() beats its plating, slate if not.
#
# Plating (DEMO-SPEC Rules) lives in one function, resolve(): punch for a ball contact
# is (base + force * k) * heft, punch for a weapon hit is its damage after parts; punch
# at or above the target's plating lands in full, below it chips CHIP. strike(), the
# tint, punch_now(), plating_of() and would_crush() all read that one function.
#
# Shred (Andrew, 2026-09-27): every landed hit, a chip included, strips SHRED_PER_PUNCH
# of its punch off that enemy's plating, up to the whole plating. While the hits keep
# coming the strip bleeds off at SHRED_HOLD_DECAY a second, so held fire settles at a
# strip in proportion to its damage per second: the base kit's gun barely dents Warden
# III and an engaged build's strips it bare. SHRED_GRACE after the last hit the plate
# knits back at SHRED_REST_DECAY. The strip is kept per enemy instance and subtracted
# from whatever plating_for answers, so Wardens, the miniboss, vaults and Brindle's
# pieces shed alike, and a weak point already at 0 stays 0.

const MUZZLE := 1.25
const AIM_SLACK := 14.0
const KINDS := ["chaser", "lobber", "miniboss", "warden", "vault"]
const CONTACT_KINDS := ["stomp", "ram", "slam"]
# A build synergy's strike: its force is the punch (build scales it by heft), and it
# always meets body plating, since it is never a landing on a weak point.
const SYNERGY := "synergy"
const FIGHT_GROUPS := ["enemy", "enemy_shot", "telegraph"]
const CHIP := 0.2
# The spec's values, used only for a warden field a stage def is missing.
const WARDEN_FALLBACK := [
	{"warden_plating": 30.0, "warden_hp": 400.0, "warden_lesson": "plate"},
	{"warden_plating": 60.0, "warden_hp": 700.0, "warden_lesson": "caps"},
	{"warden_plating": 95.0, "warden_hp": 1000.0, "warden_lesson": "magnet"},
]
# The last stage's vault has no next Warden, so it sits this far above its own.
const VAULT_TOP_SCALE := 1.2
const MINIBOSS_PLATING_SCALE := 1.25
const SHELL_RETURN_DAMAGE := 40.0
const BAT_REACH := 2.4
const PARTING_WINDOW := 1.0
const PULSE_STOMP_WINDOW := 1.5
const CRUSH_WINDOW := 1.0
const CRUSH_CHAIN := 3
const SHRED_PER_PUNCH := 0.017
const SHRED_HOLD_DECAY := 0.05
const SHRED_REST_DECAY := 1.0
const SHRED_GRACE := 1.5
const SHRED_FLOOR := 0.5

# Ball contacts: base damage plus a share of the contact's force.
const STRIKE_DAMAGE := {
	"stomp": [30.0, 1.1],
	"ram": [14.0, 1.3],
	"slam": [0.0, 1.2],
}

var ctx
var bolts
var effects
# The ground enemies, telegraphs and shells stand on (ground.gd): the terrain, or the
# boss floor in the arena.
var ground
var volleys := 0
# The last committed volley and discharge, for tests and anything that wants to read them.
var last_shot := {}
var last_burst := {}
# A test knob: a heft to use instead of ctx.run.heft(). Negative means off.
var heft_override := -1.0
# Every deflected hit, counted here as well as published, so a test on a spine without
# strike_deflected still sees them.
var deflections := 0
# Codex ids discovered this run, in order, with where (also sent to ctx.codex).
var discovered := {}
var discovery_log: Array = []
# Where warden_spec reads a stage other than the current one. A test may swap in any
# object with of(stage) -> Dictionary.
var stage_defs = StageDefs

var _patterns := {}
var _part_map := {}
var _cooldown := 0.0
var _overdrive := 0.0
var _since_slingshot := INF
var _crushes: Array = []
var _clock := 0.0
# The strike whose facts are going out: {id, kind, force, part}, empty otherwise.
var _pending := {}
# Shred by enemy instance id: {amount, cap (the most plating it has shown), idle
# (seconds since its last landed hit)}.
var _shred := {}

# special_id -> {geometry: Callable(fraction) -> shape, fire: Callable(fraction, shape)}.
var _specials := {}
var sticky
# The last gauge release: {id, fraction, geometry}, the geometry exactly as drawn.
var last_committed := {}
# Kest's dust cloak: seconds left and where it began (what hidden enemies see).
var cloak_left := 0.0
var cloak_at := Vector3.ZERO
var _rocket_left := 0.0
# Items shorten the rocket jump's self-launch cooldown through this; it floors at 0.4 s.
var rocket_cooldown_scale := 1.0
# Pins already paid, "carrier:knock:victim" -> clock, and how many landed this attempt.
var _pinned := {}
var pins := 0


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	name = "Combat"
	ctx.spawner = self
	ground = Ground.new(ctx)
	effects = Effects.new()
	ctx.root.add_child(effects)
	effects.setup()
	bolts = Bolts.new()
	ctx.root.add_child(bolts)
	bolts.setup()
	bolts.on_hit = _on_bolt_hit
	bolts.on_shell = func(_bolt: Dictionary, shell: Node3D) -> bool: return _bat(shell)
	bolts.on_stop = func(at: Vector3, color: Color): effects.spark(at, color)
	sticky = Sticky.new()
	sticky.name = "StickyCharges"
	ctx.root.add_child(sticky)
	_specials = {
		"detonation_gauge": {"geometry": _discharge_geometry, "fire": _fire_discharge},
		"overdrive_blast": {"geometry": _overdrive_geometry, "fire": _fire_overdrive},
		"detonation_line": {"geometry": _line_geometry, "fire": _fire_line},
	}
	ctx.player.heft_of = heft
	ctx.events.demo_slammed.connect(_on_demo_slammed)
	ctx.events.arc_slammed.connect(func(at: Vector3, _faces: int): effects.ring(at, 12.0, ClassDef.SABLE_COLOR))
	ctx.events.skid_smashed.connect(func(at: Vector3, _hits: int): effects.ring(at, 4.0, ClassDef.RIVET_COLOR))
	ctx.events.blink_used.connect(_on_blink)
	ctx.events.stage_entered.connect(_on_stage_entered)
	ctx.events.stage_content_cleared.connect(_on_stage_content_cleared)
	ctx.events.run_started.connect(func(_class_id: String):
		discovered = {}
		_rebuild_patterns())
	ctx.events.dismounted.connect(func(v: Vector3):
		if v.length() > 0.1:
			_since_slingshot = 0.0)
	ctx.events.part_gained.connect(func(_part: String, _source: String): _rebuild_patterns())
	ctx.events.mounted.connect(_on_mounted)
	_rebuild_patterns()
	_declare_codex()


# --- Spawner API (CONTRACTS.md) -----------------------------------------------------

# kind is "chaser", "lobber", "miniboss", "warden" or "vault". An unknown kind spawns a
# chaser, with a warning, so a typo in an event table never leaves a stage empty. The
# Warden and the vault sit on the ground under `at`; the others are placed at `at`.
func spawn_enemy(kind: String, at: Vector3) -> Node3D:
	var enemy: Node3D
	match kind:
		"lobber":
			enemy = Lobber.new()
		"miniboss":
			enemy = Miniboss.new()
		"warden":
			enemy = Warden.new()
		"vault":
			enemy = Vault.new()
		"chaser":
			enemy = Chaser.new()
		_:
			push_warning("spawn_enemy: unknown kind '%s', spawning a chaser" % kind)
			kind = "chaser"
			enemy = Chaser.new()
	ctx.root.add_child(enemy)
	enemy.global_position = at
	# Fodder sees the player through its sight, which Kest's cloak can fool; the Warden
	# and the vault are set pieces and always see the ball.
	var target = Sight.new(ctx.player, self, enemy, kind) if Sight.REACH.has(kind) else ctx.player
	enemy.setup(target, ground, ctx.root, Callable(ctx.flow, "in_play"), _threat(), _spec_for(kind))
	enemy.hit_player.connect(_on_player_hit.bind(kind))
	enemy.died.connect(func(where: Vector3, scrap: int): ctx.run.record_kill(kind, where, scrap))
	if enemy.has_signal("fired"):
		enemy.fired.connect(_on_lobber_fired.bind(enemy))
	ctx.events.enemy_spawned.emit(enemy, kind)
	return enemy


# A hit the spine or a weapon made, resolved into damage exactly once. The bus facts go
# out before the damage so a kill never publishes a freed node: enemy_struck always,
# then strike_deflected when the punch fell short of the plating. `part` names a weak
# point ("" for the body; a ball contact finds its own through contact_part()).
func strike(enemy: Node3D, kind: String, force: float, part := "") -> void:
	if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
		return
	if enemy.has_method("is_dead") and enemy.is_dead():
		return
	var result := resolve(enemy, kind, force, part)
	_detect_before(enemy, kind, result)
	var outer := _pending
	_pending = {"id": enemy.get_instance_id(), "kind": kind, "force": force, "part": result["part"]}
	ctx.events.enemy_struck.emit(enemy, kind, force)
	if not result["full"]:
		deflections += 1
		ctx.events.strike_deflected.emit(enemy, kind, result["punch"], result["plating"])
	_pending = outer
	if enemy.has_method("on_struck"):
		enemy.on_struck(kind, result["part"], result)
	enemy.take_damage(result["dealt"])
	_add_shred(enemy, result["punch"])
	_detect_after(enemy, kind, result)


# The one plating rule. Returns {punch, plating, full, dealt, part}. Asked from an
# enemy_struck or strike_deflected handler with that strike's enemy, kind and force, it
# answers with the strike's own part, so the handler sees the plating the hit meets.
func resolve(enemy: Node3D, kind: String, force: float, part := "") -> Dictionary:
	if part == "" and not _pending.is_empty() and _pending["id"] == enemy.get_instance_id() \
			and _pending["kind"] == kind and _pending["force"] == force:
		part = _pending["part"]
	if part == "" and kind in CONTACT_KINDS and enemy.has_method("contact_part"):
		part = enemy.contact_part(ctx.player.ball_position(), kind)
	if kind == SYNERGY:
		part = ""
	var punch := punch_of(kind, force)
	var reported: float = enemy.plating_for(kind, part) if enemy.has_method("plating_for") else 0.0
	var plating := maxf(0.0, reported - shred_of(enemy))
	var full := punch >= plating
	var mult: float = enemy.hit_mult(kind, part) if full and enemy.has_method("hit_mult") else 1.0
	var dealt := punch * mult if full else punch * CHIP
	return {"punch": punch, "plating": plating, "full": full, "dealt": dealt, "part": part}


# Punch for a hit of this kind and force: a ball contact scales with heft, a weapon hit
# is its damage.
func punch_of(kind: String, force: float) -> float:
	if STRIKE_DAMAGE.has(kind):
		var row: Array = STRIKE_DAMAGE[kind]
		var sprint: float = Weapons.SPRINT_PUNCH if ctx != null and ctx.player.kit.sprinting else 1.0
		return (row[0] + force * row[1]) * heft() * sprint
	return force


func heft() -> float:
	if heft_override >= 0.0:
		return heft_override
	if ctx != null and ctx.run != null and ctx.run.has_method("heft"):
		return ctx.run.heft()
	return 1.0


# The best punch you have right now: a ram at your planar speed (from CRUISE up), or one
# hit of the weapon in your hands. The HUD's "Punch 48 / plating 60" reads this.
func punch_now() -> float:
	var weapon := active_weapon()
	var shot: float = _patterns[weapon].damage * _damage_mod(weapon) if _patterns.has(weapon) else 0.0
	return maxf(ram_punch_now(), shot)


# A ram at your planar speed, from CRUISE up; 0 below it. No weapon term: for a target
# only a ram can beat (a clash), this is the whole punch.
func ram_punch_now() -> float:
	if ctx.player.speed_tier() < SpeedTier.CRUISE:
		return 0.0
	return punch_of("ram", ctx.player.planar_velocity().length())


# Build owns tuning mods (CONTRACTS). Combat reads its weapon keys live, at the moment
# of use, so it never depends on which module heard part_gained first.
func _damage_mod(weapon: String) -> float:
	var scale: float = ctx.tuning.mod("weapon_damage")
	if weapon == Weapons.PYLON_TURRET:
		scale *= ctx.tuning.mod("turret_damage")
	return scale


# The body plating a hit would meet now, shred taken off.
func plating_of(enemy: Node3D) -> float:
	if not is_instance_valid(enemy) or not enemy.has_method("plating_now"):
		return 0.0
	return maxf(0.0, enemy.plating_now() - shred_of(enemy))


# How much plating landed hits have stripped off this enemy right now.
func shred_of(enemy: Node3D) -> float:
	if not is_instance_valid(enemy):
		return 0.0
	return float(_shred.get(enemy.get_instance_id(), {}).get("amount", 0.0))


# hp / max_hp, 1.0 for an invalid enemy (as the spec says), 0.0 for a dead one.
func integrity_of(enemy: Node3D) -> float:
	if not is_instance_valid(enemy):
		return 1.0
	if (enemy.has_method("is_dead") and enemy.is_dead()) or float(enemy.get("max_hp")) <= 0.0:
		return 0.0
	return clampf(float(enemy.get("hp")) / float(enemy.get("max_hp")), 0.0, 1.0)


# True when this contact would kill an unplated target outright: the spine's crush
# pass-through asks before it decides to skip the knock. A plated break-through is
# not a crush, and neither is a hit on a target whose crushable() says it cannot die
# at its current HP (a boss held at a phase floor): the ball would end inside it.
func would_crush(enemy: Node3D, kind: String, force: float) -> bool:
	if not is_instance_valid(enemy) or enemy.is_dead():
		return false
	if enemy.has_method("crushable") and not enemy.crushable():
		return false
	var result := resolve(enemy, kind, force)
	return result["plating"] <= 0.0 and result["dealt"] >= enemy.hp


# --- Pattern API for parts (README.md) ----------------------------------------------

# A part applies these transformer ids once per stack in run.parts. Build calls this
# from its setup (combat is set up first). A part whose id is itself a transformer id
# needs no registration.
func register_part(part_id: String, transformer_ids: Array) -> void:
	_part_map[part_id] = transformer_ids.duplicate()
	_rebuild_patterns()


func transformer_ids() -> PackedStringArray:
	return PackedStringArray(Pattern.TRANSFORMERS.keys())


func transformer_info(id: String) -> Dictionary:
	var row: Dictionary = Pattern.TRANSFORMERS.get(id, {})
	return {"label": row.get("label", id), "text": row.get("text", "")}


# The transformer ids the current parts apply, in part order.
func active_transformers() -> Array:
	var ids := []
	if ctx == null or ctx.run == null:
		return ids
	for part in ctx.run.parts:
		if _part_map.has(part):
			ids.append_array(_part_map[part])
		elif Pattern.has_transformer(part):
			ids.append(part)
	return ids


# A copy of a weapon's current pattern, after every part.
func pattern(weapon_id: String) -> Resource:
	return (_patterns[weapon_id] as Resource).copy()


func live_projectiles() -> int:
	return bolts.live()


func active_weapon() -> String:
	var def = ctx.run.class_def
	if def == null:
		return ""
	if def.weapon_id == Weapons.ARC_CASTER and ctx.player.kit.mounted:
		return Weapons.PYLON_TURRET
	return def.weapon_id


# The discharge a given speed would fire right now, with the current parts.
func discharge_preview(speed: float) -> Dictionary:
	var p: Resource = _patterns[Weapons.PYLON_TURRET]
	var scale: float = p.damage * _damage_mod(Weapons.PYLON_TURRET) / Weapons.BASE[Weapons.PYLON_TURRET]["damage"]
	return Weapons.burst(speed, p.burst_scale, scale)


# --- The tick -----------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if ctx == null:
		return
	var playing: bool = ctx.flow.in_play()
	ctx.camera.shoulder_target = 1.0 if playing and ctx.player.kit.mounted else 0.0
	if not playing or ctx.run.class_def == null:
		return
	_clock += delta
	_since_slingshot += delta
	_cooldown -= delta
	_overdrive = maxf(0.0, _overdrive - delta)
	_rocket_left = maxf(0.0, _rocket_left - delta)
	_tick_cloak(delta)
	var intent = ctx.player.intent
	var weapon := active_weapon()
	if weapon == Weapons.STICKY_CHARGE:
		_step_sticky_weapon(intent, delta)
	elif intent.fire_held and _cooldown <= 0.0 and _patterns.has(weapon):
		_fire(weapon)
		_cooldown += 1.0 / _rate(weapon)
	if not intent.fire_held:
		_cooldown = maxf(_cooldown, 0.0)
	_step_special(intent, delta)
	var enemies := get_tree().get_nodes_in_group("enemy")
	var shells := get_tree().get_nodes_in_group("enemy_shot")
	var space: PhysicsDirectSpaceState3D = ctx.root.get_world_3d().direct_space_state
	bolts.step(delta, space, enemies, shells)
	for charge in sticky.step(delta, space, enemies):
		_detonate(charge)
	_pin_step(enemies)
	_bat_by_ball(shells)
	_decay_shred(delta)
	_tint()


# Plated targets glow amber when your punch beats their plating right now, slate when
# it does not. Same function as the strike, re-read every physics tick. A target whose
# tint_verb() is "ram" is compared with the ram alone, since only a ram counts there.
func _tint() -> void:
	var punch := punch_now()
	var ram := ram_punch_now()
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not enemy.has_method("set_tint") or enemy.is_dead() or enemy.plating <= 0.0:
			continue
		var against: float = ram if enemy.has_method("tint_verb") and enemy.tint_verb() == "ram" else punch
		enemy.set_tint("amber" if against >= plating_of(enemy) else "slate")


func _add_shred(enemy: Node3D, punch: float) -> void:
	if enemy.has_method("is_dead") and enemy.is_dead():
		return
	var id := enemy.get_instance_id()
	var entry: Dictionary = _shred.get(id, {"amount": 0.0, "cap": 0.0, "idle": 0.0})
	if enemy.has_method("plating_now"):
		entry["cap"] = maxf(entry["cap"], enemy.plating_now())
	entry["amount"] = minf(entry["amount"] + punch * SHRED_PER_PUNCH, entry["cap"])
	entry["idle"] = 0.0
	_shred[id] = entry
	_show_shred(enemy, entry["amount"])


func _decay_shred(delta: float) -> void:
	for id in _shred.keys():
		var enemy := instance_from_id(id) as Node3D
		if enemy == null or not is_instance_valid(enemy) or (enemy.has_method("is_dead") and enemy.is_dead()):
			_shred.erase(id)
			continue
		var entry: Dictionary = _shred[id]
		entry["idle"] += delta
		var resting: bool = entry["idle"] > SHRED_GRACE
		entry["amount"] *= exp(-(SHRED_REST_DECAY if resting else SHRED_HOLD_DECAY) * delta)
		if resting and entry["amount"] < SHRED_FLOOR:
			_shred.erase(id)
			_show_shred(enemy, 0.0)
		else:
			_show_shred(enemy, entry["amount"])


# An enemy that draws its shred (the Warden's glowing seams) is told the amount.
func _show_shred(enemy: Node3D, amount: float) -> void:
	if enemy.has_method("set_shred"):
		enemy.set_shred(amount)


# A rolling ball at CRUISE or faster that reaches a shell in flight bats it home.
func _bat_by_ball(shells: Array) -> void:
	if ctx.player.speed_tier() < SpeedTier.CRUISE:
		return
	var ball: Vector3 = ctx.player.ball_position()
	for shell in shells:
		if is_instance_valid(shell) and not shell.returned and shell.global_position.distance_to(ball) <= BAT_REACH:
			_bat(shell)


func _bat(shell: Node3D) -> bool:
	if not is_instance_valid(shell) or not shell.bat():
		return false
	effects.spark(shell.global_position, Palette.AMBER)
	return true


func _rate(weapon: String) -> float:
	var rate: float = minf(_patterns[weapon].rate * ctx.tuning.mod("weapon_rate"), Pattern.MAX_RATE)
	if _overdrive > 0.0:
		rate *= Weapons.OVERDRIVE_RATE
	return rate


func _fire(weapon: String) -> void:
	var p: Resource = _patterns[weapon]
	var space: PhysicsDirectSpaceState3D = ctx.root.get_world_3d().direct_space_state
	var ball: Vector3 = ctx.player.ball_position()
	var reach: float = p.range_m * ctx.tuning.mod("weapon_range")
	var damage: float = p.damage * _damage_mod(weapon)
	var aim := Hitscan.aim(space, ctx.aim_origin(), ctx.aim_forward(), ball, reach + AIM_SLACK)
	var point: Vector3 = aim["point"]
	var forward := point - ball
	if forward.length() < MUZZLE * 1.5:
		forward = ctx.aim_forward()
	forward = forward.normalized()
	var muzzle := ball + forward * MUZZLE
	var color := Weapons.color(weapon)
	var kind := Weapons.strike_kind(weapon)
	var layout: Array = p.layout(forward, volleys)
	for entry in layout:
		bolts.fire({
			"origin": muzzle, "dir": entry["dir"], "speed": p.speed, "max_dist": reach,
			"damage": damage, "kind": kind, "weapon_id": weapon, "radius": p.bolt_radius,
			"knock": p.knock, "chain_jumps": p.chain_jumps, "chain_range": p.chain_range,
			"chain_falloff": p.chain_falloff, "color": color,
			"wave_amp": 0.0 if entry["centre"] else p.wave_amp, "wave_hz": p.wave_hz, "phase": entry["phase"],
		})
	volleys += 1
	last_shot = {"weapon_id": weapon, "from": muzzle, "to": aim["to"], "point": point,
		"blocked": aim["blocked"], "bolts": layout.size(), "volley": volleys}
	ctx.events.shot_fired.emit(weapon, muzzle, aim["to"])


func _on_bolt_hit(bolt: Dictionary, enemy: Node3D, point: Vector3, part := "") -> void:
	effects.spark(point, bolt["color"])
	var from: Vector3 = enemy.global_position
	_hit(enemy, bolt["kind"], bolt["damage"], bolt["dir"], bolt["knock"], 0.25, part)
	if bolt["chain_jumps"] > 0:
		_chain(enemy, from, bolt)


# One resolved weapon hit: the shove, the flash, then strike() for damage and the fact.
func _hit(enemy: Node3D, kind: String, damage: float, direction: Vector3, knock: float, lift := 0.25, part := "") -> void:
	var push := Vector3(direction.x, 0.0, direction.z)
	push = push.normalized() if push.length() > 0.01 else Vector3.FORWARD
	enemy.knock(push + Vector3.UP * lift, knock)
	enemy.flash()
	strike(enemy, kind, damage, part)


# The arc jumps from the struck enemy to the nearest one it has not touched, losing
# chain_falloff of its damage per jump.
func _chain(first: Node3D, from: Vector3, bolt: Dictionary) -> void:
	var visited := [first]
	var damage: float = bolt["damage"] * bolt["chain_falloff"]
	var at := from
	for _jump in int(bolt["chain_jumps"]):
		var next := _nearest(at, bolt["chain_range"], visited)
		if next == null:
			return
		visited.append(next)
		var to: Vector3 = next.global_position
		effects.arc(at, to, bolt["color"])
		_hit(next, bolt["kind"], damage, to - at, bolt["knock"] * 0.5)
		damage *= bolt["chain_falloff"]
		at = to


func _nearest(at: Vector3, reach: float, exclude: Array) -> Node3D:
	var best: Node3D = null
	var best_distance := reach
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy in exclude or enemy.is_dead():
			continue
		var distance: float = enemy.global_position.distance_to(at)
		if distance <= best_distance:
			best_distance = distance
			best = enemy
	return best


func _nearest_list(at: Vector3, reach: float, limit: int) -> Array:
	var found := []
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.is_dead():
			continue
		var distance: float = enemy.global_position.distance_to(at)
		if distance <= reach:
			found.append([distance, enemy])
	found.sort_custom(func(a, b): return a[0] < b[0])
	var out := []
	for i in mini(limit, found.size()):
		out.append(found[i][1])
	return out


# --- Specials -----------------------------------------------------------------------

# The one hold-gauge-release loop for every class's special. A press starts the gauge
# if a charge is in; a second press or RMB drops it with nothing spent; the key coming
# up, or a full gauge held past its grace, fires the geometry drawn at that fraction.
func _step_special(intent, delta: float) -> void:
	var abilities = ctx.player.abilities
	var id: String = abilities.id_of(AbilityState.SPECIAL)
	var gauge = abilities.gauge(AbilityState.SPECIAL)
	if gauge == null or not _specials.has(id):
		return
	var row: Dictionary = _specials[id]
	if gauge.charging and (intent.special_pressed or intent.cancel_pressed):
		gauge.cancel()
		ctx.player.indicator.collapse("special")
		ctx.events.gauge_cancelled.emit(id, "cancel")
		return
	if not gauge.charging and intent.special_pressed and abilities.ready(AbilityState.SPECIAL):
		gauge.begin()
		ctx.events.gauge_charging.emit(id)
	if not gauge.charging:
		ctx.player.indicator.clear("special")
		return
	if not gauge.step(delta, intent.special_held):
		ctx.player.indicator.set_shape("special", row["geometry"].call(gauge.fraction()))
		return
	var f: float = gauge.fired_fraction
	var shape: Dictionary = row["geometry"].call(f)
	ctx.player.indicator.set_shape("special", shape)
	ctx.player.indicator.clear("special")
	abilities.spend(AbilityState.SPECIAL)
	last_committed = {"id": id, "fraction": f, "geometry": shape}
	row["fire"].call(f, shape)
	ctx.events.gauge_released.emit(id, f)
	ctx.events.special_used.emit(id, ctx.player.ball_position())


# Hull within the drawn radius plus the forgiveness counts as inside a ring.
static func in_ring(centre: Vector3, radius: float, enemy: Node3D) -> bool:
	var flat := enemy.global_position - centre
	flat.y = 0.0
	return flat.length() - _hull(enemy) <= radius * (1.0 + AbilityState.FORGIVENESS)


# Hull within the drawn half-width plus the forgiveness, and along the drawn length.
static func in_line(from: Vector3, to: Vector3, width: float, point: Vector3, hull := 0.0) -> bool:
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	var p := Vector2(point.x, point.z)
	var along := b - a
	var length := along.length()
	if length < 0.001:
		return false
	var t := (p - a).dot(along / length)
	var slack := AbilityState.FORGIVENESS
	if t < -hull or t > length * (1.0 + slack) + hull:
		return false
	var side := absf((p - a).cross(along / length))
	return side - hull <= width * 0.5 * (1.0 + slack)


static func _hull(enemy: Node3D) -> float:
	var r = enemy.get("radius")
	return float(r) if r != null else 1.0


func _ground_under(at: Vector3) -> Vector3:
	return at + Vector3.DOWN * 0.9


func _flat_aim() -> Vector3:
	var dir: Vector3 = ctx.aim_forward()
	dir.y = 0.0
	return dir.normalized() if dir.length_squared() > 0.0001 else Vector3.FORWARD


# Sable: the gauge stands in for speed in the discharge curve, and the bank counts if
# you are mounted and it is bigger.
func _discharge_speed(f: float) -> float:
	var speed := f * Weapons.DISCHARGE_FULL_SPEED
	if ctx.player.kit.mounted:
		speed = maxf(speed, ctx.player.kit.mount_banked)
	return speed


func _discharge_geometry(f: float) -> Dictionary:
	var burst := discharge_preview(_discharge_speed(f))
	return ctx.player.yours({"kind": "ring", "centre": _ground_under(ctx.player.ball_position()), "radius": burst["radius"],
		"full_radius": discharge_preview(_discharge_speed(1.0))["radius"], "fill": f})


func _fire_discharge(f: float, shape: Dictionary) -> void:
	var kit = ctx.player.kit
	_discharge(ctx.player.ball_position(), _discharge_speed(f), "turret" if kit.mounted else "arc", shape["centre"])


func _overdrive_geometry(f: float) -> Dictionary:
	return ctx.player.yours({"kind": "ring", "centre": _ground_under(ctx.player.ball_position()),
		"radius": Weapons.OVERDRIVE_RADIUS * AbilityState.Gauge.scaled(f, 1.0, Weapons.OVERDRIVE_FULL),
		"full_radius": Weapons.OVERDRIVE_RADIUS * Weapons.OVERDRIVE_FULL, "fill": f})


func _fire_overdrive(f: float, shape: Dictionary) -> void:
	_overdrive_blast(ctx.player.ball_position(), AbilityState.Gauge.scaled(f, 1.0, Weapons.OVERDRIVE_FULL), shape)


func _line_geometry(f: float) -> Dictionary:
	var from := _ground_under(ctx.player.ball_position())
	var length := AbilityState.Gauge.scaled(f, Weapons.LINE_MIN, Weapons.LINE_MAX)
	return ctx.player.yours({"kind": "line", "from": from, "to": from + _flat_aim() * length, "width": Weapons.LINE_WIDTH,
		"full_to": from + _flat_aim() * Weapons.LINE_MAX, "fill": f})


# Kest's detonation line: every live charge in the line goes off early, then the line
# itself hits, +25% per charge caught up to three. A shot out of the cloak crits.
func _fire_line(f: float, shape: Dictionary) -> void:
	var caught := []
	for charge in sticky.charges.duplicate():
		if in_line(shape["from"], shape["to"], shape["width"], charge["pos"]):
			caught.append(sticky.take(charge))
	var bonus := 1.0 + Weapons.LINE_PER_CHARGE * mini(caught.size(), Weapons.LINE_MAX_CAUGHT)
	var damage := AbilityState.Gauge.scaled(f, Weapons.LINE_DAMAGE_MIN, Weapons.LINE_DAMAGE_MAX) * bonus \
		* _damage_mod(Weapons.STICKY_CHARGE) * _cloak_shot()
	for charge in caught:
		_detonate(charge)
	var hit := 0
	var from: Vector3 = shape["from"]
	var to: Vector3 = shape["to"]
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.is_dead() or not in_line(from, to, shape["width"], enemy.global_position, _hull(enemy)):
			continue
		_hit(enemy, "line", damage, to - from, Weapons.OVERDRIVE_KNOCK * 0.5, 0.5)
		hit += 1
	effects.arc(from + Vector3.UP * 0.5, to + Vector3.UP * 0.5, ClassDef.KEST_COLOR)
	_start_cloak()
	last_burst = {"at": from, "to": to, "damage": damage, "hit": hit, "kind": "line", "caught": caught.size()}


# The pylon's opening burst: planting as the engineer discharges the banked speed.
func _on_mounted(at: Vector3, banked_speed: float) -> void:
	if ctx.run.class_def == null or not ctx.flow.in_play():
		return
	if ctx.run.class_def.special_id != "detonation_gauge":
		return
	_discharge(at, banked_speed, "turret")
	ctx.events.special_used.emit(ctx.run.class_def.special_id, at)


# A released gauge passes its drawn centre, and its targets are chosen with the
# forgiveness; the plant's free burst has no drawing and keeps the plain radius.
func _discharge(at: Vector3, speed: float, kind: String, drawn_centre = null) -> void:
	var burst := discharge_preview(speed)
	var targets: Array
	if drawn_centre == null:
		targets = _nearest_list(at, burst["radius"], burst["targets"])
	else:
		targets = _nearest_in_ring(drawn_centre, burst["radius"], burst["targets"])
	var color := Weapons.color(Weapons.PYLON_TURRET)
	for enemy in targets:
		var to: Vector3 = enemy.global_position
		effects.arc(at, to, color)
		_hit(enemy, kind, burst["damage"], to - at, Weapons.BURST_KNOCK, 0.4)
	effects.ring(at, burst["radius"], color)
	last_burst = burst.duplicate()
	last_burst["at"] = at
	last_burst["hit"] = targets.size()
	last_burst["kind"] = kind


func _nearest_in_ring(centre: Vector3, radius: float, limit: int) -> Array:
	var found := []
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not enemy.is_dead() and in_ring(centre, radius, enemy):
			found.append([enemy.global_position.distance_to(centre), enemy])
	found.sort_custom(func(a, b): return a[0] < b[0])
	return found.slice(0, limit).map(func(pair): return pair[1])


func _overdrive_blast(at: Vector3, scale := 1.0, shape := {}) -> void:
	var p: Resource = _patterns[Weapons.RAPID_LASER]
	var damage: float = Weapons.OVERDRIVE_DAMAGE * scale * p.damage * _damage_mod(Weapons.RAPID_LASER) / Weapons.BASE[Weapons.RAPID_LASER]["damage"]
	var radius := Weapons.OVERDRIVE_RADIUS * scale
	var centre: Vector3 = shape.get("centre", at)
	var hit := 0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.is_dead() or not in_ring(centre, radius, enemy):
			continue
		_hit(enemy, "runner", damage, enemy.global_position - at, Weapons.OVERDRIVE_KNOCK * scale, 0.5)
		hit += 1
	_overdrive = Weapons.OVERDRIVE_SECONDS * p.special_scale
	effects.ring(at, radius, ClassDef.RIVET_COLOR)
	last_burst = {"at": at, "radius": radius, "damage": damage, "hit": hit, "kind": "runner",
		"overdrive": _overdrive}


# --- Kest: sticky charges, the cloak, the rocket jump ---------------------------------

# LMB is a hold-release throw: hold draws the lobbed arc and its landing ring, release
# throws to exactly that point. Held, it auto-throws at full reach after the grace and
# starts again when the next charge is in. A fourth charge sets off the oldest.
func _step_sticky_weapon(intent, delta: float) -> void:
	var abilities = ctx.player.abilities
	var gauge = abilities.gauge(AbilityState.WEAPON)
	if gauge == null:
		return
	if not gauge.charging and (intent.fire_pressed or intent.fire_held) and abilities.ready(AbilityState.WEAPON):
		gauge.begin()
	if not gauge.charging:
		ctx.player.indicator.clear("weapon")
		ctx.player.indicator.clear("landing")
		return
	if not gauge.step(delta, intent.fire_held):
		_draw_throw(_throw_landing(gauge.fraction()))
		return
	var landing := _throw_landing(gauge.fired_fraction)
	_draw_throw(landing)
	if landing["blocked"]:
		ctx.player.indicator.collapse("weapon")
		ctx.player.indicator.collapse("landing")
		ctx.events.gauge_cancelled.emit(Weapons.STICKY_CHARGE, "blocked")
		return
	ctx.player.indicator.clear("weapon")
	ctx.player.indicator.clear("landing")
	abilities.spend(AbilityState.WEAPON)
	_throw_sticky(landing["point"])


func _throw_origin() -> Vector3:
	return ctx.player.ball_position() + _flat_aim() * MUZZLE + Vector3.UP * 0.6


# Where a throw at this fraction lands: along the flat aim, on the ground under it.
# Over a void there is no ground to stick to, so the aim is blocked (RR-03): it draws
# in bone with a cross and a release throws nothing and spends nothing.
func _throw_landing(f: float) -> Dictionary:
	var p: Resource = _patterns[Weapons.STICKY_CHARGE]
	var reach := AbilityState.Gauge.scaled(f, Weapons.STICKY_THROW_MIN, p.range_m * ctx.tuning.mod("weapon_range"))
	var flat: Vector3 = ctx.player.ball_position() + _flat_aim() * reach
	var space: PhysicsDirectSpaceState3D = ctx.root.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(flat + Vector3.UP * 30.0, flat + Vector3.DOWN * 60.0, 1))
	if hit.is_empty():
		return {"point": flat + Vector3.DOWN * 0.9, "blocked": true}
	return {"point": hit["position"], "blocked": false}


func _draw_throw(landing: Dictionary) -> void:
	var at: Vector3 = landing["point"]
	var blocked: bool = landing["blocked"]
	ctx.player.indicator.set_shape("weapon", ctx.player.yours({"kind": "arc",
		"points": Sticky.arc_points(_throw_origin(), at), "blocked": blocked}))
	ctx.player.indicator.set_shape("landing", ctx.player.yours({"kind": "ring", "centre": at,
		"radius": _patterns[Weapons.STICKY_CHARGE].bolt_radius, "blocked": blocked}))


func _throw_sticky(landing: Vector3) -> void:
	var p: Resource = _patterns[Weapons.STICKY_CHARGE]
	var live: Array = sticky.live()
	if live.size() >= Weapons.STICKY_MAX_LIVE:
		_detonate(sticky.take(live[0]))
	var origin := _throw_origin()
	var crit := cloak_left > 0.0
	var damage: float = p.damage * _damage_mod(Weapons.STICKY_CHARGE) * _cloak_shot()
	var charge: Dictionary = sticky.throw(origin, landing, damage, p.bolt_radius, Weapons.STICKY_FUSE, crit)
	volleys += 1
	last_shot = {"weapon_id": Weapons.STICKY_CHARGE, "from": origin, "to": landing, "point": landing,
		"blocked": false, "bolts": 1, "volley": volleys, "radius": charge["radius"]}
	ctx.events.shot_fired.emit(Weapons.STICKY_CHARGE, origin, landing)


# One charge going off: its blast (the drawn landing radius plus the forgiveness), a
# rocket jump if Kest holds Space inside it, and the cloak.
func _detonate(charge: Dictionary) -> void:
	var at: Vector3 = charge["pos"]
	var radius: float = charge["radius"]
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.is_dead():
			continue
		if (enemy.global_position - at).length() - _hull(enemy) > radius * (1.0 + AbilityState.FORGIVENESS):
			continue
		_hit(enemy, "sticky", charge["damage"], enemy.global_position - at, Weapons.BASE[Weapons.STICKY_CHARGE]["knock"], 0.4)
	effects.ring(at, radius, ClassDef.KEST_COLOR)
	ctx.events.sticky_detonated.emit(at, charge["crit"])
	_rocket_jump(at)
	_start_cloak()


# Kest's rocket jump: Space held inside your own blast throws you away from it, harder
# the closer you are. Its own cooldown and the throw cadence bound the chain.
func _rocket_jump(at: Vector3) -> void:
	var player = ctx.player
	if player.kit.movement_id != "smoke_blink" or not player.intent.jump_held or _rocket_left > 0.0:
		return
	var away: Vector3 = player.ball_position() - at
	var reach := away.length()
	if reach > Weapons.ROCKET_REACH:
		return
	var dir := (away.normalized() if reach > 0.01 else Vector3.ZERO) + Vector3.UP
	dir = dir.normalized()
	var speed := AbilityState.Gauge.scaled(1.0 - reach / Weapons.ROCKET_REACH, Weapons.ROCKET_MIN, Weapons.ROCKET_MAX)
	var v: Vector3 = player.state.velocity
	var gain := maxf(0.0, speed - v.dot(dir))
	player.add_external_accel(dir * gain / get_physics_process_delta_time())
	_rocket_left = AbilityState.floored(Weapons.ROCKET_COOLDOWN, rocket_cooldown_scale)
	ctx.events.rocket_jumped.emit(at, speed)


func _on_demo_slammed(at: Vector3) -> void:
	if not ctx.flow.in_play():
		return
	var heading: Vector3 = ctx.player.planar_velocity()
	var turn := atan2(heading.z, heading.x) if heading.length() > 0.5 else 0.0
	for i in Weapons.MINI_COUNT:
		var angle := turn + TAU * float(i) / float(Weapons.MINI_COUNT)
		var spot := at + Vector3(cos(angle), 0.0, sin(angle)) * Weapons.MINI_SPREAD
		sticky.drop(spot, Weapons.MINI_DAMAGE * _damage_mod(Weapons.STICKY_CHARGE), Weapons.MINI_RADIUS,
			Weapons.MINI_FUSE, Weapons.MINI_ARM)


func _on_blink(from: Vector3, _to: Vector3) -> void:
	effects.ring(from, 2.5, ClassDef.KEST_COLOR)
	_start_cloak()


func _start_cloak() -> void:
	if ctx.player.kit.movement_id != "smoke_blink":
		return
	var fresh := cloak_left <= 0.0
	cloak_left = Weapons.CLOAK_SECONDS
	cloak_at = ctx.player.ball_position()
	if fresh:
		ctx.events.cloak_started.emit(cloak_left)


func _tick_cloak(delta: float) -> void:
	if cloak_left <= 0.0:
		return
	cloak_left -= delta
	if cloak_left <= 0.0:
		cloak_left = 0.0
		ctx.events.cloak_broken.emit("faded")


# The first shot out of the cloak crits and ends it; any other shot is plain.
func _cloak_shot() -> float:
	if cloak_left <= 0.0:
		return 1.0
	cloak_left = 0.0
	ctx.events.cloak_broken.emit("shot")
	return Weapons.CLOAK_CRIT


# --- Pins ---------------------------------------------------------------------------

# A knocked enemy flying faster than PIN_MIN_SPEED at another within PIN_RADIUS (hull
# to hull) hits it once per knock, keyed by the carrier's instance and knock count, and
# hands on PIN_CARRY of its speed, so a chain always runs down below the bar.
func _pin_step(enemies: Array) -> void:
	for key in _pinned.keys():
		if _clock - float(_pinned[key]) > 3.0:
			_pinned.erase(key)
	for carrier in enemies:
		if not _pinnable(carrier) or not carrier.has_method("_knocked_speed"):
			continue
		var speed: float = carrier._knocked_speed()
		if speed <= Weapons.PIN_MIN_SPEED:
			continue
		var heading := Vector3(carrier.velocity.x, 0.0, carrier.velocity.z)
		heading = heading.normalized() if heading.length() > 0.1 else Vector3.ZERO
		for victim in enemies:
			if victim == carrier or not _pinnable(victim):
				continue
			var to: Vector3 = victim.global_position - carrier.global_position
			to.y = 0.0
			if to.length() - _hull(carrier) - _hull(victim) > Weapons.PIN_RADIUS:
				continue
			if heading == Vector3.ZERO or to.normalized().dot(heading) < 0.5:
				continue
			var key := "%d:%d:%d" % [carrier.get_instance_id(), carrier.knocks, victim.get_instance_id()]
			if _pinned.has(key):
				continue
			_pinned[key] = _clock
			var damage := minf(Weapons.PIN_CAP, Weapons.PIN_BASE + Weapons.PIN_PER_SPEED * speed)
			pins += 1
			ctx.events.enemy_pinned.emit(victim, damage)
			victim.knock(to + Vector3.UP * 0.2, speed * Weapons.PIN_CARRY * float(victim.weight))
			victim.flash()
			strike(victim, "pin", damage)


static func _pinnable(enemy) -> bool:
	return is_instance_valid(enemy) and enemy.has_method("knock") and enemy.has_method("is_dead") and not enemy.is_dead()


# --- Enemy attacks ------------------------------------------------------------------

# An enemy's committed attack reached the ball. The run takes the damage; the shove is
# the hit's weight (a hit taken is the player's performance, principle 1).
func _on_player_hit(amount: float, shove: Vector3, source: String) -> void:
	if not ctx.flow.in_play():
		return
	ctx.run.damage(amount, source)
	if ctx.calm:
		return
	# The damage always lands; what the hit may take is the stop, and that goes through
	# the player's crowd-control door, which Rivet's sprint shuts.
	ctx.player.crowd_control("knock", shove / get_physics_process_delta_time())


func _on_lobber_fired(origin: Vector3, landing: Vector3, flight: float, lobber: Node3D) -> void:
	var shell := Projectile.new()
	ctx.root.add_child(shell)
	shell.setup(ctx.player, ground, ctx.root, Callable(ctx.flow, "in_play"), origin, landing, flight, lobber)
	shell.hit_player.connect(_on_player_hit.bind("lobber"))
	shell.returned_landed.connect(_on_shell_returned)
	shell.exploded.connect(func(at: Vector3, blast: float, _hit: bool): effects.ring(at, blast, Palette.HAZARD))


# A batted shell's blast hits every enemy its amber ring contains.
func _on_shell_returned(shell: Node3D) -> void:
	var ring: Node3D = shell.ring
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.is_dead() or not is_instance_valid(ring) or not ring.contains(enemy.global_position - Vector3.UP * enemy.half_height):
			continue
		var owned: bool = enemy == shell.lobber
		strike(enemy, "shell", SHELL_RETURN_DAMAGE)
		if owned and enemy.is_dead():
			_discover("shell_return", enemy.global_position)


func _threat() -> float:
	return ctx.flow.stage_def()["threat"]


# A stage's Warden numbers: the current stage from flow's stage_def(), any other stage
# (the vault's next one) from stage_defs.of(stage). A missing field falls back to the
# spec's per-stage value.
func warden_spec(stage: int) -> Dictionary:
	var def: Dictionary = ctx.flow.stage_def() if stage == ctx.flow.stage() else stage_defs.of(stage)
	var fallback: Dictionary = WARDEN_FALLBACK[clampi(stage, 1, 3) - 1]
	return {
		"plating": float(def.get("warden_plating", fallback["warden_plating"])),
		"hp": float(def.get("warden_hp", fallback["warden_hp"])),
		"lesson": String(def.get("warden_lesson", fallback["warden_lesson"])),
	}


func _spec_for(kind: String) -> Dictionary:
	var stage: int = ctx.flow.stage()
	match kind:
		"warden":
			var w := warden_spec(stage)
			w["stage"] = stage
			w["reach"] = float(ctx.flow.stage_def().get("beacon_radius", 30.0))
			return w
		"miniboss":
			return {"plating": float(roundi(MINIBOSS_PLATING_SCALE * warden_spec(stage)["plating"]))}
		"vault":
			var next_plating: float = roundf(VAULT_TOP_SCALE * warden_spec(stage)["plating"]) if StageDefs.is_last(stage) \
					else warden_spec(stage + 1)["plating"]
			return {"stage": stage, "plating": next_plating, "hp": 400.0 * stage}
	return {}


# --- Codex (category "enemy") -------------------------------------------------------

func codex_entries() -> Array:
	return CodexEntries.all()


func _codex():
	return ctx.get("codex") if ctx != null else null


func _declare_codex() -> void:
	var codex = _codex()
	if codex == null or not codex.has_method("declare"):
		return
	for entry in CodexEntries.all():
		codex.declare(entry)


# Every time a trick fires. The codex dedupes per run and per attempt, so a trick first
# pulled in a retried attempt pays again after the retry (CONTRACTS, Codex).
func _discover(id: String, at: Vector3) -> void:
	if not discovered.has(id):
		discovery_log.append(id)
	discovered[id] = at
	var codex = _codex()
	if codex != null and codex.has_method("mark_discovered"):
		codex.mark_discovered(id, at, ["player"])


# Tricks that read the target's state before the hit lands.
func _detect_before(enemy: Node3D, kind: String, result: Dictionary) -> void:
	var target_kind = enemy.get("kind")
	if kind == "ram" and target_kind == "chaser" and enemy.state_name() == "windup":
		_discover("counter_ram", enemy.global_position)
	if kind == "stomp" and result["part"] == "cap" and target_kind == "warden" \
			and enemy.seconds_since_pulse() <= PULSE_STOMP_WINDOW:
		_discover("pulse_stomp", enemy.global_position)


# Tricks that read the outcome.
func _detect_after(enemy: Node3D, kind: String, result: Dictionary) -> void:
	if not enemy.has_method("is_dead") or not enemy.is_dead():
		return
	var at: Vector3 = enemy.global_position
	if kind == "ram" and result["plating"] <= 0.0:
		_crushes.append(_clock)
		while not _crushes.is_empty() and _clock - _crushes[0] > CRUSH_WINDOW:
			_crushes.pop_front()
		if _crushes.size() >= CRUSH_CHAIN:
			_discover("crush_chain", at)
	if kind in ["runner", "arc", "turret", "sticky", "line"] and _since_slingshot <= PARTING_WINDOW:
		_discover("parting_shot", at)
	if enemy.get("kind") == "warden" and enemy.unplated_by_magnet():
		_discover("magnet_break", at)


# --- Stage reset --------------------------------------------------------------------

# A stage entry or retry starts the fight clean, and recomputes every pattern from the
# restored part list, so a retry restores the build exactly.
func _on_stage_entered(_stage: int, _retry: bool) -> void:
	_start_attempt()
	ctx.camera.shoulder_target = 0.0
	volleys = 0
	last_shot = {}
	last_burst = {}
	_since_slingshot = INF
	_rebuild_patterns()


# The arena is not a stage (DESIGN-NOTES spine call 34). Flow publishes this before the
# boss module's enter_arena, on entry and on every arena retry, so nothing of Brindle's
# exists yet and every enemy, shell and telegraph standing now came from the stage or
# from the attempt being retried. The class kit keeps working, and its cooldowns start
# fresh as they do on a stage retry.
func _on_stage_content_cleared(_reason: String) -> void:
	_start_attempt()


func _start_attempt() -> void:
	_clear_fight()
	_crushes.clear()
	_shred.clear()
	_pinned.clear()
	_cooldown = 0.0
	_overdrive = 0.0
	_rocket_left = 0.0
	cloak_left = 0.0
	last_committed = {}
	for id in ctx.player.abilities.cancel_gauges():
		ctx.events.gauge_cancelled.emit(id, "reset")
	ctx.player.indicator.clear_all()


# Every enemy, shell and telegraph leaves its group, stops acting and stops colliding
# now, and is freed at the end of the frame, so a count or a hit test straight after
# the clear already sees an empty field.
func _clear_fight() -> void:
	for group in FIGHT_GROUPS:
		for node in get_tree().get_nodes_in_group(group):
			node.remove_from_group(group)
			node.process_mode = Node.PROCESS_MODE_DISABLED
			node.queue_free()
	bolts.clear()
	sticky.clear()
	effects.clear()


func _rebuild_patterns() -> void:
	var ids := active_transformers()
	for weapon in Weapons.ALL:
		_patterns[weapon] = Weapons.base(weapon).transformed(ids)
