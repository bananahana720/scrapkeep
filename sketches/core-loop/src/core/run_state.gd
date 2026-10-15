extends RefCounted

# One object owns the run: class, stage, health, scrap, parts and the counters the
# summary prints. Modules change it only through the mutators below, and each mutator
# publishes its fact on the bus after the change is made, so the HUD and the numbers
# here cannot disagree. Flow alone calls begin(), snapshot() and restore().

const Companion := preload("res://src/core/companion.gd")
const Relics := preload("res://src/build/relics.gd")
const StartPicks := preload("res://src/core/start_picks.gd")
const Profile := preload("res://src/core/profile.gd")
const RunTier := preload("res://src/core/run_tier.gd")
const MAX_HP := 100.0
const REGEN_DELAY := 5.0
const REGEN_RATE := 6.0
# Match HUD.LOW_HEALTH. Two seconds allows a clutch move before the 5 s regen delay;
# player code will consume the window, without changing the hit's damage or retries.
const ESCAPE_LOW_HULL := 0.25
const ESCAPE_WINDOW_SECONDS := 2.0
# Heft is the growth number (DEMO-SPEC): scrap rolled up becomes mass, parts add more.
# It scales punch and never touches handling. Classes I to V start at these values.
const HEFT_PER_MASS := 1.0 / 450.0
const HEFT_PER_PART := 0.2
const HEFT_CLASS_AT := [1.0, 1.5, 2.2, 3.2, 4.6]
# Bonus cores past this many add nothing more to the gate tier.
const CORE_TIER_CAP := 2
# Scrap as armour (the durability prototype, tuning `scrap_mode`): mass is a temporary
# health layer over the hull. SCRAP_PER_HP scrap absorbs one HP; of the scrap a hit
# removes, SPILL_SHARE spills as at most SPILL_CLUSTERS recovery clusters and the rest
# is destroyed. Wear (tuning `wear`) is WEAR_PER_MINUTE scrap a minute at cruise.
const SCRAP_PER_HP := 10.0
const SPILL_SHARE := 0.75
const SPILL_CLUSTERS := 6
const WEAR_PER_MINUTE := 30.0
# A class falls only this share of the preceding class interval below its threshold.
const CLASS_HYSTERESIS := 0.05

# A hit that reached the scrap: how much it removed, how much of that spills, and the
# source. player_hit still fires for every hit, armour-only included, with the whole hit.
signal armor_hit(removed: float, spill: int, source: String)
# Rolling wear took `removed` whole units of mass (wear_step only, --wear=on). Read-only; Rivet's
# Run and Gun trail reads it (world_one_rtree_test).
signal wear_taken(removed: float)

var events
var class_def: Resource
var stage := 1
var max_hp := MAX_HP
var hp := MAX_HP
var scrap := 0
# Mass is separate from the scrap wallet: spending compacts scrap into a part and keeps
# the mass; only lose_scrap (a crane theft) takes mass away.
var mass := 0.0
# Bonus cores from events and vaults this stage; each one overcharges the beacon.
var bonus_cores := 0
var pocket_draw_cache := {}
var _pocket_draw_entrance_doc := {}
var trade_memory := preload("res://src/world/trade_pockets.gd").memory()
var run_id := ""
var parts: Array[String] = []
# RL2: the relic held in each kit slot, slot name to relic id. One per slot (Relics.can_hold).
var relics := {}
var kills := 0
var events_won: Array[String] = []
var run_time := 0.0
var _tallies := {}
var _seen_wardens := {}
var stage_time := 0.0
var since_damage := 99.0
var retries := 0
var over := false
# Seam faults the run log should carry, such as a Warden that vanished unbroken.
var anomalies: Array[Dictionary] = []

# The prototype's switches; build sets them from the tuning flags. Off is the base game.
var armor_mode := false
# Scrap one absorbed HP costs. Build resolves it on each recompute (Riveted Shell halves it);
# nothing else writes it, and the damage order below is the only reader.
var scrap_per_hp := SCRAP_PER_HP
var wear_on := false
# The share of a hit the passive damage reduction removes first (build sets it each
# tick in armour mode, where the reduction runs before the scrap).
var mitigation := 0.0
# Optional Callable(source) -> share: the brace window's extra reduction for a hit's
# source. It joins the passive reduction before the scrap layer (the damage order).
var brace_hook := Callable()
# Deflect plates: returns true when this hit glances off. A ward: given the hull left after
# overflow, returns the hull to hold instead. Both run inside the one damage order.
var deflect_hook := Callable()
var ward_hook := Callable()
# The set piece's defence (SKILL-BAR section 4): Callable(amount, hp) -> the amount to take,
# x0.2 and never below 1 health; ride_hook answers whether a set piece rides, when no scrap
# is knocked loose. The one choke point every hit passes, so a boss's direct hit obeys it too.
var defend_hook := Callable()
var ride_hook := Callable()
# Whole wear units owed but not yet taken from the mass.
var _wear_accum := 0.0
# The armour metrics the run log carries; a retry adds to them, they are never restored.
var metrics := {}

