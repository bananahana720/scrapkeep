extends Node

const Chaser := preload("res://src/combat/chaser.gd")
const EnemyBase := preload("res://src/combat/enemy.gd")
const Lobber := preload("res://src/combat/lobber.gd")
const Miniboss := preload("res://src/combat/miniboss.gd")
const Rogue := preload("res://src/combat/rogue.gd")
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
const AbilityState := preload("res://src/core/ability_state.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const MindAttacks := preload("res://src/boss/mind_attacks.gd")
const Sticky := preload("res://src/combat/sticky.gd")
const Devices := preload("res://src/core/devices.gd")
const NearMiss := preload("res://src/combat/near_miss.gd")
const WayOutPaint := preload("res://src/presentation/way_out_paint.gd")
const Redline := preload("res://src/combat/redline.gd")
const Flail := preload("res://src/combat/flail.gd")
const Augments := preload("res://src/movement/augments.gd")
const Ultimate := preload("res://src/combat/ultimate.gd")
const KestKit := preload("res://src/combat/kest_kit.gd")
const Sight := preload("res://src/combat/sight.gd")
# v2 W7 enemies: the reinforcements, the ancients and their holds (fleet.gd).
const Fleet := preload("res://src/combat/fleet.gd")
const Dunk := preload("res://src/combat/dunk.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")
# The roster row fleet.gd's own reinforcement-pack system reads (M0's "adds" classification).
const Roster := preload("res://src/combat/roster.gd")
const RunTier := preload("res://src/core/run_tier.gd")
const EliteAffixes := preload("res://src/combat/elite_affixes.gd")
const SpecialCues := preload("res://src/combat/special_cues.gd")
const Companion := preload("res://src/core/companion.gd")
const DamageFamilies := preload("res://src/combat/damage_families.gd")
const DamageDoor := preload("res://src/combat/damage_door.gd")
const PackPressure := preload("res://src/combat/pack_pressure.gd")
const ChurnGround := preload("res://src/combat/churn_ground.gd")
const SiltBoil := preload("res://src/combat/silt_boil.gd")
const HazardHits := preload("res://src/world/events/hazard_hits.gd")

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
# from whatever plating_for answers, so the miniboss, vaults and Brindle's pieces shed
# (a Warden fights on posture and never sheds), and a weak point already at 0 stays 0.

const MUZZLE := 1.25
const AIM_SLACK := 14.0
const KINDS := ["chaser", "lobber", "miniboss", "warden", "vault"]
const CONTACT_KINDS := ["stomp", "ram", "slam"]
# SG1 arc mark (comps/gunfire/elements-and-fusion.md, shock +10% for 5 s, a start value): an
# "arc" strike marks its target for ARC_MARK_SECONDS, and while the mark holds every strike
# through the damage door deals 1 + ARC_MARK_FRACTION. The mark is its own entry kind in
# _exposed, read once in the door's caps stage (_strike_mult). The wear trail and primer-mesh
# shares bypass the door (_trail_deal), so the mark never raises them.
const ARC_MARK_FRACTION := 0.10
const ARC_MARK_SECONDS := 5.0
const ARC_MARK_KIND := "arc"
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
	{"warden_plating": 30.0, "warden_hp": 400.0},
	{"warden_plating": 60.0, "warden_hp": 700.0},
	{"warden_plating": 95.0, "warden_hp": 1000.0},
]
# The last stage's vault has no next Warden, so it sits this far above its own.
const VAULT_TOP_SCALE := 1.2
const MINIBOSS_PLATING_SCALE := 1.25
const SHELL_RETURN_DAMAGE := 40.0
const BAT_REACH := 2.4
const PARTING_WINDOW := 1.0
const CRUSH_WINDOW := 1.0
const CRUSH_CHAIN := 3
const SHRED_PER_PUNCH := 0.017
const SHRED_HOLD_DECAY := 0.05
const SHRED_REST_DECAY := 1.0
const SHRED_GRACE := 1.5
const SHRED_FLOOR := 0.5
# Companion ram-brace family: the prow's shove beats every INTERRUPT (10) once per foe per
# PROW_STAGGER s; a landed ram arms the spring for SPRING_WINDOW s and the next shot pays it.
const PROW_SHOVE := 12.0
const PROW_STAGGER := 0.8
const SPRING_WINDOW := 3.0
const SPRING_MULT := 1.5

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
# shell); drop_or_slam (the slam contact kind); special (a gauge release); item_proc (a build
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
# This stage attempt's damaging stomp and slam hits on the Warden. Reset every attempt
# (_start_attempt) and snapshotted into _ledger's warden_slam_hits on beacon_unsealed.
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
# object with of(stage) -> Dictionary; null reads the context's table.
var _warden_warned := {}
var stage_defs = null

var _patterns := {}
var _part_map := {}
var _cooldown := 0.0
var _overdrive := 0.0
var _since_slingshot := INF
var _crushes: Array = []
var _clock := 0.0
# A reel impact's mark on a body and how long a kill after it still counts as the reel's.
const REEL_MARK := "panel_reel_at"
const REEL_KILL_WINDOW := 0.25
# The strike whose facts are going out: {id, kind, force, part}, empty otherwise.
var _pending := {}
# Shred by enemy instance id: {amount, cap (the most plating it has shown), idle
# (seconds since its last landed hit)}.
var _shred := {}
# Linker guards (linker.gd): partner instance id -> the Linker whose dish braces over it.
var _guards := {}

# special_id -> {geometry: Callable(fraction) -> shape, fire: Callable(fraction, shape)}, or
# {tap: Callable() -> bool} for a row with no gauge.
var _specials := {}
# The line skill's dispatch table (built in setup) and the load waiting for the next bite:
# {} or {id, fraction, left}.
var _line_skills := {}
var _line_load := {}
# The last line skill that fired: {id, on, target, at, fraction, mult}. Read only outside.
var last_line := {}
var sticky
# The device ledger (devices.gd): per-kind caps, refills and the leash for sticky and mini
# charges and the Sentry Post. Cleared with the fight. Read only outside.
var devices
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
# Hulks (KNOCKBACK-FEEL): a body a ram or a pin killed keeps flying for a moment and bowls
# what lies ahead of it. {at, vel, radius, id, hit: {victim id: true}}; cleared each attempt.
var _hulks: Array = []
var pins := 0
# Upgrade-tree state (upgrade_tree.gd): each proc's next allowed time by node:fact, the
# pending special echo, marked targets (instance id -> clock the mark ends), the blink's
# smoke cloud, the Sentry Post, the timed-upgrade clock and how long the cloak has held.
var _proc_ready := {}
var _echo := {}
var _echoing := false
var _marks := {}
# Conductive-primer expiries by instance id (transient, never saved). Cleared on run start and every attempt; a kill drops its entry.
var _primed := {}
# Ram-brace state: prow stagger ends by instance id, and the clock the spring stays armed until. Both maps clear on run start and every attempt; a kill drops its entry.
var _prow_until := {}
var _spring_until := -1.0
# Escape corridor: the act in progress ({piece, style, until}) and the lane it laid ({from,
# dir, length, half_width, friction, hold, until}), both cleared on run start and stage entry.
# escape_acts counts acts this run, and escape_acted fires once per act.
signal escape_acted(piece: String, style: String)
# The companion's driver rows (Companion.DRIVERS); every module act asks Companion.pick()
# against this table, so a test or the lab can reorder rows without a code edit.
var drivers: Dictionary = Companion.DRIVERS
# COMPANION-GROWS: the assist gauge (0 to Companion.ASSIST_FULL) and the assists called this
# run. companion_assisted carries {id, name, word, cue, at, radius, knock, layers, hits,
# mark}; companion_body.gd shows it. The gauge clears on run start and every attempt.
signal companion_assisted(assist: Dictionary)
signal companion_assist_full
# A swung or thrown body (flail_hit) landed on `enemy`, whatever path the hit then takes: a
# Warden's posture path never emits enemy_struck, so Called Shot reads BOWL from this.
signal flung(enemy: Node3D)
var assist_charge := 0.0
var assists := 0
var last_assist := {}
var escape_acts := 0
var escape_lane := {}
var _escape := {}
# Tarn's clamp: caught enemies (instance id -> clock the clamp ends) take CLAMP_BONUS from claw sweeps. Cleared on run start and every attempt; a kill drops its entry.
var _clamped := {}
# The remembered cannon: committed volleys ({family, hazards, damage, source, struck,
# expose, verb, window, and the commit's seed, target, centre, radius and phase}), how many it has committed (its seed counter),
# and plate-exposed enemies (instance id -> {until, verb}) that take MindAttacks.BRACE_MULT
# from any contact strike. _exposed clears on run start and every attempt; a kill drops its entry.
# SG1's arc mark rides the same table under _arc_key(id) ({kind, id, until, window, radius,
# mark}), so a plate row and an arc row on one enemy never collide.
var _cannon := []
var _cannon_count := 0
var _exposed := {}
# Tally's program cards. bay is the selected card (0, 1 or 2); plate is Gather's plate ({}
# or {"at", "until"}); link_group the live clips ({} or {"ids", "until", "spent"}); last_card
# the last run ({"card", "at", "hits", "spent"}). All read only outside this file.
var bay := 0
var plate := {}
var link_group := {}
var last_card := {}
var _cards := {}
var _arcing := false
var _gather_tick := 0.0
var _roll_clock := 0.0
var _restored_frame := {}
# Tally's wave P-C state (pilots/tally.md sections 2 and 3). clip_post is the world-latch post
# ({} or {at, until, shape}); tally_piece the set piece riding (one of TALLY_PIECES, or "");
# ride_clips the enemies clipped this ride (instance id -> true); tally_last_settle the last
# landing ({at, hits, settles, ids}); all read only outside. The run and stage counters feed the
# eyeshade and punch tape discoveries, and _tally_cards queues her codex cards behind the
# framework card they extend (B6's rule), one card per tick.
const TALLY_PIECES := ["plate_return", "plate_audit", "plate_flywheel"]
# The discoveries behind her three grants (CUSTOMIZE section 8): ledger clips fired in one
# stage, clips one landing settles, clips settled in one run.
const PUNCH_TAPE_CASTS := 10
const BOOKS_SETTLES := 6
const EYESHADE_SETTLES := 20
var clip_post := {}
var tally_piece := ""
var ride_clips := {}
var tally_last_settle := {}
var _fly_plates: Array = []
var _fly_pulled := false
var _run_settles := 0
var _stage_clip_casts := 0
var _tally_cards := {}
var _tally_card_frame := -1
# The dodge read (near_miss.gd), and the last hit the ball took: where it came from, for
# presentation's edge flash. last_impact names the IMPACT row and the enemy of the strike
# whose enemy_struck is out right now, because a blast publishes under a gun kind; it is
# empty outside that emission and for a strike that names no row. All read only.
var near_miss
var flail
# The set piece on Q (ultimate.gd), a child like near_miss; it owns the meter.
var ultimate
# The active slot on F (src/combat/actives), behind --actives.
var actives
var last_player_hit := {}
var _hit_attack := ""
var last_impact := {}
var _cloud := {}
var _sentry := {}
var _pulse_left := 0.0
var _cloak_held := 0.0
# UpgradeTree.ACTIONS name -> Callable(scale).
var _actions := {}
# SR1: every strike passes this door (damage_door.gd), which runs the stages below in its
# declared order and then its hooks; the primer mesh and the companion ram ride as "hit" hooks.
var door := DamageDoor.new()
# The world 1 pack pressure experiments (pack_pressure.gd): chasers spawned under a flank dial, every second
# one a flanker; the churned silt (idle at its identity dial) and the silt boils (on in world 1).
var _pressure_chasers := 0
var churn
var boils
var _strike_stages := {}


func _init() -> void:
	_strike_stages = {"armour": _door_armour, "caps": _door_caps, "crit": _door_crit,
		"announce": _door_announce, "plates": _door_plates, "health": _door_health,
		"execute": _door_execute, "events": _door_events}
	door.hook("hit", "primer_mesh", _hook_primer_mesh)
	door.hook("hit", "companion_ram", _hook_companion_ram)
	door.hook("hit", "companion_assist", _hook_companion_assist)


func _stage_table():
	return stage_defs if stage_defs != null else ctx.stages


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
	devices = Devices.new()
	sticky.ledger = devices
	wear_trail = WearTrail.new()
	wear_trail.setup(ctx, effects, _floor_at)
	wear_trail.deal = _trail_deal
	churn = ChurnGround.new()
	churn.setup(ctx)
	boils = SiltBoil.new()
	boils.setup(ctx, ground)
	boils.deal = func(amount: float, shove: Vector3): _on_player_hit(amount, shove, "silt_boil")
	near_miss = NearMiss.new()
	add_child(near_miss)
	flail = Flail.new()
	flail.name = "Flail"
	add_child(flail)
	flail.setup(ctx, self)
	near_miss.setup(ctx.events, Callable(ctx.player, "ball_position"))
	# The way out of the warning the ball stands in, painted on the floor (W1-05).
	var way_out := WayOutPaint.new()
	near_miss.add_child(way_out)
	way_out.setup(near_miss, Callable(ctx.player, "ball_position"), Callable(ground, "height"))
	_wire_redline()
	_specials = {
		"detonation_gauge": {"geometry": _discharge_geometry, "fire": _fire_discharge},
		"overdrive_blast": {"geometry": _overdrive_geometry, "fire": _fire_overdrive},
		"detonation_line": {"geometry": _line_geometry, "fire": _fire_line},
		"point_blank": {"geometry": _point_blank_geometry, "fire": _fire_point_blank},
		"clamp": {"geometry": _clamp_geometry, "fire": _fire_clamp},
		"cannon_plate": {"geometry": _plate_geometry, "fire": _fire_plate},
		"gather_plate": {"tap": _tap_gather, "commit": _card_aim},
	}
	# line_id -> {on_body: Callable(target, fraction, chain_mult), on_world: Callable(anchor,
	# fraction, chain_mult), geometry: Callable(fraction)} (SKILL-BAR section 7). Each pilot owns
	# one marked block for its wave P-C row (section 12, item 4).
	_line_skills = {
		"line_reel": {"on_body": _line_reel_body, "on_world": _reel_burst, "geometry": _line_reel_geometry},
		# --- P-C Sable line skill ---
		"bank_shot": {"on_body": _bank_body, "on_world": _bank_world, "geometry": _bank_geometry},
		# --- end Sable ---
		# --- P-C Rivet line skill ---
		"line_drive": preload("res://src/combat/rivet_kit.gd").line_row(self),
		# --- end Rivet ---
		# --- P-C Kest line skill ---
		"cable_charge": KestKit.line_row(self),
		# --- end Kest ---
		# --- P-C Tarn line skill ---
		"claw_drag": preload("res://src/combat/tarn_claw.gd").line_row(self),
		# --- end Tarn ---
		# --- P-C Tally line skill ---
		"link_clips": {"on_body": _link_clips_body, "on_world": _link_clips_world, "geometry": _clip_geometry},
		# --- end Tally ---
		# --- P-C Cannon line skill ---
		"cannon_lane_charge": {"on_body": _cannon_line_body, "on_world": _cannon_line_world, "geometry": _cannon_line_geometry},
		# --- end Cannon ---
	}
	ctx.player.line_load_of = line_load
	# The set piece (SKILL-BAR section 4) and the shared placeholder every pilot carries until
	# wave P-C: paths line then arc, a volley of the pilot's own weapon per beat, the default
	# landing. A pilot's own row goes in its marked block in ultimate.gd's _ult_rows.
	ultimate = KestKit.new()
	add_child(ultimate)
	ultimate.setup(ctx, self)
	ultimate.register("ult_default", {"tech": _ult_volley, "peak": _ult_peak, "landing": _ult_landing})
	actives = preload("res://src/combat/actives/active_rack.gd").new()
	add_child(actives)
	actives.setup(ctx, self)
	# A loaded line skill rides the next bite, body or world (grapple_fired goes out for both,
	# after the latch is set). A reset point drops the load.
	ctx.events.grapple_fired.connect(func(_anchor: Vector3): _bite_load())
	ctx.events.player_died.connect(func(): _line_load = {})
	ctx.events.stage_content_cleared.connect(func(_reason: String): _line_load = {})
	_cards = {"balance_due": _run_balance}
	ctx.events.enemy_struck.connect(_on_card_struck)
	ctx.events.harpoon_smashed.connect(func(_enemy: Node3D, _at: Vector3, _speed: float): _grant_pressure(1))
	ctx.events.slammed.connect(func(_at: Vector3, _strength: float, _flatness: float):
		if ctx.player.abilities.cap(AbilityState.SMASH, "flavour", "") != "stamp":
			_grant_pressure(1))
	_wire_tally()
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
	ctx.events.slammed.connect(_on_cannon_slammed)
	ctx.events.dashed.connect(_on_cannon_dashed)
	ctx.events.dismounted.connect(_on_dismounted_sentry)
	ctx.events.tree_picked.connect(func(_c: String, _n: String, _d: int): _rebuild_patterns())
	ctx.player.heft_of = heft
	ctx.player.pressure_grant = _grant_pressure
	ctx.player.hulk_launch = bowl_hulk
	ctx.player.mass_of = func() -> float: return ctx.run.mass
	_reset_ledger()
	ctx.events.demo_slammed.connect(_on_demo_slammed)
	ctx.events.arc_slammed.connect(func(at: Vector3, _faces: int): effects.ring(at, 12.0, ClassDef.SABLE_COLOR))
	ctx.events.skid_smashed.connect(func(at: Vector3, _hits: int): effects.ring(at, 4.0, ClassDef.RIVET_COLOR))
	ctx.events.blink_used.connect(_on_blink)
	ctx.events.line_state_changed.connect(_on_chain_state)
	ctx.events.stage_entered.connect(_on_stage_entered)
	ctx.events.escape_window.connect(func(_seconds: float): _escape_act())
	ctx.events.stage_content_cleared.connect(_on_stage_content_cleared)
	ctx.events.run_ended.connect(func(_won: bool): _clear_devices())
	ctx.events.run_started.connect(func(_class_id: String):
		churn.reset(true)
		boils.reset(true)
		_armour_known = {}
		discovered = {}
		discovery_log = []
		_proc_ready = {}
		_echo = {}
		_marks = {}
		_primed = {}
		assist_charge = 0.0
		assists = 0
		last_assist = {}
		_prow_until = {}
		_clamped = {}
		_escape = {}
		escape_lane = {}
		escape_acts = 0
		_free_cannon()
		_cannon_count = 0
		_exposed = {}
		_reset_cards()
		_line_load = {}
		_cloud = {}
		_sentry = {}
		_pulse_left = 0.0
		_boss_add_ids = {}
		_reset_ledger()
		_rebuild_patterns())
	ctx.events.beacon_unsealed.connect(func(stage: int):
		_ledger["warden_slam_hits"][str(stage)] = _warden_slam_hits
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
# `health_scale` multiplies the health the enemy would otherwise spawn with (the survival yard's later counts).
func spawn_enemy(kind: String, at: Vector3, affix_id := "", perch := Vector3.INF, health_scale: float = 1.0) -> Node3D:
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
		_ when Rogue.ROWS.has(kind):
			enemy = Rogue.new()
		_ when fleet.makes(kind):
			enemy = fleet.make(kind)
		_:
			push_warning("spawn_enemy: unknown kind '%s', spawning a chaser" % kind)
			kind = "chaser"
			enemy = Chaser.new()
	# Placed before it joins the tree, so its body enters the physics space where it stands.
	# Jolt reads a kinematic body moved after that as a velocity over the next step: one moved
	# from the world origin to `at` shoved a ball rolling at the origin out at 500 m/s
	# (item_fuzz seed 2751, 243.9 m/s against the 60 m/s ceiling).
	enemy.position = ctx.root.global_transform.affine_inverse() * at
	ctx.root.add_child(enemy)
	# M0 (review fix round 1, finding 2): the only spawner call reachable while the boss
	# arena is up is boss.gd's own drone drop, so a spawn landing here is a boss add, not
	# an ordinary field enemy, whatever kind string it uses (currently always "lobber").
	if ctx.flow != null and ctx.flow.in_arena:
		_boss_add_ids[enemy.get_instance_id()] = true
	# Fodder sees the player through its sight, which Kest's cloak can fool; the Warden
	# and the vault are set pieces and always see the ball.
	var target = Sight.new(ctx.player, self, enemy, kind) if Sight.REACH.has(kind) or fleet.makes(kind) else ctx.player
	var health := _threat()
	var enemy_spec: Dictionary = fleet.dress(kind, _spec_for(kind))
	if kind == "lobber" and ctx.flow.in_stage():
		enemy_spec["lead"] = ChallengeDials.by_stage_or("mobs.lobber_lead_by_stage", ctx.flow.stage(), Lobber.LEAD)
	if affix_id == EliteAffixes.PLATED:
		enemy_spec["armour"] = EliteAffixes.PLATED
	# A park perch top (terrain.perch_near) is the Dispatcher's spec["perch"]; with none it builds its own mast.
	if kind == "dispatcher" and perch.is_finite():
		enemy_spec["perch"] = perch
	if kind not in ["warden", "vault"]:
		var director = _director()
		if director != null:
			health = director.hp_scale()
			enemy_spec["rest_scale"] = director.rest_scale()
		if director != null and director.run_tier() >= 1:
			enemy_spec["stage_threat"] = _threat()
			if kind == "plated_brute" and director.run_tier() >= RunTier.HARD and not EliteAffixes.row(affix_id).is_empty():
				enemy_spec.merge(RunTier.row(director.run_tier()).elite_stats, true)
				enemy_spec["affix"] = affix_id
				enemy_spec["affix_world"] = director.world
		var pressure := PackPressure.crew_row(int(ctx.run.stage))
		if ctx.flow.in_stage() and (pressure.lead > 0.0 or pressure.rest != 1.0 or pressure.flank > 0.0):
			if kind == "chaser" and pressure.flank > 0.0:
				_pressure_chasers += 1
				pressure["flanker"] = _pressure_chasers % 2 == 0
			enemy_spec["pressure"] = pressure
		# A chaser runs at its stage's speed (ChallengeDials mobs.chaser_speed_by_stage); boss adds keep their own.
		if kind == "chaser" and ctx.flow.in_stage():
			enemy_spec["run_speed"] = Chaser.stage_speed(int(ctx.run.stage))
	enemy.setup(target, ground, ctx.root, Callable(ctx.flow, "in_play"), health * health_scale, enemy_spec)
	# The vault and the Warden settle onto the ground or their landmark anchor in setup.
	if enemy is CollisionObject3D and not enemy.global_position.is_equal_approx(at):
		_reenter_space(enemy)
	# Poles and flails weigh a body by its stage threat, as the trap ratings do (movement/grip.gd).
	if "threat_level" in enemy:
		enemy.threat_level = _threat()
	# A body with more than one attack says which one landed (miniboss.gd, rogue.gd); connected
	# first, so _on_player_hit files it on last_player_hit for the RUN OVER cause line.
	if "landed_attack" in enemy:
		enemy.hit_player.connect(func(_amount: float, _shove: Vector3): _hit_attack = String(enemy.landed_attack))
	enemy.hit_player.connect(_on_player_hit.bind(kind))
	if enemy.has_signal("counter_hit"):
		enemy.counter_hit.connect(_on_player_hit.bind("warden_counter"))
	enemy.died.connect(func(where: Vector3, scrap: int):
		var source: String = enemy.last_damage_source if "last_damage_source" in enemy else ""
		if enemy.has_meta(HazardHits.STRUCK):
			source = "hazard"
		# A fuse death is an enemy spent by its own blast (splitter_pod.gd): nobody killed it.
		if source != "fuse":
			ctx.run.kill_tags = _kill_tags(enemy, affix_id)
			ctx.run.record_kill(kind, where, scrap, source)
		var id := enemy.get_instance_id()
		_primed.erase(id)
		_prow_until.erase(id)
		_record_retirement(_class_for_id(id, kind))
		_clamped.erase(id)
		_exposed.erase(id)
		_exposed.erase(_arc_key(id))
		_boss_add_ids.erase(id))
	if enemy.has_signal("fired"):
		enemy.fired.connect(_on_lobber_fired.bind(enemy))
	# A kill-first special gets its special_tell signal before its listeners hear it arrive.
	SpecialCues.attach(enemy)
	ctx.events.enemy_spawned.emit(enemy, kind)
	fleet.on_spawned(enemy, kind)
	return enemy


# A body moved after it entered the space would push what stands at its old spot along the
# move; leaving the space and entering it again at the new transform places it with no push.
static func _reenter_space(body: CollisionObject3D) -> void:
	var rid := body.get_rid()
	var space := PhysicsServer3D.body_get_space(rid)
	PhysicsServer3D.body_set_space(rid, RID())
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, body.global_transform)
	PhysicsServer3D.body_set_space(rid, space)


