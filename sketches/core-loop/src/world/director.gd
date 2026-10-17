extends RefCounted

# The spawn director: pure scheduling with no node of its own. The stage hands it a
# delta, the live enemy count and where the ball is going, and gets due spawns back.
# A headless test steps a whole stage in a loop instead of in real seconds.
#
# Honesty rules (demo spec, Director honesty):
# - Tier 0 enemy HP comes from stage threat only. The opt-in run tier adds capped
#   per-world health, damage and rest dials; the clock never toughens an enemy.
# - The clock's tier is clamped at +2, and every rise, the beacon spike included, is
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
# - HP reads stage threat and the opt-in world's health dial; the clock adds packs,
#   never toughness.
#
# Authored packs (slice table): with `authored` set, every arrival is one whole pack from
# that list and nothing else spawns: no single draws, no unlock clock, no build tilt, no
# ancient share. Packs are drawn uniformly and never the same twice in a row; the
# `elite_arrival`-th arrival is the `elite` pack, once. Pacing stays the director's own, and
# a pack arrives only when the cap has room for all of it.
#
# Pressure (GP3): the stage row's "pressure" (alpha_defs.gd PRESSURE) times the Breath row
# (BREATH, keyed by the tuning's breath option) multiplies the constants below, never replaces
# them: pack_scale the crowd cap and pack share, interval_scale the spawn interval, elite_rate
# the chance a later authored arrival is the elite again. A row with no pressure reads 1.0.
enum { CHASER, LOBBER }

