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
# 3. The special fires on its key: overdrive for the runner, the pylon discharge for
#    the engineer. Planting a pylon as the engineer fires the discharge for free,
#    powered by the banked speed (the turret's opening burst).
# 4. Bolts step; a bolt that reaches an enemy is resolved once through strike().
# 5. Every plated enemy is tinted amber if punch_now() beats its plating, slate if not.
#
# Plating (DEMO-SPEC Rules) lives in one function, resolve(): punch for a ball contact
# is (base + force * k) * heft, punch for a weapon hit is its damage after parts; punch
# at or above the target's plating lands in full, below it chips CHIP. strike(), the
# tint, punch_now(), plating_of() and would_crush() all read that one function.

const MUZZLE := 1.25
const AIM_SLACK := 14.0
const KINDS := ["chaser", "lobber", "miniboss", "warden", "vault"]
const CONTACT_KINDS := ["stomp", "ram", "slam"]
const CHIP := 0.2
# Used only when stage_def() has no warden fields yet (the old spine): the spec's values.
const WARDEN_FALLBACK := [
	{"warden_plating": 30.0, "warden_hp": 400.0, "warden_lesson": "plate"},
	{"warden_plating": 60.0, "warden_hp": 700.0, "warden_lesson": "caps"},
	{"warden_plating": 95.0, "warden_hp": 1000.0, "warden_lesson": "magnet"},
]
const VAULT_TOP_PLATING := 120.0
const MINIBOSS_PLATING_SCALE := 1.25
const SHELL_RETURN_DAMAGE := 40.0
const BAT_REACH := 2.4
const PARTING_WINDOW := 1.0
const PULSE_STOMP_WINDOW := 1.5
const CRUSH_WINDOW := 1.0
const CRUSH_CHAIN := 3

# Ball contacts: base damage plus a share of the contact's force.
const STRIKE_DAMAGE := {
	"stomp": [30.0, 1.1],
	"ram": [14.0, 1.3],
	"slam": [0.0, 1.2],
}

var ctx
var bolts
var effects
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

var _patterns := {}
var _part_map := {}
var _cooldown := 0.0
var _special_cooldown := 0.0
var _overdrive := 0.0
var _since_slingshot := INF
var _crushes: Array = []
var _clock := 0.0


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	name = "Combat"
	ctx.spawner = self
	effects = Effects.new()
	ctx.root.add_child(effects)
	effects.setup()
	bolts = Bolts.new()
	ctx.root.add_child(bolts)
	bolts.setup()
	bolts.on_hit = _on_bolt_hit
	bolts.on_shell = func(_bolt: Dictionary, shell: Node3D) -> bool: return _bat(shell)
	bolts.on_stop = func(at: Vector3, color: Color): effects.spark(at, color)
	ctx.events.stage_entered.connect(_on_stage_entered)
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
	enemy.setup(ctx.player, ctx.terrain, ctx.root, Callable(ctx.flow, "in_play"), _threat(), _spec_for(kind))
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
	ctx.events.enemy_struck.emit(enemy, kind, force)
	if not result["full"]:
		deflections += 1
		ctx.events.strike_deflected.emit(enemy, kind, result["punch"], result["plating"])
	if enemy.has_method("on_struck"):
		enemy.on_struck(kind, result["part"], result)
	enemy.take_damage(result["dealt"])
	_detect_after(enemy, kind, result)


# The one plating rule. Returns {punch, plating, full, dealt, part}.
func resolve(enemy: Node3D, kind: String, force: float, part := "") -> Dictionary:
	if part == "" and kind in CONTACT_KINDS and enemy.has_method("contact_part"):
		part = enemy.contact_part(ctx.player.ball_position(), kind)
	var punch := punch_of(kind, force)
	var plating: float = enemy.plating_for(kind, part) if enemy.has_method("plating_for") else 0.0
	var full := punch >= plating
	var mult: float = enemy.hit_mult(kind, part) if full and enemy.has_method("hit_mult") else 1.0
	var dealt := punch * mult if full else punch * CHIP
	return {"punch": punch, "plating": plating, "full": full, "dealt": dealt, "part": part}


