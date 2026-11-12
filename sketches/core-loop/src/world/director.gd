extends RefCounted

# The spawn director: pure scheduling with no node of its own. The stage hands it a
# delta, the live enemy count and where the ball is going, and gets due spawns back.
# A headless test steps a whole stage in a loop instead of in real seconds.
#
# Honesty rules (demo spec, Director honesty):
# - Enemy HP comes from stage threat only, at every run tier (ruling al). The opt-in run
#   tier adds capped per-world damage and rest dials; the clock never toughens an enemy.
# - The clock's tier is clamped at the stage's last tier (+2; +3 on world 1, clock_tiers()), and every rise, the beacon spike included, is
#   recorded for the world to announce with threat_rose. Nothing rises silently.
# - 60% of spawns land ahead of the ball, within 35 degrees of where it is rolling,
#   60 to 90 m out; the rest on the flanks. None lands within 25 m of the ball, and
#   each shows a ground ring for 1 s before its body arrives.
#
# v2 W7 enemies: pack composition (DESIGN-V2 sections 10.5 and 15.4-15.5).
# - The difficulty clock gates reinforcements. At tick 0 every spawn is a chaser or a
#   lobber; from tick 1 a share of the spawn slots become packs, PACK_PER_TICK a tick,
#   and each tick past the Warden break (while the spike is on) adds PAST_BREAK_STEP.
# - A tagged pack pairs a controller with a punisher (PACKS): the enemy synergies. Its
#   members arrive together, on one ring timer, so combat reads them as one pack and
#   publishes pack_arrived with the faction.
# - New counters unlock as the ticks rise: UNLOCK_BASE by stage, UNLOCK_PER_TICK more a
#   tick, in the roster's order (combat/roster.gd COUNTERS). A pack is drawn only once
#   both its members are unlocked.
# - The stage's ancient family arrives as its own pack, ANCIENT_SHARE of the packs.
# - Weighting tests the build: `build` is combat's build_read() (class, habit shares,
#   W3's upgrade-tree branch tags through TAG_AXES). Each pack's weight is 1 + BUILD_TILT times how
#   strongly the build leans on the axis the pack tests, so the build's own axis comes
#   up to twice as often and every other unlocked pack still comes: fair, never a hard
#   counter. With no build read every pack weighs the same.
# - HP reads stage threat only; the clock adds packs, never toughness.
#
# Authored packs (slice table): with `authored` set, every arrival is one whole pack from
# that list and nothing else spawns: no single draws, no unlock clock, no ancient share. Packs
# are drawn uniformly (but for the nemesis lean below) and never the same twice in a row; the
# `elite_arrival`-th arrival is the `elite` pack, once. Pacing stays the director's own, and
# a pack arrives only when the cap has room for all of it.
#
# Pressure (GP3): the stage row's "pressure" (alpha_defs.gd PRESSURE) times the Breath row
# (BREATH, keyed by the tuning's breath option) multiplies the constants below, never replaces
# them: pack_scale the crowd cap and pack share, interval_scale the spawn interval, elite_rate
# the chance a later authored arrival is the elite again. A row with no pressure reads 1.0.
#
# 2026-10-18 (w17 nemesis): the one build tilt an authored table keeps. From Nemesis.FROM_WORLD
# a pack that holds a kind pressing the pilot's nemesis axis (combat/nemesis.gd) weighs
# Nemesis.PACK_WEIGHT against 1.0 for the rest, in both draws. World one, an unknown class and an
# empty build weigh nothing, so those draws stay the uniform pick, RNG call for call.
enum { CHASER, LOBBER }