# The entrance document layer (RS1): fields a zone-entrance save carries that the live run did
# not hold. flow.enter_stage sets `world` from the stage table at every entry, so a loaded doc's
# world (0 in one saved before that was wired) is recomputed on resume. flow seeds `companion`
# from the profile at a run's start.
var run_seed := 0
# Bot runner only; normal play keeps the clock-based identity.
var run_seed_override = null
var world := 0
# The spend wallet (CG1): shop, fabricator, sell and refund move cogs and nothing else.
# Damage, theft, wear and mass recovery never touch it; only add_cogs and spend_cogs do.
var cogs := 0
var companion := {}
# SG9's run-start offer: {"options": three ids, "rerolls_left": int, "taken": id or ""}. Drawn
# from run_seed in begin(); {} on a run loaded from a doc saved before SG9, which offers nothing.
var start_pick := {}
var run_tier := 0
var event_core_grants := 0
# True once enter_stage has run in this run. A pick opens only after flow's enter_stage(1),
# because enter_stage zeroes bonus_cores and would wipe a Bonus Core taken before it.
var _stage_entered := false
# One-time grant ids already settled (RS4); the profile keeps the same set and Progress
# unions the two. Optional in the entrance doc.
var settled: Array[String] = []
var escape_window_left := 0.0
var escape_window_active: bool:
	get:
		return escape_window_left > 0.0 and alive()
# World id to retries spent there, merged by max so a reload never hands retries back.
var retries_spent := {}
# Keys a newer build wrote that this one does not know; they ride through a round trip.
var extra := {}
# Upgrade-tree picks and the opened-pick count as last read from the tree or a loaded doc.
var tree_picks: Array[String] = []
var tree_allowed := 0
# The run skipped its late take_or_skip item (SG8); a save without the field means no skip.
var tree_late_skipped := false
var _loaded_class_id := ""

var _snapshot := {}
var _heft_class := 1
# The first stage-start snapshot of each stage in this run, kept for a replay of that
# stage (the boss death screen's T replays stage 3).
var _stage_starts := {}
var _id_rng := RandomNumberGenerator.new()


static func roman(n: int) -> String:
	return ["0", "I", "II", "III", "IV", "V", "VI"][clampi(n, 0, 6)]


func _init(events_ref = null, session_seed = null) -> void:
	# The id stream is seeded once from the session's global stream: players get fresh luck each
	# session, seeded bots and tests repeat, and nothing drawn later can move it. Game takes the
	# draw the moment it is created, before any node exists; a bare RunState draws here.
	_id_rng.seed = session_seed if session_seed != null else randi() # lint: session seed
	events = events_ref
	for key in Profile.RUN_TALLY_KEYS:
		if key != "time" and key != "wardens_seen":
			_tallies[key] = 0
	reset_metrics()
	if events != null:
		events.stage_entered.connect(_on_stage_entered)
		events.stage_cleared.connect(func(_stage: int): _tallies["stages_cleared"] += 1)
		events.enemy_killed.connect(func(_kind: String, _at: Vector3, _scrap: int): _tallies["kills"] += 1)
		events.player_died.connect(func(): _tallies["deaths"] += 1)
		events.warden_engaged.connect(_on_warden_engaged)


func _on_warden_engaged(index: int) -> void:
	_seen_wardens["%d/%d" % [world, index]] = true


# The highest heft class this run has been rewarded for (the slice table opens one tree pick
# per new class). Class I is the start pick's. A new run resets it. A retry keeps it, because
# a retry keeps the tree picks it paid for.
var class_rewarded := 1


func _unix_time() -> float:
	return Time.get_unix_time_from_system()


func begin(chosen_class: Resource) -> void:
	class_def = chosen_class
	stage = 1
	max_hp = MAX_HP
	hp = MAX_HP
	scrap = 0
	mass = 0.0
	bonus_cores = 0
	_heft_class = 1
	class_rewarded = 1
	_stage_starts = {}
	pocket_draw_cache = {}
	_pocket_draw_entrance_doc = {}
	trade_memory = preload("res://src/world/trade_pockets.gd").memory()
	# The suffix also seeds device luck; presentation must never choose it.
	if run_seed_override != null:
		run_id = "bot-%d" % int(run_seed_override)
	else:
		run_id = "%d-%06d" % [int(_unix_time()), _id_rng.randi() % 1000000]
	# Derived from the run id so it draws nothing from the global RNG.
	run_seed = hash(run_id)
	world = 0
	cogs = 0
	start_pick = {}
	run_tier = 0
	event_core_grants = 0
	load("res://src/build/parts.gd").bind_run(self)
	_stage_entered = false
	# 2026-10-11 (w13 coordinator, after SG9): a class without an id offers no pick. The run identity
	# case begins runs with a bare Resource, which read chosen_class.id as a script error.
	var pick_class := String(chosen_class.get("id")) if chosen_class != null and chosen_class.get("id") != null else ""
	if pick_class != "":
		start_pick = {"options": StartPicks.draw(pick_class, run_seed, 0), "rerolls_left": StartPicks.REROLLS, "taken": ""}
	companion = {}
	settled.clear()
	escape_window_left = 0.0
	retries_spent = {}
	extra = {}
	_loaded_class_id = ""
	tree_picks.clear()
	tree_allowed = 0
	tree_late_skipped = false
	parts.clear()
	relics = {}
	kills = 0
	events_won.clear()
	run_time = 0.0
	_seen_wardens.clear()
	for key in _tallies:
		_tallies[key] = 0
	stage_time = 0.0
	since_damage = 99.0
	retries = 0
	over = false
	anomalies.clear()
	_snapshot = {}
	_wear_accum = 0.0
	reset_metrics()


func alive() -> bool:
	return hp > 0.0 and not over


func class_id() -> String:
	return class_def.id if class_def != null else _loaded_class_id


