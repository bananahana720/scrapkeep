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
const EventKinds := preload("res://src/core/event_kinds.gd")
const Ground := preload("res://src/combat/ground.gd")
const WearTrail := preload("res://src/combat/wear_trail.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Sticky := preload("res://src/combat/sticky.gd")
const NearMiss := preload("res://src/combat/near_miss.gd")
const Sight := preload("res://src/combat/sight.gd")
# v2 W7 enemies: the reinforcements, the ancients and their holds (fleet.gd).
const Fleet := preload("res://src/combat/fleet.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")
# The v3 fun lab's loop_mode switch and the roster row fleet.gd's own
# reinforcement-pack system reads (M0's "adds" classification).
const LoopMode := preload("res://src/core/loop_mode.gd")
const Roster := preload("res://src/combat/roster.gd")
const WardenDrop := preload("res://src/combat/warden_drop.gd")

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
# Mass-K: radius bonus at full mass, and the mass that counts as full (BUILD-SYSTEMS.md).
const MASS_K_RADIUS := 0.25
const MASS_K_SATURATION := 990.0
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

# M0: delivered-damage baseline and provenance (design-v3/STRATEGY-SPINE.md §7 row M0,
# §8 row 1). strike() is the one place a hit becomes damage (TADR-008), so it is the
# one place the ledger is written; no double counting is possible across combat.gd and
# enemy.gd because enemy.take_damage() only ever returns the HP it actually removed,
# clamped to what was left (overkill), and never records anything itself.
# Range buckets are metres from the ball at the moment of the hit; near/mid match a
# weapon's close reach and mid-fight spacing, not measured play data yet.
const RANGE_NEAR_M := 6.0
const RANGE_MID_M := 16.0
# source: weapon (fired bolts, chains); ram_or_contact (a ball contact, a pin, a batted
# shell); drop_or_slam (the slam contact kind, or any contact warden_drop.gd's rule
# judged a drop, whatever its kind); special (a gauge release); item_proc (a build
# synergy, an element-field proc, an upgrade-tree proc or timed upgrade); persistent_actor
# (a standing structure's own attack, e.g. the Sentry Post). Any strike() call from
# outside this file (build.gd, element_field.gd) that does not name its source falls
# through to item_proc: SEAMS.md says those strikes are never the player's own weapon
# fire or gauge release, both of which always tag themselves below.
# target_class: enemy (a v1 kind or the v2 Fleet roster's own field population), Warden,
# adds (a Fleet reinforcement pack, fleet.gd's own name for it), boss (Brindle) or
# boss_adds (something spawned while ctx.flow.in_arena is true, e.g. Brindle's
# drone-dropped lobbers; boss.gd is out of this unit's allowed files, so the tag comes
# from spawn provenance in spawn_enemy() below, not a caller-set flag). Fleet-roster
# kinds keep "adds" (fleet.gd calls its own spawns "reinforcement packs", asserted in
# _target_class_of_kind against Roster.is_reinforcement rather than left as an implicit
# complement of KINDS, review finding 3, fix round 2, confirmed rather than renamed: see
# that function for the evidence). cache (the vault: static, never attacks, never moves)
# is its own class, not "enemy" (finding 3, fix round 1).
# "Scenery" is excluded by construction: a piece that cannot be hit (boss_target.gd's
# world-layer wrecked hull) never reaches strike() to begin with.

var ctx
var fleet
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
# M0's delivered-damage ledger, reset on run_started only (a per-run measure; a stage
# retry does not clear it). Mirrored onto ctx.run's meta after every change so run_log
# can read it without a new reference or bus signal. delivered_damage() reads it.
var _ledger := {}
# This stage attempt's landed drops (one per warden_drop_landed, however many strikes the
# landing made) and its damaging stomp and slam hits on the Warden, kept apart so a hit
# count is never read as a drop count. Reset every attempt (_start_attempt) and
# snapshotted into _ledger's drops_to_break and warden_slam_hits on beacon_unsealed.
var _warden_drops := 0
var _warden_slam_hits := 0
# Instance ids spawned while ctx.flow.in_arena was true (M0, review fix round 1): the
# only spawner call reachable there is boss.gd's own drone drop, so this is how a boss
# add is told apart from an ordinary field enemy without a flag boss.gd would have to
# set (boss.gd is not in this unit's allowed files). Entries are erased on death.
var _boss_add_ids := {}
# A block of hits' source when the kind string alone cannot say it (a discharge, an
# overdrive blast, an upgrade proc): set right before the calls and restored right after,
# so a block nested inside another keeps the outer block's tag.
# strike()'s own `source` argument always wins over this when given.
var _forced_source := ""
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
# Rivet's Run and Gun wear trail (world one, --wear=on); wear_trail.gd.
var wear_trail
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
# Upgrade-tree state (upgrade_tree.gd): each proc's next allowed time by node:fact, the
# pending special echo, marked targets (instance id -> clock the mark ends), the blink's
# smoke cloud, the Sentry Post, the timed-upgrade clock and how long the cloak has held.
var _proc_ready := {}
var _echo := {}
var _echoing := false
var _marks := {}
# The dodge read (near_miss.gd), and the last hit the ball took: where it came from, for
# presentation's edge flash. Both read only.
var near_miss
var last_player_hit := {}
var _cloud := {}
var _sentry := {}
var _pulse_left := 0.0
var _cloak_held := 0.0
# UpgradeTree.ACTIONS name -> Callable(scale).
var _actions := {}


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	name = "Combat"
	ctx.spawner = self
	ground = Ground.new(ctx)
	fleet = Fleet.new()
	add_child(fleet)
	fleet.setup(ctx, self)
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
	wear_trail = WearTrail.new()
	wear_trail.setup(ctx, effects, _floor_at)
	wear_trail.deal = _trail_deal
	near_miss = NearMiss.new()
	add_child(near_miss)
	near_miss.setup(ctx.events, Callable(ctx.player, "ball_position"))
	_specials = {
		"detonation_gauge": {"geometry": _discharge_geometry, "fire": _fire_discharge},
		"overdrive_blast": {"geometry": _overdrive_geometry, "fire": _fire_overdrive},
		"detonation_line": {"geometry": _line_geometry, "fire": _fire_line},
		"point_blank": {"geometry": _point_blank_geometry, "fire": _fire_point_blank},
	}
	_actions = _proc_actions()
	# Every bus fact any tree's procs listen for, connected once; the tree decides who fires.
	var facts := {}
	for class_id in UpgradeTree.TREES:
		for n in UpgradeTree.TREES[class_id]:
			for proc in n.get("proc", []):
				facts[proc["on"]] = true
	for kind in facts:
		if not ctx.events.has_signal(kind):
			continue
		var argc: int = _signal_argc(ctx.events, kind)
		ctx.events.connect(kind, _on_proc_fact.bind(kind).unbind(argc))
	ctx.events.slammed.connect(_on_slammed_upgrade)
	ctx.events.dismounted.connect(_on_dismounted_sentry)
	ctx.events.tree_picked.connect(func(_c: String, _n: String, _d: int): _rebuild_patterns())
	ctx.player.heft_of = heft
	ctx.player.mass_of = func() -> float: return ctx.run.mass
	_reset_ledger()
	ctx.events.demo_slammed.connect(_on_demo_slammed)
	ctx.events.arc_slammed.connect(func(at: Vector3, _faces: int): effects.ring(at, 12.0, ClassDef.SABLE_COLOR))
	ctx.events.skid_smashed.connect(func(at: Vector3, _hits: int): effects.ring(at, 4.0, ClassDef.RIVET_COLOR))
	ctx.events.blink_used.connect(_on_blink)
	ctx.events.stage_entered.connect(_on_stage_entered)
	ctx.events.stage_content_cleared.connect(_on_stage_content_cleared)
	ctx.events.run_started.connect(func(_class_id: String):
		discovered = {}
		_proc_ready = {}
		_echo = {}
		_marks = {}
		_cloud = {}
		_sentry = {}
		_pulse_left = 0.0
		_boss_add_ids = {}
		_reset_ledger()
		_rebuild_patterns())
	ctx.events.warden_drop_landed.connect(func(_at: Vector3, _speed: float, _left: int, _segments: int):
		_warden_drops += 1)
	ctx.events.beacon_unsealed.connect(func(stage: int):
		_ledger["drops_to_break"][str(stage)] = _warden_drops if LoopMode.is_drop(ctx.tuning) else null
		_ledger["warden_slam_hits"][str(stage)] = _warden_slam_hits
		_warden_drops = 0
		_warden_slam_hits = 0)
	# review finding 1, fix round 2: Brindle's parts are never spawned through
	# spawn_enemy(), so the died-signal retirement path below never sees him; boss_defeated
	# (already a bus fact, game_events.gd:73 / event_kinds.gd:81, published once by
	# boss.gd's own _defeat()) is the one signal every boss kill fires, whatever finished
	# him (the scooter catch or, if a future path lets a hull hit zero the pool directly,
	# that too), so it is where the "boss" retirement belongs instead.
	ctx.events.boss_defeated.connect(func(): _record_retirement("boss"))
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
		_ when fleet.makes(kind):
			enemy = fleet.make(kind)
		_:
			push_warning("spawn_enemy: unknown kind '%s', spawning a chaser" % kind)
			kind = "chaser"
			enemy = Chaser.new()
	ctx.root.add_child(enemy)
	enemy.global_position = at
	# M0 (review fix round 1, finding 2): the only spawner call reachable while the boss
	# arena is up is boss.gd's own drone drop, so a spawn landing here is a boss add, not
	# an ordinary field enemy, whatever kind string it uses (currently always "lobber").
	if ctx.flow != null and ctx.flow.in_arena:
		_boss_add_ids[enemy.get_instance_id()] = true
	# Fodder sees the player through its sight, which Kest's cloak can fool; the Warden
	# and the vault are set pieces and always see the ball.
	var target = Sight.new(ctx.player, self, enemy, kind) if Sight.REACH.has(kind) or fleet.makes(kind) else ctx.player
	enemy.setup(target, ground, ctx.root, Callable(ctx.flow, "in_play"), _threat(), fleet.dress(kind, _spec_for(kind)))
	enemy.hit_player.connect(_on_player_hit.bind(kind))
	enemy.died.connect(func(where: Vector3, scrap: int):
		ctx.run.record_kill(kind, where, scrap, enemy.last_damage_source if "last_damage_source" in enemy else "")
		var id := enemy.get_instance_id()
		_record_retirement(_class_for_id(id, kind))
		_boss_add_ids.erase(id))
	if enemy.has_signal("fired"):
		enemy.fired.connect(_on_lobber_fired.bind(enemy))
	ctx.events.enemy_spawned.emit(enemy, kind)
	fleet.on_spawned(enemy, kind)
	return enemy


# What the director weights reinforcement packs against (fleet.gd build_read).
func build_read() -> Dictionary:
	return fleet.build_read()


# A hit the spine or a weapon made, resolved into damage exactly once. The bus facts go
# out before the damage so a kill never publishes a freed node: enemy_struck always,
# then strike_deflected when the punch fell short of the plating. `part` names a weak
# point ("" for the body; a ball contact finds its own through contact_part()).
func strike(enemy: Node3D, kind: String, force: float, part := "", source := "") -> void:
	if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
		return
	if enemy.has_method("is_dead") and enemy.is_dead():
		return
	var result := resolve(enemy, kind, force, part)
	_detect_before(enemy, kind, result)
	var outer := _pending
	_pending = {"id": enemy.get_instance_id(), "kind": kind, "force": force, "part": result["part"]}
	# review finding 1, fix round 2: a Brindle piece's hp is a getter over the boss's one
	# shared pool (boss_target.gd), and a listener on enemy_struck can remove HP from that
	# pool synchronously (boss.gd's _on_enemy_struck -> _defeat, the scooter catch) before
	# take_damage() ever runs, outside take_damage()'s own return-value accounting. Reading
	# hp before the emit and again after take_damage() catches that removal too, clamped
	# the same way overkill already is; for every ordinary target this equals what
	# take_damage() itself returned, so the maxf below never double-counts. hp_after is
	# floored at 0 before the subtraction: enemy.gd's own take_damage() subtracts past 0
	# rather than clamping (unlike the removed value it returns and unlike boss.gd's own
	# floor clamp), so an unclamped delta would read the full overkill swing as "removed"
	# on every ordinary kill.
	var hp_before := _hp_of(enemy)
	ctx.events.enemy_struck.emit(enemy, kind, force)
	if not result["full"]:
		deflections += 1
		ctx.events.strike_deflected.emit(enemy, kind, result["punch"], result["plating"])
	_pending = outer
	if enemy.has_method("on_struck"):
		enemy.on_struck(kind, result["part"], result)
	# Hits, not drops: one Rivet skid landing strikes SLAM twice (the shockwave, then the
	# skid push), so drops come only from warden_drop_landed (see setup()). Counted before
	# take_damage() because a killing hit unseals the stage (beacon_unsealed, which
	# snapshots this count) inside it.
	if kind in ["stomp", "slam"] and float(result["dealt"]) > 0.0 and _target_class(enemy) == "Warden":
		_warden_slam_hits += 1
	var removed: float = enemy.take_damage(result["dealt"])
	if is_instance_valid(enemy):
		removed = maxf(removed, hp_before - maxf(0.0, _hp_of(enemy)))
	if result.get("shred", true):
		_add_shred(enemy, result["punch"])
	_detect_after(enemy, kind, result)
	_record_delivered(enemy, kind, removed, result["dealt"], source if source != "" else _forced_source,
		bool(result.get("drop", false)))


# hp is not part of the enemy protocol (README.md), but every implementation carries it
# (enemy.gd's own var, boss_target.gd's getter over boss.hp); a target without one (the
# scenery-guard's plain Node3D, which never reaches here because it fails the
# has_method("take_damage") check above) reads 0.0 and never inflates a delta.
func _hp_of(enemy: Node3D) -> float:
	if not is_instance_valid(enemy):
		return 0.0
	var v = enemy.get("hp")
	return float(v) if v != null else 0.0


# --- M0: delivered-damage ledger (see the constants above for the categories) --------

# `drop` is resolve()'s own "drop" key: warden_drop.gd's rule sets it on a contact it
# judged a drop, so a stomp- or ram-kind drop still lands under drop_or_slam.
func _record_delivered(enemy: Node3D, kind: String, removed: float, dealt: float, raw_source: String, drop: bool, known_class := "") -> void:
	if _ledger.is_empty():
		_reset_ledger()
	var source := _classify_source(kind, raw_source, drop)
	var target_class := known_class if known_class != "" else _target_class(enemy)
	_ledger["hits"] = int(_ledger["hits"]) + 1
	if removed <= 0.0:
		_ledger["zero_damage_hits"] = int(_ledger["zero_damage_hits"]) + 1
	_ledger["total"] = float(_ledger["total"]) + removed
	_ledger["overkill"] = float(_ledger["overkill"]) + maxf(0.0, dealt - removed)
	_bump(_ledger["by_source"], source, removed)
	_bump(_ledger["by_action"], kind, removed)
	_bump(_ledger["by_target_class"], target_class, removed)
	_bump(_ledger["by_range"], _range_bucket(enemy), removed)


# A wear-trail patch's damage (wear_trail.gd): straight to take_damage, never strike(), so no
# bus fact goes out, but the HP it removes is still delivered damage. The class is read before
# the hit because a kill retires a boss add's tag. Action "spark", source persistent_actor.
func _trail_deal(enemy: Node3D, amount: float) -> float:
	var target_class := _target_class(enemy)
	var hp_before := _hp_of(enemy)
	var removed: float = enemy.take_damage(amount)
	# Same measure as strike(): a Brindle piece's return value undercounts (M0 delivered damage).
	if is_instance_valid(enemy):
		removed = maxf(removed, hp_before - maxf(0.0, _hp_of(enemy)))
	_record_delivered(enemy, "spark", removed, amount, "persistent_actor", false, target_class)
	return removed


func _record_retirement(target_class: String) -> void:
	if _ledger.is_empty():
		_reset_ledger()
	_ledger["retirements"][target_class] = int(_ledger["retirements"].get(target_class, 0)) + 1


static func _bump(map: Dictionary, key: String, amount: float) -> void:
	map[key] = float(map.get(key, 0.0)) + amount


func _classify_source(kind: String, explicit: String, drop := false) -> String:
	if explicit != "":
		return explicit
	if kind == SYNERGY:
		return "item_proc"
	if drop:
		return "drop_or_slam"
	if kind in CONTACT_KINDS:
		return "drop_or_slam" if kind == "slam" else "ram_or_contact"
	if kind == "pin" or kind == "shell":
		return "ram_or_contact"
	return "item_proc"


func _target_class(enemy: Node3D) -> String:
	return _class_for_id(enemy.get_instance_id(), _spawn_kind_of(enemy))


# Boss-add provenance wins over the kind name (finding 2, fix round 1): shared by
# _target_class (a live strike) and spawn_enemy's died handler (a retirement), so both
# read the same tag instead of two derivations that could drift apart.
func _class_for_id(id: int, kind: String) -> String:
	if _boss_add_ids.has(id):
		return "boss_adds"
	return _target_class_of_kind(kind)


# The kind an enemy was spawned as: a Fleet unit and the Warden carry it on spec
# (fleet.dress); the base kinds (chaser, lobber, miniboss, vault) set their own `kind`
# var instead, since dress() never touches their spec.
func _spawn_kind_of(enemy: Node3D) -> String:
	var spec_val = enemy.get("spec")
	if spec_val is Dictionary and (spec_val as Dictionary).has("kind"):
		return String((spec_val as Dictionary)["kind"])
	var k = enemy.get("kind")
	return String(k) if k != null else ""


func _target_class_of_kind(kind: String) -> String:
	if kind == "warden":
		return "Warden"
	if kind.begins_with("brindle_"):
		return "boss"
	# The vault (roster.gd role "cache") never moves and never attacks (vault.gd's own
	# header); it is the one static, non-combatant damageable in the game, so it earns
	# its own class rather than inflating "enemy" (finding 3, fix round 1).
	if kind == "vault":
		return "cache"
	if kind in KINDS:
		return "enemy"
	# review finding 3, fix round 2 (confidence 0.6, evidence a director-composed
	# mag_trapper landing in "adds"): rejected as a bug, kept as a deliberate reading,
	# confirmed rather than renamed. spawn_enemy()'s match above only ever builds a v1
	# KINDS enemy, the Warden, the vault, or a fleet.makes(kind) enemy, so any kind
	# reaching here is a Fleet SCRIPTS kind, whoever spawned it. fleet.gd's own
	# reinforcement-pack system (on_spawned, Roster.is_reinforcement, the per-frame batch
	# it flushes into pack_arrived: "every reinforcement spawned in one physics frame is
	# one pack") already calls every one of those kinds a reinforcement, director-composed
	# or not; chaser and lobber, KINDS' only other director-spawned kinds, are not
	# reinforcements and land in "enemy" above. "adds" names that system, so it is
	# asserted against Roster.is_reinforcement here instead of left as an implicit
	# complement of KINDS, so the two names cannot silently drift apart. A kind that is
	# neither is a real gap (a KINDS or SCRIPTS addition this unit missed), so it still
	# counts under "adds" but is warned once rather than counted silently.
	if not Roster.is_reinforcement(kind):
		push_warning("_target_class_of_kind: '%s' is neither a v1 kind nor a Fleet reinforcement; counting it under 'adds'" % kind)
	return "adds"


func _range_bucket(enemy: Node3D) -> String:
	if ctx == null or ctx.player == null:
		return "far"
	var d := enemy.global_position.distance_to(ctx.player.ball_position())
	if d <= RANGE_NEAR_M:
		return "near"
	if d <= RANGE_MID_M:
		return "mid"
	return "far"


func _reset_ledger() -> void:
	_ledger = {
		"total": 0.0, "overkill": 0.0, "hits": 0, "zero_damage_hits": 0,
		"by_source": {}, "by_action": {}, "by_target_class": {}, "by_range": {"near": 0.0, "mid": 0.0, "far": 0.0},
		"retirements": {}, "drops_to_break": {}, "warden_slam_hits": {},
	}
	_warden_drops = 0
	_warden_slam_hits = 0
	# review finding 4, fix round 2: a duplicate(true) on every hit is a hot-path
	# allocation (measured ~36x the rest of a hit's bookkeeping; a multi-target discharge
	# can spend roughly 0.8 ms of a ~26 ms frame on copies that are thrown away every time
	# but the run's end). GDScript Dictionaries are references, so publishing this once
	# and mutating it in place (_bump and friends assign into the same object) keeps
	# ctx.run's meta current without a copy; run_log._write() reads it once, right before
	# JSON.stringify serialises the line synchronously, so no caller ever observes a
	# half-written ledger.
	if ctx != null and ctx.run != null:
		ctx.run.set_meta("delivered_damage", _ledger)


# Read-only: run_log mirrors this onto ctx.run's meta (delivered_damage) at every
# change; a test may read it directly.
func delivered_damage() -> Dictionary:
	return _ledger


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
	# The v3 fun lab: a loop mode's own damage rule (warden_drop.gd) answers first; an
	# empty answer (v2, or any enemy without one) falls through to the plating rule.
	if enemy.has_method("loop_rule"):
		var rule: Dictionary = enemy.loop_rule(kind, part, force, punch, heft())
		if not rule.is_empty():
			return rule
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
		var scale := 1.0
		if ctx != null and ctx.player.kit.sprinting:
			scale = _knob("sprint_punch")
		# Winch Ram: hauling in on the rope, you hit like a sprint.
		elif ctx != null and ctx.player.kit.hooked and ctx.player.intent.reel_held:
			scale = _knob("winch_punch")
		return (row[0] + force * row[1]) * heft() * scale
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
	var abilities = ctx.player.abilities
	var weapon: String = abilities.id_of(AbilityState.WEAPON)
	var mounted_as = abilities.cap(AbilityState.WEAPON, "mounted", null)
	# Air Turret: airborne counts as mounted for the weapon.
	if mounted_as != null and (ctx.player.kit.mounted or (_knob("air_turret") and not ctx.player.state.grounded)):
		return mounted_as
	return weapon


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
	_tick_upgrades(delta)
	var intent = ctx.player.intent
	var weapon := active_weapon()
	if ctx.player.abilities.cap(AbilityState.WEAPON, "lob", 0) > 0:
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
	wear_trail.step(delta, enemies)
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


func _fire(weapon: String, source := "weapon") -> void:
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
			"source": source,
		})
	volleys += 1
	last_shot = {"weapon_id": weapon, "from": muzzle, "to": aim["to"], "point": point,
		"blocked": aim["blocked"], "bolts": layout.size(), "volley": volleys}
	ctx.events.shot_fired.emit(weapon, muzzle, aim["to"])