const Roster := preload("res://src/combat/roster.gd")
const Nemesis := preload("res://src/combat/nemesis.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const Cards := preload("res://src/world/director_cards.gd")
const RunTier := preload("res://src/core/run_tier.gd")
const PackPressure := preload("res://src/combat/pack_pressure.gd")
const EliteAffixes := preload("res://src/combat/elite_affixes.gd")
const IslandEdge := preload("res://src/combat/island_edge.gd")
const BallastHeavy := preload("res://src/combat/ballast_heavy.gd")
const DIG_WORLD := 2
const StageDefs := preload("res://src/core/stage_defs.gd")
const ParkGraph := preload("res://src/world/park/park_graph.gd")

const KIND_NAMES := ["chaser", "lobber", "mag_trapper", "bola_thrower", "hooker", "plated_brute", "netcaster",
	"deflector", "winch_drone", "gyro_jammer", "swatter", "ramp_flipper", "catch_trap", "reactor_relic",
	"swarm_remnant", "mind_hand", "burrower", "drill_crew", "lamp_swarm", "line_cutter", "anchor_crew",
	"kite_drone", "linker", "foreman", "prop_crew", "pit_jaw", "splitter", "ballast_heavy", "gap_net",
	"dispatcher", "jolt_layer", "boom_tender"]
const COUNTERS := ["mag_trapper", "bola_thrower", "hooker", "plated_brute", "netcaster", "deflector", "winch_drone",
	"gyro_jammer", "swatter", "ramp_flipper", "catch_trap"]
const FAMILY_ANCIENT := ["reactor_relic", "swarm_remnant", "mind_hand"]
const PACKS := {
	"grounded": {"controller": "mag_trapper", "punisher": "bola_thrower", "tests": "heft"},
	"strung": {"controller": "hooker", "punisher": "plated_brute", "tests": "speed"},
	"netted": {"controller": "netcaster", "punisher": "bola_thrower", "tests": "air"},
	"rebound": {"controller": "deflector", "punisher": "chaser", "tests": "contact"},
	"reeled": {"controller": "winch_drone", "punisher": "plated_brute", "tests": "weapon"},
	"wobble": {"controller": "gyro_jammer", "punisher": "swatter", "tests": "steer"},
	"flung": {"controller": "ramp_flipper", "punisher": "lobber", "tests": "steer"},
	"cupped": {"controller": "catch_trap", "punisher": "swatter", "tests": "speed"},
}
const PACK_PER_TICK := 0.12
const PAST_BREAK_STEP := 0.08
const PACK_MAX := 0.6
const UNLOCK_BASE := [2, 4, 6]
const UNLOCK_PER_TICK := 2
const ANCIENT_SHARE := 0.25
const BUILD_TILT := 1.0
const PACK_SPREAD := 4.5
# A habit's share of play and the build axes it leans on; a class adds its own axis.
const HABIT_AXES := {"ram": ["contact", "speed", "heft"], "rebound": ["contact"], "stomp": ["contact", "air"],
	"smash": ["contact"], "vault": ["air"], "weapon": ["weapon"], "special": ["weapon"], "jump": ["air"],
	"air": ["air"], "boost": ["speed", "steer"], "grapple": ["steer"], "glide": ["air"]}
# Keyed by ClassDef id (what fleet.gd build_read() reads from run.class_def.id), one row per
# pilot. 2026-10-17 CLASS-TILT: the wave-3 keys were display names, so no real run ever matched.
# Tarn, Tally and the Cannon are new rows, a design call for Andrew's veto:
#   tarn  contact: claw melee, clamp and rend slam live at arm's length.
#   tally  weapon: the ledger reader and link clips are a caster's aimed fire.
#   remembered_cannon  heft: plate, rush ring and recoil are about mass and holding ground.
const CLASS_AXIS := {"pylon_engineer": "steer", "runner_gunner": "speed", "demolitions_caster": "air",
	"tarn": "contact", "tally": "weapon", "remembered_cannon": "heft"}
# W3's upgrade-tree tags (upgrade_tree.gd TAGS) and the axes each leans on.
const TAG_AXES := {"air": ["air"], "burst": ["weapon"], "close": ["contact"], "ranged": ["weapon"],
	"mobility": ["steer", "speed"], "mounted": ["weapon"], "sustain": ["heft"], "cc_immune": ["speed"],
	"traps": ["contact"], "stealth": ["weapon"]}
const CLASS_AXIS_SHARE := 0.25
const TIER_SECONDS := 45.0
const MAX_TIME_TIERS := 2
const SPIKE_TIERS := 2
const BASE_INTERVAL := 6.5
const MIN_INTERVAL := 1.5
const FIRST_SPAWN := 4.0
const HEFT_CAP_STEP := 2
const HARD_CAP := 24
const ARRIVAL := 1.0
const AHEAD_SHARE := 0.6
const AHEAD_CONE := 0.6108652  # 35 degrees
const AHEAD_RANGE := Vector2(60.0, 90.0)
const FLANK_RANGE := Vector2(45.0, 70.0)
const MIN_GAP := 25.0
# A ballast heavy arrives on the post of a rim within RIM_SEEK of its pack spot, so a ram can
# ring it out (Andrew, "Ring-outs", 2026-10-17); with none in reach it keeps the spot (beached).
const RIM_SEEK := 24.0
const SLOW := 3.0
const TRIES := 8
const HOME_WINDOW := Vector2(60.0, 250.0)
# Past the stage's elite arrival, the chance at elite_rate 1.0 that an authored arrival is the
# elite pack again; never two elites in a row.
const ELITE_REPEAT := 0.1
const PRESSURE_KEYS := ["pack_scale", "interval_scale", "elite_rate", "posture_curve", "boss_phase_scale"]
# Breath as a gameplay setting, keyed by the same option values the music reads. The authored
# PRESSURE rows are the default game: hard (the default) and raw read 1.0 on every key; gentle eases.
const BREATH_NORMAL := {"pack_scale": 1.0, "interval_scale": 1.0, "elite_rate": 1.0, "posture_curve": 1.0, "boss_phase_scale": 1.0}
const BREATH := {
	"raw": BREATH_NORMAL,
	"hard": BREATH_NORMAL,
	"gentle": {"pack_scale": 0.85, "interval_scale": 1.15, "elite_rate": 0.8, "posture_curve": 1.0, "boss_phase_scale": 0.9},
}

var stage_time := 0.0
var mode := "interval"
var _run_tier_reader := Callable()
var credits := 0.0
var credits_accrued := 0.0
var credits_spent := 0.0
var spike := false
# The stage's threat: more enemies alive, arriving sooner, and base enemy HP.
var threat := 1.0
var world := 1
# The run stage (1 to 6) of the row given to use_row(), for the per-stage challenge dials; 0 before
# a row, which reads every by_stage dial as 1.0.
var dial_stage := 0
# Pack pressure B: how many extra chasers the last _place_pack queued (combat/pack_pressure.gd).
var extras_placed := 0
var dial_steps := StageDefs.RUN_TIER_DIAL_STEPS
# From run.heft_class(): a heavier ball earns a bigger crowd to roll through.
var heft_class := 1
var play_rect := Rect2(-150.0, -150.0, 300.0, 300.0)
# The stage's height source (height(x, z)), set by world.gd; null leaves rim placement off.
var terrain = null
# A traversal test needs the stage without the fight in it.
var paused := false
# Spawns whose ground ring is showing: {"kind": int, "at": Vector2, "left": float}.
var arrivals: Array[Dictionary] = []
# The stage (1 to 3), for the unlock base and the ancient family; 0 reads it from the
# threat dial, which stage_defs sets per stage. A row given to use_row() wins over both.
var stage := 0
# The stage row's unlock_base and ancient, once use_row() has been called; {} reads the guess.
var _row := {}
# The stage row's pressure multipliers and the Breath option, set by use_row().
var pressure_row := {}
var breath := ""
# combat's build_read(): {class, habits: {habit: share}, branch_tags: [axis]}.
var build := {}
# Every pack composed, in order: {id, kinds, tests}. For tests and the balance read.
var packs: Array[Dictionary] = []
# The stage table's authored packs ({id, kinds}), its elite pack and the arrival that is the
# elite. Empty `authored` keeps the director's own rules.
var authored: Array = []
var elite := {}
var elite_arrival := 0
# Pack kind names KIND_NAMES lacks, each warned once and never spawned.
var unknown_kinds := {}

var _timer := FIRST_SPAWN
# Breathers (map audit unit 7; breather_rows.gd through ParkMap.breathers()): circles on the riding lines where no
# pack is placed. While the ball is inside one, with no crew home in the window, the timer's packs are banked, up to BANK_MAX, and all fall due the
# moment it leaves (cap() still holds them to the room); credit income keeps accruing. A breather moves pressure later,
# never away (ruling cu). BANK_MAX only stops a ball parked in one from storing a stage's worth: crossing a 120 m
# breather at cruise takes about 6 s, one to four ticks.
const BANK_MAX := 6
var breathers: Array = []
var banked := 0
var _rng := RandomNumberGenerator.new()
var _last_tier := 0
var _rises: Array[int] = []
var _spike_time := 0.0
var _pack_seq := 0
var _arrivals_made := 0
var _elite_packs_made := 0
var _next_pack := {}
var _last_pack_id := ""
var _last_was_elite := false
var homes: Array[Dictionary] = []
var _park_map
var _park_graph
var _graph_path := ""
var _corridors
# read_park results by map id, shared by every director: {"task", "out"} while a worker reads one,
# then {"park"} (SWAP-HITCH-2: the read cost 58 to 85 ms a stage entry).
static var _parks := {}
var _home_sites := {}
var _forward_homes: Array[Dictionary] = []
var _stopped_kinds := {}


# The stage table's say on what a stage sends: the row's own packs, elite and elite arrival win
# over the table's.
func author(def: Dictionary, stages) -> void:
	authored = _packs_of(def, stages)
	elite = _elite_of(def, stages)
	elite_arrival = int(def["elite_arrival"] if def.has("elite_arrival") else stages.elite_arrival())


# Every kind author() hands the director for that row, once each: the packs' in the order they
# name them, then the elite's. What an authored stage can send, for a caller that readies kinds
# before play (BakeWarm). A row with no packs leaves the director to its own rules, and the kinds
# those pick are not named here.
static func kinds_sent(def: Dictionary, stages) -> Array:
	var out := []
	for pack: Dictionary in _packs_of(def, stages) + [_elite_of(def, stages)]:
		for kind in pack.get("kinds", []):
			if not out.has(kind):
				out.append(kind)
	return out


static func _packs_of(def: Dictionary, stages) -> Array:
	return def["packs"] if def.has("packs") else stages.packs()


static func _elite_of(def: Dictionary, stages) -> Dictionary:
	return def["elite"] if def.has("elite") else stages.elite()


func _init(seed_value := 20260922) -> void:
	_rng.seed = seed_value


func set_run_tier_reader(reader: Callable) -> void:
	_run_tier_reader = reader


func run_tier() -> int:
	return int(_run_tier_reader.call()) if _run_tier_reader.is_valid() else 0


func tier() -> int:
	return mini(int(stage_time / TIER_SECONDS), clock_tiers(dial_stage))


# The clock's last tier on a stage: ChallengeDials mobs.clock_tiers_by_stage, MAX_TIME_TIERS for a director
# with no stage row. World 1 climbs to +3 (wave 37 unit D3); the run clock (build/run_clock.gd) reads the same dial.
static func clock_tiers(stage: int) -> int:
	return maxi(0, roundi(ChallengeDials.by_stage_or("mobs.clock_tiers_by_stage", stage, MAX_TIME_TIERS)))


func effective_tier() -> int:
	return tier() + (SPIKE_TIERS if spike else 0)


# The clock has no part in these dials. Tier 0 keeps the original values exactly.
# Every run tier reads the stage threat alone: difficulty never raises enemy health (ruling al, the HARD ladder).
func hp_scale() -> float:
	return threat


func damage_scale() -> float:
	if run_tier() < RunTier.HARD:
		return 1.0
	return minf(RunTier.DAMAGE_DIAL_CAP, 1.0 + world * float(dial_steps.damage))


func rest_scale() -> float:
	if run_tier() < RunTier.HARD:
		return 1.0
	return maxf(RunTier.REST_DIAL_FLOOR, 1.0 - world * float(dial_steps.aggression))


func cap() -> int:
	var base := int(round((6 + effective_tier() * 2) * threat * scale("pack_scale") * ChallengeDials.stage_mult("mobs.pack_scale", dial_stage)))
	if run_tier() != 0:
		base = int(round((6 + effective_tier() * 2) * threat * scale("pack_scale") * ChallengeDials.stage_mult("mobs.pack_scale", dial_stage) * RunTier.row(run_tier()).cap_weight))
	return mini(HARD_CAP, base + HEFT_CAP_STEP * maxi(0, heft_class - 1))


func interval() -> float:
	if run_tier() == 0:
		return maxf(MIN_INTERVAL, (BASE_INTERVAL - effective_tier() * 0.7) / threat * scale("interval_scale") * ChallengeDials.stage_mult("mobs.interval_scale", dial_stage))
	return maxf(MIN_INTERVAL, (BASE_INTERVAL - effective_tier() * 0.7) / threat * scale("interval_scale") * ChallengeDials.stage_mult("mobs.interval_scale", dial_stage) * RunTier.row(run_tier()).interval_weight)


func lobber_share() -> float:
	return clampf(0.15 + effective_tier() * ChallengeDials.by_stage_or("mobs.lobber_share_step_by_stage", dial_stage, 0.07), 0.0, 0.5)


# 0 with nothing alive and nothing coming, 1 at the cap during a beacon spike.
func pressure(alive_count: int) -> float:
	var crowd := clampf(float(alive_count) / float(maxi(1, cap())), 0.0, 1.0)
	return clampf(crowd * 0.7 + (0.3 if spike else 0.0) + minf(0.2, tier() * 0.05), 0.0, 1.0)


# The level threat_rose announces: the effective tier.
func level() -> int:
	return effective_tier()


# Every rise of the level since the last call, in order.
func take_threat_rises() -> Array[int]:
	var out := _rises
	_rises = []
	return out


# Returns the spawns whose arrival ring has run its second: {"kind", "at": Vector2}.
func advance(delta: float, alive_count: int, ball := Vector2.ZERO, velocity := Vector2.ZERO,
		forward := Vector2(0.0, 1.0)) -> Array[Dictionary]:
	stage_time += delta
	_spike_time = _spike_time + delta if spike else 0.0
	var now := effective_tier()
	if now > _last_tier:
		for t in range(_last_tier + 1, now + 1):
			_rises.append(t)
	_last_tier = now
	var due: Array[Dictionary] = []
	for a in arrivals:
		a["left"] -= delta
	for a in arrivals.duplicate():
		if a["left"] <= 0.0:
			arrivals.erase(a)
			if (a["at"] as Vector2).distance_to(ball) >= MIN_GAP and not _kind_stopped(a["kind"]):
				var spawn := {"kind": a["kind"], "at": a["at"]}
				if a.has("affix"):
					spawn["affix"] = a["affix"]
				spawn["pack"] = int(a.get("pack", -1))
				if a.has("rider"):
					spawn["rider"] = true
				if a.has("elite"):
					spawn["elite"] = true
				due.append(spawn)
	if paused:
		return due
	if mode == "credit":
		_credit_advance(delta, alive_count + due.size(), ball, velocity, forward)
		return due
	_timer -= delta
	var ticks := 0
	while _timer <= 0.0:
		_timer += interval()
		ticks += 1
	if _breathing(ball):
		banked = mini(banked + ticks, BANK_MAX)
		return due
	ticks += banked
	banked = 0
	for _i in ticks:
		_timer_pack(alive_count + due.size(), ball, velocity, forward)
	return due


# One timer tick's pack, unless the room is full: an authored arrival, or a pack or a single at spawn_spot. alive is
# every enemy up or falling due this tick.
func _timer_pack(alive: int, ball: Vector2, velocity: Vector2, forward: Vector2) -> void:
	if alive + arrivals.size() >= cap():
		return
	if not authored.is_empty():
		_authored_arrival(cap() - (alive + arrivals.size()), ball, velocity, forward)
		return
	var at := spawn_spot(ball, velocity, forward)
	if at == Vector2.INF:
		return
	var room := cap() - (alive + arrivals.size())
	var weight := reinforcement_weight()
	var pack := compose() if weight > 0.0 and room >= 2 and _rng.randf() < weight else []
	if pack.is_empty():
		var kind := LOBBER if _rng.randf() < lobber_share() else CHASER
		if _park_map == null:
			arrivals.append({"kind": kind, "at": at, "left": ARRIVAL})
		else:
			_place_pack(at, [KIND_NAMES[kind]], ball)
		return
	_place_pack(at, pack, ball, false, room)


func income_per_second() -> float:
	return Cards.I0 * (1.0 + Cards.K * effective_tier())


func credit_pack_cost(kinds: Array, is_elite := false) -> float:
	return Cards.cost(kinds, is_elite)


func _credit_advance(delta: float, alive_count: int, ball: Vector2, velocity: Vector2, forward: Vector2) -> void:
	var room := cap() - alive_count - arrivals.size()
	if room <= 0:
		return
	var income := delta * income_per_second()
	credits += income
	credits_accrued += income
	if _breathing(ball):
		return
	if _next_pack.is_empty():
		_next_pack = _draw_credit()
	if _next_pack.is_empty() or _next_pack.kinds.size() > room:
		return
	while room > 0:
		if _next_pack.is_empty():
			_next_pack = _draw_credit()
		if _next_pack.is_empty():
			return
		var kinds: Array = _next_pack.kinds
		var is_elite: bool = _next_pack == elite
		var price := credit_pack_cost(kinds, is_elite)
		if kinds.size() > room or price > credits:
			return
		var at := spawn_spot(ball, velocity, forward)
		if at == Vector2.INF:
			return
		var first := arrivals.size()
		var queued := _place_pack(at, kinds, ball, is_elite, room)
		if queued == 0:
			return
		var placed := []
		for arrival in arrivals.slice(first):
			placed.append(KIND_NAMES[arrival.kind])
		var spent := credit_pack_cost(placed.slice(0, placed.size() - extras_placed), is_elite)
		credits -= spent
		credits_spent += spent
		packs.append({"id": _next_pack.id, "kinds": placed, "tests": _next_pack.get("tests", "")})
		_last_was_elite = is_elite
		if not is_elite:
			_last_pack_id = _next_pack.id
		_next_pack = {}
		_arrivals_made += 1
		room -= queued


func _draw_credit() -> Dictionary:
	if not elite.is_empty() and elite_arrival > 0:
		if _arrivals_made + 1 == elite_arrival:
			return elite
		if _arrivals_made + 1 > elite_arrival and not _last_was_elite and _rng.randf() < ELITE_REPEAT * scale("elite_rate") * ChallengeDials.stage_mult("mobs.elite_rate", dial_stage):
			return elite
	var choices: Array = authored
	var weights := {}
	if choices.is_empty():
		choices = [{"id": "chaser", "kinds": ["chaser"]}, {"id": "lobber", "kinds": ["lobber"]}]
		var share := reinforcement_weight()
		weights = {"chaser": (1.0 - share) * (1.0 - lobber_share()), "lobber": (1.0 - share) * lobber_share()}
		var open := open_packs()
		for id in open:
			var pack: Dictionary = PACKS[id]
			choices.append({"id": id, "kinds": [pack.controller, pack.punisher], "tests": pack.tests})
			weights[id] = share * (1.0 - ANCIENT_SHARE) * pack_weight(id) / open.size()
		if effective_tier() > 0:
			var ancient := _ancient()
			choices.append({"id": ancient, "kinds": [ancient], "tests": "ancient"})
			weights[ancient] = share * ANCIENT_SHARE
	var pool := choices if authored.is_empty() else choices.filter(func(p: Dictionary) -> bool: return p.id != _last_pack_id)
	if pool.is_empty():
		pool = choices
	var lean := _nemesis_weights(pool) if not authored.is_empty() else {}
	for id in lean:
		weights[id] = lean[id]
	var total := 0.0
	for pack in pool:
		total += Cards.weight(pack.kinds) * float(weights.get(pack.id, 1.0))
	if total <= 0.0:
		return {}
	var pick := _rng.randf() * total
	for pack in pool:
		pick -= Cards.weight(pack.kinds) * float(weights.get(pack.id, 1.0))
		if pick < 0.0:
			return pack
	return pool[-1]


# One pack's members side by side across the line from the ball, on one ring timer.
# room: the cap's room the caller checked the pack against; pack pressure B's extra chasers fit inside it.
func _place_pack(at: Vector2, kinds: Array, ball: Vector2, is_elite := false, room := 0) -> int:
	# Pack pressure B (pack_pressure.gd; 0 without --pack-pressure): extra chasers join a crew, last, as far as
	# the room allows. extras_placed tells the credit path not to charge for them.
	extras_placed = 0
	var extra := mini(PackPressure.crew_extra(dial_stage), room - kinds.size())
	if extra > 0 and kinds.size() >= 2:
		kinds = kinds.duplicate()
		for _i in extra:
			kinds.append("chaser")
	else:
		extra = 0
	var queued := 0
	var affixed := false
	var heading := (at - ball).normalized() if at.distance_to(ball) > 0.1 else Vector2.RIGHT
	var side := Vector2(-heading.y, heading.x)
	var riders := {}
	var home_spots := _home_pack_spots(kinds, ball, side, riders) if _park_map != null and not _forward_homes.is_empty() else {}
	var assigned: Array[Vector2] = []
	for i in kinds.size():
		var kind := KIND_NAMES.find(kinds[i])
		if kind == -1:
			if not unknown_kinds.has(kinds[i]):
				unknown_kinds[kinds[i]] = true
				push_warning("director: pack kind %s is not an enemy; skipped" % kinds[i])
			continue
		if not Roster.built(kinds[i]):
			if not unknown_kinds.has(kinds[i]):
				unknown_kinds[kinds[i]] = true
				push_warning("director: pack kind %s is not built yet; skipped" % kinds[i])
			continue
		var spot: Vector2 = at + side * PACK_SPREAD * (i - (kinds.size() - 1) * 0.5)
		spot.x = clampf(spot.x, play_rect.position.x, play_rect.end.x)
		spot.y = clampf(spot.y, play_rect.position.y, play_rect.end.y)
		if kinds[i] == "ballast_heavy":
			spot = rim_spot(spot, ball)
		if _park_map != null:
			if _kind_stopped(kind):
				continue
			if not _forward_homes.is_empty():
				spot = home_spots.get(i, Vector2.INF)
			if spot == Vector2.INF or not _park_safe(spot) or spot.distance_to(ball) < MIN_GAP or not _pack_gap(spot, assigned):
				continue
		var arrival := {"kind": kind, "at": spot, "left": ARRIVAL, "pack": _pack_seq}
		if is_elite:
			arrival["elite"] = true
		if riders.has(i):
			arrival["rider"] = true
		if is_elite and run_tier() >= RunTier.HARD and kinds[i] == "plated_brute":
			arrival["affix"] = EliteAffixes.for_arrival(_elite_packs_made)
			affixed = true
		elif is_elite and world == DIG_WORLD:
			arrival["affix"] = EliteAffixes.PLATED
		arrivals.append(arrival)
		assigned.append(spot)
		queued += 1
		if extra > 0 and i >= kinds.size() - extra:
			extras_placed += 1
	if _park_map == null or queued > 0:
		_pack_seq += 1
	if affixed:
		_elite_packs_made += 1
	return queued


# The post of the nearest rim to `spot` that stays in the play rect and MIN_GAP from the ball,
# where a ballast heavy stands (ballast_heavy.gd); `spot` itself when there is none.
func rim_spot(spot: Vector2, ball: Vector2) -> Vector2:
	if terrain == null:
		return spot
	var at := Vector3(spot.x, terrain.height(spot.x, spot.y), spot.y)
	for rim in IslandEdge.rims(terrain, at, RIM_SEEK, BallastHeavy.RIM_DROP):
		var post: Vector3 = (rim["at"] as Vector3) - (rim["dir"] as Vector3) * BallastHeavy.POST_IN
		var flat := Vector2(post.x, post.z)
		if play_rect.has_point(flat) and flat.distance_to(ball) >= MIN_GAP:
			return flat
	return spot


# An authored arrival: the pack due next waits until the cap has room for all of it.
func _authored_arrival(room: int, ball: Vector2, velocity: Vector2, forward: Vector2) -> void:
	if _next_pack.is_empty():
		_next_pack = _draw_authored()
	var kinds: Array = _next_pack["kinds"]
	if room < kinds.size():
		return
	var at := spawn_spot(ball, velocity, forward)
	if at == Vector2.INF:
		return
	var queued := _place_pack(at, kinds, ball, _next_pack == elite, room)
	if _park_map != null and queued == 0:
		return
	packs.append({"id": _next_pack["id"], "kinds": kinds.duplicate(), "tests": ""})
	_last_was_elite = _next_pack == elite
	if not _last_was_elite:
		_last_pack_id = _next_pack["id"]
	_next_pack = {}
	_arrivals_made += 1


func _draw_authored() -> Dictionary:
	if not elite.is_empty() and elite_arrival > 0 and _arrivals_made + 1 == elite_arrival:
		return elite
	if not elite.is_empty() and elite_arrival > 0 and _arrivals_made + 1 > elite_arrival \
			and not _last_was_elite and _rng.randf() < ELITE_REPEAT * scale("elite_rate") * ChallengeDials.stage_mult("mobs.elite_rate", dial_stage):
		return elite
	var pool := authored.filter(func(p: Dictionary) -> bool: return p["id"] != _last_pack_id)
	if pool.is_empty():
		pool = authored
	var lean := _nemesis_weights(pool)
	if lean.is_empty():
		return pool[_rng.randi_range(0, pool.size() - 1)]
	var total := 0.0
	for pack in pool:
		total += float(lean.get(pack["id"], 1.0))
	var pick := _rng.randf() * total
	for pack in pool:
		pick -= float(lean.get(pack["id"], 1.0))
		if pick < 0.0:
			return pack
	return pool[-1]


# {pack id: Nemesis.PACK_WEIGHT} for the pool's packs that press the pilot's nemesis axis, or {}
# when none do (world one, no class, or no matching pack): callers then keep the uniform pick.
func _nemesis_weights(pool: Array) -> Dictionary:
	var lean := {}
	if world < Nemesis.FROM_WORLD:
		return lean
	var class_id := String(build.get("class", ""))
	if Nemesis.of(class_id).is_empty():
		return lean
	for pack in pool:
		if Nemesis.pack_presses(class_id, pack.get("kinds", [])):
			lean[pack["id"]] = Nemesis.PACK_WEIGHT
	return lean


# --- v2 W7 enemies: pack composition -------------------------------------------------

# The world hands the director the stage's table row on stage entry: its counter unlock
# level and its ancient enemy come from the row, so a stage past the third reads its own. The
# row's pressure and the Breath option scale the pacing (scale()).
func use_row(row: Dictionary, breath_option := "", tier_reader := Callable()) -> void:
	if tier_reader.is_valid():
		set_run_tier_reader(tier_reader)
	row = RunTier.stage_row(row, run_tier())
	world = int(row.get("world", 1))
	dial_stage = int(row.get("stage", 0))
	_row = {}
	if row.has("unlock_base") and row.has("ancient"):
		_row = {"unlock_base": int(row["unlock_base"]), "ancient": String(row["ancient"])}
	pressure_row = row.get("pressure", {})
	breath = breath_option
	_read_homes(String(row.get("map", "")))


func _read_homes(map_id: String) -> void:
	homes.clear()
	_home_sites.clear()
	_stopped_kinds.clear()
	_forward_homes.clear()
	_park_map = null
	breathers = []
	_park_graph = null
	_corridors = null
	_graph_path = ""
	var park := _park_for(map_id)
	if park.is_empty():
		return
	var map = park.map
	_park_map = map
	breathers = map.breathers()
	for row in map.park.park_rows:
		_home_sites[row.id] = row
	for row in map.park.home_rows:
		var home: Dictionary = row.duplicate(true)
		home.broken = false
		homes.append(home)
	# The graph is the game's shared copy (Activities.shared_graph), taken on first use: by then
	# activities has adopted the one its worker read for this map, so the entry reads none.
	var graph_path := "res://assets/park/%s/graph.bin" % map_id
	if FileAccess.file_exists(graph_path):
		_graph_path = graph_path
	_corridors = park.corridors


# A park map's parsed rows and its corridor reader (KE1 owns both the pilot-line reader and the
# corridor clearance), read once a process and read-only after: {"map", "corridors"}, or {} for a
# map that is not a park or fails its schema. Pure, so a worker can read it (prepare_park).
static func read_park(map_id: String) -> Dictionary:
	var path := "res://src/world/park/%s.json" % map_id
	if not map_id.begins_with("park_") or not FileAccess.file_exists(path):
		return {}
	# Runtime loads avoid the schema's preload of Director forming a cycle.
	var map = load("res://src/world/park/park_map.gd").new(path)
	if not map.ok:
		return {}
	return {"map": map, "corridors": load("res://src/world/event_director.gd").new(0, {}, map, 0.0, Callable())}


# Starts a worker reading a park map the game will enter (activities.gd asks for the next stage's).
static func prepare_park(map_id: String) -> void:
	if _parks.has(map_id) or not map_id.begins_with("park_"):
		return
	# The schema's registry and the recipes' origins fill lazily and set their read flag first, so
	# the main thread fills them before a worker can be their first reader.
	load("res://src/world/park/park_schema.gd")._registry()
	load("res://src/world/park/park_recipes.gd").origin("")
	var out := {}
	_parks[map_id] = {"task": WorkerThreadPool.add_task(func(): out.merge(read_park(map_id)), false, "director park " + map_id), "out": out}


static func _park_for(map_id: String) -> Dictionary:
	settle_park(map_id)
	if not _parks.has(map_id):
		_parks[map_id] = {"park": read_park(map_id)}
	return _parks[map_id].park


# Waits once on a park read still running, so the read is never waited on twice or left open.
static func settle_park(map_id: String) -> void:
	if _parks.has(map_id) and _parks[map_id].has("task"):
		WorkerThreadPool.wait_for_task_completion(_parks[map_id].task)
		_parks[map_id] = {"park": _parks[map_id].out, "worker": true}


static func settle_parks() -> void:
	for map_id in _parks.keys():
		settle_park(map_id)


# Teardown: waits on every read, then lets the parsed maps go with the Game.
static func release_parks() -> void:
	settle_parks()
	_parks.clear()


var _rib_graph = null
var _rib_zones := {}


func _graph():
	if _park_graph == null and _graph_path != "":
		_park_graph = load("res://src/world/activities.gd").shared_graph(_graph_path)
		_graph_path = ""
	return _park_graph


# Grey panels' rib read (IL-01, the map veto pass's ribs and pockets): 1 where `at` stands
# in an off-spine dead end, a graph anchor zone (one way in) that holds no line or Warden
# node, or in the zone of a park row tagged "off_spine": true; 0 elsewhere; -1 when the stage
# has no zone data (no graph, or a version 1 graph), so the caller pays the plain rate and logs
# the case rather than guessing. The tag holds whatever the graph reads (ruling bd): a terrain
# fix that opens a way into a tagged row's zone does not change what its kills pay.
func off_spine(at: Vector3) -> int:
	var graph = _graph()
	if graph == null or graph.zone_count() == 0:
		return -1
	if not is_same(_rib_graph, graph):
		_rib_graph = graph
		_rib_zones = {}
		for anchor in graph.anchors():
			if not anchor["on_route"]:
				_rib_zones[int(anchor["zone"])] = true
		for row in tagged_off_spine(_park_map.park if _park_map != null else {}):
			_rib_zones[graph.zone_of(graph.nearest(Vector2(float(row["at"][0]), float(row["at"][1]))))] = true
	return 1 if _rib_zones.has(graph.zone_of(graph.nearest(at))) else 0


# The park's rows tagged "off_spine": true.
static func tagged_off_spine(park: Dictionary) -> Array:
	return park.get("park_rows", []).filter(func(row): return row.get("off_spine", false) == true)


# Grey panels' rib caches (IL-01, coordinator ruling 23 Oct: exploring pays): up to `count`
# spots, one per off-route dead end with door ground (anchors() rank > 0), drawn without
# repeats from a stream seeded by `seed`. Each spot is the zone's door node furthest from the
# spawn: the end of the dead end. The draw takes dead ends a player hunting the park would roll
# into first: at most RIB_DETOUR_MAX_M over the drop-in to landmark path, and at least
# RIB_LANDMARK_CLEAR_M of path short of the landmark (a cache in the Warden's yard is met on the
# way out of the fight, not found). On the flume half the dead ends are the outer washes,
# 500 to 1,300 m off the line, where a 14 m column and a 45 m chime reach nobody: no bot or player
# run took a cache there (25 Oct, seeds 1-4). A door node on a line or a grind line's deck (the
# siphon span's trough, 40 m over the wash) is never the spot: the explorer stood under that cache. A map with too few
# such ends tops up from the rest, least detour first. Empty where the map has no graph.
# A dead end counts once it has RIB_MIN_DOORS door nodes, per park (ruling az, 30 Oct): the flume's
# near ends are small benches and pockets of 3 to 15 door nodes, so at the graph's own 16 only three
# far-west ends qualified and every seed drew the same three (the explorer took 2 of 51).
const RIB_DETOUR_MAX_M := 300.0
const RIB_LANDMARK_CLEAR_M := 120.0
const RIB_MIN_DOORS := {"park_flume": 3}


func rib_cache_spots(count: int, seed: int) -> Array[Vector3]:
	var graph = _graph()
	if graph == null or graph.zone_count() == 0:
		return [] as Array[Vector3]
	var spawn := Vector2.INF
	var park := {}
	if _park_map != null:
		park = _park_map.park
		spawn = Vector2(float(park.spawn.at[0]), float(park.spawn.at[1]))
	return rib_spots(graph, spawn, count, seed, grind_rows(park), rib_min_doors(String(park.get("map", ""))))


# The door nodes a dead end needs to hold a rib cache on this park (RIB_MIN_DOORS, else the graph's own).
static func rib_min_doors(map_id: String) -> int:
	return int(RIB_MIN_DOORS.get(map_id, ParkGraph.ANCHOR_MIN_DOOR_NODES))


# The park's grind lines by row id: their decks are ridden, not stood on.
static func grind_rows(park: Dictionary) -> Dictionary:
	var out := {}
	for row in park.get("park_rows", []):
		if String(row.get("element", "")) == "grind_line":
			out[String(row.get("id", ""))] = true
	return out


# rib_cache_spots on a given park graph, the drop-in at `spawn` (INF: no detour rule), never on a
# node of a line or of a deck in `grind` (grind_rows), on off-route dead ends of `min_doors` door nodes
# or more.
static func rib_spots(graph, spawn: Vector2, count: int, seed: int, grind := {},
		min_doors := ParkGraph.ANCHOR_MIN_DOOR_NODES) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var direct: float = graph.d_landmark(spawn) if spawn != Vector2.INF else INF
	var pool := []
	var rest := []
	for anchor in graph.anchors():
		if anchor["on_route"] or int(anchor["door_nodes"]) < min_doors:
			continue
		var best := -1
		var best_d := -1.0
		for node in graph.zone_door_nodes(int(anchor["zone"])):
			var d: float = graph.d_spawn_node(node)
			if is_finite(d) and d > best_d and not off_ground(graph, node, grind):
				best_d = d
				best = node
		if best < 0:
			continue
		var land: float = graph.d_landmark_node(best)
		var detour: float = best_d + land - direct
		if detour <= RIB_DETOUR_MAX_M and land >= RIB_LANDMARK_CLEAR_M:
			pool.append(best)
		else:
			rest.append([detour, best])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	while out.size() < count and not pool.is_empty():
		out.append(graph.position(pool.pop_at(rng.randi_range(0, pool.size() - 1))))
	rest.sort_custom(func(a, b): return a[0] < b[0])
	for r in rest:
		if out.size() >= count:
			break
		out.append(graph.position(r[1]))
	return out


static func off_ground(graph, node: int, grind: Dictionary) -> bool:
	return "line" in graph.flag_names(node) or grind.has(graph.node_row(node))


func home_live(id: String) -> bool:
	for home in homes:
		if home.id == id:
			return not home.broken and not home.dormant
	return false


func break_home(id: String) -> bool:
	for home in homes:
		if home.id != id or home.broken:
			continue
		home.broken = true
		if home.stops_kind:
			_stopped_kinds[home.enemy] = true
			for arrival in arrivals.duplicate():
				if _kind_stopped(arrival.kind):
					arrivals.erase(arrival)
		return true
	return false


func activate_home(id: String) -> bool:
	for home in homes:
		if home.id == id and not home.broken:
			home.dormant = false
			return true
	return false


func _kind_stopped(kind: int) -> bool:
	return _stopped_kinds.has(KIND_NAMES[kind])


func _home_at(home: Dictionary) -> Vector2:
	var at: Array = _home_sites[home.site].at
	return Vector2(float(at[0]), float(at[1]))


func _ahead(at: Vector2, ball: Vector2) -> bool:
	var graph = _graph()
	if graph == null:
		return false
	var ahead: float = graph.d_landmark(ball) - graph.d_landmark(at)
	return is_finite(ahead) and ahead >= HOME_WINDOW.x and ahead <= HOME_WINDOW.y


func _window_homes(ball: Vector2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for home in homes:
		if home_live(home.id) and not _stopped_kinds.has(home.enemy) and _ahead(_home_at(home), ball):
			out.append(home)
	return out



# `riders` gains each member placed only because it rides with a housed crew (no home of its
# own in the window); the Warden clamp counts that crew without them (stage_locks.gd).
func _home_pack_spots(kinds: Array, ball: Vector2, side: Vector2, riders := {}) -> Dictionary:
	var spots := {}
	var assigned: Array[Vector2] = []
	var crew_home := {}
	for home in _forward_homes:
		var indices: Array[int] = []
		for i in kinds.size():
			var kind := KIND_NAMES.find(kinds[i])
			if not spots.has(i) and kinds[i] == home.enemy and kind >= 0 and Roster.built(kinds[i]) and not _kind_stopped(kind):
				indices.append(i)
		if indices.is_empty():
			continue
		var site: Dictionary = _home_sites[home.site]
		var half: Vector2 = _park_map.footprint_half_extents(site)
		var group := {}
		for attempt in TRIES * 4:
			var offset := Vector2.ZERO if attempt == 0 else Vector2(_rng.randf_range(-half.x, half.x), _rng.randf_range(-half.y, half.y))
			var anchor := _home_at(home) + offset.rotated(-deg_to_rad(float(site.yaw_deg)))
			var occupied := assigned.duplicate()
			group.clear()
			for i in indices:
				var spot := anchor + side * PACK_SPREAD * (i - (kinds.size() - 1) * 0.5)
				if not _home_point_safe(site, spot, ball, occupied):
					break
				group[i] = spot
				occupied.append(spot)
			if group.size() == indices.size():
				break
		if group.size() == indices.size():
			for i in indices:
				spots[i] = group[i]
				assigned.append(group[i])
		else:
			for i in indices:
				var offset := side * PACK_SPREAD * (i - (kinds.size() - 1) * 0.5)
				var spot := _home_spot(home, ball, offset, assigned)
				if spot != Vector2.INF:
					spots[i] = spot
					assigned.append(spot)
		if crew_home.is_empty() and indices.any(func(i: int) -> bool: return spots.has(i)):
			crew_home = home
	# A member whose kind has no home in the window rides with the crew from the crew's home
	# (the first window home when the whole pack is homeless), never stripped from it.
	var housed_crew := not crew_home.is_empty()
	if not housed_crew:
		crew_home = _forward_homes[0]
	var housed := {}
	for home in _forward_homes:
		housed[home.enemy] = true
	for i in kinds.size():
		var kind := KIND_NAMES.find(kinds[i])
		if spots.has(i) or housed.has(kinds[i]) or kind < 0 or not Roster.built(kinds[i]) or _kind_stopped(kind):
			continue
		var offset := side * PACK_SPREAD * (i - (kinds.size() - 1) * 0.5)
		var spot := _home_spot(crew_home, ball, offset, assigned)
		if spot != Vector2.INF:
			spots[i] = spot
			assigned.append(spot)
			if housed_crew:
				riders[i] = true
	return spots


func _pack_gap(spot: Vector2, assigned: Array[Vector2]) -> bool:
	for other in assigned:
		if spot.distance_to(other) < PACK_SPREAD - 0.0001:
			return false
	return true


func _home_point_safe(site: Dictionary, spot: Vector2, ball: Vector2, assigned: Array[Vector2]) -> bool:
	return play_rect.has_point(spot) and _park_map.footprint_contains(site, spot) and _ahead(spot, ball) \
		and spot.distance_to(ball) >= MIN_GAP and _park_safe(spot) and _pack_gap(spot, assigned)


func _home_spot(home: Dictionary, ball: Vector2, preferred := Vector2.ZERO, assigned: Array[Vector2] = []) -> Vector2:
	var site: Dictionary = _home_sites[home.site]
	var half: Vector2 = _park_map.footprint_half_extents(site)
	for i in TRIES * 4:
		var offset := Vector2.ZERO if i == 0 else Vector2(_rng.randf_range(-half.x, half.x), _rng.randf_range(-half.y, half.y))
		var spot := _home_at(home) + preferred + offset.rotated(-deg_to_rad(float(site.yaw_deg)))
		if _home_point_safe(site, spot, ball, assigned):
			return spot
	return Vector2.INF


# Whether the ball's free packs wait: it is inside a breather and no live crew home is in the window ahead. A crew home
# is an authored fight the map places (and park_breath_test measures); a breather quiets only the director's own packs.
func _breathing(ball: Vector2) -> bool:
	return in_breather(ball) and (_park_map == null or _window_homes(ball).is_empty())


# Whether `p` stands inside one of the stage's breathers.
func in_breather(p: Vector2) -> bool:
	for b in breathers:
		if p.distance_to(b["at"]) <= float(b["radius_m"]):
			return true
	return false


func _park_safe(spot: Vector2) -> bool:
	if in_breather(spot):
		return false
	for line in _corridors._park_pilot_lines:
		for i in range(1, line.size()):
			# A point footprint uses ParkMap's same segment/margin predicate as KE1.
			var point := {"at": [spot.x, spot.y], "size": [0.0, 0.0, 0.0], "yaw_deg": 0.0}
			if _park_map.footprint_contains(point, line[i - 1], _corridors.PARK_CORRIDOR_M, line[i]):
				return false
	return true


# One pressure key's multiplier: the stage row's times the Breath row's, 1.0 where either is silent.
func scale(key: String) -> float:
	var breath_row: Dictionary = BREATH.get(breath, BREATH_NORMAL)
	return float(pressure_row.get(key, 1.0)) * float(breath_row.get(key, 1.0))


func _unlock_base() -> int:
	if not _row.is_empty():
		return _row["unlock_base"]
	return UNLOCK_BASE[stage_now() - 1]


func _ancient() -> String:
	if not _row.is_empty():
		return _row["ancient"]
	return FAMILY_ANCIENT[stage_now() - 1]


func stage_now() -> int:
	if stage > 0:
		return clampi(stage, 1, 3)
	if threat <= 1.1:
		return 1
	return 2 if threat <= 1.6 else 3


# Ticks past the Warden break: counted from the moment the spike came on, the first at
# once. 0 while the spike is off.
func past_break_ticks() -> int:
	return int(_spike_time / TIER_SECONDS) + 1 if spike else 0


# The share of spawn slots that become packs: 0 at tick 0, the clock's gate.
func reinforcement_weight() -> float:
	var ticks := effective_tier()
	if ticks <= 0:
		return 0.0
	return clampf(PACK_PER_TICK * scale("pack_scale") * ChallengeDials.stage_mult("mobs.pack_scale", dial_stage) * ticks + PAST_BREAK_STEP * past_break_ticks(), 0.0, PACK_MAX)


func unlocked_counters() -> Array:
	var n := clampi(_unlock_base() + UNLOCK_PER_TICK * effective_tier(), 0, COUNTERS.size())
	return COUNTERS.slice(0, n)


# The tagged packs whose members are all unlocked now.
func open_packs() -> Array:
	var unlocked := unlocked_counters()
	var out := []
	for id in PACKS:
		var row: Dictionary = PACKS[id]
		var ok := true
		for role in ["controller", "punisher"]:
			var kind: String = row[role]
			ok = ok and (not kind in COUNTERS or kind in unlocked)
		if ok:
			out.append(id)
	return out


# How strongly the build leans on each axis, 0 to 1 (the strongest is 1).
func build_axes() -> Dictionary:
	var axes := {}
	var habits: Dictionary = build.get("habits", {})
	for habit in habits:
		for axis in HABIT_AXES.get(habit, []):
			axes[axis] = float(axes.get(axis, 0.0)) + float(habits[habit])
	var class_axis: String = CLASS_AXIS.get(String(build.get("class", "")), "")
	if class_axis != "":
		axes[class_axis] = float(axes.get(class_axis, 0.0)) + CLASS_AXIS_SHARE
	for tag in build.get("branch_tags", []):
		for axis in TAG_AXES.get(String(tag), [String(tag)]):
			axes[axis] = float(axes.get(axis, 0.0)) + CLASS_AXIS_SHARE
	var top := 0.0
	for axis in axes:
		top = maxf(top, float(axes[axis]))
	if top > 0.0:
		for axis in axes:
			axes[axis] = float(axes[axis]) / top
	return axes


func pack_weight(id: String, axes := build_axes()) -> float:
	return 1.0 + BUILD_TILT * float(axes.get(PACKS[id]["tests"], 0.0))


# One pack's kinds: the stage's ancient, or a tagged controller-and-punisher pair drawn
# by build weight. Empty when nothing is unlocked yet.
func compose() -> Array:
	var open := open_packs()
	if open.is_empty() and effective_tier() <= 0:
		return []
	if open.is_empty() or _rng.randf() < ANCIENT_SHARE:
		var ancient: String = _ancient()
		packs.append({"id": ancient, "kinds": [ancient], "tests": "ancient"})
		return [ancient]
	var axes := build_axes()
	var total := 0.0
	for id in open:
		total += pack_weight(id, axes)
	var pick := _rng.randf() * total
	var chosen: String = open[-1]
	for id in open:
		pick -= pack_weight(id, axes)
		if pick <= 0.0:
			chosen = id
			break
	var row: Dictionary = PACKS[chosen]
	var kinds := [row["controller"], row["punisher"]]
	packs.append({"id": chosen, "kinds": kinds, "tests": row["tests"]})
	return kinds


func spawn_spot(ball: Vector2, velocity: Vector2, forward: Vector2) -> Vector2:
	if _park_map != null:
		_forward_homes = _window_homes(ball)
		if not _forward_homes.is_empty():
			for home in _forward_homes:
				var at := _home_spot(home, ball)
				if at != Vector2.INF:
					return at
			return Vector2.INF
	var heading := velocity.normalized() if velocity.length() > SLOW else forward.normalized()
	var ahead := _rng.randf() < AHEAD_SHARE
	for i in TRIES:
		var angle: float
		var dist: float
		if ahead:
			angle = _rng.randf_range(-AHEAD_CONE, AHEAD_CONE)
			dist = _rng.randf_range(AHEAD_RANGE.x, AHEAD_RANGE.y)
		else:
			angle = _rng.randf_range(AHEAD_CONE, PI) * (1.0 if _rng.randf() < 0.5 else -1.0)
			dist = _rng.randf_range(FLANK_RANGE.x, FLANK_RANGE.y)
		var spot := ball + heading.rotated(angle) * dist
		spot.x = clampf(spot.x, play_rect.position.x, play_rect.end.x)
		spot.y = clampf(spot.y, play_rect.position.y, play_rect.end.y)
		if spot.distance_to(ball) >= MIN_GAP and (_park_map == null or _park_safe(spot)):
			return spot
	return Vector2.INF