# What a kill was, for the panel drop (build.gd): an elite-pack member or an affixed elite,
# a jackpot when a reel impact or dunk struck it inside REEL_KILL_WINDOW, and a yard lock's crew
# (stage_locks.gd), which the cleared yard pays for instead.
func _kill_tags(enemy: Node3D, affix_id: String) -> Dictionary:
	var reel_at = enemy.get_meta(REEL_MARK) if enemy.has_meta(REEL_MARK) else null
	return {"elite": bool(enemy.get_meta("elite_pack", false)) or affix_id != "",
		"jackpot": reel_at != null and _clock - float(reel_at) <= REEL_KILL_WINDOW,
		"yard": bool(enemy.get_meta("yard_crew", false))}


# What the director weights reinforcement packs against (fleet.gd build_read).
func build_read() -> Dictionary:
	return fleet.build_read()


# A hit the spine or a weapon made, resolved into damage exactly once. The bus facts go
# out before the damage so a kill never publishes a freed node: enemy_struck always,
# then strike_deflected when the punch fell short of the plating. `part` names a weak
# point ("" for the body; a ball contact finds its own through contact_part()).
func strike(enemy: Node3D, kind: String, force: float, part := "", source := "", impact := "") -> void:
	if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
		return
	if enemy.has_method("is_dead") and enemy.is_dead():
		return
	# The ball's own contacts while the set piece rides count under its 45-posture cap on a
	# closed Warden guard, volleys and landing together (SKILL-BAR section 12, item 7).
	if ultimate != null and ultimate.active() and kind in CONTACT_KINDS and enemy.has_method("_apply_posture") \
			and enemy.has_method("staggered") and not enemy.staggered():
		ultimate.warden_posture(enemy, resolve(enemy, kind, force, part, 0.0,
			panel_punch(kind, _classify_source(kind, source if source != "" else _forced_source))))
		return
	var dunk := _dunk_bonus(enemy, kind)
	# A reel impact or a dunk marks the body, so a kill it lands is a jackpot (grey panels).
	if ctx != null and ctx.player != null and ctx.player.get("kit") != null and \
			(dunk > 0.0 or is_reel_impact(kind, ctx.player.smash_landing == enemy)):
		enemy.set_meta(REEL_MARK, _clock)
	door.pass_hit({"enemy": enemy, "kind": kind, "force": force, "part": part, "source": source,
		"impact": impact, "dunk": dunk}, _strike_stages)


# --- SR1: strike()'s stages, in damage_door.gd's ORDER --------------------------------

func _door_armour(hit: Dictionary) -> void:
	hit["cls"] = _classify_source(hit["kind"], hit["source"] if hit["source"] != "" else _forced_source)
	hit["bonus"] = panel_punch(hit["kind"], hit["cls"])
	hit["result"] = resolve(hit["enemy"], hit["kind"], hit["force"], hit["part"], hit["dunk"], hit["bonus"])
	if hit["dunk"] > 0.0 and bool(hit["result"].get("guarded", false)):
		hit["dunk"] = 0.0
		hit["result"] = resolve(hit["enemy"], hit["kind"], hit["force"], hit["part"], 0.0, hit["bonus"])


func _door_caps(hit: Dictionary) -> void:
	var enemy: Node3D = hit["enemy"]
	var result: Dictionary = hit["result"]
	# The plating rule's figure before the multipliers: the crit read compares this to the punch,
	# so an arc mark or a weak armour read alone is not a crit (damage_numbers.gd is_crit).
	result["base_dealt"] = float(result["dealt"])
	result["dealt"] = float(result["dealt"]) * _strike_mult(enemy, hit["kind"], hit["cls"])
	_read_armour(enemy, hit, result)
	if enemy.has_method("absorbs_hit") and enemy.absorbs_hit(result):
		result["absorbed"] = true
	# An absorbed hit (a miniboss turn, a popped plate, a crew fitter) bites nothing, so the
	# charge stays held for the next reel, unless the charge did the work: a plate the plain
	# reel would only chip, popped because the stored slam lifted the reel over the plating.
	if hit["dunk"] > 0.0:
		if bool(result.get("absorbed", false)) and enemy.absorbs_hit(
				resolve(enemy, hit["kind"], hit["force"], hit["part"], 0.0, hit["bonus"])):
			hit["dunk"] = 0.0
		else:
			ctx.player.dunk.spend(enemy)
			result["dunk"] = hit["dunk"]
	if hit["kind"] in CONTACT_KINDS and _exposed.has(enemy.get_instance_id()) \
			and float(_exposed[enemy.get_instance_id()]["until"]) <= _clock:
		_exposed.erase(enemy.get_instance_id())
	# SG1: the mark was read above, so the hit that sets or refreshes it is never raised by
	# its own mark.
	if hit["kind"] == ARC_MARK_KIND:
		_arc_mark(enemy)


# The dunk charge (dunk.gd) pays on a reel impact on the body the line bit: the stored slam
# damage joins the hit's punch, so it meets the same plating, chip, weak point and armour
# rules as the reel it rides on. Read here, spent in _door_caps once the hit is known to be
# neither guard-blocked nor absorbed; knockback and the struck force are untouched.
func _dunk_bonus(enemy: Node3D, kind: String) -> float:
	if ctx == null or ctx.player == null or not ctx.player.get("dunk"):
		return 0.0
	var smash: bool = ctx.player.smash_landing == enemy
	var kit = ctx.player.kit
	# A reel impact is a smash landing, or a stomp, ram or slam while (or just after) a
	# right-mouse reel hauls the ball onto this body.
	var reeled: bool = kind in ["stomp", "ram", "slam"] and kit.reel_body == enemy and kit.reel_left > 0.0
	if not reeled and (not is_reel_impact(kind, smash) or not (smash or kit.anchor_body == enemy)):
		return 0.0
	return ctx.player.dunk.peek()


# The reel test punch_of's winch branch already uses (a smash landing counts as hooked: the
# landing lets the line go before its strikes resolve), shared with the dunk charge.
func is_reel_impact(kind: String, smash: bool) -> bool:
	var kit = ctx.player.kit
	return Dunk.is_reel_impact(kind, smash, kit.hooked, kit.winching)


# Damage families (DamageFamilies, FIELDS-AND-CASTS section 6): a hit that beat the plating
# meets its target's armour row, resisted about 60% and weak about 150%. The read rides on the
# target as meta "armour_read" for this hit's enemy_struck listeners (presentation stamps DENT
# or ZZAP! on the first of each per run), and the first read of an armour class discovers its
# codex entry, after which the class wears its icon.


func _read_armour(enemy: Node3D, hit: Dictionary, result: Dictionary) -> void:
	var armour := DamageFamilies.armour_of(enemy)
	var read := DamageFamilies.verdict(armour, hit["kind"], hit["cls"]) if bool(result.get("full", false)) else ""
	enemy.set_meta("armour_read", read)
	if read == "":
		return
	result["dealt"] = float(result["dealt"]) * DamageFamilies.mult(armour, hit["kind"], hit["cls"])
	result["read"] = read
	if _armour_known.has(armour):
		return
	_armour_known[armour] = true
	match armour:
		"plated":
			_discover("armour_plated", enemy.global_position)
		"wet":
			_discover("armour_wet", enemy.global_position)


func _door_crit(hit: Dictionary) -> void:
	hit["spent"] = _primer_hit(hit["enemy"], hit["kind"], hit["cls"])


# review finding 1, fix round 2: a Brindle piece's hp is a getter over the boss's one
# shared pool (boss_target.gd), and a listener on enemy_struck can remove HP from that
# pool synchronously (boss.gd's _on_enemy_struck -> _defeat, the scooter catch) before
# take_damage() ever runs. hp_before is read before the emit so the health stage's
# measure (DamageDoor.health) catches that removal too.
func _door_announce(hit: Dictionary) -> void:
	var enemy: Node3D = hit["enemy"]
	var kind: String = hit["kind"]
	var force: float = hit["force"]
	var result: Dictionary = hit["result"]
	hit["at"] = enemy.global_position
	hit["id"] = enemy.get_instance_id()
	_detect_before(enemy, kind, result)
	var outer := _pending
	_pending = {"id": enemy.get_instance_id(), "kind": kind, "force": force, "part": result["part"], "dunk": hit["dunk"],
		"bonus": hit["bonus"], "result": result}
	hit["hp_before"] = _hp_of(enemy)
	var outer_impact := last_impact
	last_impact = {"key": hit["impact"], "enemy": enemy.get_instance_id()} if hit["impact"] != "" else {}
	ctx.events.enemy_struck.emit(enemy, kind, force)
	last_impact = outer_impact
	if not result["full"]:
		deflections += 1
		ctx.events.strike_deflected.emit(enemy, kind, result["punch"], result["plating"])
	_pending = outer


func _door_plates(hit: Dictionary) -> void:
	var enemy: Node3D = hit["enemy"]
	var result: Dictionary = hit["result"]
	if enemy.has_method("on_struck"):
		enemy.on_struck(hit["kind"], result["part"], result)
	# Counted before take_damage() because a killing hit unseals the stage
	# (beacon_unsealed, which snapshots this count) inside it.
	if hit["kind"] in ["stomp", "slam"] and float(result["dealt"]) > 0.0 and _target_class(enemy) == "Warden":
		_warden_slam_hits += 1


func _door_health(hit: Dictionary) -> void:
	hit["removed"] = DamageDoor.health(hit["enemy"], hit["result"]["dealt"], hit["hp_before"])


func _door_execute(hit: Dictionary) -> void:
	hit["killed"] = DamageDoor.dead(hit["enemy"])


func _door_events(hit: Dictionary) -> void:
	var enemy: Node3D = hit["enemy"]
	var result: Dictionary = hit["result"]
	if result.get("shred", true):
		_add_shred(enemy, result["punch"])
	_detect_after(enemy, hit["kind"], result)
	_record_delivered(enemy, hit["kind"], hit["removed"], result["dealt"],
		hit["source"] if hit["source"] != "" else _forced_source)


func _hook_primer_mesh(hit: Dictionary) -> void:
	if hit["spent"] == "primer_mesh":
		_primer_mesh(hit["at"], hit["id"], float(hit["result"]["dealt"]))


func _hook_companion_ram(hit: Dictionary) -> void:
	_companion_ram(hit["enemy"], hit["kind"], hit["result"])


# --- Companion: the assist (companion.gd ASSIST_*) ----------------------------------
# A hit that removed HP fills the gauge; a ram with the gauge full calls the assist at the
# struck foe. The assist deals through _trail_deal, so it takes no door pass, fires no hook
# and never refills the gauge. Posture fighters keep their own rules and are left out.
func _hook_companion_assist(hit: Dictionary) -> void:
	if ctx.run.companion.is_empty() or float(hit["result"].get("dealt", 0.0)) <= 0.0:
		return
	if is_instance_valid(hit["enemy"]) and _fights_posture(hit["enemy"]):
		return
	var kind: String = hit["kind"]
	if kind == Companion.ASSIST_TRIGGER and assist_ready():
		_call_assist(hit["at"], float(hit["result"]["dealt"]))
		return
	_charge_assist(kind)


func _charge_assist(kind: String) -> void:
	if ctx.run.companion.is_empty():
		return
	var was := assist_ready()
	assist_charge = Companion.assist_charge(assist_charge, kind)
	if assist_ready() and not was:
		companion_assist_full.emit()


func assist_ready() -> bool:
	return assist_charge >= Companion.ASSIST_FULL


# 0 to 1, for the halo.
func assist_fill() -> float:
	return clampf(assist_charge / Companion.ASSIST_FULL, 0.0, 1.0)


func _call_assist(at: Vector3, dealt: float) -> void:
	var sockets: Array = ctx.run.companion.get("sockets", [])
	var row := Companion.assist_of(sockets)
	var heft: int = ctx.run.heft_class() if ctx.run.has_method("heft_class") else 1
	var power := Companion.assist_power(heft)
	var radius: float = power["radius"]
	var ball: Vector3 = ctx.player.ball_position()
	var travel: Vector3 = ctx.player.planar_velocity()
	travel.y = 0.0
	var dir := travel.normalized() if travel.length_squared() > 0.01 else (at - ball).normalized()
	if dir.length_squared() < 0.01:
		dir = Vector3.FORWARD
	var damage := maxf(dealt, Companion.ASSIST_DAMAGE_FLOOR)
	# Spent before any damage, so nothing a kill sets off can call it twice.
	assist_charge = 0.0
	assists += 1
	var struck := _assist_targets(row["shape"], at, ball, dir, radius)
	for enemy in struck:
		_trail_deal(enemy, damage, "companion_assist", "item_proc")
		if DamageDoor.dead(enemy):
			continue
		if row["prime"]:
			_primed[enemy.get_instance_id()] = _clock + Companion.PRIMER_SECONDS
		if row["shove"] and enemy.has_method("knock"):
			var flat: Vector3 = enemy.global_position - (ball if row["shape"] == "lane" else at)
			flat.y = 0.0
			var away := flat.normalized() if flat.length_squared() > 0.0001 else dir
			var weight = enemy.get("weight")
			enemy.knock(away + Vector3.UP * 0.35, Companion.ASSIST_KNOCK * float(power["knock"]) * (float(weight) if weight != null else 1.0))
	if row["slick"] and (escape_lane.is_empty() or _clock >= float(escape_lane["until"])):
		escape_lane = {"from": ball, "dir": dir, "length": radius * 2.0, "half_width": Companion.ESCAPE_LANE_HALF_WIDTH,
			"friction": Companion.ESCAPE_LANE_FRICTION, "hold": maxf(travel.dot(dir), Companion.ESCAPE_LANE_FLOOR),
			"until": _clock + Companion.ASSIST_SLICK_SECONDS}
	if row["shape"] == "lane":
		effects.arc(ball, ball + dir * radius * 2.0, Palette.VERDIGRIS)
	else:
		effects.ring(at, radius, Palette.VERDIGRIS)
	last_assist = {"id": row["id"], "name": row["name"], "word": row["word"], "cue": row["cue"], "at": at,
		"radius": radius, "knock": power["knock"], "area": power["area"], "layers": power["layers"],
		"hits": struck.size(), "mark": int(Companion.mark_of(heft)["mark"])}
	companion_assisted.emit(last_assist)