# Punch for a hit of this kind and force: a ball contact scales with heft, a weapon hit
# is its damage.
func punch_of(kind: String, force: float) -> float:
	if STRIKE_DAMAGE.has(kind):
		var row: Array = STRIKE_DAMAGE[kind]
		return (row[0] + force * row[1]) * heft()
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
	var ram := 0.0
	if ctx.player.speed_tier() >= SpeedTier.CRUISE:
		ram = punch_of("ram", ctx.player.planar_velocity().length())
	var weapon := active_weapon()
	var shot: float = _patterns[weapon].damage * _damage_mod(weapon) if _patterns.has(weapon) else 0.0
	return maxf(ram, shot)


# Build owns tuning mods (CONTRACTS). Combat reads its weapon keys live, at the moment
# of use, so it never depends on which module heard part_gained first.
func _damage_mod(weapon: String) -> float:
	var scale: float = ctx.tuning.mod("weapon_damage")
	if weapon == Weapons.PYLON_TURRET:
		scale *= ctx.tuning.mod("turret_damage")
	return scale


func plating_of(enemy: Node3D) -> float:
	if not is_instance_valid(enemy) or not enemy.has_method("plating_now"):
		return 0.0
	return enemy.plating_now()


# hp / max_hp, 1.0 for an invalid enemy (as the spec says), 0.0 for a dead one.
func integrity_of(enemy: Node3D) -> float:
	if not is_instance_valid(enemy):
		return 1.0
	if (enemy.has_method("is_dead") and enemy.is_dead()) or float(enemy.get("max_hp")) <= 0.0:
		return 0.0
	return clampf(float(enemy.get("hp")) / float(enemy.get("max_hp")), 0.0, 1.0)


# True when this contact would kill an unplated target outright: the spine's crush
# pass-through asks before it decides to skip the knock. A plated break-through is
# not a crush.
func would_crush(enemy: Node3D, kind: String, force: float) -> bool:
	if not is_instance_valid(enemy) or enemy.is_dead():
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
	_special_cooldown = maxf(0.0, _special_cooldown - delta)
	_overdrive = maxf(0.0, _overdrive - delta)
	var intent = ctx.player.intent
	var weapon := active_weapon()
	if intent.fire_held and _cooldown <= 0.0 and _patterns.has(weapon):
		_fire(weapon)
		_cooldown += 1.0 / _rate(weapon)
	if not intent.fire_held:
		_cooldown = maxf(_cooldown, 0.0)
	if intent.special_pressed and _special_cooldown <= 0.0:
		_special()
	var shells := get_tree().get_nodes_in_group("enemy_shot")
	bolts.step(delta, ctx.root.get_world_3d().direct_space_state, get_tree().get_nodes_in_group("enemy"), shells)
	_bat_by_ball(shells)
	_tint()


# Plated targets glow amber when your punch beats their plating right now, slate when
# it does not. Same function as the strike, re-read every physics tick.
func _tint() -> void:
	var punch := punch_now()
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not enemy.has_method("set_tint") or enemy.is_dead() or enemy.plating <= 0.0:
			continue
		enemy.set_tint("amber" if punch >= enemy.plating_now() else "slate")


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

func _special() -> void:
	var def = ctx.run.class_def
	var at: Vector3 = ctx.player.ball_position()
	if def.weapon_id == Weapons.ARC_CASTER:
		var kit = ctx.player.kit
		var speed: float = kit.mount_banked if kit.mounted else ctx.player.state.velocity.length()
		_discharge(at, speed, "turret" if kit.mounted else "arc")
		_special_cooldown = Weapons.DISCHARGE_COOLDOWN
	else:
		_overdrive_blast(at)
		_special_cooldown = Weapons.OVERDRIVE_COOLDOWN
	ctx.events.special_used.emit(def.special_id, at)