func _on_bolt_hit(bolt: Dictionary, enemy: Node3D, point: Vector3, part := "") -> void:
	effects.spark(point, bolt["color"])
	var from: Vector3 = enemy.global_position
	_hit(enemy, bolt["kind"], bolt["damage"], bolt["dir"], bolt["knock"], part, bolt.get("source", "weapon"))
	if bolt["chain_jumps"] > 0:
		_chain(enemy, from, bolt)


# One resolved weapon hit: the shove, the flash, then strike() for damage and the fact.
func _hit(enemy: Node3D, kind: String, damage: float, direction: Vector3, knock: float, part := "", source := "", impact := "") -> void:
	var push := Vector3(direction.x, 0.0, direction.z)
	push = push.normalized() if push.length() > 0.01 else Vector3.FORWARD
	enemy.knock(push + Vector3.UP * float(EventKinds.impact(impact if impact != "" else kind)["lift"]), knock)
	enemy.flash()
	strike(enemy, kind, damage, part, source)
	# Death Mark: a marked enemy that dies here bursts like a charge.
	var id := enemy.get_instance_id()
	if _marks.has(id) and enemy.is_dead():
		var live: bool = _marks[id] > _clock
		_marks.erase(id)
		if live and _knob("mark_burst"):
			_detonate({"pos": enemy.global_position, "radius": Weapons.BASE[Weapons.STICKY_CHARGE]["bolt_radius"],
				"damage": _patterns[Weapons.STICKY_CHARGE].damage * _damage_mod(Weapons.STICKY_CHARGE), "crit": false, "born": _clock,
				"_source": "item_proc"})


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
		_hit(next, bolt["kind"], damage, to - at, bolt["knock"] * 0.5, "", bolt.get("source", "weapon"))
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