# The foes an assist of this shape hits: the nearest one ("single"), every one within radius
# of at ("ring"), or every one in a lane from the ball along dir for twice the radius.
func _assist_targets(shape: String, at: Vector3, ball: Vector3, dir: Vector3, radius: float) -> Array:
	var found := []
	var nearest: Node3D = null
	var best := INF
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if DamageDoor.dead(enemy) or _fights_posture(enemy):
			continue
		var flat: Vector3 = enemy.global_position - at
		flat.y = 0.0
		match shape:
			"single":
				if flat.length() <= radius and flat.length() < best:
					best = flat.length()
					nearest = enemy
			"ring":
				if flat.length() <= radius:
					found.append(enemy)
			"lane":
				var rel: Vector3 = enemy.global_position - ball
				rel.y = 0.0
				var along := rel.dot(dir)
				if along >= 0.0 and along <= radius * 2.0 and (rel - dir * along).length() <= radius * Companion.ASSIST_LANE_HALF_WIDTH:
					found.append(enemy)
	if nearest != null:
		found.append(nearest)
	return found


# --- Companion: conductive primer (companion.gd PRIMER_*) ---------------------------
# A weapon hit primes; the next ball contact or special on a primed foe consumes it and
# returns the seated piece. Posture fighters, items and persistent actors never take part.

# The primer_coil's PRIMER_COIL_MULT is applied through _strike_mult, before this consumes
# the prime; _result stays for the companion tests that pass one and is not changed.
func _primer_hit(enemy: Node3D, kind: String, cls: String, _result := {}) -> String:
	var row := _primer_driver(enemy, kind, cls)
	var id := enemy.get_instance_id()
	match String(row.get("act", "")):
		"prime":
			var live: bool = float(_primed.get(id, -1.0)) > _clock
			_primed[id] = _clock + Companion.PRIMER_SECONDS
			if not live:
				effects.spark(enemy.global_position + Vector3.UP * 0.5, Palette.VERDIGRIS)
		"consume":
			_primed.erase(id)
			effects.arc(ctx.player.ball_position() + Vector3.UP * 0.5, enemy.global_position + Vector3.UP * 0.5, Palette.VERDIGRIS)
			return Companion.seated(ctx.run.companion, Companion.CONDUCTIVE_PRIMER)
	return ""


# The primer driver row a hit of this kind and source class picks on this enemy now, or {}.
# The trigger is "weapon" for a weapon hit, "contact" for a ball contact, "special" for a
# special, else "other". Posture fighters never take part.
func _primer_driver(enemy: Node3D, kind: String, cls: String) -> Dictionary:
	var piece := Companion.seated(ctx.run.companion, Companion.CONDUCTIVE_PRIMER)
	if piece == "" or _fights_posture(enemy):
		return {}
	var on := "weapon" if cls == "weapon" else ("contact" if kind in CONTACT_KINDS else ("special" if cls == "special" else "other"))
	return Companion.pick({"piece": piece, "on": on,
		"primed": float(_primed.get(enemy.get_instance_id(), -1.0)) > _clock}, drivers)


# The seated primer piece a hit of this kind and source class would consume on this
# enemy now, or "". Reads only; _primer_hit does the consuming.
func _primer_consumes(enemy: Node3D, kind: String, cls: String) -> String:
	if _primer_driver(enemy, kind, cls).get("act", "") != "consume":
		return ""
	return Companion.seated(ctx.run.companion, Companion.CONDUCTIVE_PRIMER)


# What strike() multiplies resolve()'s dealt by, beyond the plating rule: the cannon's
# plate exposure (any contact deals BRACE_MULT while the window holds; the damage scales,
# not the force, because a contact's punch is affine in its force), a seated primer
# coil consuming a live prime, and SG1's arc mark on every kind. Reads only, so would_crush() asks the same question the
# strike will answer (F005).
func _strike_mult(enemy: Node3D, kind: String, cls: String) -> float:
	var mult := 1.0
	if kind in CONTACT_KINDS and float(_exposed.get(enemy.get_instance_id(), {}).get("until", -INF)) > _clock:
		mult *= MindAttacks.BRACE_MULT
	if _primer_consumes(enemy, kind, cls) == "primer_coil":
		mult *= Companion.PRIMER_COIL_MULT
	if _arc_marked(enemy):
		mult *= 1.0 + ARC_MARK_FRACTION
	return mult


# Mesh shares go through _trail_deal, never strike(): no bus fact, no proc, no prime.
func _primer_mesh(at: Vector3, struck_id: int, dealt: float) -> void:
	var found := []
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.get_instance_id() == struck_id or enemy.is_dead() or _fights_posture(enemy):
			continue
		var distance: float = enemy.global_position.distance_to(at)
		if distance <= Companion.PRIMER_MESH_RANGE:
			found.append([distance, enemy])
	found.sort_custom(func(a, b): return a[0] < b[0])
	for i in mini(Companion.PRIMER_MESH_TARGETS, found.size()):
		var n: Node3D = found[i][1]
		effects.arc(at + Vector3.UP * 0.5, n.global_position + Vector3.UP * 0.5, Palette.VERDIGRIS)
		if n.has_method("flash"):
			n.flash()
		_trail_deal(n, dealt * Companion.PRIMER_MESH_SHARE, "primer_mesh", "item_proc")


func _fights_posture(enemy: Node3D) -> bool:
	return enemy.has_method("fight") and enemy.call("fight") == "posture"


func primed(enemy: Node3D) -> bool:
	return is_instance_valid(enemy) and float(_primed.get(enemy.get_instance_id(), -1.0)) > _clock


func primer_expired(enemy_id: int) -> bool:
	return _primed.has(enemy_id) and float(_primed[enemy_id]) <= _clock


# --- Companion: ram brace ------------------------------------------------------------
# Runs after the strike resolved and its facts went out; it shoves and arms, and never
# strikes, hits or fires itself. Posture fighters (staggered()) keep their own rules.
func _companion_ram(enemy: Node3D, kind: String, result: Dictionary) -> void:
	var piece := Companion.seated(ctx.run.companion, Companion.RAM_BRACE)
	if piece == "":
		return
	var valid := is_instance_valid(enemy)
	var free: bool = valid and not enemy.has_method("staggered") and not (enemy.has_method("is_dead") and enemy.is_dead())
	var row := Companion.pick({"piece": piece, "on": kind, "foe_free": free,
		"prow_ready": valid and _clock >= float(_prow_until.get(enemy.get_instance_id(), -1.0)),
		"dealt": float(result.get("dealt", 0.0)) > 0.0}, drivers)
	match String(row.get("act", "")):
		"shove":
			# A row edited to drop foe_free still never shoves a freed foe.
			if not valid:
				return
			_prow_until[enemy.get_instance_id()] = _clock + PROW_STAGGER
			var flat: Vector3 = enemy.global_position - ctx.player.ball_position()
			flat.y = 0.0
			var flat_dir: Vector3 = flat.normalized() if flat.length_squared() > 0.0001 else Vector3.FORWARD
			var weight = enemy.get("weight")
			if enemy.has_method("knock"):
				enemy.knock(flat_dir + Vector3.UP * 0.35, PROW_SHOVE * (float(weight) if weight != null else 1.0))
			effects.ring(enemy.global_position, 2.5, Palette.VERDIGRIS)
		"arm":
			_spring_until = _clock + SPRING_WINDOW
			effects.spark(ctx.player.ball_position(), Palette.VERDIGRIS)


# --- Companion: escape corridor ------------------------------------------------------
# Run state has just spent the charge and opened the window after a survived low-hull hit;
# this applies the seated piece's style. It adds velocity or a lane and never touches the
# hull, the retries or the charge itself. The hit direction comes from last_player_hit when
# that hit is this frame's, else the ball's own travel: no random draw.
func _escape_act() -> void:
	var piece := Companion.seated(ctx.run.companion, Companion.ESCAPE_CORRIDOR)
	var esc := Companion.escape_of(piece)
	var row := Companion.pick({"piece": piece, "on": "escape_window", "alive": ctx.run.alive()}, drivers)
	if esc.is_empty() or row.is_empty():
		return
	var style := String(row["act"])
	_escape = {"piece": piece, "style": style, "until": _clock + float(esc["seconds"])}
	var ball: Vector3 = ctx.player.ball_position()
	var v: Vector3 = ctx.player.planar_velocity()
	var speed := v.length()
	var away := Vector3.ZERO
	if not last_player_hit.is_empty() and int(last_player_hit.get("frame", -1)) == Engine.get_physics_frames():
		away = ball - Vector3(last_player_hit["from"])
		away.y = 0.0
	if away.length_squared() < 0.0001:
		away = v
	away = away.normalized() if away.length_squared() > 0.0001 else Vector3.FORWARD
	if style == "shove":
		var after := v + away * maxf(Companion.ESCAPE_SHOVE_FLOOR, speed * Companion.ESCAPE_SHOVE_SHARE)
		var cap := maxf(speed * Companion.ESCAPE_SHOVE_CAP, Companion.ESCAPE_SHOVE_FLOOR)
		if after.length() > cap:
			after = after.normalized() * cap
		if after.length() < speed:
			after = after.normalized() * speed
		ctx.player.add_external_accel((after - v) / get_physics_process_delta_time())
		effects.ring(ball, 2.0, Palette.VERDIGRIS)
	else:
		var dir := v.normalized() if speed > 1.0 else away
		escape_lane = {"from": ball, "dir": dir, "length": Companion.ESCAPE_LANE_LENGTH,
			"half_width": Companion.ESCAPE_LANE_HALF_WIDTH, "friction": Companion.ESCAPE_LANE_FRICTION,
			"hold": maxf(v.dot(dir), Companion.ESCAPE_LANE_FLOOR), "until": _escape["until"]}
		effects.arc(ball, ball + dir * Companion.ESCAPE_LANE_LENGTH, Palette.VERDIGRIS)
	escape_acts += 1
	escape_acted.emit(piece, style)


# Inside the lane the ball keeps its hold speed along it: each tick returns all but
# LANE_FRICTION of the shortfall. Leaving the lane, or its time running out, ends it.
func _step_escape_lane() -> void:
	if escape_lane.is_empty():
		return
	if _clock >= float(escape_lane["until"]):
		escape_lane = {}
		return
	var dir: Vector3 = escape_lane["dir"]
	var rel: Vector3 = ctx.player.ball_position() - Vector3(escape_lane["from"])
	rel.y = 0.0
	var along := rel.dot(dir)
	if along < -0.5 or along > float(escape_lane["length"]) or (rel - dir * along).length() > float(escape_lane["half_width"]):
		return
	var short: float = float(escape_lane["hold"]) - ctx.player.planar_velocity().dot(dir)
	if short > 0.0:
		ctx.player.add_external_accel(dir * short * (1.0 - float(escape_lane["friction"])) / get_physics_process_delta_time())


# "none" without a seated escape piece; "acting" for the act's seconds; then "spent" until a
# fresh stage re-arms the charge, else "ready".
func escape_phase() -> String:
	if Companion.seated(ctx.run.companion, Companion.ESCAPE_CORRIDOR) == "":
		return "none"
	if not _escape.is_empty() and _clock < float(_escape["until"]):
		return "acting"
	return "spent" if ctx.run.companion.get("escape_spent", false) == true else "ready"


func escape_style() -> String:
	return String(_escape.get("style", ""))


func prow_staggered(enemy: Node3D) -> bool:
	return is_instance_valid(enemy) and _clock < float(_prow_until.get(enemy.get_instance_id(), -1.0))


func spring_armed() -> bool:
	return _clock < _spring_until


# hp is not part of the enemy protocol (README.md), but every implementation carries it
# (enemy.gd's own var, boss_target.gd's getter over boss.hp); a target without one (the
# scenery-guard's plain Node3D, which never reaches here because it fails the
# has_method("take_damage") check above) reads 0.0 and never inflates a delta.
func _hp_of(enemy: Node3D) -> float:
	return DamageDoor.hp_of(enemy)


# --- M0: delivered-damage ledger (see the constants above for the categories) --------

func _record_delivered(enemy: Node3D, kind: String, removed: float, dealt: float, raw_source: String, known_class := "") -> void:
	if _ledger.is_empty():
		_reset_ledger()
	var source := _classify_source(kind, raw_source)
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
func _trail_deal(enemy: Node3D, amount: float, action := "spark", source := "persistent_actor") -> float:
	var target_class := _target_class(enemy)
	# Same measure as strike()'s health stage: a Brindle piece's return value undercounts (M0
	# delivered damage). The bypass takes no door pass and fires no door hook.
	var removed := DamageDoor.health(enemy, amount, _hp_of(enemy))
	_record_delivered(enemy, action, removed, amount, source, target_class)
	return removed


func _record_retirement(target_class: String) -> void:
	if _ledger.is_empty():
		_reset_ledger()
	_ledger["retirements"][target_class] = int(_ledger["retirements"].get(target_class, 0)) + 1


static func _bump(map: Dictionary, key: String, amount: float) -> void:
	map[key] = float(map.get(key, 0.0)) + amount


func _classify_source(kind: String, explicit: String) -> String:
	if explicit != "":
		return explicit
	if kind == SYNERGY:
		return "item_proc"
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
	if Roster.is_boss_piece(kind):
		return "boss"
	# The vault (roster.gd role "cache") never moves and never attacks (vault.gd's own
	# header); it is the one static, non-combatant damageable in the game, so it earns
	# its own class rather than inflating "enemy" (finding 3, fix round 1).
	if kind == "vault":
		return "cache"
	if kind in KINDS or Rogue.ROWS.has(kind):
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
	# A special's spawn (roster_specials.gd "spawned") is an add, but not a reinforcement.
	# So is a world's own kind (a row with "world", e.g. drill_crew, boom_tender): the
	# director composes it into authored packs, never the reinforcement clock.
	if not Roster.is_reinforcement(kind) and not Roster.row(kind).has("priority") and not Roster.is_world_kind(kind):
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
		"retirements": {}, "warden_slam_hits": {},
	}
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
func resolve(enemy: Node3D, kind: String, force: float, part := "", dunk := 0.0, bonus := 0.0) -> Dictionary:
	if not _pending.is_empty() and _pending["id"] == enemy.get_instance_id() \
			and _pending["kind"] == kind and _pending["force"] == force:
		# Inside the strike's own announce the hit is settled: answer with its result after the
		# caps (strike multiplier, armour), so a damage number shows what the hit removes.
		if _pending.has("result") and (part == "" or part == _pending["part"]):
			return (_pending["result"] as Dictionary).duplicate()
		if part == "":
			part = _pending["part"]
		if dunk == 0.0:
			dunk = _pending["dunk"]
		bonus = maxf(bonus, float(_pending.get("bonus", 0.0)))
	if part == "" and kind in CONTACT_KINDS and enemy.has_method("contact_part"):
		part = enemy.contact_part(ctx.player.ball_position(), kind)
	if kind == SYNERGY:
		part = ""
	# The dunk's stored slam rides the punch, so every rule below treats it as part of the reel,
	# and so does a weapon hit's or a contact's panel punch (bonus, panel_punch).
	var punch := punch_of(kind, force) + dunk + bonus
	if enemy.has_method("fight") and enemy.fight() == "posture":
		var tier: int = SpeedTier.of(force, ctx.player.tuning.tier_cruise()) if kind == "ram" else 0
		var smash: bool = ctx.player.smash_landing == enemy
		# A judge that takes the part (warden.gd) meets plating_for(kind, part) (F004);
		# BossContract's judge_hit is four arguments, so a boss piece gets four.
		var judged: Dictionary = enemy.judge_hit(kind, punch, smash, tier, part) \
				if enemy.get_method_argument_count("judge_hit") >= 5 else enemy.judge_hit(kind, punch, smash, tier)
		if not judged.is_empty():
			# A reel impact, by the one reel test the dunk charge also reads (is_reel_impact).
			judged["reel"] = is_reel_impact(kind, smash)
			return judged
	var guard := guard_of(enemy)
	if guard != null and guard.blocks(kind):
		return {"punch": punch, "plating": guard.DISH_PLATING, "full": false, "dealt": 0.0, "part": part, "shred": false,
			"guarded": true}
	var reported: float = enemy.plating_for(kind, part) if enemy.has_method("plating_for") else 0.0
	var plating := maxf(0.0, reported - shred_of(enemy))
	var full := punch >= plating
	var mult: float = enemy.hit_mult(kind, part) if full and enemy.has_method("hit_mult") else 1.0
	var dealt := punch * mult if full else punch * CHIP
	return {"punch": punch, "plating": plating, "full": full, "dealt": dealt, "part": part}


# The Linker bracing a dish over this enemy, or null (linker.gd; blocks() decides each hit).
func guard_of(enemy: Node3D) -> Node3D:
	if enemy == null or not is_instance_valid(enemy):
		return null
	var linker = _guards.get(enemy.get_instance_id())
	if linker == null or not is_instance_valid(linker) or not linker.guarding(enemy):
		return null
	return linker


# One Linker per partner: a second asks and is refused while the first still holds it.
func guard(partner: Node3D, linker: Node3D) -> bool:
	var held = _guards.get(partner.get_instance_id())
	if held != null and held != linker and is_instance_valid(held) and held.holds_partner(partner):
		return false
	_guards[partner.get_instance_id()] = linker
	return true


func guard_holder(enemy: Node3D) -> Node3D:
	var held = _guards.get(enemy.get_instance_id())
	return held if held != null and is_instance_valid(held) and held.holds_partner(enemy) else null


func unguard(partner: Node3D, linker: Node3D) -> void:
	if partner == null or not is_instance_valid(partner):
		for id in _guards.keys():
			if _guards[id] == linker:
				_guards.erase(id)
		return
	if _guards.get(partner.get_instance_id()) == linker:
		_guards.erase(partner.get_instance_id())


# Punch for a hit of this kind and force: a ball contact scales with heft, a weapon hit
# is its damage.
func punch_of(kind: String, force: float) -> float:
	if STRIKE_DAMAGE.has(kind):
		var row: Array = STRIKE_DAMAGE[kind]
		var scale := 1.0
		if ctx != null and ctx.player.kit.sprinting:
			scale = _knob("sprint_punch")
		# Winch Ram: hauling in on the rope, you hit like a sprint.
		elif ctx != null and ctx.player.kit.hooked and ctx.player.kit.winching:
			scale = _knob("winch_punch")
		# Ram Bumper panels (the build's ram_force mod).
		if kind == "ram" and ctx != null and ctx.tuning != null:
			scale *= ctx.tuning.mod("ram_force")
		return (row[0] + force * row[1]) * heft() * scale
	return force