# The pylon's opening burst: planting as the engineer discharges the banked speed.
func _on_mounted(at: Vector3, banked_speed: float) -> void:
	if ctx.run.class_def == null or not ctx.flow.in_play():
		return
	if ctx.run.class_def.weapon_id != Weapons.ARC_CASTER:
		return
	_discharge(at, banked_speed, "turret")
	ctx.events.special_used.emit(ctx.run.class_def.special_id, at)


func _discharge(at: Vector3, speed: float, kind: String) -> void:
	var burst := discharge_preview(speed)
	var targets := _nearest_list(at, burst["radius"], burst["targets"])
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


func _overdrive_blast(at: Vector3) -> void:
	var p: Resource = _patterns[Weapons.RAPID_LASER]
	var damage: float = Weapons.OVERDRIVE_DAMAGE * p.damage * _damage_mod(Weapons.RAPID_LASER) / Weapons.BASE[Weapons.RAPID_LASER]["damage"]
	var hit := 0
	for enemy in _nearest_list(at, Weapons.OVERDRIVE_RADIUS, 64):
		_hit(enemy, "runner", damage, enemy.global_position - at, Weapons.OVERDRIVE_KNOCK, 0.5)
		hit += 1
	_overdrive = Weapons.OVERDRIVE_SECONDS * p.special_scale
	effects.ring(at, Weapons.OVERDRIVE_RADIUS, Weapons.color(Weapons.RAPID_LASER))
	last_burst = {"at": at, "radius": Weapons.OVERDRIVE_RADIUS, "damage": damage, "hit": hit, "kind": "runner",
		"overdrive": _overdrive}


# --- Enemy attacks ------------------------------------------------------------------

# An enemy's committed attack reached the ball. The run takes the damage; the shove is
# the hit's weight (a hit taken is the player's performance, principle 1).
func _on_player_hit(amount: float, shove: Vector3, source: String) -> void:
	if not ctx.flow.in_play():
		return
	ctx.run.damage(amount, source)
	if shove != Vector3.ZERO and not ctx.calm:
		ctx.player.add_external_accel(shove / get_physics_process_delta_time())


func _on_lobber_fired(origin: Vector3, landing: Vector3, flight: float, lobber: Node3D) -> void:
	var shell := Projectile.new()
	ctx.root.add_child(shell)
	shell.setup(ctx.player, ctx.terrain, ctx.root, Callable(ctx.flow, "in_play"), origin, landing, flight, lobber)
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


# The stage's Warden numbers: stage_def() fields when the spine has them, else the
# spec's per-stage values.
func warden_spec(stage: int) -> Dictionary:
	var def: Dictionary = ctx.flow.stage_def() if stage == ctx.flow.stage() else {}
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
			var next_plating: float = VAULT_TOP_PLATING if stage >= 3 else warden_spec(stage + 1)["plating"]
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


# Once per run per id here; the codex itself owns what persists across runs.
func _discover(id: String, at: Vector3) -> void:
	if discovered.has(id):
		return
	discovered[id] = at
	discovery_log.append(id)
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
	if kind in ["runner", "arc", "turret"] and _since_slingshot <= PARTING_WINDOW:
		_discover("parting_shot", at)
	if enemy.get("kind") == "warden" and enemy.unplated_by_magnet():
		_discover("magnet_break", at)


# --- Stage reset --------------------------------------------------------------------

# A stage entry or retry starts the fight clean, and recomputes every pattern from the
# restored part list, so a retry restores the build exactly.
func _on_stage_entered(_stage: int, _retry: bool) -> void:
	for group in ["enemy", "enemy_shot", "telegraph"]:
		for node in get_tree().get_nodes_in_group(group):
			node.queue_free()
	bolts.clear()
	effects.clear()
	ctx.camera.shoulder_target = 0.0
	_cooldown = 0.0
	_special_cooldown = 0.0
	_overdrive = 0.0
	volleys = 0
	last_shot = {}
	last_burst = {}
	_crushes.clear()
	_since_slingshot = INF
	_rebuild_patterns()


func _rebuild_patterns() -> void:
	var ids := active_transformers()
	for weapon in Weapons.ALL:
		_patterns[weapon] = Weapons.base(weapon).transformed(ids)