func advance(delta: float) -> void:
	if not alive():
		return
	run_time += delta
	stage_time += delta
	escape_window_left = maxf(0.0, escape_window_left - maxf(0.0, delta))
	since_damage += delta
	if since_damage > REGEN_DELAY and hp < max_hp:
		hp = minf(max_hp, hp + REGEN_RATE * delta)


func add_scrap(amount: int, at: Vector3) -> void:
	if amount <= 0 or not alive():
		return
	scrap += amount
	mass += amount
	metrics["fresh"] += amount
	events.scrap_collected.emit(amount, at, scrap)
	_publish_heft_class()


# A theft: mass drops by the amount (not below zero) and the wallet by what it holds.
# Returns the mass actually taken, which a spill trail can pay back through add_scrap.
func lose_scrap(amount: int, at: Vector3, cause: String) -> int:
	if amount <= 0:
		return 0
	var taken := int(minf(float(amount), mass))
	mass = maxf(0.0, mass - amount)
	scrap -= mini(amount, scrap)
	events.scrap_lost.emit(taken, at, scrap, cause)
	_publish_heft_class()
	return taken


func reset_metrics() -> void:
	metrics = {"fresh": 0.0, "hit_loss": 0.0, "wear_loss": 0.0, "recovered": 0.0, "destroyed": 0.0,
		"expired": 0.0, "hull_damage": 0.0, "class_changes": 0, "class_drops": 0, "min_heft": -1.0, "heft_at_hits": [], "reverse_seconds": 0.0, "arena_destroyed": 0.0}


# Heft in armour mode comes from scrap alone; the base formula is untouched otherwise.
func heft() -> float:
	if armor_mode:
		return 1.0 + mass * HEFT_PER_MASS
	return 1.0 + mass * HEFT_PER_MASS + HEFT_PER_PART * parts.size()


# The class heft reaches with no memory: the highest threshold it has crossed.
func raw_heft_class(h: float) -> int:
	var result := 1
	for i in HEFT_CLASS_AT.size():
		if h >= HEFT_CLASS_AT[i]:
			result = i + 1
	return result


# Armour mode adds hysteresis: a class is held until heft is CLASS_HYSTERESIS of the
# interval below it under its threshold, so wear draining across a threshold cannot
# flicker the class. It only rises at the threshold itself.
func heft_class() -> int:
	var h := heft()
	var raw := raw_heft_class(h)
	if not armor_mode:
		return raw
	var held := clampi(_heft_class, 1, HEFT_CLASS_AT.size())
	if raw >= held:
		return raw
	while held > raw and held > 1:
		var below: float = HEFT_CLASS_AT[held - 1]
		var interval: float = HEFT_CLASS_AT[held - 1] - HEFT_CLASS_AT[held - 2]
		if h >= below - CLASS_HYSTERESIS * interval:
			break
		held -= 1
	return maxi(held, raw)


# 0 to 1 across the current class toward the next; 1 at the top class.
func heft_progress() -> float:
	var c := heft_class()
	if c >= HEFT_CLASS_AT.size():
		return 1.0
	var low: float = HEFT_CLASS_AT[c - 1]
	var high: float = HEFT_CLASS_AT[c]
	return clampf((heft() - low) / (high - low), 0.0, 1.0)


# A rise and a drop are different facts with different sounds, so each has its own
# signal: heft_class_changed only ever means the class went up.
func _publish_heft_class() -> void:
	var c := heft_class()
	if c == _heft_class:
		return
	var rose := c > _heft_class
	_heft_class = c
	metrics["class_changes"] += 1
	if not rose:
		metrics["class_drops"] += 1
	if rose:
		events.heft_class_changed.emit(c, heft())
	else:
		events.heft_class_dropped.emit(c, heft())


# Events and vaults grant bonus cores; each one overcharges this stage's beacon.
func add_core(source: String, at: Vector3) -> void:
	bonus_cores += 1
	events.core_gained.emit(source, at, bonus_cores)


func selected_run_tier() -> int:
	return run_tier


func select_run_tier(value: int, profile) -> bool:
	if value not in [0, 1] or not _start_pick_open() or not _stage_entered:
		return false
	if value == 1 and not RunTier.unlocked(profile):
		return false
	run_tier = value
	# A start-card choice survives retry, while the pick still rewinds as SG9 specifies.
	if not _snapshot.is_empty():
		_snapshot["run_tier"] = value
	if _stage_starts.has(stage):
		_stage_starts[stage]["run_tier"] = value
	return true


func add_event_core(at: Vector3) -> void:
	if run_tier == 0:
		add_core("event", at)
		return
	var multiplier: float = RunTier.row(run_tier).event_core_multiplier
	var before := floori(event_core_grants * multiplier)
	event_core_grants += 1
	var amount := floori(event_core_grants * multiplier) - before
	for core in amount:
		add_core("event", at)


# A lost risk bet burns this stage's cores (world/bet_crate.gd); its bet_resolved fact
# reports the loss. Returns how many burned.
func burn_cores() -> int:
	var burned := bonus_cores
	bonus_cores = 0
	return burned


# The gate tier bonus the cores buy: 0, 1 or 2 (two or more cores).
func gate_tier_bonus() -> int:
	return mini(bonus_cores, CORE_TIER_CAP)


# A cog pickup or a sale: the wallet only, never mass, heft or a pickup proc.
func add_cogs(amount: int) -> void:
	if amount <= 0 or not alive():
		return
	cogs += amount


# Shop and fabricator buys spend cogs; short of the price, nothing is spent.
func spend_cogs(amount: int) -> bool:
	if amount < 0 or cogs < amount:
		return false
	cogs -= amount
	return true