# Punch Rivet panels' flat damage (build.panel_punch) for a hit of this kind and source class:
# a weapon hit or the ball's own contact (the panel's "+damage per hit"); 0 for procs, for
# specials (an ultimate's punches strike as "ram" with source "special") and for actives,
# which read the build's punch_bonus themselves.
func panel_punch(kind: String, cls: String) -> float:
	if not (cls == "weapon" or (kind in CONTACT_KINDS and cls in ["ram_or_contact", "drop_or_slam"])):
		return 0.0
	var build = ctx.build if ctx != null else null
	if build == null or not build.has_method("panel_punch"):
		return 0.0
	return float(build.panel_punch())


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
	var shot: float = _patterns[weapon].damage * _damage_mod(weapon) + panel_punch("", "weapon") if _patterns.has(weapon) else 0.0
	return maxf(ram_punch_now(), shot)


# A ram at your planar speed, from CRUISE up; 0 below it. No weapon term: for a target
# only a ram can beat (a clash), this is the whole punch.
# The tier reads base cruise like resolve()'s ram tier (tier_cruise), so a cruise up never
# drops the preview below CRUISE (coordinator ruling 24 Oct, principle 5).
func ram_punch_now() -> float:
	var planar: float = ctx.player.planar_velocity().length()
	if SpeedTier.of(planar, ctx.player.tuning.tier_cruise()) < SpeedTier.CRUISE:
		return 0.0
	return punch_of("ram", planar) + panel_punch("ram", "ram_or_contact")


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


# Puts back all the plating hits have stripped off this enemy (foreman.gd's wipe).
func wipe_shred(enemy: Node3D) -> void:
	if not is_instance_valid(enemy):
		return
	_shred.erase(enemy.get_instance_id())
	_show_shred(enemy, 0.0)


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
	var cls := _classify_source(kind, _forced_source)
	var result := resolve(enemy, kind, force, "", 0.0, panel_punch(kind, cls))
	var dealt: float = float(result["dealt"]) * _strike_mult(enemy, kind, cls)
	# The armour read the strike will apply (_read_armour), asked without recording it (F005).
	if bool(result.get("full", false)):
		dealt *= DamageFamilies.mult(DamageFamilies.armour_of(enemy), kind, cls)
	return result["plating"] <= 0.0 and dealt >= enemy.hp


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
	if mounted_as != null and (ctx.player.kit.mounted or (_knob("air_turret") and not ctx.player.state.on_floor())):
		return mounted_as
	return weapon


# The discharge a given speed would fire right now, with the current parts.
func discharge_preview(speed: float) -> Dictionary:
	var p: Resource = _patterns[Weapons.PYLON_TURRET]
	var scale: float = p.damage * _damage_mod(Weapons.PYLON_TURRET) / Weapons.BASE[Weapons.PYLON_TURRET]["damage"]
	var burst := Weapons.burst(speed, p.burst_scale, scale)
	# Splash Skirt panels widen the ring the telegraph draws and the hit reads alike.
	burst["radius"] = float(burst["radius"]) + ctx.tuning.add("area_radius")
	return burst


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
	_step_escape_lane()
	var intent = ctx.player.intent
	var weapon := active_weapon()
	# Tally's reader runs cards, never bolts: this branch comes first so _fire never sees
	# the ledger_reader row, which exists only for _patterns and _damage_mod.
	if ctx.player.abilities.cap(AbilityState.WEAPON, "cards", null) != null:
		_step_cards(intent, delta)
	elif ctx.player.abilities.cap(AbilityState.WEAPON, "family", "") == "lane":
		if intent.fire_held and _cooldown <= 0.0 and _patterns.has(weapon):
			_fire_cannon_lane(weapon)
			_cooldown += 1.0 / _rate(weapon)
	elif ctx.player.abilities.cap(AbilityState.WEAPON, "lob", 0) > 0:
		_step_sticky_weapon(intent, delta)
	elif intent.fire_held and _cooldown <= 0.0 and _patterns.has(weapon):
		_fire(weapon)
		_cooldown += 1.0 / _rate(weapon)
	if not intent.fire_held:
		_cooldown = maxf(_cooldown, 0.0)
	_step_cast()
	_step_special(intent, delta)
	_step_line(intent, delta)
	_step_cannon(delta)
	var enemies := get_tree().get_nodes_in_group("enemy")
	var shells := get_tree().get_nodes_in_group("enemy_shot")
	var space: PhysicsDirectSpaceState3D = ctx.root.get_world_3d().direct_space_state
	bolts.step(delta, space, enemies, shells)
	for charge in sticky.step(delta, space, enemies):
		_detonate(charge)
	_step_devices(delta)
	wear_trail.step(delta, enemies)
	PackPressure.observe(ctx.player.planar_velocity(), ctx.player.tuning.f("cruise"))
	churn.step(delta)
	boils.step(delta, enemies)
	_pin_step(enemies)
	_hulk_step(enemies, delta)
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
	if enemy.get("kind") == "warden":
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
		if DamageDoor.dead(enemy):
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
	var rate: float = clampf(_patterns[weapon].rate * ctx.tuning.mod("weapon_rate"), Pattern.MIN_RATE, Pattern.MAX_RATE)
	if _overdrive > 0.0:
		rate *= Weapons.OVERDRIVE_RATE
	return rate


func _fire(weapon: String, source := "weapon") -> void:
	var p: Resource = _patterns[weapon]
	var space: PhysicsDirectSpaceState3D = ctx.root.get_world_3d().direct_space_state
	var ball: Vector3 = ctx.player.ball_position()
	var reach: float = p.range_m * ctx.tuning.mod("weapon_range")
	var damage: float = p.damage * _damage_mod(weapon)
	var sprung := source == "weapon" and spring_armed()
	if sprung:
		damage *= SPRING_MULT
		_spring_until = -1.0
	var aim := Hitscan.aim(space, ctx.aim_origin(), ctx.aim_forward(), ball, reach + AIM_SLACK)
	var point: Vector3 = aim["point"]
	var forward := point - ball
	if forward.length() < MUZZLE * 1.5:
		forward = ctx.aim_forward()
	forward = forward.normalized()
	var muzzle := ball + forward * MUZZLE
	if sprung:
		effects.ring(muzzle, 1.5, Palette.VERDIGRIS)
	var color := Weapons.color(weapon)
	var kind := Weapons.strike_kind(weapon)
	var layout: Array = p.layout(forward, volleys)
	for entry in layout:
		bolts.fire({
			"origin": muzzle, "dir": entry["dir"], "speed": p.speed, "max_dist": reach,
			"damage": damage, "kind": kind, "weapon_id": weapon, "radius": p.bolt_radius,
			"knock": p.knock, "chain_jumps": p.chain_jumps, "chain_range": p.chain_range,
			"chain_falloff": p.chain_falloff, "lattice_chain_falloff": p.lattice_chain_falloff, "color": color,
			"wave_amp": 0.0 if entry["centre"] else p.wave_amp, "wave_hz": p.wave_hz, "phase": entry["phase"],
			"source": source,
		})
	volleys += 1
	last_shot = {"weapon_id": weapon, "from": muzzle, "to": aim["to"], "point": point,
		"blocked": aim["blocked"], "bolts": layout.size(), "volley": volleys, "sprung": sprung}
	ctx.events.shot_fired.emit(weapon, muzzle, aim["to"])


func _on_bolt_hit(bolt: Dictionary, enemy: Node3D, point: Vector3, part := "") -> void:
	effects.spark(point, bolt["color"])
	var from: Vector3 = enemy.global_position
	var damage: float = bolt["damage"]
	if bolt["kind"] == "claw":
		var id := enemy.get_instance_id()
		if float(_clamped.get(id, -INF)) > _clock:
			damage *= Weapons.CLAMP_BONUS
		else:
			_clamped.erase(id)
	_hit(enemy, bolt["kind"], damage, bolt["dir"], bolt["knock"], part, bolt.get("source", "weapon"))
	if bolt["chain_jumps"] > 0:
		_chain(enemy, from, bolt)


# One resolved weapon hit: the shove, the flash, then strike() for damage and the fact.
func _hit(enemy: Node3D, kind: String, damage: float, direction: Vector3, knock: float, part := "", source := "", impact := "") -> void:
	var push := Vector3(direction.x, 0.0, direction.z)
	push = push.normalized() if push.length() > 0.01 else Vector3.FORWARD
	enemy.knock(push + Vector3.UP * float(EventKinds.impact(impact if impact != "" else kind)["lift"]), knock)
	if enemy.has_method("react"):
		enemy.react(String(EventKinds.impact(impact if impact != "" else kind)["react"]), push, true)
	enemy.flash()
	strike(enemy, kind, damage, part, source, impact)
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
	var damage: float = bolt["damage"]
	var at := from
	for jump in int(bolt["chain_jumps"]):
		var falloff: float = bolt["chain_falloff"]
		if jump == int(bolt["chain_jumps"]) - 1 and float(bolt.get("lattice_chain_falloff", 0.0)) > 0.0:
			falloff = bolt["lattice_chain_falloff"]
		damage *= falloff
		var next := _nearest(at, bolt["chain_range"], visited)
		if next == null:
			return
		visited.append(next)
		var to: Vector3 = next.global_position
		effects.arc(at, to, bolt["color"])
		_hit(next, bolt["kind"], damage, to - at, bolt["knock"] * 0.5, "", bolt.get("source", "weapon"))
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
# A row with no gauge is a tap (SKILL-BAR section 1): it casts on the press, through its
# `tap` callable, which answers whether it landed and spends nothing itself.
func _step_special(intent, delta: float) -> void:
	var abilities = ctx.player.abilities
	var kit = ctx.player.kit
	var id: String = abilities.id_of(AbilityState.SPECIAL)
	var gauge = abilities.gauge(AbilityState.SPECIAL)
	if not _specials.has(id):
		return
	var row: Dictionary = _specials[id]
	if gauge == null:
		# A second press or right mouse drops a running cast with nothing spent, like a gauge.
		if abilities.casting == AbilityState.SPECIAL:
			if intent.special_pressed or intent.cancel_pressed:
				var dropped: String = abilities.cancel_cast()
				if dropped != "":
					ctx.events.gauge_cancelled.emit(dropped, "cancel")
			return
		if row.has("tap") and intent.special_pressed:
			_tap(AbilityState.SPECIAL, id, row["tap"], row.get("commit", Callable()))
		return
	if not gauge.charging and intent.special_pressed and not abilities.ready(AbilityState.SPECIAL):
		_refuse_cast(AbilityState.SPECIAL, "cooling")
	# Auto Gauge: mounted, the gauge starts and holds by itself, so it fires at full.
	var auto: bool = _knob("mounted_autogauge") and kit.mounted
	if gauge.charging and (intent.special_pressed or intent.cancel_pressed):
		gauge.cancel()
		ctx.player.indicator.collapse("special")
		ctx.events.gauge_cancelled.emit(id, "cancel")
		return
	if not gauge.charging and (intent.special_pressed or auto) and abilities.ready(AbilityState.SPECIAL) \
			and (not row.has("can") or row["can"].call()):
		gauge.begin()
		ctx.events.gauge_charging.emit(id)
		# Hip Fire: pressed mid-sprint, the gauge is already full and fires now.
		if _knob("sprint_full_blast") and kit.sprinting:
			gauge.held = gauge.charge_max
	if not gauge.charging:
		ctx.player.indicator.clear("special")
		return
	var held: bool = (intent.special_held or auto) and not (_knob("sprint_full_blast") and kit.sprinting)
	var step: float = delta * (_knob("air_charge") if not ctx.player.state.on_floor() else 1.0)
	if not gauge.step(step, held):
		ctx.player.indicator.set_shape("special", row["geometry"].call(gauge.fraction()))
		return
	var f: float = gauge.fired_fraction
	var shape: Dictionary = row["geometry"].call(f)
	ctx.player.indicator.set_shape("special", shape)
	ctx.player.indicator.clear("special")
	# The plate can expire while the gauge fills: a release with nothing to return spends nothing.
	if row.has("can") and not row["can"].call():
		ctx.events.gauge_cancelled.emit(id, "blocked")
		return
	abilities.spend(AbilityState.SPECIAL)
	last_committed = {"id": id, "fraction": f, "geometry": shape}
	row["fire"].call(f, shape)
	# Twin Discharge and Vortex: the same release again, smaller, a moment later.
	if _knob("special_echo") > 0.0:
		_echo = {"row": row, "fraction": f * 0.6, "left": _knob("special_echo")}
	ctx.events.gauge_released.emit(id, f)
	ctx.events.special_used.emit(id, ctx.player.ball_position())
	ctx.events.slot_cast.emit(AbilityState.SPECIAL, id, ctx.player.ball_position())


# One tap cast on a bar slot: refused while cooling, refused with no target, else spent and
# published. Nothing is spent on a refusal, and the selection and its timer stay. A row with a
# `cast` time starts its cast here instead and lands through _step_cast when it finishes; an
# interrupting hit drops it first with nothing spent (FIELDS-AND-CASTS section 4). A row's
# `commit` aims at the press: an invalid aim is refused then, and the cast lands where it aimed.
func _tap(slot: String, id: String, cast: Callable, commit := Callable()) -> void:
	var abilities = ctx.player.abilities
	if abilities.casting == slot:
		return
	if not abilities.ready(slot):
		_refuse_cast(slot, "cooling")
		return
	if abilities.cast_of(slot) > 0.0:
		var fire := cast
		if commit.is_valid():
			var aim: Dictionary = commit.call()
			if not bool(aim.get("valid", true)):
				_refuse_cast(slot, "no_target")
				return
			fire = cast.bind(aim)
		if not abilities.begin_cast(slot):
			_refuse_cast(slot, "cooling")
			return
		_cast_pending = {"slot": slot, "id": id, "fire": fire}
		ctx.events.gauge_charging.emit(id)
		return
	_land_tap(slot, id, cast)


# A cast that ran its time lands now as the tap it started from, with the same refusals.
func _step_cast() -> void:
	var done: String = ctx.player.abilities.take_cast_done()
	var swapped: String = ctx.player.abilities.take_swap_dropped()
	if _cast_pending.is_empty():
		return
	if swapped != "":
		# A pick or relic swapped the casting slot: the cast ends as any cancel does.
		ctx.player.indicator.collapse(String(_cast_pending["slot"]))
		ctx.events.gauge_cancelled.emit(swapped, "swap")
		_cast_pending = {}
		return
	if done == "":
		if ctx.player.abilities.casting == "":
			_cast_pending = {}
		return
	var pending := _cast_pending
	_cast_pending = {}
	if done == String(pending["slot"]):
		ctx.events.gauge_released.emit(String(pending["id"]), 1.0)
		_land_tap(done, String(pending["id"]), pending["fire"])


func _land_tap(slot: String, id: String, cast: Callable) -> void:
	var abilities = ctx.player.abilities
	if not abilities.ready(slot):
		_refuse_cast(slot, "cooling")
		return
	if not bool(cast.call()):
		_refuse_cast(slot, "no_target")
		return
	abilities.spend(slot)
	var at: Vector3 = ctx.player.ball_position()
	if slot == AbilityState.SPECIAL:
		ctx.events.special_used.emit(id, at)
	ctx.events.slot_cast.emit(slot, id, at)


# A cast left click asked for that cannot go. Only a click the bar routed answers with a cue;
# a module test or a bot writing special_* directly hears nothing new.
func _refuse_cast(slot: String, reason: String) -> void:
	if reason == "cooling" and ctx.player.abilities.silenced(slot):
		reason = "jammed"
	if ctx.player.abilities.selected == slot:
		ctx.events.verb_failed.emit("fire", reason, ctx.player.ball_position())


func _tick_echo(delta: float) -> void:
	if _echo.is_empty():
		return
	_echo["left"] -= delta
	if _echo["left"] > 0.0:
		return
	var row: Dictionary = _echo["row"]
	var f: float = _echo["fraction"]
	_echo = {}
	# A special that needs live state (Tally's plate) echoes only while its can() still holds
	# (wave 15, 2026-10-05); a stale echo fired at the ball otherwise.
	if row.has("can") and not row["can"].call():
		return
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
	var speed := maxf(f * Weapons.DISCHARGE_FULL_SPEED, 0.75 * ctx.player.state.velocity.length())
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


# Tarn's clamp: the ring catches every enemy in it, drags it in and holds it for claw sweeps.
func _clamp_geometry(f: float) -> Dictionary:
	return ctx.player.yours({"kind": "ring", "centre": _ground_under(ctx.player.ball_position()),
		"radius": AbilityState.Gauge.scaled(f, Weapons.CLAMP_RADIUS_MIN, Weapons.CLAMP_RADIUS_MAX),
		"full_radius": Weapons.CLAMP_RADIUS_MAX, "fill": f})


func _fire_clamp(f: float, shape: Dictionary) -> void:
	var prev_source := _forced_source
	_forced_source = "special"
	var ball: Vector3 = ctx.player.ball_position()
	var centre: Vector3 = shape["centre"]
	var radius: float = shape["radius"]
	var damage := AbilityState.Gauge.scaled(f, Weapons.CLAMP_DAMAGE_MIN, Weapons.CLAMP_DAMAGE_MAX) * _damage_mod(Weapons.CLAW_SWEEP)
	var seconds := AbilityState.Gauge.scaled(f, Weapons.CLAMP_SECONDS_MIN, Weapons.CLAMP_SECONDS_MAX)
	var hit := 0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.is_dead() or not in_ring(centre, radius, enemy):
			continue
		_clamped[enemy.get_instance_id()] = _clock + seconds
		_hit(enemy, "claw", damage, ball - enemy.global_position, Weapons.CLAMP_KNOCK, "", "special", "clamp")
		hit += 1
	effects.ring(centre, radius, ClassDef.TARN_COLOR)
	last_burst = {"at": centre, "radius": radius, "damage": damage, "hit": hit, "kind": "clamp"}
	_forced_source = prev_source


# --- The remembered cannon (BIBLE "Mind and the remembered cannon") ------------------
# Every cannon attack is one of the Mind's four families, committed through
# MindAttacks with the ball as the source and the aim or an enemy as the target, laid as
# a real Hazard in the cannon's colour. A non-hostile colour keeps it out of Threat.GROUP;
# a hit lands only where the Hazard's own contains() holds, while it is live.

func _cannon_phase() -> int:
	return clampi(ctx.stages.world_of(ctx.run.stage), 1, 3) if ctx.stages != null else 1


func _cannon_ground(p: Vector3) -> float:
	return _floor_at(p + Vector3.UP).y


func _commit_cannon(family: String, target: Vector3, centre: Vector3, radius: float, damage: float, source: String,
		expose := false, overrides := {}) -> Dictionary:
	_cannon_count += 1
	var seed: int = _cannon_count * 7919 + ctx.run.stage
	var phase := _cannon_phase()
	var descriptors: Array = MindAttacks.commit(family, seed, target, centre, phase, radius)
	var entry := {"family": family, "hazards": [], "damage": damage, "source": source, "struck": {}, "expose": expose,
		"verb": "", "window": 0.0, "seed": seed, "target": target, "centre": centre, "radius": radius, "phase": phase, "options": overrides, "noted": false, "born": _clock}
	for d in descriptors:
		d["id"] = "cannon_%s_%d" % [String(d["id"]).trim_prefix("mind_"), _cannon_count]
		for key in ["warn", "live", "from", "dir", "ahead", "band"]:
			if overrides.has(key):
				d[key] = overrides[key]
		var h = MindAttacks.build(d)
		# The one-second floor belongs to hostile hazards. Friendly cable and beat calls
		# use the committed warn, including zero for the last landing-beat call.
		if overrides.has("warn"):
			h.warn_seconds = maxf(0.0, float(overrides["warn"]))
		h.color = ClassDef.CANNON_COLOR
		h.ground = _cannon_ground
		ctx.root.add_child(h)
		entry["hazards"].append(h)
		if d.has("verb"):
			entry["verb"] = String(d["verb"])
			entry["window"] = float(d["weak_window"])
	_cannon.append(entry)
	return entry