func _knob(name: String):
	return ctx.player.tree.knob(name)


# The one hold-gauge-release loop for every class's special. A press starts the gauge
# if a charge is in; a second press or RMB drops it with nothing spent; the key coming
# up, or a full gauge held past its grace, fires the geometry drawn at that fraction.
# The slot's ability id picks the row in _specials, so a swapped variant plays here too.
func _step_special(intent, delta: float) -> void:
	var abilities = ctx.player.abilities
	var kit = ctx.player.kit
	var id: String = abilities.id_of(AbilityState.SPECIAL)
	var gauge = abilities.gauge(AbilityState.SPECIAL)
	if gauge == null or not _specials.has(id):
		return
	var row: Dictionary = _specials[id]
	# Auto Gauge: mounted, the gauge starts and holds by itself, so it fires at full.
	var auto: bool = _knob("mounted_autogauge") and kit.mounted
	if gauge.charging and (intent.special_pressed or intent.cancel_pressed):
		gauge.cancel()
		ctx.player.indicator.collapse("special")
		ctx.events.gauge_cancelled.emit(id, "cancel")
		return
	if not gauge.charging and (intent.special_pressed or auto) and abilities.ready(AbilityState.SPECIAL):
		gauge.begin()
		ctx.events.gauge_charging.emit(id)
		# Hip Fire: pressed mid-sprint, the gauge is already full and fires now.
		if _knob("sprint_full_blast") and kit.sprinting:
			gauge.held = gauge.charge_max
	if not gauge.charging:
		ctx.player.indicator.clear("special")
		return
	var held: bool = (intent.special_held or auto) and not (_knob("sprint_full_blast") and kit.sprinting)
	var step: float = delta * (_knob("air_charge") if not ctx.player.state.grounded else 1.0)
	if not gauge.step(step, held):
		ctx.player.indicator.set_shape("special", row["geometry"].call(gauge.fraction()))
		return
	var f: float = gauge.fired_fraction
	var shape: Dictionary = row["geometry"].call(f)
	ctx.player.indicator.set_shape("special", shape)
	ctx.player.indicator.clear("special")
	abilities.spend(AbilityState.SPECIAL)
	last_committed = {"id": id, "fraction": f, "geometry": shape}
	row["fire"].call(f, shape)
	# Twin Discharge and Vortex: the same release again, smaller, a moment later.
	if _knob("special_echo") > 0.0:
		_echo = {"row": row, "fraction": f * 0.6, "left": _knob("special_echo")}
	ctx.events.gauge_released.emit(id, f)
	ctx.events.special_used.emit(id, ctx.player.ball_position())