# The old scrap wallet: only world devices still charge it until they move to cogs.
# A failed spend changes nothing.
func spend_scrap(amount: int) -> bool:
	if amount < 0 or scrap < amount:
		return false
	scrap -= amount
	return true


func add_part(part_id: String, source: String) -> void:
	if RunTier.is_variant_id(part_id):
		return
	parts.append(part_id)
	events.part_gained.emit(part_id, source)
	_publish_heft_class()


# RL2: holds a relic in its slot and announces it as a relic-rarity find. False, and
# nothing changes, when the pilot cannot use it or the slot already holds one.
func add_relic(relic_id: String, source: String) -> bool:
	if not Relics.can_hold(relic_id, class_id(), relics):
		return false
	relics[Relics.slot_of(relic_id)] = relic_id
	events.part_gained.emit(Relics.part_of(relic_id), source)
	return true


func part_count(part_id: String) -> int:
	return parts.count(part_id)


# SG9: the three options on offer; empty once nothing is offered (an old doc).
func start_pick_options() -> Array:
	return (start_pick.get("options", []) as Array).duplicate()


# The offer is open in the first stage only, untaken, on a live run; an untaken pick does not
# follow the run into stage 2 through the entrance doc.
func _start_pick_open() -> bool:
	return alive() and stage == 1 and not start_pick.is_empty() and String(start_pick.get("taken", "")) == ""


# The one reroll: shows the pilot list's other three. Refused once taken or spent.
func reroll_start_pick() -> bool:
	if not _start_pick_open():
		return false
	var left := int(start_pick.get("rerolls_left", 0))
	if left <= 0:
		return false
	var options := StartPicks.draw(class_id(), run_seed, StartPicks.REROLLS - left + 1)
	if options.size() != StartPicks.OFFERED:
		return false
	start_pick["options"] = options
	start_pick["rerolls_left"] = left - 1
	return true


# Takes option `index` of the three and grants it through the mutators above. Once per run,
# in stage 1, and only after enter_stage(1) so a Bonus Core is not zeroed by the stage entry.
func take_start_pick(index: int) -> bool:
	if not _start_pick_open() or not _stage_entered:
		return false
	var options := start_pick_options()
	if index < 0 or index >= options.size():
		return false
	var id := String(options[index])
	if not StartPicks.apply(self, class_id(), id):
		return false
	start_pick["taken"] = id
	return true


static func _start_pick_from(value) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or (value as Dictionary).is_empty():
		return {}
	var options := []
	for id in value.get("options", []):
		options.append(String(id))
	return {"options": options, "rerolls_left": int(value.get("rerolls_left", 0)), "taken": String(value.get("taken", ""))}


# Build owns what parts do; a max-health part routes through here so a restore can
# put the old ceiling back.
func set_max_hp(value: float) -> void:
	var gained := maxf(0.0, value - max_hp)
	max_hp = maxf(1.0, value)
	hp = minf(max_hp, hp + gained)


func heal(amount: float) -> void:
	if alive():
		hp = minf(max_hp, hp + amount)


# Armour mode resolves every hit in one order: mitigation, then the scrap layer, then
# the hull. The scrap layer takes what it can (SCRAP_PER_HP scrap per HP), SPILL_SHARE of
# the scrap removed spills as recovery clusters and the rest is destroyed.
func damage(amount: float, source: String) -> void:
	if not alive() or amount <= 0.0:
		return
	if defend_hook.is_valid():
		amount = float(defend_hook.call(amount, hp))
	if armor_mode:
		_damage_armored(amount, source)
		return
	hp = maxf(0.0, hp - amount)
	since_damage = 0.0
	_try_escape_window()
	events.player_hit.emit(amount, source)
	if hp <= 0.0:
		events.player_died.emit()


func _damage_armored(amount: float, source: String) -> void:
	var share := clampf(mitigation, 0.0, 1.0)
	if brace_hook.is_valid():
		var brace: float = clampf(float(brace_hook.call(source)), 0.0, 1.0)
		share = 1.0 - (1.0 - share) * (1.0 - brace)
	# A glancing plate turns the hit aside before the scrap sees it, but the hit still
	# happened: every listener hears it (items, near-miss, the hurt sound and flash).
	var deflected: bool = deflect_hook.is_valid() and bool(deflect_hook.call(source))
	var left := 0.0 if deflected else amount * (1.0 - share)
	since_damage = 0.0
	if left <= 0.0:
		_try_escape_window()
		events.player_hit.emit(amount, source)
		return
	# No scrap is knocked loose during a set piece: the defended hit goes to the hull.
	var riding: bool = ride_hook.is_valid() and bool(ride_hook.call())
	var absorbed := 0.0 if riding else minf(left, mass / scrap_per_hp)
	var removed := absorbed * scrap_per_hp
	var overflow := left - absorbed
	if removed > 0.0:
		mass = maxf(0.0, mass - removed)
		var spill := int(round(removed * SPILL_SHARE))
		metrics["hit_loss"] += removed
		metrics["destroyed"] += removed - spill
		_publish_heft_class()
		# The spiral is observable: heft after each hit, and the lowest heft reached.
		metrics["min_heft"] = heft() if metrics["min_heft"] < 0.0 else minf(metrics["min_heft"], heft())
		if metrics["heft_at_hits"].size() < 200:
			metrics["heft_at_hits"].append(snappedf(heft(), 0.01))
		armor_hit.emit(removed, spill, source)
	if overflow > 0.0:
		var after := maxf(0.0, hp - overflow)
		# A ward holds the hull at its floor, once, inside the same order.
		if ward_hook.is_valid():
			after = maxf(after, float(ward_hook.call(after)))
		metrics["hull_damage"] += hp - after
		hp = after
	_try_escape_window()
	events.player_hit.emit(amount, source)
	if hp <= 0.0:
		events.player_died.emit()