func _step_cannon(delta: float) -> void:
	_step_cannon_exposure()
	if ctx.player.abilities.selected == AbilityState.LINE and ctx.player.abilities.id_of(AbilityState.LINE) == "cannon_lane_charge" and ctx.player.kit.hooked:
		ctx.player.indicator.set_shape(AbilityState.LINE, _cannon_line_geometry(1.0))
	elif ctx.player.abilities.id_of(AbilityState.LINE) == "cannon_lane_charge":
		ctx.player.indicator.clear(AbilityState.LINE)
	if _cannon.is_empty():
		return
	var enemies := get_tree().get_nodes_in_group("enemy")
	var kept := []
	for entry in _cannon:
		var done := true
		for h in entry["hazards"]:
			if not is_instance_valid(h):
				continue
			var options: Dictionary = entry["options"]
			if options.has("live_at"):
				h.age = maxf(0.0, h.warn_seconds + _clock - float(options["live_at"]))
				h.step(0.0)
			else:
				h.step(delta)
			if h.is_live() and not entry["noted"]:
				entry["noted"] = true
				entry["live_clock"] = _clock
				_cannon_note(entry)
			if not h.is_done():
				done = false
			if h.is_live():
				_cannon_strike(entry, h, enemies)
		if done:
			for h in entry["hazards"]:
				if is_instance_valid(h):
					h.queue_free()
		else:
			kept.append(entry)
	_cannon = kept


func _cannon_strike(entry: Dictionary, h: Node3D, enemies: Array) -> void:
	for enemy in enemies:
		if DamageDoor.dead(enemy):
			continue
		var id: int = enemy.get_instance_id()
		if entry["struck"].has(id) or (enemy != entry["options"].get("forced") and not h.contains(enemy.global_position)):
			continue
		entry["struck"][id] = true
		var push: Vector3 = h.heading if h.shape == MindAttacks.Hazard.Shape.LANE else enemy.global_position - h.centre
		var options: Dictionary = entry["options"]
		if options.has("budget"):
			var dealt := _cannon_set_piece_hit(enemy, float(entry["damage"]), h.centre, false, false, options["budget"])
			var record: Dictionary = options["record"]
			if entry["struck"].size() == 1:
				record["zone_hits"] = int(record.get("zone_hits", 0)) + 1
			record["volley_hits"] = int(record.get("volley_hits", 0)) + 1
			record["damage"] = float(record.get("damage", 0.0)) + dealt
		else:
			_hit(enemy, "cannon", float(entry["damage"]) * _damage_mod(Weapons.CANNON_LANE), push, Weapons.CANNON_KNOCK, "", entry["source"])
		if not entry.get("recital_checked", false):
			entry["recital_checked"] = true
			_cannon_recital(entry["family"], enemy.global_position)
			if options.has("discovery"):
				_discover("cannon_lane_charge", enemy.global_position)
		if entry["expose"] and is_instance_valid(enemy) and not enemy.is_dead():
			_cannon_expose(enemy, float(entry["window"]), entry["verb"])


# Every cannon Hazard leaves the tree now and is freed at the end of the frame.
func _free_cannon() -> void:
	_recital_index = 0
	_recital_at = -INF
	for row in _exposed.values():
		if is_instance_valid(row.get("mark")):
			row["mark"].queue_free()
	for entry in _cannon:
		for h in entry["hazards"]:
			if is_instance_valid(h):
				if h.get_parent() != null:
					h.get_parent().remove_child(h)
				h.queue_free()
	_cannon = []


# The weapon: one Mind lane from the ground under the ball down the aim, per cooldown.
func _fire_cannon_lane(weapon: String) -> void:
	var space: PhysicsDirectSpaceState3D = ctx.root.get_world_3d().direct_space_state
	var ball: Vector3 = ctx.player.ball_position()
	var reach: float = Weapons.CANNON_LANE_REACH * ctx.tuning.mod("weapon_range")
	var aim := Hitscan.aim(space, ctx.aim_origin(), ctx.aim_forward(), ball, reach + AIM_SLACK)
	var point: Vector3 = aim["point"]
	var centre := _ground_under(ball)
	var target := point
	if Vector2(point.x - centre.x, point.z - centre.z).length() < 1.5:
		target = centre + _flat_aim() * 10.0
	var entry := _commit_cannon("lane", target, centre, reach, Weapons.LANE_DAMAGE, "weapon")
	var h = entry["hazards"][0]
	# The body the ball's line holds is struck when the lane's footprint covers it, however high it
	# hangs: the lane reaches 3 m over the ground, and the stage-2 flume relic hangs 12 m over the
	# drum floor, so latched lanes landed 0 of about 80 (ruling BL2). The line charge strikes its
	# anchor the same way (_cannon_line_fire's "forced").
	var kit = ctx.player.kit
	if kit.hooked and kit.on_body and is_instance_valid(kit.anchor_body):
		var held: Vector3 = kit.anchor_body.global_position
		# A body already inside the lane at its real position takes the normal strike, not the forced one.
		if h.contains(Vector3(held.x, h.ground_at(held) + 1.0, held.z)) and not h.contains(held):
			entry["options"] = {"forced": kit.anchor_body}
	var end: Vector3 = h.centre + h.heading * h.length
	var muzzle: Vector3 = ball + h.heading * MUZZLE
	volleys += 1
	last_shot = {"weapon_id": weapon, "from": muzzle, "to": end, "point": point, "blocked": aim["blocked"], "bolts": 0,
		"volley": volleys, "sprung": false}
	ctx.events.shot_fired.emit(weapon, muzzle, end)


# The movement: the recoil kicks the ball along the aim; the split lands behind it.
func _on_cannon_dashed(dir: Vector3) -> void:
	if ctx.player.abilities.cap(AbilityState.MOVEMENT, "family", "") != "split_lane":
		return
	var flat := Vector3(dir.x, 0.0, dir.z)
	flat = flat.normalized() if flat.length() > 0.01 else _flat_aim()
	var centre := _ground_under(ctx.player.ball_position())
	_commit_cannon("split_lane", centre - flat * 10.0, centre, Weapons.RECOIL_REACH, Weapons.RECOIL_DAMAGE, "special")


# The special: the gauge draws the plate's own band as a cone; the release commits it.
func _plate_geometry(f: float) -> Dictionary:
	return ctx.player.yours({"kind": "cone", "apex": _ground_under(ctx.player.ball_position()), "dir": _flat_aim(),
		"length": 2.0 * MindAttacks.PLATE_HALF_BAND, "half_angle": MindAttacks.PLATE_HALF_SPAN, "fill": f})


func _fire_plate(f: float, shape: Dictionary) -> void:
	var apex: Vector3 = shape["apex"]
	var dir: Vector3 = shape["dir"]
	var damage := AbilityState.Gauge.scaled(f, Weapons.PLATE_DAMAGE_MIN, Weapons.PLATE_DAMAGE_MAX)
	_commit_cannon("plate", apex + dir * MindAttacks.PLATE_HALF_BAND, apex, shape["length"], damage, "special", true)
	last_burst = {"at": apex, "damage": damage, "kind": "cannon_plate"}


# The smash: after the shared slam, a rush ring about the landing over the nearest enemy.
func _on_cannon_slammed(at: Vector3, strength: float, _flatness: float) -> void:
	if ctx.player.abilities.cap(AbilityState.SMASH, "family", "") != "rush":
		return
	var landing := _floor_at(at + Vector3.UP)
	var target := landing + _flat_aim() * 6.0
	var best := Weapons.RUSH_REACH
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.has_method("is_dead") and enemy.is_dead():
			continue
		var d := Vector2(enemy.global_position.x - landing.x, enemy.global_position.z - landing.z).length()
		if d <= best:
			best = d
			target = enemy.global_position
	_commit_cannon("rush", target, landing, Weapons.RUSH_REACH, Weapons.RUSH_DAMAGE * clampf(strength, 0.5, 1.5),
		"drop_or_slam")


# --- PC-CANNON: the cable lane and the set-piece zones --------------------------------
const CannonAugments := preload("res://src/movement/augments.gd")
var _recital_index := 0
var _recital_at := -INF
static var _exposure_mesh: ArrayMesh
static var _exposure_material: ShaderMaterial


func _cannon_audio():
	var presentation = ctx.root.get("presentation")
	return presentation.audio if presentation != null else null


func _cannon_note(entry: Dictionary) -> void:
	var audio = _cannon_audio()
	if audio != null:
		var kind: String = {"weapon": "cannon_weapon", "line": "cannon_line_live", "drop_or_slam": "cannon_smash"}.get(entry["source"], "cannon_live")
		if entry["family"] == "split_lane" and entry["source"] == "special" and not entry["options"].has("budget"):
			kind = "cannon_recoil"
		audio.cannon_family(entry["family"], false, kind)


func _cannon_line_geometry(fraction: float) -> Dictionary:
	var kit = ctx.player.kit
	var ball: Vector3 = ctx.player.ball_position()
	var from := _ground_under(ball)
	var dir := _flat_aim()
	var ahead := Weapons.CANNON_LANE_REACH - MindAttacks.LANE_HALF
	if kit.hooked and kit.on_body:
		dir = Vector3(kit.anchor.x - ball.x, 0.0, kit.anchor.z - ball.z).normalized()
		if dir.length() < 0.01:
			dir = _flat_aim()
		ahead = Vector2(kit.anchor.x - ball.x, kit.anchor.z - ball.z).length() + Weapons.LANE_CHARGE_PAST
	elif kit.hooked:
		var floor = _cannon_floor(kit.anchor)
		if floor != null:
			from = floor
			var normal: Vector3 = kit.anchor_normal
			if absf(normal.y) < 0.7 and Vector2(normal.x, normal.z).length() > 0.01:
				dir = Vector3(normal.x, 0.0, normal.z).normalized()
		else:
			dir = Vector3(kit.anchor.x - ball.x, 0.0, kit.anchor.z - ball.z).normalized()
			if dir.length() < 0.01:
				dir = _flat_aim()
	return ctx.player.yours({"kind": "line", "from": from, "to": from + dir * ahead,
		"full_to": from + dir * ahead, "width": MindAttacks.LANE_HALF * 2.0, "fill": fraction})


func _cannon_line_body(target: Node3D, fraction: float, mult: float) -> void:
	_cannon_line_fire(fraction, mult, target)


func _cannon_line_world(_anchor: Vector3, fraction: float, mult: float) -> void:
	_cannon_line_fire(fraction, mult, null)


func _cannon_line_fire(fraction: float, mult: float, target: Node3D) -> void:
	var shape := _cannon_line_geometry(fraction)
	var from: Vector3 = shape["from"]
	var to: Vector3 = shape["to"]
	_commit_cannon("lane", to, from, from.distance_to(to) + MindAttacks.LANE_HALF,
		Weapons.LANE_CHARGE_DAMAGE * mult, "line", false,
		{"warn": Weapons.LANE_CHARGE_WARN, "live": Weapons.LANE_CHARGE_LIVE,
		"from": from, "dir": (to - from).normalized(), "ahead": from.distance_to(to), "forced": target,
		"discovery": "cannon_lane_charge"})
	var audio = _cannon_audio()
	if audio != null:
		audio.cannon_line(ctx.player.chain.combo)


# A call needs a real floor. Unlike _floor_at this never substitutes the terrain sample
# when a ray misses, so a gap cannot silently become a zone.
func _cannon_floor(at: Vector3):
	var space: PhysicsDirectSpaceState3D = ctx.root.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.1,
		at - Vector3.UP * Weapons.VOID_DROP, CannonAugments.WORLD_MASK))
	return hit["position"] if not hit.is_empty() and (hit["normal"] as Vector3).y >= 0.7 else null


func _cannon_recital(family: String, at: Vector3) -> void:
	if _clock - _recital_at > Weapons.RECITAL_SECONDS:
		_recital_index = 0
	if family == MindAttacks.FAMILIES[_recital_index]:
		if _recital_index == 0:
			_recital_at = _clock
		_recital_index += 1
	elif family == "lane":
		_recital_at = _clock
		_recital_index = 1
	else:
		_recital_index = 0
	if _recital_index == MindAttacks.FAMILIES.size():
		_recital_index = 0
		_discover("cannon_recital", at)
		var audio = _cannon_audio()
		if audio != null:
			audio.cannon_motif("cannon_recital", true)


func _cannon_set_piece_hit(enemy: Node3D, damage: float, at: Vector3, landing: bool, mortar: bool, budget: Dictionary) -> float:
	if enemy.has_method("_apply_posture") and enemy.has_method("staggered"):
		if landing and enemy.staggered():
			return _ult_hit(enemy, "ultimate", damage, at, true)
		var judged: Dictionary = enemy.judge_hit("slam" if landing else "cannon",
			damage if landing else damage * Ultimate.WARDEN_VOLLEY, landing, 0)
		var id := enemy.get_instance_id()
		var spent := float(budget.get(id, 0.0))
		judged["gain"] = minf(float(judged.get("gain", 0.0)), maxf(0.0, Ultimate.cap_for_warden(enemy) - spent))
		judged["shatter"] = false
		judged["crack"] = false
		budget[id] = spent + float(judged["gain"])
		enemy._apply_posture(judged)
		effects.spark(enemy.global_position + Vector3.UP, Palette.SLATE)
		return 0.0
	return _ult_hit(enemy, "slam" if mortar and landing else "ultimate", damage, at, landing)


func _cannon_expose(enemy: Node3D, window: float, verb: String) -> void:
	var id := enemy.get_instance_id()
	var mark: MeshInstance3D = enemy.get_node_or_null("CannonExposure")
	if mark == null:
		if _exposure_mesh == null:
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			for i in 24:
				if i % 6 == 0:
					continue
				var a := TAU * i / 24.0
				var b := TAU * (i + 0.8) / 24.0
				for p in [Vector2(a, 1.1), Vector2(b, 1.1), Vector2(a, 1.25),
					Vector2(b, 1.1), Vector2(b, 1.25), Vector2(a, 1.25)]:
					surface.add_vertex(Vector3(cos(p.x) * p.y, 0.12, sin(p.x) * p.y))
			_exposure_mesh = surface.commit()
			_exposure_material = ShaderMaterial.new()
			var shader := Shader.new()
			shader.code = "shader_type spatial; render_mode unshaded, cull_disabled; uniform vec4 tint : source_color; instance uniform float left = 1.0; void fragment(){ ALBEDO = tint.rgb; ALPHA = left; }"
			_exposure_material.shader = shader
			_exposure_material.set_shader_parameter("tint", Palette.ANCIENT)
			_exposure_mesh.surface_set_material(0, _exposure_material)
		mark = MeshInstance3D.new()
		mark.name = "CannonExposure"
		mark.mesh = _exposure_mesh
		enemy.add_child(mark)
	mark.set_instance_shader_parameter("left", 1.0)
	_exposed[id] = {"until": _clock + window, "verb": verb, "window": window, "mark": mark}


# --- SG1 arc mark ----------------------------------------------------------------------
# The committed geometry is the marked enemy's hull (_hull, the radius area hits test
# against), recorded once on the row; the ring is drawn at that radius under the enemy and
# lives exactly as long as the row, so what is drawn and what raises damage are one record.
static var _arc_mark_mesh: ArrayMesh


static func _arc_key(id: int) -> String:
	return "arc:%d" % id


func _arc_marked(enemy: Node3D) -> bool:
	return float(_exposed.get(_arc_key(enemy.get_instance_id()), {}).get("until", -INF)) > _clock


func _arc_mark(enemy: Node3D) -> void:
	if not is_instance_valid(enemy):
		return
	var id := enemy.get_instance_id()
	var radius := _hull(enemy)
	var mark: MeshInstance3D = enemy.get_node_or_null("ArcMark")
	if mark == null or mark.is_queued_for_deletion():
		mark = arc_mark_view()
		enemy.add_child(mark)
	# Scale against the enemy's own, so the drawn radius is the committed one in world units.
	var parent_scale: Vector3 = enemy.global_basis.get_scale()
	mark.scale = Vector3(radius / maxf(parent_scale.x, 0.0001), 1.0, radius / maxf(parent_scale.z, 0.0001))
	mark.set_instance_shader_parameter("left", 1.0)
	_exposed[_arc_key(id)] = {"kind": ARC_MARK_KIND, "id": id, "until": _clock + ARC_MARK_SECONDS,
		"window": ARC_MARK_SECONDS, "radius": radius, "mark": mark}


static func arc_mark_view() -> MeshInstance3D:
	var mark := MeshInstance3D.new()
	mark.name = "ArcMark"
	mark.mesh = _arc_ring()
	return mark


# A unit-radius dashed ring (outer edge 1.0), tinted the arc colour and fading with "left".
static func _arc_ring() -> ArrayMesh:
	if _arc_mark_mesh != null:
		return _arc_mark_mesh
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 16:
		if i % 4 == 3:
			continue
		var a := TAU * i / 16.0
		var b := TAU * (i + 0.7) / 16.0
		for p in [Vector2(a, 0.86), Vector2(b, 0.86), Vector2(a, 1.0),
			Vector2(b, 0.86), Vector2(b, 1.0), Vector2(a, 1.0)]:
			surface.add_vertex(Vector3(cos(p.x) * p.y, 0.14, sin(p.x) * p.y))
	_arc_mark_mesh = surface.commit()
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded, cull_disabled; uniform vec4 tint : source_color; instance uniform float left = 1.0; void fragment(){ ALBEDO = tint.rgb; ALPHA = left; }"
	material.shader = shader
	material.set_shader_parameter("tint", Palette.ARC)
	_arc_mark_mesh.surface_set_material(0, material)
	return _arc_mark_mesh


func _step_cannon_exposure() -> void:
	for key in _exposed.keys():
		var row: Dictionary = _exposed[key]
		var left := float(row["until"]) - _clock
		var mark = row.get("mark")
		if left <= 0.0 or not is_instance_valid(instance_from_id(int(row.get("id", key)))):
			if is_instance_valid(mark):
				# Out of the tree now, so a mark set again this frame takes the name at once.
				if mark.get_parent() != null:
					mark.get_parent().remove_child(mark)
				mark.queue_free()
			_exposed.erase(key)
		elif is_instance_valid(mark):
			mark.set_instance_shader_parameter("left", left / float(row["window"]))


# --- The line skill (design-v3/SKILL-BAR.md section 3) --------------------------------
# Slot 3 sends the pilot's flavour along the harpoon. With a line standing it fires now along
# it; with none the cast loads, and the next bite within the row's load_seconds carries it. A
# dry fire keeps the load; a load that runs out publishes line_skill_expired and refunds
# nothing (the cooldown started at the cast). The flavour adds no chain link and scales by
# chain.multiplier() when it fires.