func _tick_echo(delta: float) -> void:
	if _echo.is_empty():
		return
	_echo["left"] -= delta
	if _echo["left"] > 0.0:
		return
	var row: Dictionary = _echo["row"]
	var f: float = _echo["fraction"]
	_echo = {}
	_echoing = true
	row["fire"].call(f, row["geometry"].call(f))
	_echoing = false


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


# The ground straight below a point, for charges a proc drops from the air.
func _floor_at(at: Vector3) -> Vector3:
	var space: PhysicsDirectSpaceState3D = ctx.root.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 80.0, 1))
	return hit["position"] if not hit.is_empty() else _ground_under(at)


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
	var prev_source := _forced_source
	_forced_source = "special"
	_discharge(ctx.player.ball_position(), _discharge_speed(f), "turret" if kit.mounted else "arc", shape["centre"])
	_forced_source = prev_source


func _overdrive_geometry(f: float) -> Dictionary:
	return ctx.player.yours({"kind": "ring", "centre": _ground_under(ctx.player.ball_position()),
		"radius": Weapons.OVERDRIVE_RADIUS * AbilityState.Gauge.scaled(f, 1.0, Weapons.OVERDRIVE_FULL),
		"full_radius": Weapons.OVERDRIVE_RADIUS * Weapons.OVERDRIVE_FULL, "fill": f})