func _try_escape_window() -> void:
	if not alive():
		escape_window_left = 0.0
		return
	if hp > max_hp * ESCAPE_LOW_HULL:
		return
	var model := Companion.new()
	if not model.from_dict(companion) or not model.spend_escape():
		return
	# Keep the entrance document's companion opaque; only its charge changes here.
	companion["escape_ready"] = false
	companion["escape_spent"] = true
	escape_window_left = ESCAPE_WINDOW_SECONDS
	events.escape_window.emit(ESCAPE_WINDOW_SECONDS)


func _on_stage_entered(_index: int, retry: bool) -> void:
	escape_window_left = 0.0
	if retry:
		return
	var model := Companion.new()
	if model.from_dict(companion):
		model.reset_escape()
		companion["escape_ready"] = true
		companion["escape_spent"] = false


# Spilled scrap picked back up: mass returns, but it is not a fresh pickup, so no
# scrap_collected, no wallet, no procs and no discovery.
func recover_mass(amount: int) -> void:
	if amount <= 0 or not alive():
		return
	mass += amount
	metrics["recovered"] += amount
	_publish_heft_class()


# A spill cluster that timed out unreached: its value is gone for good.
func note_spill_expired(amount: int) -> void:
	metrics["expired"] += amount


# The wear rate in scrap a second: WEAR_PER_MINUTE at cruise, scaled down below it and
# capped above it, so a faster ball pays no more than a cruising one.
static func wear_rate(speed: float, cruise: float) -> float:
	if cruise <= 0.0:
		return 0.0
	return WEAR_PER_MINUTE / 60.0 * clampf(speed / cruise, 0.0, 1.0)


# Rolling friction takes whole units of mass, and accrues only while a whole unit is left to
# take, so a fractional remainder never banks debt for the next pickup. `active` is false while paused, in the bay
# and in authored transfers or flights; wear never touches the hull and makes no event.
func wear_step(delta: float, speed: float, cruise: float, active: bool) -> void:
	if not armor_mode or not wear_on or not active or not alive() or delta <= 0.0 or mass < 1.0:
		return
	_wear_accum += wear_rate(speed, cruise) * delta
	var whole := minf(floorf(_wear_accum), floorf(mass))
	if whole < 1.0:
		return
	_wear_accum -= whole
	mass -= whole
	metrics["wear_loss"] += whole
	_publish_heft_class()
	wear_taken.emit(whole)


# The fixed route's opening mass (tuning `start_mass`): mass only, no wallet, no procs.
func grant_start_mass(amount: float) -> void:
	mass = maxf(0.0, amount)
	_heft_class = raw_heft_class(heft())


# True only while enemy_killed is emitting for a kill a wear spark landed: the item and tree
# consumers skip it, the bookkeeping ones do not.
var last_kill_from_spark := false


func record_kill(kind: String, at: Vector3, scrap_value: int, source := "") -> void:
	kills += 1
	last_kill_from_spark = source == "spark"
	events.enemy_killed.emit(kind, at, scrap_value)
	last_kill_from_spark = false


func note_anomaly(kind: String) -> void:
	anomalies.append({"stage": stage, "kind": kind, "ticks": int(round(stage_time * Engine.physics_ticks_per_second))})


func record_milestone(event_id: String) -> void:
	events_won.append(event_id)
	events.milestone_won.emit(event_id)


# Flow calls this as a stage begins (not on a retry): cores are stage-scoped.
func enter_stage(index: int) -> void:
	if index != stage:
		for offer in trade_memory.seen:
			if int(offer.stage) == stage and not trade_memory.decisions.has(str(stage)):
				preload("res://src/world/trade_pockets.gd").decide(trade_memory, offer, false)
	stage = index
	bonus_cores = 0
	event_core_grants = 0
	_stage_entered = true


# The stage-start checkpoint: everything a retry puts back, including where and how
# fast the ball entered, so a retry drops you in with the launch's speed.
func snapshot(entry_position: Vector3, entry_velocity: Vector3, camera_yaw: float) -> void:
	stage_time = 0.0
	_snapshot = {
		"stage": stage,
		"trade_memory": trade_memory.duplicate(true),
		"pocket_draw_cache": pocket_draw_cache.duplicate(true),
		"max_hp": max_hp,
		"hp": hp,
		"scrap": scrap,
		"cogs": cogs,
		"mass": mass,
		"heft_class": _heft_class,
		"wear_accum": _wear_accum,
		"bonus_cores": bonus_cores,
		"parts": parts.duplicate(),
		"relics": relics.duplicate(),
		"kills": kills,
		"events_won": events_won.duplicate(),
		# The hot-wired offer (id, state, spent) rides the checkpoint with the cogs a Recycle
		# pays, so a retry returns both to the pre-choice state together.
		"hotwire": (extra.get("hotwire", {}) as Dictionary).duplicate(true),
		# A retry rewinds a run-start pick with the part or cogs it paid, and offers the same three.
		"start_pick": start_pick.duplicate(true),
		"run_tier": run_tier,
		"event_core_grants": event_core_grants,
		"entry_position": entry_position,
		"entry_velocity": entry_velocity,
		"camera_yaw": camera_yaw,
	}
	if not _stage_starts.has(stage):
		_stage_starts[stage] = _snapshot.duplicate(true)