const LINE_LOAD_SECONDS := 4.0
# The shared placeholder until wave P-C (SKILL-BAR section 3, start): on a body a 10 damage
# yank toward the ball, about 4 m, times the chain multiplier; on the world a reel burst.
const LINE_REEL_DAMAGE := 10.0
const LINE_REEL_KNOCK := 12.0
const REEL_BURST := 8.0

# The tap whose cast is running, {slot, id, fire}, or {} (FIELDS-AND-CASTS section 4).
var _cast_pending := {}
# Armour classes read this run; the codex dedupes too, this skips the call.
var _armour_known := {}
# A bite this tick waits for _step_line, so it fires after the bite's chain link is counted.
var _bite_pending := false


# The load waiting for the next bite, {id, fraction, left}, or {} (HUD and bots read it).
func line_load() -> Dictionary:
	return _line_load.duplicate()


func _bite_load() -> void:
	if not _line_load.is_empty():
		_bite_pending = true


func _step_line(intent, delta: float) -> void:
	var abilities = ctx.player.abilities
	var kit = ctx.player.kit
	if _bite_pending:
		_bite_pending = false
		if not _line_load.is_empty() and kit.hooked:
			var waiting := _line_load
			_line_load = {}
			_fire_line_skill(String(waiting["id"]), float(waiting["fraction"]))
			_discover("loaded_line", kit.anchor)
	if not _line_load.is_empty():
		_line_load["left"] = float(_line_load["left"]) - delta
		if float(_line_load["left"]) <= 0.0:
			var gone := String(_line_load["id"])
			_line_load = {}
			ctx.events.line_skill_expired.emit(gone)
	var id: String = abilities.id_of(AbilityState.LINE)
	if not _line_skills.has(id):
		return
	var gauge = abilities.gauge(AbilityState.LINE)
	var fraction := 1.0
	if gauge != null:
		if gauge.charging and (intent.line_pressed or intent.cancel_pressed):
			gauge.cancel()
			ctx.player.indicator.collapse(AbilityState.LINE)
			ctx.events.gauge_cancelled.emit(id, "cancel")
			return
		if not gauge.charging and intent.line_pressed and _line_cast_ok():
			gauge.begin()
			ctx.events.gauge_charging.emit(id)
		if not gauge.charging:
			ctx.player.indicator.clear(AbilityState.LINE)
			return
		if not gauge.step(delta, intent.line_held):
			ctx.player.indicator.set_shape(AbilityState.LINE, _line_skills[id]["geometry"].call(gauge.fraction()))
			return
		ctx.player.indicator.clear(AbilityState.LINE)
		fraction = gauge.fired_fraction
		if not abilities.ready(AbilityState.LINE) or not _line_load.is_empty():
			ctx.events.gauge_cancelled.emit(id, "blocked")
			return
		ctx.events.gauge_released.emit(id, fraction)
	elif not intent.line_pressed or not _line_cast_ok():
		return
	_cast_line(id, fraction)


func _line_cast_ok() -> bool:
	if not _line_load.is_empty():
		ctx.events.verb_failed.emit("select", "loaded", ctx.player.ball_position())
		return false
	if not ctx.player.abilities.ready(AbilityState.LINE):
		_refuse_cast(AbilityState.LINE, "cooling")
		return false
	return true


# The cast commits: spent, published, then fired along a standing line or loaded.
func _cast_line(id: String, fraction: float) -> void:
	var abilities = ctx.player.abilities
	abilities.spend(AbilityState.LINE)
	ctx.events.slot_cast.emit(AbilityState.LINE, id, ctx.player.ball_position())
	if ctx.player.kit.hooked:
		_fire_line_skill(id, fraction)
		return
	var seconds := float(AbilityState.ABILITIES.get(id, {}).get("load_seconds", LINE_LOAD_SECONDS))
	_line_load = {"id": id, "fraction": fraction, "left": seconds}
	ctx.events.line_skill_loaded.emit(id, seconds)


func _fire_line_skill(id: String, fraction: float) -> void:
	var row: Dictionary = _line_skills.get(id, {})
	if row.is_empty():
		return
	var kit = ctx.player.kit
	var mult := float(ctx.player.chain.multiplier())
	var target: Node3D = kit.anchor_body if kit.on_body and is_instance_valid(kit.anchor_body) and not (id == "bank_shot" and Augments.anchor_line(kit.anchor_body)) else null
	var at: Vector3 = kit.anchor
	var on := "body" if target != null else "world"
	var prev_source := _forced_source
	_forced_source = "special"
	if target != null:
		row["on_body"].call(target, fraction, mult)
	else:
		row["on_world"].call(at, fraction, mult)
	_forced_source = prev_source
	last_line = {"id": id, "on": on, "target": target, "at": at, "fraction": fraction, "mult": mult}
	ctx.events.line_skill_fired.emit(id, target, at, on)


# line_reel on a body: the bitten enemy is yanked toward the ball and struck.
func _line_reel_body(target: Node3D, _fraction: float, mult: float) -> void:
	if target.has_method("is_dead") and target.is_dead():
		return
	_hit(target, "line", LINE_REEL_DAMAGE * mult, ctx.player.ball_position() - target.global_position, LINE_REEL_KNOCK, "", "special")


# --- ult_default, the placeholder set piece (SKILL-BAR section 4) -----------------------

# One volley a beat: the pilot's own weapon at up to volley_targets() enemies within 10 m of
# the ball, those within 25 degrees of the reticle first. Returns the hits.
func _ult_volley(_beat: int, ball: Vector3, aim: Vector3, _heft_mult: float) -> int:
	var picks: Array = []
	var bias := deg_to_rad(Ultimate.VOLLEY_BIAS_DEG)
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if DamageDoor.dead(enemy):
			continue
		var gap: float = enemy.global_position.distance_to(ball)
		if gap > Ultimate.VOLLEY_RADIUS:
			continue
		var to: Vector3 = enemy.global_position - ball
		var biased: bool = aim.length() > 0.01 and to.length() > 0.01 and aim.angle_to(to) <= bias
		picks.append([(0.0 if biased else 100.0) + gap, enemy])
	picks.sort_custom(func(a, b): return a[0] < b[0])
	var weapon := active_weapon()
	var kind := weapon if weapon != "" else "ultimate"
	var hits := 0
	for entry in picks.slice(0, ultimate.volley_targets()):
		var enemy: Node3D = entry[1]
		effects.arc(ball + Vector3.UP * 0.5, enemy.global_position + Vector3.UP * 0.5, ctx.player.class_color())
		_ult_hit(enemy, kind, Ultimate.VOLLEY_DAMAGE * _heft_mult, ball, false)
		hits += 1
	return hits


func _ult_peak(at: Vector3) -> void:
	effects.ring(at, Ultimate.VOLLEY_RADIUS, ctx.player.class_color())


# The landing strike: 60 x heft multiplier x chain multiplier within the class's landing
# radius, knock 26. Returns [hits, damage].
func _ult_landing(at: Vector3, heft_mult: float, chain_mult: float) -> Array:
	var radius: float = ultimate.landing_radius()
	effects.ring(at, radius, ctx.player.class_color())
	var hits := 0
	var dealt := 0.0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if DamageDoor.dead(enemy):
			continue
		if enemy.global_position.distance_to(at) > radius:
			continue
		dealt += _ult_hit(enemy, "ultimate", Ultimate.LANDING_DAMAGE * heft_mult * chain_mult, at, true)
		hits += 1
	return [hits, dealt]


# One set-piece hit. A Warden fights on posture: an open core takes the landing as a harpoon
# smash (it shatters); a closed guard takes posture under the set piece's 45 cap, the volleys
# at half, and shows the slate glance. A boss takes half and its windows stay as they are.
func _ult_hit(enemy: Node3D, kind: String, damage: float, from: Vector3, landing: bool) -> float:
	if enemy.has_method("_apply_posture") and enemy.has_method("staggered"):
		if landing and enemy.staggered():
			_discover("set_piece_core", enemy.global_position)
			var held: Node3D = ctx.player.smash_landing
			ctx.player.smash_landing = enemy
			_hit(enemy, "slam", damage, enemy.global_position - from, 0.0, "", "special", "slam")
			ctx.player.smash_landing = held
			return damage
		var punch := damage if landing else damage * Ultimate.WARDEN_VOLLEY
		ultimate.warden_posture(enemy, enemy.judge_hit("slam" if landing else kind, punch, landing, 0))
		effects.spark(enemy.global_position + Vector3.UP, Palette.SLATE)
		return 0.0
	if _target_class(enemy) == "boss":
		damage *= Ultimate.BOSS_MULT
	if not (enemy.has_method("knock") and enemy.has_method("flash")):
		strike(enemy, kind, damage, "", "special")
		return damage
	_hit(enemy, kind, damage, enemy.global_position - from, Ultimate.LANDING_KNOCK if landing else 3.0, "", "special",
		"slam" if landing else "")
	return damage


# The default on a world latch: one +8 m/s burst toward the anchor.
func _reel_burst(anchor: Vector3, _fraction: float, _mult: float) -> void:
	var body: RigidBody3D = ctx.player.body()
	var toward: Vector3 = anchor - body.global_position
	if toward.length() > 0.01:
		body.linear_velocity += toward.normalized() * REEL_BURST


# The committed geometry a line gauge draws: the cable from the ball to the anchor, or along
# the aim with no line.
func _line_reel_geometry(f: float) -> Dictionary:
	var ball: Vector3 = ctx.player.ball_position()
	var kit = ctx.player.kit
	var to: Vector3 = kit.anchor if kit.hooked else ball + _flat_aim() * ctx.player.grapple_range()
	return ctx.player.yours({"kind": "line", "from": ball, "to": to, "width": 1.0, "full_to": to, "fill": f})


# --- Tally's kit (pilots/tally.md sections 2 and 3, wave P-C) ----------------------------
# Slot 1 runs Balance Due, the one card left in the reader, and is the only slot that spends
# pressure. Slot 2 plants the gather plate on its own cooldown. Slot 3 is the ledger clip line
# skill, which pays pressure. Q is Plate Return or a depth-3 variant, which settles the clips.
# Rolling, contact, the stamp, the surge and the clips refill pressure; time never does.

func _reset_cards() -> void:
	bay = 0
	plate = {}
	link_group = {}
	last_card = {}
	_arcing = false
	_gather_tick = 0.0
	_roll_clock = 0.0
	_restored_frame = {}
	_clear_clip_post()
	_clear_tally_piece()
	tally_last_settle = {}
	_tally_cards = {}


func _wire_tally() -> void:
	var ev = ctx.events
	# Flywheel Surge pays SURGE_PRESSURE (A2-CRITIC); the surge is Tally's only dashed source.
	ev.dashed.connect(func(_dir: Vector3):
		if ctx.player.abilities.id_of(AbilityState.MOVEMENT) == "flywheel_surge":
			_grant_pressure(Weapons.SURGE_PRESSURE))
	ev.line_skill_fired.connect(func(id: String, _target: Node3D, at: Vector3, _on: String):
		if id != "link_clips":
			return
		_stage_clip_casts += 1
		if _stage_clip_casts >= PUNCH_TAPE_CASTS:
			_tally_discover("tally_punch_tape", "loaded_line", at))
	ev.stage_entered.connect(func(_stage: int, _retry: bool):
		_stage_clip_casts = 0
		_clear_clip_post())
	ev.run_started.connect(func(_class_id: String):
		_run_settles = 0
		_stage_clip_casts = 0)
	ev.ultimate_started.connect(func(id: String, _path: String, _from: Vector3, _to: Vector3, _seconds: float):
		_clear_tally_piece()
		if id in TALLY_PIECES:
			tally_piece = id)
	ev.ultimate_cancelled.connect(func(_id: String, _reason: String, _refunded: bool): _clear_tally_piece())
	ev.synergy_discovered.connect(func(_id: String, _category: String, _first: bool):
		_tally_card_frame = Engine.get_physics_frames())


# Since the skill bar (SKILL-BAR section 1, "Tally's deck, re-cut") the reader holds one card,
# balance due, on slot 1, so `bay` stays 0. The same tick runs her plates, the clip post, the
# clip preview and her codex queue.
func _step_cards(intent, delta: float) -> void:
	var abilities = ctx.player.abilities
	var cards: Array = abilities.cap(AbilityState.WEAPON, "cards", [])
	bay = clampi(bay, 0, cards.size() - 1)
	abilities.slot(AbilityState.WEAPON).icon = String(Weapons.CARDS.get(cards[bay], {}).get("icon", ""))
	_step_plate(delta)
	if not link_group.is_empty() and float(link_group["until"]) <= _clock:
		link_group = {}
	_step_roll_restore(delta)
	_step_clip_post()
	_step_clip_preview()
	_step_tally_piece(delta)
	_step_tally_cards()
	if not intent.fire_pressed or _cooldown > 0.0:
		return
	var card: String = cards[bay]
	if not _cards.has(card):
		return
	var aim := _card_aim()
	if not _cards[card].call(aim["point"], aim["valid"]):
		return
	_cooldown = maxf(_cooldown, 0.0) + Weapons.CARD_RECOVERY
	ctx.events.shot_fired.emit(card, ctx.player.ball_position(), aim["point"])


# Where a card lands: the shared aim query's point, valid within CARD_REACH and unblocked.
func _card_aim() -> Dictionary:
	var space: PhysicsDirectSpaceState3D = ctx.root.get_world_3d().direct_space_state
	var ball: Vector3 = ctx.player.ball_position()
	var aim := Hitscan.aim(space, ctx.aim_origin(), ctx.aim_forward(), ball, Weapons.CARD_REACH + AIM_SLACK)
	var point: Vector3 = aim["point"]
	return {"point": point, "valid": not aim["blocked"] and ball.distance_to(point) <= Weapons.CARD_REACH}


# Slot 2's tap: plant the plate at the aim. The tap path spends slot 2's own charge.
func _tap_gather(aim := {}) -> bool:
	if aim.is_empty():
		aim = _card_aim()
	if not _run_gather(aim["point"], aim["valid"]):
		return false
	ctx.events.shot_fired.emit("gather_plate", ctx.player.ball_position(), aim["point"])
	return true


func _ordinary(enemy: Node3D) -> bool:
	var kind := _spawn_kind_of(enemy)
	if kind in ["chaser", "lobber"]:
		return _target_class(enemy) == "enemy"
	return Roster.has(kind) and Roster.faction_of(kind) == Roster.SWARM and _target_class(enemy) == "adds"


# The plate pulls every GATHER_TICK; Plate Return's peak widens it to the landing radius.
func _step_plate(delta: float) -> void:
	if plate.is_empty():
		return
	if float(plate["until"]) <= _clock:
		plate = {}
		return
	_gather_tick += delta
	while _gather_tick >= Weapons.GATHER_TICK:
		_gather_tick -= Weapons.GATHER_TICK
		_gather_pull(plate["at"], float(plate.get("radius", Weapons.GATHER_RADIUS)))


# One pull tick: ordinary enemies within `radius` roll toward `at`, harder from farther out.
func _gather_pull(at: Vector3, radius: float) -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.is_dead() or not _ordinary(enemy):
			continue
		var inward: Vector3 = at - enemy.global_position
		inward.y = 0.0
		var distance := inward.length()
		if distance > radius or distance < 0.01:
			continue
		enemy.knock(inward / distance, Weapons.GATHER_KNOCK * clampf(distance / radius, 0.25, 1.0))


func _step_roll_restore(delta: float) -> void:
	var abilities = ctx.player.abilities
	var s = abilities.slot(AbilityState.WEAPON)
	if s.charges >= s.max_charges:
		_roll_clock = 0.0
		return
	var planar: float = ctx.player.planar_velocity().length()
	if not ctx.player.state.on_floor() or SpeedTier.of(planar, ctx.player.tuning.f("cruise")) < SpeedTier.CRUISE:
		return
	_roll_clock += delta
	while _roll_clock >= Weapons.PRESSURE_ROLL_S:
		_roll_clock -= Weapons.PRESSURE_ROLL_S
		_grant_pressure(1)


func _grant_pressure(count: int) -> void:
	var abilities = ctx.player.abilities
	if count > 0 and abilities.cap(AbilityState.WEAPON, "pressure", null) != null:
		abilities.grant(AbilityState.WEAPON, count)


func _spend_card(card: String, at: Vector3) -> bool:
	if not ctx.player.abilities.spend(AbilityState.WEAPON):
		return false
	last_card = {"card": card, "at": at, "hits": 0, "spent": true}
	return true


# Gather Plate spends no pressure: the tap path spends slot 2's own charge (6 s cooldown).
func _run_gather(point: Vector3, valid: bool) -> bool:
	if not valid:
		return false
	last_card = {"card": "gather_plate", "at": point, "hits": 0, "spent": false}
	var at := _floor_at(point + Vector3.UP)
	plate = {"at": at, "until": _clock + Weapons.GATHER_SECONDS}
	_gather_tick = 0.0
	effects.ring(at, Weapons.GATHER_RADIUS, ClassDef.TALLY_COLOR)
	return true


# A dry press answers verb_failed("fire", "cooling") and spends nothing.
func _run_balance(point: Vector3, valid: bool) -> bool:
	if not valid:
		return false
	var speed: float = ctx.player.planar_velocity().length()
	if not _spend_card("balance_due", point):
		_refuse_cast(AbilityState.WEAPON, "cooling")
		return false
	var damage := minf(Weapons.BALANCE_MAX, Weapons.BALANCE_BASE + Weapons.BALANCE_PER_SPEED * speed) * _damage_mod(Weapons.LEDGER_READER)
	var hits := 0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.is_dead() or not in_ring(point, Weapons.BALANCE_RADIUS, enemy):
			continue
		_ledger_hit(enemy, damage, point, Weapons.LEDGER_KNOCK, "weapon")
		hits += 1
	effects.ring(point, Weapons.BALANCE_RADIUS, ClassDef.TALLY_COLOR)
	last_card["hits"] = hits
	last_card["damage"] = damage
	return true


# --- The ledger clip, slot 3 --------------------------------------------------------------

# The committed geometry: a LINK_NEIGHBOUR_REACH ring round the latched enemy, or a
# CLIP_POST_RADIUS ring at a world anchor. The cast clips exactly what the drawn ring holds.
func _clip_geometry(_f: float) -> Dictionary:
	var kit = ctx.player.kit
	if kit.hooked and kit.on_body and is_instance_valid(kit.anchor_body):
		return _clip_ring(kit.anchor_body.global_position, Weapons.LINK_NEIGHBOUR_REACH)
	var at: Vector3 = kit.anchor if kit.hooked else ctx.player.ball_position() + _flat_aim() * ctx.player.grapple_range()
	return _clip_ring(at, Weapons.CLIP_POST_RADIUS)


func _clip_ring(centre: Vector3, radius: float) -> Dictionary:
	return ctx.player.yours({"kind": "ring", "centre": centre, "radius": radius, "full_radius": radius, "fill": 1.0, "ticks": "square"})


# While slot 3 is picked and a line stands, the ring the clip will commit to is drawn.
func _step_clip_preview() -> void:
	var abilities = ctx.player.abilities
	if abilities.selected == AbilityState.LINE and abilities.id_of(AbilityState.LINE) == "link_clips" and ctx.player.kit.hooked:
		ctx.player.indicator.set_shape("tally_clip", _clip_geometry(1.0))
	else:
		ctx.player.indicator.clear("tally_clip")