func _fire_overdrive(f: float, shape: Dictionary) -> void:
	var prev_source := _forced_source
	_forced_source = "special"
	_overdrive_blast(ctx.player.ball_position(), AbilityState.Gauge.scaled(f, 1.0, Weapons.OVERDRIVE_FULL), shape)
	_forced_source = prev_source


# Point Blank, Rivet's variant: half the radius, double the damage, same gauge.
func _point_blank_geometry(f: float) -> Dictionary:
	var shape := _overdrive_geometry(f)
	shape["radius"] = float(shape["radius"]) * Weapons.POINT_BLANK_RADIUS
	shape["full_radius"] = float(shape["full_radius"]) * Weapons.POINT_BLANK_RADIUS
	return shape


func _fire_point_blank(f: float, shape: Dictionary) -> void:
	var prev_source := _forced_source
	_forced_source = "special"
	_overdrive_blast(ctx.player.ball_position(), AbilityState.Gauge.scaled(f, 1.0, Weapons.OVERDRIVE_FULL), shape,
		Weapons.POINT_BLANK_RADIUS, Weapons.POINT_BLANK_DAMAGE)
	_forced_source = prev_source


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
		# Marked: the line tags what it hits, and charges hit tagged targets harder.
		if _knob("line_marks") > 0.0:
			_marks[enemy.get_instance_id()] = _clock + _knob("line_marks")
		_hit(enemy, "line", damage, to - from, Weapons.LINE_KNOCK, "", "special")
		hit += 1
	# Fuse Line: charges left along the line.
	var along: int = _knob("line_charges")
	for i in along:
		var spot: Vector3 = from.lerp(to, (float(i) + 0.5) / float(along))
		var fuse_charge: Dictionary = sticky.drop(spot, Weapons.MINI_DAMAGE * _damage_mod(Weapons.STICKY_CHARGE), Weapons.MINI_RADIUS,
			Weapons.MINI_FUSE, Weapons.MINI_ARM, _knob("sticky_reach"), _clock)
		fuse_charge["_source"] = "item_proc"
	effects.arc(from + Vector3.UP * 0.5, to + Vector3.UP * 0.5, ClassDef.KEST_COLOR)
	_start_cloak()
	last_burst = {"at": from, "to": to, "damage": damage, "hit": hit, "kind": "line", "caught": caught.size()}


# The pylon's opening burst: planting fires the special free when its row says so
# (Sable's detonation gauge). Siege Plate lets it reach everything in range.
func _on_mounted(at: Vector3, banked_speed: float) -> void:
	if ctx.run.class_def == null or not ctx.flow.in_play():
		return
	var abilities = ctx.player.abilities
	if not abilities.cap(AbilityState.SPECIAL, "plant_discharge", false):
		return
	var prev_source := _forced_source
	_forced_source = "special"
	_discharge(at, banked_speed, "turret", null, 64 if _knob("plant_all") else -1)
	_forced_source = prev_source
	ctx.events.special_used.emit(abilities.id_of(AbilityState.SPECIAL), at)


# A released gauge passes its drawn centre, and its targets are chosen with the
# forgiveness; the plant's free burst has no drawing and keeps the plain radius.
# Chain Reaction arcs on from every target to one more at half damage.
func _discharge(at: Vector3, speed: float, kind: String, drawn_centre = null, limit := -1) -> void:
	var burst := discharge_preview(speed)
	var count: int = burst["targets"] if limit < 0 else limit
	var targets: Array
	if drawn_centre == null:
		targets = _nearest_list(at, burst["radius"], count)
	else:
		targets = _nearest_in_ring(drawn_centre, burst["radius"], count)
	var color := Weapons.color(Weapons.PYLON_TURRET)
	for enemy in targets:
		var to: Vector3 = enemy.global_position
		effects.arc(at, to, color)
		_hit(enemy, kind, burst["damage"], to - at, Weapons.BURST_KNOCK, "", "", "burst")
	if _knob("discharge_chain"):
		for enemy in targets:
			if not is_instance_valid(enemy):
				continue
			var next := _nearest(enemy.global_position, Weapons.BASE[Weapons.ARC_CASTER]["chain_range"], targets)
			if next != null:
				effects.arc(enemy.global_position, next.global_position, color)
				_hit(next, kind, burst["damage"] * 0.5, next.global_position - enemy.global_position, Weapons.BURST_KNOCK * 0.5, "", "", "spill")
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


# Rivet's blast. Magnet Blast pulls instead of pushing; its echo (Vortex) pushes. A
# proc blast (boost false) knocks without granting the fire-rate boost.
func _overdrive_blast(at: Vector3, scale := 1.0, shape := {}, radius_scale := 1.0, damage_scale := 1.0, boost := true) -> void:
	var p: Resource = _patterns[Weapons.RAPID_LASER]
	var damage: float = Weapons.OVERDRIVE_DAMAGE * scale * damage_scale * p.damage * _damage_mod(Weapons.RAPID_LASER) \
		/ Weapons.BASE[Weapons.RAPID_LASER]["damage"]
	var radius := Weapons.OVERDRIVE_RADIUS * scale * radius_scale
	var centre: Vector3 = shape.get("centre", at)
	var pull: bool = _knob("blast_pull") and not _echoing
	var hit := 0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.is_dead() or not in_ring(centre, radius, enemy):
			continue
		var away: Vector3 = enemy.global_position - at
		_hit(enemy, "runner", damage, -away if pull else away, Weapons.OVERDRIVE_KNOCK * scale, "", "", "overdrive")
		hit += 1
	if boost:
		_boost(Weapons.OVERDRIVE_SECONDS * p.special_scale)
	effects.ring(at, radius, ClassDef.RIVET_COLOR)
	last_burst = {"at": at, "radius": radius, "damage": damage, "hit": hit, "kind": "runner",
		"overdrive": _overdrive}