# Flow takes the snapshot before stage_entered and fills in the entry pose once the
# ball is placed; the kept stage start gets the same pose.
func set_snapshot_entry(entry_position: Vector3, entry_velocity: Vector3, camera_yaw: float) -> void:
	for record in [_snapshot, _stage_starts.get(stage, {})]:
		if record.is_empty() or record["stage"] != stage:
			continue
		if record == _snapshot or record["entry_position"] == Vector3.ZERO:
			record["entry_position"] = entry_position
			record["entry_velocity"] = entry_velocity
			record["camera_yaw"] = camera_yaw
			record["pocket_draw_cache"] = pocket_draw_cache.duplicate(true)
	# Flow creates the entrance doc before stage assembly, then fills its entry pose here.
	# Refresh that doc's shared cache dictionary before Flow writes it to disk.
	_pocket_draw_entrance_doc.clear()
	_pocket_draw_entrance_doc.merge(preload("res://src/world/pockets/pocket_draw.gd").to_doc(pocket_draw_cache))


func has_stage_start(index: int) -> bool:
	return _stage_starts.has(index)


# Makes a kept stage start the live checkpoint, so the next restore() replays it.
func use_stage_start(index: int) -> bool:
	if not _stage_starts.has(index):
		return false
	_snapshot = (_stage_starts[index] as Dictionary).duplicate(true)
	return true


func has_snapshot() -> bool:
	return not _snapshot.is_empty()


func snapshot_value(key: String):
	return _snapshot.get(key)


func restore() -> void:
	escape_window_left = 0.0
	pocket_draw_cache = (_snapshot.get("pocket_draw_cache", pocket_draw_cache) as Dictionary).duplicate(true)
	trade_memory = (_snapshot.get("trade_memory", preload("res://src/world/trade_pockets.gd").memory()) as Dictionary).duplicate(true)
	stage = _snapshot["stage"]
	max_hp = _snapshot["max_hp"]
	hp = _snapshot["hp"]
	scrap = _snapshot["scrap"]
	cogs = int(_snapshot.get("cogs", 0))
	mass = _snapshot["mass"]
	bonus_cores = _snapshot["bonus_cores"]
	parts.assign(_snapshot["parts"])
	relics = (_snapshot.get("relics", {}) as Dictionary).duplicate()
	kills = _snapshot["kills"]
	events_won.assign(_snapshot["events_won"])
	var hotwire: Dictionary = _snapshot.get("hotwire", {})
	if hotwire.is_empty():
		extra.erase("hotwire")
	else:
		extra["hotwire"] = hotwire.duplicate(true)
	start_pick = _start_pick_from(_snapshot.get("start_pick", {}))
	run_tier = int(_snapshot.get("run_tier", 0))
	event_core_grants = int(_snapshot.get("event_core_grants", 0))
	load("res://src/build/parts.gd").bind_run(self)
	stage_time = 0.0
	since_damage = 99.0
	retries += 1
	over = false
	# A restore is a rewind, not growth: the class follows silently, with no stinger.
	# Armour mode puts back the class held at the checkpoint, hysteresis and all.
	if armor_mode:
		_heft_class = int(_snapshot.get("heft_class", raw_heft_class(heft())))
		_wear_accum = float(_snapshot.get("wear_accum", 0.0))
	else:
		_heft_class = heft_class()


func tallies() -> Dictionary:
	var totals := _tallies.duplicate()
	totals["time"] = run_time
	totals["wardens_seen"] = _seen_wardens.size()
	return totals


func reconcile_tallies(saved: Dictionary) -> void:
	# An entrance loaded after a death can predate the profile's logged snapshot.
	# Retain those contributions before the resumed attempt adds any new ones.
	for key in _tallies:
		_tallies[key] = maxi(int(_tallies[key]), int(saved.get(key, 0)))
	run_time = maxf(run_time, float(saved.get("time", 0.0)))


func summary() -> Dictionary:
	return {
		"class": class_def.display_name if class_def != null else "",
		"stages": stage,
		"scrap": scrap,
		"cogs": cogs,
		"mass": mass,
		"heft": heft(),
		"parts": parts.duplicate(),
		"kills": kills,
		"events_won": events_won.size(),
		"time": run_time,
		"retries": retries,
		"tallies": tallies(),
		"trade_pockets": (trade_memory.seen as Array).duplicate(true),
	}


# ---- Entrance document (RS1): a pure, versioned Dictionary of the zone-entrance state. ----
# JSON loses Vector3 and typed arrays, so vectors are [x, y, z] and arrays are plain.

const ENTRANCE_SCHEMA := 1
# key: expected kind. "int" accepts a whole float, "num" any number, "vec3" three numbers,
# "strs" an array of strings, "dict" a Dictionary, "str" a String, "bool" true or false.
const ENTRANCE_KEYS := {
	"schema": "int", "run_id": "str", "class_id": "str", "seed": "int", "stage": "int",
	"world": "int", "max_hp": "num", "hp": "num", "mass": "num", "scrap": "int",
	"heft_class": "int", "wear_accum": "num", "bonus_cores": "int", "class_rewarded": "int",
	"parts": "strs", "kills": "int", "events_won": "strs", "run_time": "num", "retries": "int",
	"entry_position": "vec3", "entry_velocity": "vec3", "camera_yaw": "num",
	"tree_picks": "strs", "tree_allowed": "int", "retries_spent": "dict",
}
const ENTRANCE_OPTIONAL := {"cogs": "int", "companion": "dict", "settled": "strs", "relics": "dict", "start_pick": "dict", "run_tier": "int", "event_core_grants": "int", "run_tallies": "dict", "seen_wardens": "strs", "trade_memory": "dict", "pocket_draw_cache": "dict", "tree_late_skipped": "bool"}