const Roster := preload("res://src/combat/roster.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const Cards := preload("res://src/world/director_cards.gd")
const RunTier := preload("res://src/core/run_tier.gd")
const EliteAffixes := preload("res://src/combat/elite_affixes.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")

const KIND_NAMES := ["chaser", "lobber", "mag_trapper", "bola_thrower", "hooker", "plated_brute", "netcaster",
	"deflector", "winch_drone", "gyro_jammer", "swatter", "ramp_flipper", "catch_trap", "reactor_relic",
	"swarm_remnant", "mind_hand", "burrower", "drill_crew", "lamp_swarm", "line_cutter", "anchor_crew",
	"kite_drone"]
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
var dial_steps := StageDefs.RUN_TIER_DIAL_STEPS
# From run.heft_class(): a heavier ball earns a bigger crowd to roll through.
var heft_class := 1
var play_rect := Rect2(-150.0, -150.0, 300.0, 300.0)
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


func _init(seed_value := 20260922) -> void:
	_rng.seed = seed_value


func set_run_tier_reader(reader: Callable) -> void:
	_run_tier_reader = reader


func run_tier() -> int:
	return int(_run_tier_reader.call()) if _run_tier_reader.is_valid() else 0


func tier() -> int:
	return mini(int(stage_time / TIER_SECONDS), MAX_TIME_TIERS)


func effective_tier() -> int:
	return tier() + (SPIKE_TIERS if spike else 0)


# The clock has no part in these dials. Tier 0 keeps the original values exactly.
func hp_scale() -> float:
	if run_tier() < RunTier.HARD:
		return threat
	return threat * minf(RunTier.HEALTH_DIAL_CAP, 1.0 + world * float(dial_steps.health))


func damage_scale() -> float:
	if run_tier() < RunTier.HARD:
		return 1.0
	return minf(RunTier.DAMAGE_DIAL_CAP, 1.0 + world * float(dial_steps.damage))


func rest_scale() -> float:
	if run_tier() < RunTier.HARD:
		return 1.0
	return maxf(RunTier.REST_DIAL_FLOOR, 1.0 - world * float(dial_steps.aggression))


func cap() -> int:
	var base := int(round((6 + effective_tier() * 2) * threat * scale("pack_scale")))
	if run_tier() != 0:
		base = int(round((6 + effective_tier() * 2) * threat * scale("pack_scale") * RunTier.row(run_tier()).cap_weight))
	return mini(HARD_CAP, base + HEFT_CAP_STEP * maxi(0, heft_class - 1))


func interval() -> float:
	if run_tier() == 0:
		return maxf(MIN_INTERVAL, (BASE_INTERVAL - effective_tier() * 0.7) / threat * scale("interval_scale"))
	return maxf(MIN_INTERVAL, (BASE_INTERVAL - effective_tier() * 0.7) / threat * scale("interval_scale") * RunTier.row(run_tier()).interval_weight)


func lobber_share() -> float:
	return clampf(0.15 + effective_tier() * 0.07, 0.0, 0.5)


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
				due.append(spawn)
	if paused:
		return due
	if mode == "credit":
		_credit_advance(delta, alive_count + due.size(), ball, velocity, forward)
		return due
	_timer -= delta
	while _timer <= 0.0:
		_timer += interval()
		if alive_count + arrivals.size() + due.size() >= cap():
			continue
		if not authored.is_empty():
			_authored_arrival(cap() - (alive_count + arrivals.size() + due.size()), ball, velocity, forward)
			continue
		var at := spawn_spot(ball, velocity, forward)
		if at == Vector2.INF:
			continue
		var room := cap() - (alive_count + arrivals.size() + due.size())
		var weight := reinforcement_weight()
		var pack := compose() if weight > 0.0 and room >= 2 and _rng.randf() < weight else []
		if pack.is_empty():
			var kind := LOBBER if _rng.randf() < lobber_share() else CHASER
			if _park_map == null:
				arrivals.append({"kind": kind, "at": at, "left": ARRIVAL})
			else:
				_place_pack(at, [KIND_NAMES[kind]], ball)
			continue
		_place_pack(at, pack, ball)
	return due


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
		var queued := _place_pack(at, kinds, ball, is_elite)
		if queued == 0:
			return
		var placed := []
		for arrival in arrivals.slice(first):
			placed.append(KIND_NAMES[arrival.kind])
		var spent := credit_pack_cost(placed, is_elite)
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
		if _arrivals_made + 1 > elite_arrival and not _last_was_elite and _rng.randf() < ELITE_REPEAT * scale("elite_rate"):
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
func _place_pack(at: Vector2, kinds: Array, ball: Vector2, is_elite := false) -> int:
	var queued := 0
	var affixed := false
	var heading := (at - ball).normalized() if at.distance_to(ball) > 0.1 else Vector2.RIGHT
	var side := Vector2(-heading.y, heading.x)
	var home_spots := _home_pack_spots(kinds, ball, side) if _park_map != null and not _forward_homes.is_empty() else {}
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
		if _park_map != null:
			if _kind_stopped(kind):
				continue
			if not _forward_homes.is_empty():
				spot = home_spots.get(i, Vector2.INF)
			if spot == Vector2.INF or not _park_safe(spot) or spot.distance_to(ball) < MIN_GAP or not _pack_gap(spot, assigned):
				continue
		var arrival := {"kind": kind, "at": spot, "left": ARRIVAL, "pack": _pack_seq}
		if is_elite and run_tier() >= RunTier.HARD and kinds[i] == "plated_brute":
			arrival["affix"] = EliteAffixes.for_arrival(_elite_packs_made)
			affixed = true
		arrivals.append(arrival)
		assigned.append(spot)
		queued += 1
	if _park_map == null or queued > 0:
		_pack_seq += 1
	if affixed:
		_elite_packs_made += 1
	return queued


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
	var queued := _place_pack(at, kinds, ball, _next_pack == elite)
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
			and not _last_was_elite and _rng.randf() < ELITE_REPEAT * scale("elite_rate"):
		return elite
	var pool := authored.filter(func(p: Dictionary) -> bool: return p["id"] != _last_pack_id)
	if pool.is_empty():
		pool = authored
	return pool[_rng.randi_range(0, pool.size() - 1)]


# --- v2 W7 enemies: pack composition -------------------------------------------------

# The world hands the director the stage's table row on stage entry: its counter unlock
# level and its ancient enemy come from the row, so a stage past the third reads its own. The
# row's pressure and the Breath option scale the pacing (scale()).
func use_row(row: Dictionary, breath_option := "", tier_reader := Callable()) -> void:
	if tier_reader.is_valid():
		set_run_tier_reader(tier_reader)
	row = RunTier.stage_row(row, run_tier())
	world = int(row.get("world", 1))
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
	_park_graph = null
	_corridors = null
	_graph_path = ""
	var park := _park_for(map_id)
	if park.is_empty():
		return
	var map = park.map
	_park_map = map
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


func _graph():
	if _park_graph == null and _graph_path != "":
		_park_graph = load("res://src/world/activities.gd").shared_graph(_graph_path)
		_graph_path = ""
	return _park_graph


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



func _home_pack_spots(kinds: Array, ball: Vector2, side: Vector2) -> Dictionary:
	var spots := {}
	var assigned: Array[Vector2] = []
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


func _park_safe(spot: Vector2) -> bool:
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
	return clampf(PACK_PER_TICK * scale("pack_scale") * ticks + PAST_BREAK_STEP * past_break_ticks(), 0.0, PACK_MAX)


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