# The fire-rate boost; Unstoppable makes crowd control slide off while it runs.
func _boost(seconds: float) -> void:
	_overdrive = minf(Weapons.OVERDRIVE_MAX, _overdrive + seconds) if _overdrive > 0.0 else seconds
	if _knob("overdrive_immune"):
		ctx.player.grant_immunity(_overdrive)


# --- Kest: sticky charges, the cloak, the rocket jump ---------------------------------

# LMB is a hold-release throw: hold draws the lobbed arc and its landing ring, release
# throws to exactly that point. Held, it auto-throws at full reach after the grace and
# starts again when the next charge is in. Past the live cap, the oldest goes off.
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
		ctx.events.gauge_cancelled.emit(abilities.id_of(AbilityState.WEAPON), "blocked")
		return
	ctx.player.indicator.clear("weapon")
	ctx.player.indicator.clear("landing")
	abilities.spend(AbilityState.WEAPON)
	_throw_sticky(landing["point"])


func _throw_origin() -> Vector3:
	return ctx.player.ball_position() + _flat_aim() * MUZZLE + Vector3.UP * 0.6


func _lob_pattern() -> Resource:
	var abilities = ctx.player.abilities
	return _patterns[abilities.cap(AbilityState.WEAPON, "pattern", abilities.id_of(AbilityState.WEAPON))]


# Where a throw at this fraction lands: along the flat aim, on the ground under it.
# Over a void there is no ground to stick to, so the aim is blocked (RR-03): it draws
# in bone with a cross and a release throws nothing and spends nothing.
func _throw_landing(f: float) -> Dictionary:
	var p: Resource = _lob_pattern()
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
		"radius": _lob_pattern().bolt_radius * mass_radius_scale(), "blocked": blocked}))


# Mass-K (--world-one-builds=on): a thrown or slammed charge's blast radius is multiplied by
# 1 + 0.25q, q = clamp(mass / 990, 0, 1). Read once where the charge is committed (the throw,
# the slam) and by the aim ring, so the hit test and the preview share one number. Damage,
# blink and glide never read it. Flag off it is exactly 1.
func mass_radius_scale() -> float:
	if not ctx.tuning.world_one():
		return 1.0
	return 1.0 + MASS_K_RADIUS * clampf(ctx.run.mass / MASS_K_SATURATION, 0.0, 1.0)


# One throw. A lob row with more than one charge (Sticky Rain) scatters that many smaller
# charges around the landing ring, splitting the damage.
func _throw_sticky(landing: Vector3) -> void:
	var p: Resource = _lob_pattern()
	var count: int = ctx.player.abilities.cap(AbilityState.WEAPON, "lob", 1)
	var origin := _throw_origin()
	var crit := cloak_left > 0.0
	var damage: float = p.damage * _damage_mod(Weapons.STICKY_CHARGE) * _cloak_shot()
	var ring: float = p.bolt_radius * mass_radius_scale()
	var radius: float = ring
	if count > 1:
		damage *= Weapons.RAIN_DAMAGE / float(count)
		radius *= Weapons.RAIN_RADIUS
	for i in count:
		var live: Array = sticky.live()
		if live.size() >= int(_knob("sticky_max_live")) * count:
			_detonate(sticky.take(live[0]))
		var spot := landing
		if count > 1:
			var angle := TAU * float(i) / float(count)
			spot = landing + Vector3(cos(angle), 0.0, sin(angle)) * ring
		var thrown: Dictionary = sticky.throw(origin, spot, damage, radius, _knob("sticky_fuse"), crit, _knob("sticky_reach"), _clock, _knob("sticky_ride"))
		thrown["_source"] = "weapon"
	volleys += 1
	last_shot = {"weapon_id": Weapons.STICKY_CHARGE, "from": origin, "to": landing, "point": landing,
		"blocked": false, "bolts": count, "volley": volleys, "radius": radius}
	ctx.events.shot_fired.emit(Weapons.STICKY_CHARGE, origin, landing)


# One charge going off: its blast (the drawn landing radius plus the forgiveness), a
# rocket jump if Kest holds Space inside it, and the cloak. Time Bomb grows a charge by
# how long it waited; Demolition and Marked hit plated and marked targets harder;
# Daisy Chain sets off every charge within reach, each once.
func _detonate(charge: Dictionary) -> void:
	var at: Vector3 = charge["pos"]
	var radius: float = charge["radius"]
	var damage: float = charge["damage"]
	if _knob("sticky_grow"):
		damage *= 1.0 + Weapons.GROW_PER_SECOND * minf(Weapons.GROW_MAX_SECONDS, _clock - float(charge.get("born", _clock)))
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.is_dead():
			continue
		if (enemy.global_position - at).length() - _hull(enemy) > radius * (1.0 + AbilityState.FORGIVENESS):
			continue
		var dealt := damage
		if float(enemy.get("plating") if enemy.get("plating") != null else 0.0) > 0.0:
			dealt *= _knob("sticky_breach")
		if _marks.get(enemy.get_instance_id(), -1.0) > _clock:
			dealt *= Weapons.MARK_BONUS
		_hit(enemy, "sticky", dealt, enemy.global_position - at, Weapons.BASE[Weapons.STICKY_CHARGE]["knock"],
			"", charge.get("_source", "weapon"))
	effects.ring(at, radius, ClassDef.KEST_COLOR)
	ctx.events.sticky_detonated.emit(at, charge["crit"])
	_rocket_jump(at)
	_start_cloak()
	if _knob("sticky_chain") > 0.0:
		for other in sticky.charges.duplicate():
			if (other["pos"] as Vector3).distance_to(at) <= _knob("sticky_chain"):
				_detonate(sticky.take(other))


# Kest's rocket jump: Space held inside your own blast throws you away from it, harder
# the closer you are (Blast Jumper needs no Space). Its own cooldown and the throw
# cadence bound the chain.
func _rocket_jump(at: Vector3) -> void:
	var player = ctx.player
	if not player.abilities.cap(AbilityState.MOVEMENT, "rocket", false) or _rocket_left > 0.0:
		return
	if not player.intent.jump_held and not _knob("rocket_auto"):
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


# Kest's demo slam. Demo Expert scatters more; Dive Bomber grows them with the fall;
# Scorched Earth leaves them armed at once and lingering.
func _on_demo_slammed(at: Vector3) -> void:
	if not ctx.flow.in_play():
		return
	var heading: Vector3 = ctx.player.planar_velocity()
	var turn := atan2(heading.z, heading.x) if heading.length() > 0.5 else 0.0
	var count: int = _knob("mini_count")
	var scale := 1.0
	if _knob("slam_fall_scale"):
		scale = clampf(ctx.player.kit.slam_landed / Weapons.DIVE_FALL, 1.0, Weapons.DIVE_MAX)
	var linger: float = _knob("mini_linger")
	var mass_scale := mass_radius_scale()
	for i in count:
		var angle := turn + TAU * float(i) / float(count)
		var spot := at + Vector3(cos(angle), 0.0, sin(angle)) * Weapons.MINI_SPREAD * sqrt(scale)
		var slam_charge: Dictionary = sticky.drop(spot, Weapons.MINI_DAMAGE * scale * _damage_mod(Weapons.STICKY_CHARGE), Weapons.MINI_RADIUS * sqrt(scale) * mass_scale,
			linger if linger > 0.0 else Weapons.MINI_FUSE, 0.0 if linger > 0.0 else Weapons.MINI_ARM, _knob("sticky_reach"), _clock)
		slam_charge["_source"] = "drop_or_slam"