# On a body: the latched enemy and its LINK_NEIGHBOURS nearest neighbours inside the drawn ring
# become clips, each paying CLIP_PRESSURE. The chain multiplier at the cast rides with the
# group and pays on the arc.
func _link_clips_body(target: Node3D, _fraction: float, mult: float) -> void:
	_clear_clip_post()
	_link_from(target, mult, _clip_ring(target.global_position, Weapons.LINK_NEIGHBOUR_REACH))


# On the world: the default reel burst, and a clip post that clips the first CLIP_POST_MAX
# enemies inside its ring within CLIP_POST_SECONDS.
func _link_clips_world(anchor: Vector3, fraction: float, mult: float) -> void:
	_reel_burst(anchor, fraction, mult)
	link_group = {"ids": [], "until": _clock + Weapons.CLIP_POST_SECONDS, "spent": false, "mult": mult}
	clip_post = {"at": anchor, "until": _clock + Weapons.CLIP_POST_SECONDS, "shape": _clip_ring(anchor, Weapons.CLIP_POST_RADIUS)}
	ctx.player.indicator.set_shape("tally_post", clip_post["shape"])
	effects.ring(anchor, Weapons.CLIP_POST_RADIUS, ClassDef.TALLY_COLOR)
	last_card = {"card": "link_clips", "at": anchor, "hits": 0, "spent": false}


# Clips `first` and up to LINK_NEIGHBOURS live enemies inside `shape` (default: the clip ring
# round `first`). Returns how many it clipped.
func _link_from(first: Node3D, mult := 1.0, shape := {}) -> int:
	var centre: Vector3 = shape.get("centre", first.global_position)
	var radius: float = shape.get("radius", Weapons.LINK_NEIGHBOUR_REACH)
	var clips := [first]
	for enemy in _nearest_list(centre, radius * 2.0, 16):
		if clips.size() > Weapons.LINK_NEIGHBOURS:
			break
		if enemy != first and in_ring(centre, radius, enemy):
			clips.append(enemy)
	link_group = {"ids": [], "until": _clock + Weapons.LINK_SECONDS, "spent": false, "mult": mult}
	for clip in clips:
		_add_clip(clip)
	last_card = {"card": "link_clips", "at": first.global_position, "hits": clips.size(), "spent": false}
	if clips.size() > Weapons.LINK_NEIGHBOURS:
		_tally_discover("tally_skim", "loaded_line", first.global_position)
	return clips.size()


func _add_clip(enemy: Node3D) -> void:
	(link_group["ids"] as Array).append(enemy.get_instance_id())
	link_group["until"] = maxf(float(link_group["until"]), _clock + Weapons.LINK_SECONDS)
	effects.arc(ctx.player.ball_position(), enemy.global_position, ClassDef.TALLY_COLOR)
	_grant_pressure(Weapons.CLIP_PRESSURE)


func _step_clip_post() -> void:
	if clip_post.is_empty():
		return
	if float(clip_post["until"]) <= _clock or link_group.is_empty():
		_clear_clip_post()
		return
	var ids: Array = link_group["ids"]
	var at: Vector3 = clip_post["at"]
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if ids.size() >= Weapons.CLIP_POST_MAX:
			break
		if not is_instance_valid(enemy) or enemy.is_dead() or ids.has(enemy.get_instance_id()):
			continue
		if in_ring(at, Weapons.CLIP_POST_RADIUS, enemy):
			_add_clip(enemy)
			last_card["hits"] = ids.size()
	if ids.size() >= Weapons.CLIP_POST_MAX:
		_tally_discover("tally_skim", "loaded_line", at)
		_clear_clip_post()


func _clear_clip_post() -> void:
	clip_post = {}
	if ctx != null and ctx.player != null:
		ctx.player.indicator.clear("tally_post")


# The arc and the pressure a contact restores. A direct hit on a clip (anything but the arcs
# themselves) spends the group and arcs once to every other live clip, at the chain multiplier
# stored at the cast. Arcs are ledger strikes: posture only on a Warden, half on a boss.
func _on_card_struck(enemy: Node3D, kind: String, force: float) -> void:
	if kind == "ram" or kind == "stomp":
		var frame := Engine.get_physics_frames()
		if int(_restored_frame.get(kind, -1)) != frame:
			_restored_frame[kind] = frame
			_grant_pressure(1)
	if _arcing or link_group.is_empty() or link_group["spent"] or float(link_group["until"]) <= _clock:
		return
	var ids: Array = link_group["ids"]
	if not is_instance_valid(enemy) or not ids.has(enemy.get_instance_id()):
		return
	link_group["spent"] = true
	var from: Vector3 = enemy.global_position
	var damage := maxf(Weapons.LINK_ARC_MIN, force * Weapons.LINK_ARC_SHARE) * float(link_group.get("mult", 1.0))
	_arcing = true
	for id in ids:
		if id == enemy.get_instance_id():
			continue
		var other = instance_from_id(id)
		if other == null or not is_instance_valid(other) or other.is_dead():
			continue
		var to: Vector3 = other.global_position
		effects.arc(from, to, ClassDef.TALLY_COLOR)
		_ledger_hit(other, damage, from, Weapons.LEDGER_KNOCK, "weapon")
	_arcing = false


# One ledger strike from a Tally source: a boss takes BOSS_MULT and no knock.
func _ledger_hit(enemy: Node3D, damage: float, from: Vector3, knock: float, source: String) -> float:
	if _target_class(enemy) == "boss":
		damage *= Ultimate.BOSS_MULT
		knock = 0.0
	if not (enemy.has_method("knock") and enemy.has_method("flash")):
		strike(enemy, "ledger", damage, "", source)
		return damage
	_hit(enemy, "ledger", damage, enemy.global_position - from, knock, "", source)
	return damage


# --- Plate Return, Audit Trail and Flywheel Throw (Q) ---------------------------------------
# ultimate.gd's Tally rows call these. A ride clips what its beats strike, up to CLIP_CAP by heft
# class; the peak plants the plate at B; the landing strikes the radius, then settles every clip
# outside it once, refills pressure and (in ultimate.gd) ends the chain.

func _clear_tally_piece() -> void:
	tally_piece = ""
	ride_clips = {}
	_fly_plates = []
	_fly_pulled = false


func _tally_enemies() -> Array:
	return get_tree().get_nodes_in_group("enemy").filter(func(e): return not DamageDoor.dead(e))


static func _flat_gap(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# B is her plate when it lies within reach (rope range; the arc's reach for Flywheel Throw)
# and within ULT_PLATE_AIM_DEG of the aim: a line to it, or Flywheel Throw's arc onto it.
func tally_target(id: String, ball: Vector3, aim: Dictionary) -> Dictionary:
	if plate.is_empty():
		return {}
	var at: Vector3 = plate["at"]
	var reach: float = Ultimate.ARC_REACH[ultimate._heft_index()] if id == "plate_flywheel" else ctx.player.grapple_range()
	var forward: Vector3 = aim.get("forward", Vector3.ZERO)
	var flat_aim := Vector3(forward.x, 0.0, forward.z)
	var to := Vector3(at.x - ball.x, 0.0, at.z - ball.z)
	if ball.distance_to(at) > reach or flat_aim.length() < 0.01 or to.length() < 0.01:
		return {}
	if rad_to_deg(flat_aim.angle_to(to)) > Weapons.ULT_PLATE_AIM_DEG:
		return {}
	return {"path": "arc" if id == "plate_flywheel" else "line", "to": at, "target": null}


# One beat. Plate Return punches up to volley_targets() enemies within VOLLEY_RADIUS, those
# near the reticle first; Audit Trail stamps a ring on the ground under the ball; Flywheel
# Throw throws a small plate at the densest knot near the ground track. Returns the clips made.
func tally_tech(id: String, _beat: int, ball: Vector3, aim: Vector3, heft: float) -> int:
	var cap: int = Weapons.CLIP_CAP[ultimate._heft_index()]
	var made := 0
	if id == "plate_audit":
		var ground = _audit_ground(ball)
		if ground == null:
			return 0
		var radius: float = Weapons.AUDIT_STAMP_RADIUS + float(ultimate._knob("ult_volley", 0))
		effects.ring(ground, radius, ClassDef.TALLY_COLOR)
		for enemy in _tally_enemies():
			if in_ring(ground, radius, enemy):
				_piece_hit(enemy, Ultimate.VOLLEY_DAMAGE * heft, ground, Weapons.AUDIT_STAMP_KNOCK)
				made += _ride_clip(enemy, cap)
	elif id == "plate_flywheel":
		var knot = _densest_knot(ball)
		if knot == null:
			return 0
		_fly_plates.append({"at": knot, "until": _clock + Weapons.FLY_PLATE_SECONDS, "tick": 0.0})
		effects.ring(knot, Weapons.GATHER_RADIUS, ClassDef.TALLY_COLOR)
		var near: Array = []
		for enemy in _tally_enemies():
			var gap := _flat_gap(enemy.global_position, knot)
			if gap <= Weapons.GATHER_RADIUS:
				near.append([gap, enemy])
		near.sort_custom(func(a, b): return a[0] < b[0])
		for entry in near.slice(0, Weapons.FLY_KNOT_CLIPS + int(ultimate._knob("ult_volley", 0))):
			made += _ride_clip(entry[1], cap)
	else:
		for enemy in _volley_picks(ball, aim, ultimate.volley_targets()):
			effects.arc(ball + Vector3.UP * 0.5, enemy.global_position + Vector3.UP * 0.5, ClassDef.TALLY_COLOR)
			_piece_hit(enemy, Ultimate.VOLLEY_DAMAGE * heft, ball, Weapons.LEDGER_KNOCK)
			made += _ride_clip(enemy, cap)
	return made


# Up to `count` live enemies within VOLLEY_RADIUS of the ball: those not yet clipped this ride
# first, so the clips grow beat by beat up to the cap; then those within VOLLEY_BIAS_DEG of the
# reticle; then nearest.
func _volley_picks(ball: Vector3, aim: Vector3, count: int) -> Array:
	var picks: Array = []
	var bias := deg_to_rad(Ultimate.VOLLEY_BIAS_DEG)
	for enemy in _tally_enemies():
		var to: Vector3 = enemy.global_position - ball
		if to.length() > Ultimate.VOLLEY_RADIUS:
			continue
		var biased: bool = aim.length() > 0.01 and to.length() > 0.01 and aim.angle_to(to) <= bias
		var owed: bool = ride_clips.has(enemy.get_instance_id())
		picks.append([(1000.0 if owed else 0.0) + (0.0 if biased else 100.0) + to.length(), enemy])
	picks.sort_custom(func(a, b): return a[0] < b[0])
	return picks.slice(0, count).map(func(entry): return entry[1])


# A clip made this ride, under the class cap; a boss or Warden is clipped once like anyone.
func _ride_clip(enemy: Node3D, cap: int) -> int:
	var id := enemy.get_instance_id()
	if ride_clips.has(id) or ride_clips.size() >= cap:
		return 0
	ride_clips[id] = true
	return 1


# A set-piece hit from a beat or a settle: a Warden takes posture only, under the set piece's
# cap and never on the core; a boss takes half; anything else takes a ledger strike.
func _piece_hit(enemy: Node3D, damage: float, from: Vector3, knock: float) -> float:
	if (enemy.has_method("_apply_posture") and enemy.has_method("staggered")) or _target_class(enemy) == "boss":
		return _ult_hit(enemy, "ledger", damage, from, false)
	if not (enemy.has_method("knock") and enemy.has_method("flash")):
		strike(enemy, "ledger", damage, "", "special")
		return damage
	_hit(enemy, "ledger", damage, enemy.global_position - from, knock, "", "special")
	return damage


# A flail strike (flail.gd, POLES-FLAILS section 5): a swung or thrown body, not a weapon, so
# the habit read never counts it. A Warden or a boss takes it through its posture like a volley.
func flail_hit(enemy: Node3D, damage: float, from: Vector3, knock: float) -> void:
	flung.emit(enemy)
	if (enemy.has_method("_apply_posture") and enemy.has_method("staggered")) or _target_class(enemy) == "boss":
		_ult_hit(enemy, "flail", damage, from, false)
		return
	if not (enemy.has_method("knock") and enemy.has_method("flash")):
		strike(enemy, "flail", damage, "", "flail")
		return
	_hit(enemy, "flail", damage, enemy.global_position - from, knock, "", "flail")


# Ground under the ball within AUDIT_GROUND_REACH, or null.
func _audit_ground(ball: Vector3):
	var space: PhysicsDirectSpaceState3D = ctx.root.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(ball, ball + Vector3.DOWN * Weapons.AUDIT_GROUND_REACH, 1))
	return hit["position"] if not hit.is_empty() else null


# The live enemy within FLY_KNOT_SEARCH of the ground track with the most neighbours inside
# a gather plate's radius (nearest wins a tie), as a floor point; null with none in reach.
func _densest_knot(ball: Vector3):
	var enemies := _tally_enemies()
	var best = null
	var best_score := -1.0
	for enemy in enemies:
		var gap := _flat_gap(enemy.global_position, ball)
		if gap > Weapons.FLY_KNOT_SEARCH:
			continue
		var count := 0
		for other in enemies:
			if _flat_gap(other.global_position, enemy.global_position) <= Weapons.GATHER_RADIUS:
				count += 1
		var score := count * 100.0 - gap
		if score > best_score:
			best_score = score
			best = enemy.global_position
	return _floor_at(best + Vector3.UP) if best != null else null


# The peak: the plate goes home. A plate lands at B (or her plate at B grows) with the landing
# radius and pulls until the landing.
func tally_peak(id: String, at: Vector3) -> void:
	var legs: Array = ultimate._plan.get("legs", [])
	var b: Vector3 = legs.back()["to"] if not legs.is_empty() else at
	var left := -float(ultimate._leg_time)
	for i in range(ultimate._leg, legs.size()):
		left += float(legs[i]["seconds"])
	if plate.is_empty() or _flat_gap(plate["at"], b) > 1.0:
		plate = {"at": _floor_at(b + Vector3.UP), "until": 0.0}
		_gather_tick = 0.0
	plate["radius"] = ultimate.landing_radius() + (Weapons.FLY_LANDING_BONUS if id == "plate_flywheel" else 0.0)
	plate["until"] = _clock + maxf(left, 0.0) + Weapons.GATHER_TICK
	effects.ring(plate["at"], float(plate["radius"]), ClassDef.TALLY_COLOR)


# The landing: the strike within the radius, then one settle arc to each clip outside it at
# the ult_settle share (each enemy paid once), then pressure to full. Returns [strike hits plus
# settles, damage], which ultimate_landed carries.
func tally_landing(id: String, at: Vector3, heft: float, chain: float) -> Array:
	var radius: float = ultimate.landing_radius() + (Weapons.FLY_LANDING_BONUS if id == "plate_flywheel" else 0.0)
	var amount: float = Ultimate.LANDING_DAMAGE * heft * chain
	effects.ring(at, radius, ClassDef.TALLY_COLOR)
	if not link_group.is_empty():
		link_group["spent"] = true
	var struck := {}
	var hits := 0
	var dealt := 0.0
	for enemy in _tally_enemies():
		if enemy.global_position.distance_to(at) > radius:
			continue
		struck[enemy.get_instance_id()] = true
		dealt += _ult_hit(enemy, "ultimate", amount, at, true)
		hits += 1
	var share: float = float(ultimate._knob("ult_settle", Weapons.SETTLE_SHARE))
	var debts: Array = ride_clips.keys()
	if not link_group.is_empty() and float(link_group["until"]) > _clock:
		for cid in link_group["ids"]:
			if not debts.has(cid):
				debts.append(cid)
	var settled: Array = []
	for cid in debts:
		if struck.has(cid):
			continue
		var enemy = instance_from_id(cid)
		if DamageDoor.dead(enemy):
			continue
		effects.arc(at + Vector3.UP * 0.5, enemy.global_position + Vector3.UP * 0.5, ClassDef.TALLY_COLOR)
		dealt += _piece_hit(enemy, amount * share, at, Weapons.LEDGER_KNOCK)
		settled.append(cid)
	_grant_pressure(ctx.player.abilities.slot(AbilityState.WEAPON).max_charges)
	_fly_plates = []
	_fly_pulled = false
	tally_last_settle = {"at": at, "hits": hits, "settles": settled.size(), "ids": settled}
	_run_settles += settled.size()
	if settled.size() >= BOOKS_SETTLES:
		_tally_discover("tally_books_balanced", "set_piece", at)
	if _run_settles >= EYESHADE_SETTLES:
		_tally_discover("tally_eyeshade", "set_piece", at)
	return [hits + settled.size(), dealt]


# Flywheel Throw's small plates pull while they last; FLY_PULL_LEAD s before its strike every
# ordinary enemy within the landing radius plus FLY_PULL is thrown FLY_PULL inward.
func _step_tally_piece(delta: float) -> void:
	for p in _fly_plates.duplicate():
		if float(p["until"]) <= _clock:
			_fly_plates.erase(p)
			continue
		p["tick"] = float(p["tick"]) + delta
		while float(p["tick"]) >= Weapons.GATHER_TICK:
			p["tick"] = float(p["tick"]) - Weapons.GATHER_TICK
			_gather_pull(p["at"], Weapons.GATHER_RADIUS)
	if tally_piece != "plate_flywheel" or _fly_pulled or ultimate == null or ultimate.phase() != Ultimate.FLIGHT:
		return
	var legs: Array = ultimate._plan.get("legs", [])
	if legs.is_empty() or ultimate._leg != legs.size() - 1:
		return
	if float(legs[ultimate._leg]["seconds"]) - float(ultimate._leg_time) > Weapons.FLY_PULL_LEAD:
		return
	_fly_pulled = true
	var b: Vector3 = legs[ultimate._leg]["to"]
	var reach: float = ultimate.landing_radius() + Weapons.FLY_LANDING_BONUS + Weapons.FLY_PULL
	for enemy in _tally_enemies():
		if not _ordinary(enemy):
			continue
		var inward: Vector3 = b - enemy.global_position
		inward.y = 0.0
		if inward.length() > reach or inward.length() < 0.01:
			continue
		var weight = enemy.get("weight")
		enemy.knock(inward, Weapons.FLY_PULL / Weapons.FLY_PULL_LEAD * (float(weight) if weight != null else 1.0))


# Her codex cards queue behind the framework card they extend and open one per physics tick,
# never on a tick another card opened (B6's rule).
func _tally_discover(id: String, after: String, at: Vector3) -> void:
	if discovered.has(id):
		return
	_tally_cards[id] = {"after": after, "at": at, "queued": Engine.get_physics_frames()}


func _step_tally_cards() -> void:
	var codex = _codex()
	var frame := Engine.get_physics_frames()
	if codex == null or frame <= _tally_card_frame:
		return
	for id in _tally_cards.keys():
		var entry: Dictionary = _tally_cards[id]
		if frame > int(entry["queued"]) and codex.known(entry["after"]):
			_tally_cards.erase(id)
			_tally_card_frame = frame
			_discover(id, entry["at"])
			return