# `tree` is optional: when given, its picks and allowed count are read the way world.gd
# reads them; otherwise the last values held here (from a load) are written.
func to_entrance_doc(tree = null) -> Dictionary:
	if tree != null:
		tree_picks.assign(tree.picks)
		tree_allowed = int(tree.allowed)
		tree_late_skipped = tree.has_method("late_skipped") and tree.late_skipped()
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var yaw := 0.0
	if not _snapshot.is_empty():
		pos = _snapshot["entry_position"]
		vel = _snapshot["entry_velocity"]
		yaw = _snapshot["camera_yaw"]
	var spent := {}
	for w in retries_spent:
		spent[str(int(w))] = int(retries_spent[w])
	_pocket_draw_entrance_doc = preload("res://src/world/pockets/pocket_draw.gd").to_doc(pocket_draw_cache)
	var doc := {}
	for key in extra:
		doc[key] = extra[key]
	doc.merge({
		"schema": ENTRANCE_SCHEMA,
		"run_id": run_id,
		"class_id": class_id(),
		"seed": run_seed,
		"stage": stage,
		"world": world,
		"max_hp": max_hp,
		"hp": hp,
		"mass": mass,
		"scrap": scrap,
		"heft_class": _heft_class,
		"wear_accum": _wear_accum,
		"bonus_cores": bonus_cores,
		"class_rewarded": class_rewarded,
		"parts": Array(parts),
		"kills": kills,
		"events_won": Array(events_won),
		"run_time": run_time,
		"retries": retries,
		"entry_position": [pos.x, pos.y, pos.z],
		"entry_velocity": [vel.x, vel.y, vel.z],
		"camera_yaw": yaw,
		"tree_picks": Array(tree_picks),
		"tree_allowed": tree_allowed,
		"tree_late_skipped": tree_late_skipped,
		"retries_spent": spent,
		"cogs": cogs,
		"companion": companion.duplicate(true),
		"settled": Array(settled),
		"relics": relics.duplicate(),
		"start_pick": start_pick.duplicate(true),
		"run_tier": run_tier,
		"event_core_grants": event_core_grants,
		"run_tallies": tallies(),
		"seen_wardens": _seen_wardens.keys(),
		"pocket_draw_cache": _pocket_draw_entrance_doc,
		"trade_memory": preload("res://src/world/trade_pockets.gd").to_doc(_snapshot.get("trade_memory", trade_memory)),
	}, true)
	if run_tier == 0:
		doc.erase("run_tier")
		doc.erase("event_core_grants")
	return doc


static func _entrance_kind_ok(value, kind: String) -> bool:
	var t := typeof(value)
	var is_num := t == TYPE_INT or t == TYPE_FLOAT
	match kind:
		"int":
			return t == TYPE_INT or (t == TYPE_FLOAT and is_finite(value) and value == floorf(value))
		"num":
			return is_num and is_finite(value)
		"str":
			return t == TYPE_STRING
		"bool":
			return t == TYPE_BOOL
		"dict":
			return t == TYPE_DICTIONARY
		"vec3", "strs":
			if t != TYPE_ARRAY:
				return false
			if kind == "vec3":
				if value.size() != 3:
					return false
				for n in value:
					if not (typeof(n) == TYPE_INT or typeof(n) == TYPE_FLOAT) or not is_finite(n):
						return false
				return true
			for item in value:
				if typeof(item) != TYPE_STRING:
					return false
			return true
	return false