# The blink's smoke. Phantom cuts whatever the blink passed through; Smoke Screen
# leaves a cloud that hides you while you are inside it.
func _on_blink(from: Vector3, to: Vector3) -> void:
	effects.ring(from, 2.5, ClassDef.KEST_COLOR)
	_start_cloak()
	if _knob("blink_cut"):
		for enemy in get_tree().get_nodes_in_group("enemy"):
			if not enemy.is_dead() and in_line(from, to, Weapons.BLINK_CUT_WIDTH, enemy.global_position, _hull(enemy)):
				_hit(enemy, "sticky", _patterns[Weapons.STICKY_CHARGE].damage * _damage_mod(Weapons.STICKY_CHARGE), to - from, EventKinds.IMPACT["proc"]["knock"], "", "item_proc", "proc")
	if _knob("smoke_cloud") > 0.0:
		_cloud = {"at": from, "left": _knob("smoke_cloud")}


func _start_cloak() -> void:
	if not ctx.player.abilities.cap(AbilityState.MOVEMENT, "cloak", false):
		return
	var fresh := cloak_left <= 0.0
	cloak_left = maxf(cloak_left, Weapons.CLOAK_SECONDS)
	if fresh:
		cloak_at = ctx.player.ball_position()
		_cloak_held = 0.0
		ctx.events.cloak_started.emit(cloak_left)


# The cloak fades on its clock. Nightfall holds it while you keep rolling fast (never
# standing still, never past CLOAK_HOLD_MAX); Smoke Trail holds it while gliding; Smoke
# Screen while you stay in the blink's cloud.
func _tick_cloak(delta: float) -> void:
	var kit = ctx.player.kit
	if not _cloud.is_empty():
		_cloud["left"] -= delta
		if _cloud["left"] <= 0.0:
			_cloud = {}
		elif ctx.player.ball_position().distance_to(_cloud["at"]) <= Weapons.SMOKE_CLOUD_RADIUS:
			_start_cloak()
	if _knob("glide_cloak") and kit.gliding:
		_start_cloak()
	kit.cloaked = cloak_left > 0.0
	if cloak_left <= 0.0:
		return
	_cloak_held += delta
	var holding: bool = _knob("cloak_hold_fast") and ctx.player.speed_tier() >= SpeedTier.FAST \
		and _cloak_held < Weapons.CLOAK_HOLD_MAX
	if not holding:
		cloak_left -= delta
	if cloak_left <= 0.0:
		cloak_left = 0.0
		kit.cloaked = false
		ctx.events.cloak_broken.emit("faded")


# The first shot out of the cloak crits and ends it; any other shot is plain. Ambush
# keeps the cloak up, so every shot inside it crits.
func _cloak_shot() -> float:
	if cloak_left <= 0.0:
		return 1.0
	if not _knob("cloak_keep"):
		cloak_left = 0.0
		ctx.player.kit.cloaked = false
		ctx.events.cloak_broken.emit("shot")
	return Weapons.CLOAK_CRIT


# The sight proxy's reach share while cloaked: Ghost hides you from everyone.
func cloak_sight() -> float:
	return _knob("cloak_sight")


# --- Upgrade procs and timed upgrades --------------------------------------------------

# A proc (upgrade_tree.gd) runs its action when its bus fact fires, at most once per its
# gap. No build's actions can lead back to their own trigger (UpgradeTree.problems).
func _on_proc_fact(kind: String) -> void:
	if ctx == null or not ctx.flow.in_play() or ctx.run.class_def == null:
		return
	# A spark kill (wear_trail) procs no tree effect.
	if kind == "enemy_killed" and ctx.run.last_kill_from_spark:
		return
	for proc in ctx.player.tree.procs():
		if proc["on"] != kind:
			continue
		var key: String = "%s:%s" % [proc["node"], kind]
		if _clock < float(_proc_ready.get(key, -INF)):
			continue
		_proc_ready[key] = _clock + float(proc["gap"])
		(_actions[proc["do"]] as Callable).call(float(proc.get("scale", 1.0)))


# One callable per UpgradeTree.ACTIONS name, each taking the proc's scale, so a new
# proc action is one row here and one row there.
func _proc_actions() -> Dictionary:
	var abilities = func(): return ctx.player.abilities
	return {
		"discharge": _proc_discharge,
		"blast": _proc_blast,
		"volley": _proc_volley,
		"charge": _proc_charges,
		"detonate": _proc_detonate,
		"grant_special": func(_scale: float): abilities.call().grant(AbilityState.SPECIAL),
		"grant_move": func(_scale: float): abilities.call().grant(AbilityState.MOVEMENT),
		"refund_special": func(scale: float): abilities.call().refund(AbilityState.SPECIAL, scale),
		"refund_move": func(scale: float): abilities.call().refund(AbilityState.MOVEMENT, scale),
		"overdrive": func(scale: float): _boost(scale),
		"air": func(_scale: float): ctx.player.state.air_actions = 1,
	}


func _proc_volley(scale: float) -> void:
	var weapon := active_weapon()
	if not _patterns.has(weapon) or ctx.player.abilities.cap(AbilityState.WEAPON, "lob", 0) > 0:
		return
	for i in int(scale):
		_fire(weapon, "item_proc")


# The upgrade-tree proc actions (M0: item_proc, never the player's own gauge release).
func _proc_discharge(scale: float) -> void:
	var prev_source := _forced_source
	_forced_source = "item_proc"
	_discharge(ctx.player.ball_position(), scale * Weapons.DISCHARGE_FULL_SPEED, "arc")
	_forced_source = prev_source


func _proc_blast(scale: float) -> void:
	var prev_source := _forced_source
	_forced_source = "item_proc"
	_overdrive_blast(ctx.player.ball_position(), scale, {}, 1.0, 1.0, false)
	_forced_source = prev_source


func _proc_detonate(scale: float) -> void:
	_detonate({"pos": _floor_at(ctx.player.ball_position()),
		"radius": Weapons.BASE[Weapons.STICKY_CHARGE]["bolt_radius"] * scale,
		"damage": _patterns[Weapons.STICKY_CHARGE].damage * _damage_mod(Weapons.STICKY_CHARGE) * scale,
		"crit": false, "born": _clock, "_source": "item_proc"})