func _line_geometry(f: float) -> Dictionary:
	var from := _ground_under(ctx.player.ball_position())
	var length := AbilityState.Gauge.scaled(f, Weapons.LINE_MIN, Weapons.LINE_MAX)
	var shape: Dictionary = ctx.player.yours({"kind": "line", "from": from, "to": from + _flat_aim() * length, "width": Weapons.LINE_WIDTH,
		"full_to": from + _flat_aim() * Weapons.LINE_MAX, "fill": f})
	var points: Array = []
	for charge in _caught_line(shape):
		points.append(charge["pos"])
	shape["caught"] = points
	shape["bonus"] = 1.0 + Weapons.LINE_PER_CHARGE * mini(points.size(), Weapons.LINE_MAX_CAUGHT)
	ctx.player.indicator.set_shape("kest_caught", ctx.player.yours({"kind": "marks", "points": points}))
	return shape


func _caught_line(shape: Dictionary) -> Array:
	var live: Array = sticky.charges.duplicate()
	if ultimate != null:
		live.append_array(ultimate.caught_charges())
	return live.filter(func(c): return not c.get("_inert", false) and in_line(shape["from"], shape["to"], shape["width"], c["pos"]))


# Kest's detonation line: every live charge in the line goes off early, then the line
# itself hits, +25% per charge caught up to three. A shot out of the cloak crits.
func _fire_line(f: float, shape: Dictionary) -> void:
	var caught := []
	for charge in _caught_line(shape):
		caught.append(sticky.take(charge) if sticky.charges.has(charge) else ultimate.take_charge(charge))
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
	if ultimate != null and ultimate.active() and ultimate._id == "outpost":
		return
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
	devices.set_cap(Devices.STICKY, int(_knob("sticky_max_live")) * count)
	for i in count:
		var live: Array = sticky.live()
		if live.size() >= devices.cap(Devices.STICKY):
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
		if charge.has("_kest_cast"):
			ultimate.blast_hit(charge, enemy, dealt, at)
		else:
			_hit(enemy, "sticky", dealt, enemy.global_position - at, Weapons.BASE[Weapons.STICKY_CHARGE]["knock"],
				"", charge.get("_source", "weapon"))
	effects.ring(at, radius, ClassDef.KEST_COLOR)
	ctx.events.sticky_detonated.emit(at, charge["crit"])
	_rocket_jump(at)
	_start_cloak()
	if _knob("sticky_chain") > 0.0:
		# A nested detonation can already have taken a charge from this snapshot (F001).
		var live: Array = sticky.charges.duplicate()
		live.append_array(ultimate.caught_charges())
		for other in live:
			if other.get("_inert", false) or (not sticky.charges.has(other) and not ultimate.caught_charges().has(other)):
				continue
			if (other["pos"] as Vector3).distance_to(at) <= _knob("sticky_chain"):
				_detonate(sticky.take(other) if sticky.charges.has(other) else ultimate.take_charge(other))


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
	if kind == "enemy_killed" and ctx.run.last_kill_triggerless:
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
		"grant_special": func(_scale: float): _grant_special(abilities.call()),
		"grant_move": func(_scale: float): abilities.call().grant(AbilityState.MOVEMENT),
		"refund_special": func(scale: float): _refund_special(abilities.call(), scale),
		"refund_move": func(scale: float): abilities.call().refund(AbilityState.MOVEMENT, scale),
		"overdrive": func(scale: float): _boost(scale),
		"air": func(_scale: float): ctx.player.state.air_actions = 1,
	}


# A special that spends another slot's charges (Tally's gather plate pays from slot 1's
# pressure, SKILL-BAR section 2) takes its grant there. Pressure never refills by time, so a
# refund on such a pool returns one charge instead; the proc's gap is its throttle.
func _grant_special(abilities) -> void:
	abilities.grant(abilities.pool_of(AbilityState.SPECIAL))


func _refund_special(abilities, scale: float) -> void:
	var pool: String = abilities.pool_of(AbilityState.SPECIAL)
	if pool == AbilityState.SPECIAL:
		abilities.refund(AbilityState.SPECIAL, scale)
	else:
		abilities.grant(pool)


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
		var at: Vector3 = ctx.player.kit.mount_face + ctx.player.kit.mount_normal * 1.2
		# At the cap the standing sentry is replaced; with its slot still refilling, none stands.
		var placed: Dictionary = devices.deploy(Devices.SENTRY, at)
		if int(placed["id"]) <= 0:
			return
		_sentry = {"at": at, "left": _knob("sentry"), "next": 0.0, "id": int(placed["id"])}


func _tick_sentry(delta: float) -> void:
	if _sentry.is_empty():
		return
	_sentry["left"] -= delta
	_sentry["next"] -= delta
	if _sentry["left"] <= 0.0:
		devices.remove(int(_sentry.get("id", 0)), "expired")
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
		"chain_range": p.chain_range, "chain_falloff": p.chain_falloff,
		"lattice_chain_falloff": p.lattice_chain_falloff, "color": Weapons.color(Weapons.PYLON_TURRET),
		"wave_amp": 0.0, "wave_hz": 0.0, "phase": 0.0,
		"source": "persistent_actor",
	})


# The device ledger's clock: refills tick, and a device left past the leash is recalled
# (it leaves without acting: a charge does not go off, the sentry stops firing).
func _step_devices(delta: float) -> void:
	if not _sentry.is_empty():
		devices.move(int(_sentry.get("id", 0)), _sentry["at"])
	for charge in ultimate.caught_charges():
		devices.move(int(charge.get("device_id", 0)), charge["pos"])
	for stake in ultimate.stakes.nodes:
		devices.move(stake.device_id, stake.global_position)
	for gone in devices.step(delta, ctx.player.ball_position()):
		if gone["kind"] == Devices.SENTRY:
			if int(_sentry.get("id", 0)) == int(gone["id"]):
				_sentry = {}
		elif gone["kind"] == Devices.SABLE_STAKE:
			ultimate.stakes.recall(int(gone["id"]))
		elif gone["kind"] in [Devices.KEST_MINE, Devices.KEST_RAID]:
			ultimate.payloads.recall(int(gone["id"]))
		else:
			sticky.recall(int(gone["id"]))


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
			if victim == carrier or not _pinnable(victim) or victim.get("weight") == null:
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
			_pin(victim, to, speed)


# One pin: the victim takes the pin strike and flies on at PIN_CARRY of the carrier's speed.
# A victim the pin kills becomes a hulk in its turn, so a strike runs down a crowd. A hulk's
# pins hit with the heft that threw it (mult), so a grown ball's strike still kills what it
# scatters instead of knocking it clear of the roll-up.
func _pin(victim: Node3D, to: Vector3, speed: float, mult := 1.0) -> void:
	var damage := minf(Weapons.PIN_CAP, Weapons.PIN_BASE + Weapons.PIN_PER_SPEED * speed) * mult
	pins += 1
	ctx.events.enemy_pinned.emit(victim, damage)
	victim.knock(to + Vector3.UP * 0.2, speed * Weapons.PIN_CARRY * float(victim.weight))
	victim.flash()
	strike(victim, "pin", damage)
	if is_instance_valid(victim) and victim.is_dead():
		bowl_hulk(victim, to, speed * Weapons.PIN_CARRY)


# A body killed by a ram, a crush or a pin keeps its throw as a hulk for up to HULK_SECONDS:
# it travels along `direction` at `speed`, slowing as a knock does, and pins each body it
# reaches once, as a knocked enemy would. A posture fighter (a Warden) and a boss piece are
# never a hulk's victims, so stagger timing is untouched. Below PIN_MIN_SPEED it is spent.
func bowl_hulk(enemy: Node3D, direction: Vector3, speed: float) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if speed <= Weapons.PIN_MIN_SPEED or flat.length_squared() < 0.0001 or not is_instance_valid(enemy) or enemy.get("swarm") != null:
		return
	_hulks.append({"at": enemy.global_position, "vel": flat.normalized() * speed, "radius": _hull(enemy),
		"left": Weapons.HULK_SECONDS, "hit": {enemy.get_instance_id(): true}, "mult": heft()})


func _hulk_step(enemies: Array, delta: float) -> void:
	if _hulks.is_empty():
		return
	# A pin that kills launches a new hulk into _hulks; it is stepped from the next tick.
	var stepping := _hulks
	_hulks = []
	var live: Array = []
	for hulk in stepping:
		var vel: Vector3 = hulk["vel"]
		var speed := vel.length()
		hulk["left"] = float(hulk["left"]) - delta
		if speed <= Weapons.PIN_MIN_SPEED or float(hulk["left"]) <= 0.0:
			continue
		var heading := vel / speed
		var at: Vector3 = hulk["at"]
		for victim in enemies:
			if not _pinnable(victim) or victim.get("weight") == null or (hulk["hit"] as Dictionary).has(victim.get_instance_id()):
				continue
			if victim.has_method("fight") and victim.fight() == "posture":
				continue
			if victim.get("swarm") != null:
				continue
			var to: Vector3 = victim.global_position - at
			to.y = 0.0
			if to.length() - float(hulk["radius"]) - _hull(victim) > Weapons.PIN_RADIUS or to.normalized().dot(heading) < 0.5:
				continue
			hulk["hit"][victim.get_instance_id()] = true
			_pin(victim, to, speed, float(hulk["mult"]))
		hulk["at"] = at + vel * delta
		hulk["vel"] = vel.move_toward(Vector3.ZERO, EnemyBase.KNOCK_DECAY * delta)
		live.append(hulk)
	_hulks = live + _hulks


static func _pinnable(enemy) -> bool:
	return is_instance_valid(enemy) and enemy.has_method("knock") and enemy.has_method("is_dead") and not enemy.is_dead()


# --- Enemy attacks ------------------------------------------------------------------

# The stage director, which world.gd names "World" under the root. A harness or a scene
# variant without it reads neutral scales, as build.gd _rib_mult and attack_budget.gd do.
func _director():
	var world = ctx.root.get_node_or_null("World") if ctx.root != null else null
	var director = world.get("director") if world != null else null
	if director == null:
		_warn_no_director()
	return director


var _director_warned := false


func _warn_no_director() -> void:
	if not _director_warned:
		_director_warned = true
		push_warning("combat: no World director; enemy and hit scales read neutral")


# An enemy's committed attack reached the ball. The run takes the damage; the shove is
# the hit's weight (a hit taken is the player's performance, principle 1).
func _on_player_hit(amount: float, shove: Vector3, source: String) -> void:
	var attack := _hit_attack
	_hit_attack = ""
	if not ctx.flow.in_play():
		return
	if source not in ["warden", "warden_counter", "vault"]:
		var director = _director()
		if director != null:
			amount *= director.damage_scale()
		# The Mind's hand is a boss part: it takes the mind.* dials in mind_hand.gd, not the mobs dial.
		if source != "mind_hand":
			amount *= ChallengeDials.stage_mult("mobs.damage", ctx.run.stage)
	last_player_hit = {"from": ctx.player.ball_position() - shove, "shove": shove, "source": source, "frame": Engine.get_physics_frames(), "attack": attack}
	# The set piece's defence: no knockback here; damage x0.2 and the health floor of 1 run
	# inside ctx.run.damage through its defend_hook (SKILL-BAR section 4).
	var riding: bool = ultimate != null and ultimate.active()
	ctx.run.damage(amount, source)
	if not riding:
		_charge_assist("hull")
	if ctx.calm or riding:
		return
	# The damage always lands; what the hit may take is the stop, and that goes through
	# the player's crowd-control door, which Rivet's sprint shuts.
	ctx.player.crowd_control("knock", shove / get_physics_process_delta_time())


# Heat on the shell (redline.gd, loops.md Spec 1): a hot shell scales every hit at the run's one
# damage choke point, and a cook-off takes its share of the hull. The blast itself is the
# ball's (player_ball.gd), struck through the same slam path as any other.
func _wire_redline() -> void:
	var redline = ctx.player.get("redline") if ctx.player != null else null
	if redline == null:
		return
	ctx.run.taken_hook = func(_source: String) -> float:
		redline.note_hit()
		return redline.taken_scale()
	redline.cooked_off.connect(func(_at: Vector3, _force: float):
		if ctx.flow.in_play():
			ctx.run.damage(ctx.run.max_hp * Redline.COOK_OFF_SELF_HULL, Redline.COOK_OFF_SOURCE))


func _on_lobber_fired(origin: Vector3, landing: Vector3, flight: float, lobber: Node3D) -> void:
	var shell := Projectile.new()
	ctx.root.add_child(shell)
	var cover: bool = ctx.flow.in_stage() and ChallengeDials.by_stage_or("hazard.shell_cover_by_stage", ctx.flow.stage(), 0.0) > 0.5
	shell.setup(ctx.player, ground, ctx.root, Callable(ctx.flow, "in_play"), origin, landing, flight, lobber, cover)
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
func _warn_warden_once(stage: int, text: String) -> void:
	if not _warden_warned.has(stage):
		_warden_warned[stage] = true
		push_warning("warden_spec: " + text)


func warden_spec(stage: int) -> Dictionary:
	var def: Dictionary = ctx.flow.stage_def() if stage == ctx.flow.stage() else _stage_table().of(stage)
	var fallback: Dictionary = WARDEN_FALLBACK[clampi(stage, 1, 3) - 1]
	var uses_fallback := false
	for key in fallback:
		uses_fallback = uses_fallback or not def.has(key)
	if stage > WARDEN_FALLBACK.size() and uses_fallback:
		_warn_warden_once(stage, "WARDEN_FALLBACK clamps stage %d to %d" % [stage, WARDEN_FALLBACK.size()])
	var family: String
	if def.has("warden_family"):
		family = String(def["warden_family"])
	else:
		family = Roster.warden_family(stage)
		if stage > Roster.WARDEN_FAMILIES.size():
			_warn_warden_once(stage, "stage %d row has no warden_family; Roster clamps it to %s" % [stage, family])
	return {
		"family": family,
		"plating": float(def.get("warden_plating", fallback["warden_plating"])),
		"hp": float(def.get("warden_hp", fallback["warden_hp"])),
		"posture": def.get("posture", {}),
	}


func _spec_for(kind: String) -> Dictionary:
	var stage: int = ctx.flow.stage()
	match kind:
		"warden":
			var w := warden_spec(stage)
			w["stage"] = stage
			w["reach"] = float(ctx.flow.stage_def().get("beacon_radius", 30.0))
			if ctx.stages == preload("res://src/core/park_defs.gd"):
				const ParkMap := preload("res://src/world/park/park_map.gd")
				var map = ctx.terrain.map()
				if map is ParkMap and map.ok:
					w.merge(map.warden_spec(), true)
					w["reach"] = map.reach_m
					w["park_landmark"] = true
					if ctx.flow.gate != null and ctx.flow.gate.has_gate():
						w["posture_gate"] = Callable(ctx.flow.gate, "locked")
			return w
		"miniboss":
			return {"plating": float(roundi(MINIBOSS_PLATING_SCALE * warden_spec(stage)["plating"]))}
		_ when Rogue.ROWS.has(kind):
			return {"kind": kind, "plating": float(roundi(MINIBOSS_PLATING_SCALE * warden_spec(stage)["plating"]))}
		"vault":
			var next_plating: float = roundf(VAULT_TOP_SCALE * warden_spec(stage)["plating"]) if ctx.stages.is_last(stage) \
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
	# The camp's sandbox fights happen outside play and never mark the codex.
	if ctx.flow != null and not ctx.flow.in_play():
		return
	if not discovered.has(id):
		discovery_log.append(id)
	discovered[id] = at
	var codex = _codex()
	if codex != null and codex.has_method("mark_discovered"):
		codex.mark_discovered(id, at, ["player"])


# The chain card: the player's chain reached three links. The codex dedupes per run.
func _on_chain_state(state: String, _target: Node3D, at: Vector3, _cause: String) -> void:
	if state == "chain_link" and ctx.player.chain.combo >= 3:
		_discover("chain", at)


# Tricks that read the target's state before the hit lands.
func _detect_before(enemy: Node3D, kind: String, _result: Dictionary) -> void:
	var target_kind = enemy.get("kind")
	if kind == "ram" and target_kind == "chaser" and enemy.state_name() == "windup":
		_discover("counter_ram", enemy.global_position)


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


# --- Stage reset --------------------------------------------------------------------

# A stage entry or retry starts the fight clean, and recomputes every pattern from the
# restored part list, so a retry restores the build exactly.
func _on_stage_entered(_stage: int, _retry: bool) -> void:
	_start_attempt()
	churn.reset()
	boils.reset()
	_pressure_chasers = 0
	_line_load = {}
	_escape = {}
	escape_lane = {}
	_reset_cards()
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
	_hulks.clear()
	pins = 0
	# The upgrade tree's pending specials and clocks belong to the attempt that made
	# them: no echo, sentry, cloud or marks fire into the next one (F002).
	_echo = {}
	_marks = {}
	_cloud = {}
	_sentry = {}
	_pulse_left = 0.0
	_prow_until.clear()
	_primed.clear()
	assist_charge = 0.0
	_clamped.clear()
	_exposed.clear()
	_spring_until = -1.0
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
	_clear_devices()
	effects.clear()
	_free_cannon()


func _clear_devices() -> void:
	sticky.clear()
	ultimate.clear_payloads()
	ultimate.stakes.fold()
	devices.remove(int(_sentry.get("id", 0)))
	_sentry = {}
	devices.clear()


func _rebuild_patterns() -> void:
	var ids := active_transformers()
	var lattice_falloff := 0.0
	# Combat hears part_gained before Build. Derive from the current held list so a
	# newly completed lattice works on its first volley and retry cannot retain it.
	if ctx != null and ctx.run != null:
		var sheet: RefCounted = preload("res://src/build/build_sheet.gd").from_parts(ctx.run.parts)
		for _jump in sheet.lattice_chain_jumps():
			ids.append("chain_arc")
			lattice_falloff = Pattern.new().chain_falloff
	for weapon in Weapons.ALL:
		var p: Resource = Weapons.base(weapon).transformed(ids)
		p.lattice_chain_falloff = lattice_falloff
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


# --- PC-SABLE Bank Shot ---------------------------------------------------------------
func _bank_body(target: Node3D, _fraction: float, mult: float) -> void:
	var launch: Dictionary = ctx.player.bank_geometry()
	var damage := 10.0 * mult * (0.5 if _target_class(target) == "boss" else 1.0)
	if _target_class(target) != "boss" and target.has_method("knock"):
		target.knock(-(launch["dir"] as Vector3), 12.0)
	if target.has_method("flash"):
		target.flash()
	strike(target, "arc", damage, "", "special")
	_bank_world(ctx.player.kit.anchor, _fraction, mult)


func _bank_world(_anchor: Vector3, _fraction: float, _mult: float) -> void:
	var kit = ctx.player.kit
	var stake = kit.anchor_body
	var switched: bool = is_instance_valid(stake) and stake.is_in_group(Augments.STAKE_GROUP)
	var learned: bool = ctx.codex != null and ctx.codex.known("loaded_line")
	ctx.player.bank_shot()
	if learned:
		_discover("bank_shot", _anchor)
		if switched:
			_discover("switchback", _anchor)


func _bank_geometry(_fraction: float) -> Dictionary:
	return ctx.player.bank_geometry()