# "" when the document can be applied, else the first problem.
static func validate_entrance_doc(doc) -> String:
	if typeof(doc) != TYPE_DICTIONARY:
		return "entrance doc is not a Dictionary"
	if not doc.has("schema"):
		return "missing key: schema"
	if not _entrance_kind_ok(doc["schema"], "int"):
		return "wrong type for schema"
	if int(doc["schema"]) > ENTRANCE_SCHEMA:
		return "schema %d is newer than known schema %d" % [int(doc["schema"]), ENTRANCE_SCHEMA]
	if int(doc["schema"]) < 1:
		return "schema %d is invalid" % int(doc["schema"])
	if doc.has("run_tier") and (not _entrance_kind_ok(doc.run_tier, "int") or int(doc.run_tier) not in [0, 1]):
		return "invalid run_tier"
	if doc.has("event_core_grants") and (not _entrance_kind_ok(doc.event_core_grants, "int") or doc.event_core_grants < 0):
		return "invalid event_core_grants"
	for key in ENTRANCE_KEYS:
		if not doc.has(key):
			return "missing key: %s" % key
		if not _entrance_kind_ok(doc[key], ENTRANCE_KEYS[key]):
			return "wrong type for %s (expected %s)" % [key, ENTRANCE_KEYS[key]]
	for key in ENTRANCE_OPTIONAL:
		if doc.has(key) and not _entrance_kind_ok(doc[key], ENTRANCE_OPTIONAL[key]):
			return "wrong type for %s (expected %s)" % [key, ENTRANCE_OPTIONAL[key]]
	if doc.has("pocket_draw_cache"):
		var draw_error := preload("res://src/world/pockets/pocket_draw.gd").validate_doc(doc.pocket_draw_cache, int(doc.stage))
		if not draw_error.is_empty():
			return draw_error
	if doc.has("trade_memory"):
		var trade_error := preload("res://src/world/trade_pockets.gd").validate_doc(doc.trade_memory, int(doc.stage))
		if not trade_error.is_empty():
			return trade_error
	for part_id in doc["parts"]:
		if RunTier.is_variant_id(part_id):
			return "part versions must share the base id"
	for w in doc["retries_spent"]:
		if not str(w).is_valid_int():
			return "retries_spent key %s is not a world id" % str(w)
		if not _entrance_kind_ok(doc["retries_spent"][w], "int"):
			return "wrong type for retries_spent[%s]" % str(w)
	if doc.has("run_tallies"):
		var totals: Dictionary = doc["run_tallies"]
		if totals.size() != Profile.RUN_TALLY_KEYS.size():
			return "run_tallies must have %d keys" % Profile.RUN_TALLY_KEYS.size()
		for key in Profile.RUN_TALLY_KEYS:
			if not _entrance_kind_ok(totals.get(key), "num" if key == "time" else "int") or totals[key] < 0:
				return "invalid run tally: %s" % key
		if totals["time"] != doc["run_time"]:
			return "run tally time differs from run_time"
	var seen := {}
	for id in doc.get("seen_wardens", []):
		var ids: PackedStringArray = id.split("/")
		if ids.size() != 2 or not ids[0].is_valid_int() or not ids[1].is_valid_int():
			return "invalid seen Warden: %s" % id
		if int(ids[0]) < 0 or int(ids[1]) < 1 or id != "%d/%d" % [int(ids[0]), int(ids[1])] or seen.has(id):
			return "invalid seen Warden: %s" % id
		seen[id] = true
	if doc.has("seen_wardens") and doc.has("run_tallies") and doc["run_tallies"]["wardens_seen"] != seen.size():
		return "run tally Wardens differ from seen_wardens"
	return ""


# Validates first; on any problem nothing is applied. Returns true when applied.
func from_entrance_doc(doc) -> bool:
	if validate_entrance_doc(doc) != "":
		return false
	escape_window_left = 0.0
	run_id = doc["run_id"]
	_loaded_class_id = doc["class_id"]
	if class_def != null and class_def.id != _loaded_class_id:
		class_def = null
	run_seed = int(doc["seed"])
	stage = int(doc["stage"])
	world = int(doc["world"])
	max_hp = float(doc["max_hp"])
	hp = float(doc["hp"])
	mass = float(doc["mass"])
	scrap = int(doc["scrap"])
	_heft_class = int(doc["heft_class"])
	_wear_accum = float(doc["wear_accum"])
	bonus_cores = int(doc["bonus_cores"])
	class_rewarded = int(doc["class_rewarded"])
	parts.assign(doc["parts"])
	relics = (doc["relics"] as Dictionary).duplicate() if doc.has("relics") else {}
	kills = int(doc["kills"])
	events_won.assign(doc["events_won"])
	run_time = float(doc["run_time"])
	_seen_wardens = {}
	for id in doc.get("seen_wardens", []):
		_seen_wardens[id] = true
	var totals: Dictionary = doc.get("run_tallies", {})
	for key in _tallies:
		# Older entrances can recover checkpoint kills, but contain no encounter history.
		_tallies[key] = int(totals.get(key, kills if key == "kills" else 0))
	retries = int(doc["retries"])
	tree_picks.assign(doc["tree_picks"])
	tree_allowed = int(doc["tree_allowed"])
	tree_late_skipped = bool(doc.get("tree_late_skipped", false))
	retries_spent = {}
	for w in doc["retries_spent"]:
		retries_spent[int(str(w))] = int(doc["retries_spent"][w])
	cogs = int(doc.get("cogs", 0))
	companion = (doc["companion"] as Dictionary).duplicate(true) if doc.has("companion") else {}
	settled.assign(doc.get("settled", []))
	start_pick = _start_pick_from(doc.get("start_pick", {}))
	run_tier = int(doc.get("run_tier", 0))
	event_core_grants = int(doc.get("event_core_grants", 0))
	load("res://src/build/parts.gd").bind_run(self)
	extra = {}
	for key in doc:
		if not ENTRANCE_KEYS.has(key) and not ENTRANCE_OPTIONAL.has(key):
			extra[key] = doc[key]
	var p: Array = doc["entry_position"]
	var v: Array = doc["entry_velocity"]
	over = false
	stage_time = 0.0
	since_damage = 99.0
	# The loaded entrance is the checkpoint a retry rewinds to.
	_stage_starts = {}
	pocket_draw_cache = preload("res://src/world/pockets/pocket_draw.gd").from_doc(doc.pocket_draw_cache) if doc.has("pocket_draw_cache") else {}
	trade_memory = preload("res://src/world/trade_pockets.gd").from_doc(doc.trade_memory) if doc.has("trade_memory") else preload("res://src/world/trade_pockets.gd").memory()
	_snapshot = {}
	snapshot(Vector3(p[0], p[1], p[2]), Vector3(v[0], v[1], v[2]), float(doc["camera_yaw"]))
	return true


# Max per world; a world absent from `other` keeps its count, and nothing ever decreases.
func merge_retries_spent(other: Dictionary) -> void:
	for w in other:
		var id := int(str(w))
		retries_spent[id] = maxi(int(retries_spent.get(id, 0)), int(other[w]))