func _proc_charges(scale: float) -> void:
	var ground := _floor_at(ctx.player.ball_position())
	var count := int(scale)
	for i in count:
		var angle := TAU * float(i) / float(count)
		var spot := ground + (Vector3(cos(angle), 0.0, sin(angle)) * Weapons.MINI_SPREAD if count > 1 else Vector3.ZERO)
		var proc_charge: Dictionary = sticky.drop(spot, Weapons.MINI_DAMAGE * _damage_mod(Weapons.STICKY_CHARGE), Weapons.MINI_RADIUS,
			Weapons.MINI_FUSE, Weapons.MINI_ARM, _knob("sticky_reach"), _clock)
		proc_charge["_source"] = "item_proc"


# Upgrades that run on a clock: Anchor Storm, Fortress, Carpet Bomb, the Sentry Post.
func _tick_upgrades(delta: float) -> void:
	var kit = ctx.player.kit
	_tick_echo(delta)
	_pulse_left = maxf(0.0, _pulse_left - delta)
	if _pulse_left <= 0.0:
		if kit.hooked and _knob("anchor_pulse") > 0.0:
			var prev_source := _forced_source
			_forced_source = "item_proc"
			_discharge(kit.anchor, Weapons.DISCHARGE_FULL_SPEED * 0.2, "arc")
			_forced_source = prev_source
			_pulse_left = _knob("anchor_pulse")
		elif kit.mounted and _knob("mount_pulse") > 0.0:
			var prev_source := _forced_source
			_forced_source = "item_proc"
			_discharge(ctx.player.ball_position(), kit.mount_banked * 0.5, "turret")
			_forced_source = prev_source
			_pulse_left = _knob("mount_pulse")
		elif kit.gliding and _knob("glide_bombs") > 0.0:
			var ground := _floor_at(ctx.player.ball_position())
			var glide_charge: Dictionary = sticky.drop(ground, Weapons.MINI_DAMAGE * _damage_mod(Weapons.STICKY_CHARGE), Weapons.MINI_RADIUS,
				Weapons.MINI_FUSE, Weapons.MINI_ARM, _knob("sticky_reach"), _clock)
			glide_charge["_source"] = "item_proc"
			_pulse_left = _knob("glide_bombs")
	_tick_sentry(delta)


# Sentry Post: stepping off a pylon leaves it firing turret bolts at the nearest enemy.
func _on_dismounted_sentry(_velocity: Vector3) -> void:
	if _knob("sentry") > 0.0 and ctx.flow.in_play():
		_sentry = {"at": ctx.player.kit.mount_face + ctx.player.kit.mount_normal * 1.2, "left": _knob("sentry"), "next": 0.0}


func _tick_sentry(delta: float) -> void:
	if _sentry.is_empty():
		return
	_sentry["left"] -= delta
	_sentry["next"] -= delta
	if _sentry["left"] <= 0.0:
		_sentry = {}
		return
	if _sentry["next"] > 0.0:
		return
	var from: Vector3 = _sentry["at"]
	var target := _nearest(from, Weapons.SENTRY_REACH, [])
	if target == null:
		return
	var p: Resource = _patterns[Weapons.PYLON_TURRET]
	_sentry["next"] = 1.0 / maxf(0.5, p.rate * Weapons.SENTRY_RATE)
	var dir: Vector3 = (target.global_position + Vector3.UP * 0.8 - from).normalized()
	bolts.fire({
		"origin": from, "dir": dir, "speed": p.speed, "max_dist": Weapons.SENTRY_REACH,
		"damage": p.damage * _damage_mod(Weapons.PYLON_TURRET), "kind": Weapons.strike_kind(Weapons.PYLON_TURRET),
		"weapon_id": Weapons.PYLON_TURRET, "radius": p.bolt_radius, "knock": p.knock, "chain_jumps": p.chain_jumps,
		"chain_range": p.chain_range, "chain_falloff": p.chain_falloff, "color": Weapons.color(Weapons.PYLON_TURRET),
		"wave_amp": 0.0, "wave_hz": 0.0, "phase": 0.0,
		"source": "persistent_actor",
	})


# Crater Slam: a smash row that spends the special fires a full discharge on landing.
func _on_slammed_upgrade(at: Vector3, _strength: float, _flatness: float) -> void:
	var abilities = ctx.player.abilities
	if not ctx.flow.in_play() or not abilities.cap(AbilityState.SMASH, "spends_special", false):
		return
	if abilities.spend(AbilityState.SPECIAL):
		_discharge(at, Weapons.DISCHARGE_FULL_SPEED, "arc")
		ctx.events.special_used.emit(abilities.id_of(AbilityState.SPECIAL), at)


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
	last_player_hit = {"from": ctx.player.ball_position() - shove, "shove": shove, "source": source, "frame": Engine.get_physics_frames()}
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


# The fun lab's fields on a Warden spec (loop_mode.gd): the mode and gun role, and the
# drop rules only where the stage's map has drop lines to hit it from (stage 1 in the
# lab), so a drop-mode run meets v2 Wardens on stages 2 and 3.
func _loop_spec(stage: int) -> Dictionary:
	var map = ctx.terrain.map_for(stage) if ctx.terrain != null and ctx.terrain.has_method("map_for") else null
	var lines: bool = map != null and "drop_lines" in map and not (map.drop_lines as Array).is_empty()
	var out := {"loop_mode": LoopMode.mode(ctx.tuning), "gun_role": LoopMode.gun_role(ctx.tuning),
		"drop_rules": LoopMode.is_drop(ctx.tuning) and lines,
		"drops": int(ctx.flow.stage_def().get("warden_drops", 4)),
		"cores": func() -> int: return int(ctx.run.bonus_cores) if ctx.run != null else 0,
		"gravity": ctx.tuning.f("gravity")}
	if lines and map.return_at != Vector2.INF:
		out["rebound_to"] = ctx.terrain.drop_point(map.return_at.x, map.return_at.y, 1.0)
		# Under `full` a drop throws the ball up the bank a quarter-turn from the return, so
		# the stagger is gunned from the bank before the ride.
		var side: Vector2 = (map.return_at - map.beacon).normalized().rotated(-PI * 0.5) * WardenDrop.STAGGER_PERCH
		out["perch_to"] = ctx.terrain.drop_point(map.beacon.x + side.x, map.beacon.y + side.y, 1.0)
	return out


func _spec_for(kind: String) -> Dictionary:
	var stage: int = ctx.flow.stage()
	match kind:
		"warden":
			var w := warden_spec(stage)
			w["stage"] = stage
			w["reach"] = float(ctx.flow.stage_def().get("beacon_radius", 30.0))
			w.merge(_loop_spec(stage))
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
	_warden_drops = 0
	_warden_slam_hits = 0
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
		var p: Resource = Weapons.base(weapon).transformed(ids)
		# Tree pattern ops land after the parts; the clarity caps hold whatever stacked.
		if ctx != null:
			for row in ctx.player.tree.pattern_ops(weapon):
				p._apply(row)
			p._clamp()
		_patterns[weapon] = p


static func _signal_argc(obj: Object, kind: String) -> int:
	for sig in obj.get_signal_list():
		if sig["name"] == kind:
			return sig["args"].size()
	return 0
