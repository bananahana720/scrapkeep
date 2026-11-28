extends RefCounted


const Companion := preload("res://src/core/companion.gd")
const Relics := preload("res://src/build/relics.gd")
const StartPicks := preload("res://src/core/start_picks.gd")
const Profile := preload("res://src/core/profile.gd")
const RunTier := preload("res://src/core/run_tier.gd")
const Roster := preload("res://src/combat/roster.gd")
const Panels := preload("res://src/build/panels.gd")
const Consumables := preload("res://src/build/consumables.gd")
const MetaOptions := preload("res://src/core/meta_options.gd")
const MAX_HP := 100.0
const CONSUMABLE_SLOTS_DEFAULT := 1
const CONSUMABLE_SLOTS_MAX := 2
const ONE_SHOT_GUARD := true
const SCRIPTED_KILL := 9999.0
const REGEN_DELAY := 5.0
const REGEN_RATE := 6.0
const ESCAPE_LOW_HULL := 0.25
const ESCAPE_WINDOW_SECONDS := 2.0
const HEFT_PER_MASS := 1.0 / 450.0
const HEFT_PER_PART := 0.2
const HEFT_CLASS_AT := [1.0, 1.5, 2.2, 3.2, 4.6]
const CORE_TIER_CAP := 2
const SCRAP_PER_HP := 10.0
const SPILL_SHARE := 0.75
const SPILL_CLUSTERS := 6
const WEAR_PER_MINUTE := 30.0
const CLASS_HYSTERESIS := 0.05

signal armor_hit(removed: float, spill: int, source: String)
signal wear_taken(removed: float)
signal death_saved(hp: float)

var events
var class_def: Resource
var stage := 1
var max_hp := MAX_HP
var hp := MAX_HP
var one_shot_guard := ONE_SHOT_GUARD
var scrap := 0
var mass := 0.0
var bonus_cores := 0
var pocket_draw_cache := {}
var _pocket_draw_entrance_doc := {}
var trade_memory := preload("res://src/world/trade_pockets.gd").memory()
var run_id := ""
var parts: Array[String] = []
var panels: Array[String] = []
var consumables: Array[String] = []
var consumable_slots := CONSUMABLE_SLOTS_DEFAULT
var consumable_grace_left := 0.0
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
var bot_driven := false
var anomalies: Array[Dictionary] = []

var armor_mode := false
var scrap_per_hp := SCRAP_PER_HP
var wear_on := false
var mitigation := 0.0
var brace_hook := Callable()
var deflect_hook := Callable()
var ward_hook := Callable()
var death_save_hook := Callable()
var death_save_spent := false
var defend_hook := Callable()
var ride_hook := Callable()
var taken_hook := Callable()
var _wear_accum := 0.0
var metrics := {}

var run_seed := 0
var run_seed_override = null
var route_seed := 0
var world := 0
var cogs := 0
var companion := {}
var start_pick := {}
var run_tier := 0:
	set(value):
		run_tier = value
		ChallengeDials.set_rung(RunTier.dials(value))
var event_core_grants := 0
var carried_core := 0
var brew := 0
var brew_stage := 0
var core_seat := ""
var arrived_core := 0
var cleared := false
var pick_opened := false
var landed := false
var _stage_entered := false
var _tier_closed := false
var settled: Array[String] = []
var escape_window_left := 0.0
var escape_window_active: bool:
	get:
		return escape_window_left > 0.0 and alive()
var retries_spent := {}
var extra := {}
var tree_picks: Array[String] = []
var tree_allowed := 0
var tree_late_skipped := false
var _loaded_class_id := ""

var _snapshot := {}
var _heft_class := 1
var _stage_starts := {}
var _id_rng := RandomNumberGenerator.new()


static func roman(n: int) -> String:
	return ["0", "I", "II", "III", "IV", "V", "VI"][clampi(n, 0, 6)]


func _init(events_ref = null, session_seed = null) -> void:
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


var class_rewarded := 1


func _unix_time() -> float:
	return Time.get_unix_time_from_system()


func begin(chosen_class: Resource) -> void:
	class_def = chosen_class
	_loaded_class_id = ""
	stage = 1
	_heft_class = 1
	max_hp = base_max_hp()
	hp = max_hp
	scrap = 0
	mass = 0.0
	bonus_cores = 0
	carried_core = 0
	core_seat = ""
	brew = 0
	brew_stage = 0
	arrived_core = 0
	cleared = false
	pick_opened = false
	landed = false
	panels.clear()
	consumables.clear()
	consumable_slots = CONSUMABLE_SLOTS_DEFAULT
	consumable_grace_left = 0.0
	_heft_class = 1
	class_rewarded = 1
	_stage_starts = {}
	pocket_draw_cache = {}
	_pocket_draw_entrance_doc = {}
	trade_memory = preload("res://src/world/trade_pockets.gd").memory()
	if run_seed_override != null:
		run_id = "bot-%d" % int(run_seed_override)
	else:
		run_id = "%d-%06d" % [int(_unix_time()), _id_rng.randi() % 1000000]
	run_seed = hash(["route", route_seed]) if route_seed > 0 and run_seed_override == null else hash(run_id)
	world = 0
	cogs = 0
	start_pick = {}
	run_tier = 0
	event_core_grants = 0
	load("res://src/build/parts.gd").bind_run(self)
	_stage_entered = false
	var pick_class := String(chosen_class.get("id")) if chosen_class != null and chosen_class.get("id") != null else ""
	if pick_class != "":
		start_pick = {"options": StartPicks.draw(pick_class, run_seed, 0), "rerolls_left": StartPicks.REROLLS, "taken": ""}
	companion = {}
	settled.clear()
	escape_window_left = 0.0
	retries_spent = {}
	death_save_spent = false
	extra = {}
	for meta_key in ["w50_scrap_ingots", "w50_consumable_state", "w50_trade_contracts", "w50_companion_salvage"]:
		if has_meta(meta_key):
			remove_meta(meta_key)
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


func active_overrides() -> Array:
	var raw = extra.get("overrides", [])
	return raw if raw is Array else []


func has_override(code_id: String) -> bool:
	return code_id in active_overrides()


func override_on(effect_key: String) -> bool:
	var active := active_overrides()
	if active.is_empty():
		return false
	for cid in active:
		var row: Dictionary = MetaOptions.override_row(String(cid))
		if String(row.get("upside", "")) == effect_key or String(row.get("downside", "")) == effect_key:
			return true
	return false


func base_max_hp() -> float:
	var pilot := class_def
	if pilot == null and _loaded_class_id != "":
		pilot = preload("res://src/core/class_def.gd").by_id(_loaded_class_id)
	var base := MAX_HP
	if pilot != null and pilot.get("base_hp") != null:
		base = float(pilot.base_hp) + float(pilot.hp_growth) * (_heft_class - 1)
	if override_on("hull_half"):
		return maxf(10.0, round(base * 0.5))
	return base


func advance(delta: float, rolling := true) -> void:
	if not alive():
		return
	run_time += delta
	stage_time += delta
	escape_window_left = maxf(0.0, escape_window_left - maxf(0.0, delta))
	consumable_grace_left = maxf(0.0, consumable_grace_left - maxf(0.0, delta))
	since_damage += delta
	if since_damage > REGEN_DELAY * ChallengeDials.f("pilot.regen_delay_mult") and hp < max_hp and (rolling or not regen_needs_roll()):
		hp = minf(max_hp, hp + REGEN_RATE * ChallengeDials.f("pilot.regen_rate_mult") * delta)


func regen_needs_roll() -> bool:
	return ChallengeDials.by_stage_or("pilot.regen_rolling_by_stage", stage, 0.0) > 0.0


func add_scrap(amount: int, at: Vector3) -> void:
	if amount <= 0 or not alive():
		return
	scrap += amount
	mass += amount
	metrics["fresh"] += amount
	events.scrap_collected.emit(amount, at, scrap)
	_publish_heft_class()


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


func heft() -> float:
	var panel_heft := panels.size() * Panels.PANEL_MASS * HEFT_PER_MASS
	if armor_mode:
		return 1.0 + mass * HEFT_PER_MASS + panel_heft
	return 1.0 + mass * HEFT_PER_MASS + HEFT_PER_PART * parts.size() + panel_heft


func raw_heft_class(h: float) -> int:
	var result := 1
	for i in HEFT_CLASS_AT.size():
		if h >= HEFT_CLASS_AT[i]:
			result = i + 1
	return result


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


func heft_progress() -> float:
	var c := heft_class()
	if c >= HEFT_CLASS_AT.size():
		return 1.0
	var low: float = HEFT_CLASS_AT[c - 1]
	var high: float = HEFT_CLASS_AT[c]
	return clampf((heft() - low) / (high - low), 0.0, 1.0)


func remove_part(part_id: String) -> bool:
	var i: int = parts.rfind(part_id)
	if i < 0:
		return false
	parts.remove_at(i)
	_publish_heft_class()
	return true


func clear_parts() -> void:
	parts.clear()


func _publish_heft_class() -> void:
	var c := heft_class()
	if c == _heft_class:
		return
	var previous_base := base_max_hp()
	var rose := c > _heft_class
	_heft_class = c
	set_max_hp(max_hp + base_max_hp() - previous_base)
	metrics["class_changes"] += 1
	if not rose:
		metrics["class_drops"] += 1
	if rose:
		events.heft_class_changed.emit(c, heft())
	else:
		events.heft_class_dropped.emit(c, heft())


func add_core(source: String, at: Vector3) -> void:
	bonus_cores += 1
	events.core_gained.emit(source, at, bonus_cores)


func selected_run_tier() -> int:
	return run_tier


func select_run_tier(value: int, profile, check_unlock := true) -> bool:
	if value < RunTier.BASE or value > RunTier.TOP or not run_tier_open():
		return false
	if value != RunTier.BASE and check_unlock and not RunTier.unlocked(profile, value):
		return false
	_keep_run_tier(value)
	return true


func run_tier_open() -> bool:
	return _start_pick_open() and _stage_entered and not _tier_closed


func close_run_tier() -> void:
	_tier_closed = true


func lab_run_tier(value: int) -> void:
	_keep_run_tier(clampi(value, RunTier.BASE, RunTier.TOP))


func _keep_run_tier(value: int) -> void:
	run_tier = value
	if not _snapshot.is_empty():
		_snapshot["run_tier"] = value
	if _stage_starts.has(stage):
		_stage_starts[stage]["run_tier"] = value


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


func can_stow_core() -> bool:
	return carried_core == 0 and bonus_cores > arrived_core and not companion.is_empty()


func stow_core() -> bool:
	if not can_stow_core():
		return false
	bonus_cores -= 1
	carried_core = 1
	var out: Array = Companion.unseat(companion)
	companion = out[0]
	core_seat = out[1]
	return true


func stow_cost() -> String:
	if carried_core > 0:
		return ""
	return String(Companion.unseat(companion)[1])


func companion_seats() -> int:
	return Companion.SOCKETS - carried_core


func companion_whole() -> Dictionary:
	return Companion.reseat(companion, core_seat)


func end_ride() -> void:
	companion = companion_whole()
	core_seat = ""
	carried_core = 0


func lose_core() -> bool:
	if bonus_cores <= 0:
		return false
	bonus_cores -= 1
	return true


func burn_cores() -> int:
	var burned := bonus_cores
	bonus_cores = 0
	return burned


func gate_tier_bonus() -> int:
	return mini(bonus_cores, CORE_TIER_CAP)


func add_cogs(amount: int) -> void:
	if amount <= 0 or not alive():
		return
	cogs += amount


func spend_cogs(amount: int) -> bool:
	if amount < 0 or cogs < amount:
		return false
	cogs -= amount
	return true


func spend_scrap(amount: int) -> bool:
	if amount < 0 or scrap < amount:
		return false
	scrap -= amount
	return true


func weigh_out(amount: int) -> int:
	if amount <= 0 or not alive():
		return 0
	var taken := int(minf(float(amount), mass))
	mass = maxf(0.0, mass - taken)
	scrap -= mini(taken, scrap)
	_publish_heft_class()
	return taken


func add_part(part_id: String, source: String) -> void:
	if RunTier.is_variant_id(part_id):
		return
	parts.append(part_id)
	events.part_gained.emit(part_id, source)
	_publish_heft_class()


func add_panel(panel_id: String, at: Vector3, jackpot := false) -> void:
	if not Panels.ROWS.has(panel_id):
		return
	panels.append(panel_id)
	if events != null:
		events.panel_gained.emit(panel_id, panels.count(panel_id), at, jackpot)
	_publish_heft_class()


func panel_counts() -> Dictionary:
	return Panels.counts(panels)


func consumable_capacity() -> int:
	var cap := clampi(consumable_slots, CONSUMABLE_SLOTS_DEFAULT, CONSUMABLE_SLOTS_MAX)
	if Consumables.BELT_PART_ID in parts:
		cap = CONSUMABLE_SLOTS_MAX
	return cap


func expand_consumable_belt(slots := CONSUMABLE_SLOTS_MAX) -> bool:
	var target := clampi(slots, CONSUMABLE_SLOTS_DEFAULT, CONSUMABLE_SLOTS_MAX)
	if consumable_slots >= target:
		return false
	consumable_slots = target
	return true


func can_hold_consumable() -> bool:
	return consumables.size() < consumable_capacity()


func has_consumable() -> bool:
	return not consumables.is_empty()


func peek_consumable() -> String:
	return consumables[0] if not consumables.is_empty() else ""


func add_consumable(consumable_id: String, replace_oldest := false) -> bool:
	if not Consumables.is_valid(consumable_id):
		return false
	var cap := consumable_capacity()
	if consumables.size() >= cap:
		if not replace_oldest:
			return false
		while consumables.size() >= cap:
			consumables.pop_front()
	consumables.append(consumable_id)
	return true


func pop_consumable() -> String:
	if consumables.is_empty():
		return ""
	return String(consumables.pop_front())


func clear_consumables() -> void:
	consumables.clear()


func grant_consumable_grace(seconds: float) -> void:
	consumable_grace_left = maxf(consumable_grace_left, maxf(0.0, seconds))


func consumable_grace_active() -> bool:
	return consumable_grace_left > 0.0 and alive()


func add_relic(relic_id: String, source: String) -> bool:
	if not Relics.can_hold(relic_id, class_id(), relics):
		return false
	relics[Relics.slot_of(relic_id)] = relic_id
	events.part_gained.emit(Relics.part_of(relic_id), source)
	return true


func part_count(part_id: String) -> int:
	return parts.count(part_id)


func start_pick_options() -> Array:
	return (start_pick.get("options", []) as Array).duplicate()


func _start_pick_open() -> bool:
	return alive() and stage == 1 and not start_pick.is_empty() and String(start_pick.get("taken", "")) == ""


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


func set_max_hp(value: float) -> void:
	var gained := maxf(0.0, value - max_hp)
	max_hp = maxf(1.0, value)
	hp = minf(max_hp, hp + gained)


func heal(amount: float) -> void:
	if alive():
		hp = minf(max_hp, hp + amount)


func damage(amount: float, source: String) -> void:
	if not alive() or amount <= 0.0:
		return
	if consumable_grace_active() and amount < SCRIPTED_KILL and source != "foreman_memo":
		return
	if taken_hook.is_valid():
		amount *= float(taken_hook.call(source))
	if defend_hook.is_valid():
		amount = float(defend_hook.call(amount, hp))
	if armor_mode:
		_damage_armored(amount, source)
		return
	hp = _after_hit(amount)
	_try_death_save()
	since_damage = 0.0
	_try_escape_window()
	events.player_hit.emit(amount, source)
	if hp <= 0.0:
		events.player_died.emit()


func _after_hit(amount: float, hit: float = -1.0) -> float:
	var whole := amount if hit < 0.0 else hit
	if one_shot_guard and whole < SCRIPTED_KILL and hp >= max_hp - 0.001 and hp - amount <= 0.0:
		return 1.0
	return maxf(0.0, hp - amount)


func _damage_armored(amount: float, source: String) -> void:
	var share := clampf(mitigation, 0.0, 1.0)
	if brace_hook.is_valid():
		var brace: float = clampf(float(brace_hook.call(source)), 0.0, 1.0)
		share = 1.0 - (1.0 - share) * (1.0 - brace)
	var deflected: bool = deflect_hook.is_valid() and bool(deflect_hook.call(source))
	var left := 0.0 if deflected else amount * (1.0 - share)
	since_damage = 0.0
	if left <= 0.0:
		_try_escape_window()
		events.player_hit.emit(amount, source)
		return
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
		metrics["min_heft"] = heft() if metrics["min_heft"] < 0.0 else minf(metrics["min_heft"], heft())
		if metrics["heft_at_hits"].size() < 200:
			metrics["heft_at_hits"].append(snappedf(heft(), 0.01))
		armor_hit.emit(removed, spill, source)
	if overflow > 0.0:
		var after := _after_hit(overflow, amount)
		if ward_hook.is_valid():
			after = maxf(after, float(ward_hook.call(after)))
		metrics["hull_damage"] += hp - after
		hp = after
	_try_death_save()
	_try_escape_window()
	events.player_hit.emit(amount, source)
	if hp <= 0.0:
		events.player_died.emit()


func _try_death_save() -> void:
	if hp > 0.0 or death_save_spent or not death_save_hook.is_valid():
		return
	var saved: float = float(death_save_hook.call())
	if saved <= 0.0:
		return
	death_save_spent = true
	hp = minf(max_hp, saved)
	death_saved.emit(hp)


func _try_escape_window() -> void:
	if not alive():
		escape_window_left = 0.0
		return
	if hp > max_hp * ESCAPE_LOW_HULL:
		return
	var model := Companion.new()
	if not model.from_dict(companion) or not model.spend_escape():
		return
	companion["escape_ready"] = false
	companion["escape_spent"] = true
	escape_window_left = ESCAPE_WINDOW_SECONDS
	events.escape_window.emit(ESCAPE_WINDOW_SECONDS)


func _on_stage_entered(_index: int, retry: bool) -> void:
	escape_window_left = 0.0
	consumable_grace_left = 0.0
	if retry:
		return
	var model := Companion.new()
	if model.from_dict(companion):
		model.reset_escape()
		companion["escape_ready"] = true
		companion["escape_spent"] = false


func recover_mass(amount: int) -> void:
	if amount <= 0 or not alive():
		return
	mass += amount
	metrics["recovered"] += amount
	_publish_heft_class()


func note_spill_expired(amount: int) -> void:
	metrics["expired"] += amount


static func wear_rate(speed: float, cruise: float) -> float:
	if cruise <= 0.0:
		return 0.0
	return WEAR_PER_MINUTE / 60.0 * clampf(speed / cruise, 0.0, 1.0)


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


func grant_start_mass(amount: float) -> void:
	var previous_base := base_max_hp()
	mass = maxf(0.0, amount)
	_heft_class = raw_heft_class(heft())
	set_max_hp(max_hp + base_max_hp() - previous_base)


const TRIGGERLESS_SOURCES := ["spark", "hazard"]
var last_kill_triggerless := false
var kill_tags := {}


func record_kill(kind: String, at: Vector3, scrap_value: int, source := "") -> void:
	kills += 1
	last_kill_triggerless = source in TRIGGERLESS_SOURCES
	events.enemy_killed.emit(kind, at, scrap_value)
	if kind in Roster.SPECIALS: events.special_broken.emit(kind)
	last_kill_triggerless = false
	kill_tags = {}


func note_anomaly(kind: String) -> void:
	anomalies.append({"stage": stage, "kind": kind, "ticks": int(round(stage_time * Engine.physics_ticks_per_second))})


func record_milestone(event_id: String) -> void:
	events_won.append(event_id)
	events.milestone_won.emit(event_id)


func cursed() -> bool:
	for offer in trade_memory.seen:
		if offer.get("curse", false) and bool(trade_memory.decisions.get(str(offer.stage), false)):
			return true
	return false


func enter_stage(index: int) -> void:
	if index != stage:
		for offer in trade_memory.seen:
			if int(offer.stage) == stage and not trade_memory.decisions.has(str(stage)):
				preload("res://src/world/trade_pockets.gd").decide(trade_memory, offer, false)
	if carried_core > 0:
		arrived_core = carried_core
		end_ride()
	elif index != stage:
		arrived_core = 0
	stage = index
	cleared = false
	pick_opened = false
	landed = false
	bonus_cores = arrived_core
	event_core_grants = 0
	_stage_entered = true
	_tier_closed = false


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
		"carried_core": carried_core,
		"core_seat": core_seat,
		"brew": brew,
		"brew_stage": brew_stage,
		"parts": parts.duplicate(),
		"panels": panels.duplicate(),
		"consumables": consumables.duplicate(),
		"consumable_slots": consumable_slots,
		"scrap_ingots": preload("res://src/build/fabricators.gd").ingots_to_doc(self),
		"relics": relics.duplicate(),
		"kills": kills,
		"events_won": events_won.duplicate(),
		"hotwire": (extra.get("hotwire", {}) as Dictionary).duplicate(true),
		"start_pick": start_pick.duplicate(true),
		"run_tier": run_tier,
		"event_core_grants": event_core_grants,
		"entry_position": entry_position,
		"entry_velocity": entry_velocity,
		"camera_yaw": camera_yaw,
	}
	if not _stage_starts.has(stage):
		_stage_starts[stage] = _snapshot.duplicate(true)


func set_snapshot_entry(entry_position: Vector3, entry_velocity: Vector3, camera_yaw: float) -> void:
	for record in [_snapshot, _stage_starts.get(stage, {})]:
		if record.is_empty() or record["stage"] != stage:
			continue
		if record == _snapshot or record["entry_position"] == Vector3.ZERO:
			record["entry_position"] = entry_position
			record["entry_velocity"] = entry_velocity
			record["camera_yaw"] = camera_yaw
			record["pocket_draw_cache"] = pocket_draw_cache.duplicate(true)
	_pocket_draw_entrance_doc.clear()
	_pocket_draw_entrance_doc.merge(preload("res://src/world/pockets/pocket_draw.gd").to_doc(pocket_draw_cache))


func has_stage_start(index: int) -> bool:
	return _stage_starts.has(index)


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
	consumable_grace_left = 0.0
	cleared = false
	landed = false
	_tier_closed = false
	pocket_draw_cache = (_snapshot.get("pocket_draw_cache", pocket_draw_cache) as Dictionary).duplicate(true)
	trade_memory = (_snapshot.get("trade_memory", preload("res://src/world/trade_pockets.gd").memory()) as Dictionary).duplicate(true)
	stage = _snapshot["stage"]
	max_hp = _snapshot["max_hp"]
	hp = _snapshot["hp"]
	scrap = _snapshot["scrap"]
	cogs = int(_snapshot.get("cogs", 0))
	mass = _snapshot["mass"]
	bonus_cores = _snapshot["bonus_cores"]
	if carried_core > int(_snapshot.get("carried_core", 0)):
		end_ride()
	carried_core = int(_snapshot.get("carried_core", 0))
	core_seat = String(_snapshot.get("core_seat", ""))
	brew = int(_snapshot.get("brew", 0))
	brew_stage = int(_snapshot.get("brew_stage", 0))
	parts.assign(_snapshot["parts"])
	panels.assign(_snapshot.get("panels", []))
	consumables.assign(_snapshot.get("consumables", []))
	consumable_slots = clampi(int(_snapshot.get("consumable_slots", CONSUMABLE_SLOTS_DEFAULT)), CONSUMABLE_SLOTS_DEFAULT, CONSUMABLE_SLOTS_MAX)
	if _snapshot.has("scrap_ingots"):
		preload("res://src/build/fabricators.gd").ingots_from_doc(self, _snapshot["scrap_ingots"])
	else:
		preload("res://src/build/fabricators.gd").reset_ingots(self)
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
		"save_used": 1 if death_save_spent else 0,
		"tallies": tallies(),
		"trade_pockets": (trade_memory.seen as Array).duplicate(true),
	}


const ENTRANCE_SCHEMA := 1
const ENTRANCE_KEYS := {
	"schema": "int", "run_id": "str", "class_id": "str", "seed": "int", "stage": "int",
	"world": "int", "max_hp": "num", "hp": "num", "mass": "num", "scrap": "int",
	"heft_class": "int", "wear_accum": "num", "bonus_cores": "int", "class_rewarded": "int",
	"parts": "strs", "kills": "int", "events_won": "strs", "run_time": "num", "retries": "int",
	"entry_position": "vec3", "entry_velocity": "vec3", "camera_yaw": "num",
	"tree_picks": "strs", "tree_allowed": "int", "retries_spent": "dict",
}
const ENTRANCE_OPTIONAL := {"cogs": "int", "companion": "dict", "settled": "strs", "relics": "dict", "start_pick": "dict", "run_tier": "int", "event_core_grants": "int", "run_tallies": "dict", "seen_wardens": "strs", "trade_memory": "dict", "pocket_draw_cache": "dict", "tree_late_skipped": "bool", "death_save_spent": "bool", "panels": "strs", "consumables": "strs", "consumable_slots": "int", "scrap_ingots": "dict", "arrived_core": "int", "cleared": "bool", "pick_opened": "bool", "landed": "bool", "carried_core": "int", "core_seat": "str", "brew": "int", "brew_stage": "int"}


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
		"death_save_spent": death_save_spent,
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
	if not panels.is_empty():
		doc["panels"] = Array(panels)
	if not consumables.is_empty():
		doc["consumables"] = Array(consumables)
	if consumable_slots > CONSUMABLE_SLOTS_DEFAULT:
		doc["consumable_slots"] = consumable_slots
	var ingot_doc: Dictionary = preload("res://src/build/fabricators.gd").ingots_to_doc(self)
	if int(ingot_doc.get("1", 0)) > 0 or int(ingot_doc.get("2", 0)) > 0 or int(ingot_doc.get("3", 0)) > 0:
		doc["scrap_ingots"] = ingot_doc
	if arrived_core > 0:
		doc["arrived_core"] = arrived_core
	if run_tier == 0:
		doc.erase("run_tier")
		doc.erase("event_core_grants")
	return doc


func to_cleared_doc(tree, launch_velocity: Vector3) -> Dictionary:
	cleared = true
	var doc := to_entrance_doc(tree)
	doc["cleared"] = true
	doc["entry_velocity"] = [launch_velocity.x, launch_velocity.y, launch_velocity.z]
	doc["trade_memory"] = preload("res://src/world/trade_pockets.gd").to_doc(trade_memory)
	if pick_opened:
		doc["pick_opened"] = true
	if landed:
		doc["landed"] = true
	if carried_core > 0:
		doc["carried_core"] = carried_core
		doc["core_seat"] = core_seat
	if brew > 0:
		doc["brew"] = brew
		doc["brew_stage"] = brew_stage
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
	if doc.has("run_tier") and (not _entrance_kind_ok(doc.run_tier, "int") or (int(doc.run_tier) < RunTier.BASE or int(doc.run_tier) > RunTier.TOP)):
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
	var range_error := _entrance_range_error(doc)
	if not range_error.is_empty():
		return range_error
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
	for panel_id in doc.get("panels", []):
		if not Panels.ROWS.has(panel_id):
			return "unknown panel: %s" % panel_id
	for cons_id in doc.get("consumables", []):
		if not Consumables.is_valid(String(cons_id)):
			return "unknown consumable: %s" % str(cons_id)
	if doc.has("consumable_slots") and (int(doc["consumable_slots"]) < CONSUMABLE_SLOTS_DEFAULT or int(doc["consumable_slots"]) > CONSUMABLE_SLOTS_MAX):
		return "consumable_slots %d is outside %d..%d" % [int(doc["consumable_slots"]), CONSUMABLE_SLOTS_DEFAULT, CONSUMABLE_SLOTS_MAX]
	if doc.has("scrap_ingots"):
		var ingots: Dictionary = doc["scrap_ingots"]
		for k in ingots:
			var ks := str(k)
			if not ks in ["1", "2", "3"]:
				return "invalid scrap_ingots tier: %s" % ks
			if not _entrance_kind_ok(ingots[k], "int") or int(ingots[k]) < 0:
				return "invalid scrap_ingots[%s]" % ks
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


static func _entrance_range_error(doc: Dictionary) -> String:
	if float(doc["max_hp"]) <= 0.0:
		return "max_hp %s is not above zero" % doc["max_hp"]
	if float(doc["hp"]) <= 0.0 or float(doc["hp"]) > float(doc["max_hp"]) + 0.001:
		return "hp %s is outside (0, max_hp %s]" % [doc["hp"], doc["max_hp"]]
	if int(doc["stage"]) < 1:
		return "stage %d is not a stage" % int(doc["stage"])
	if int(doc["heft_class"]) < 1 or int(doc["heft_class"]) > HEFT_CLASS_AT.size():
		return "heft_class %d is outside 1..%d" % [int(doc["heft_class"]), HEFT_CLASS_AT.size()]
	for key in ["mass", "scrap", "kills", "retries", "bonus_cores", "class_rewarded", "tree_allowed", "run_time", "wear_accum"]:
		if float(doc[key]) < 0.0:
			return "%s %s is negative" % [key, doc[key]]
	if doc.has("carried_core") and (int(doc["carried_core"]) < 0 or int(doc["carried_core"]) > 1):
		return "carried_core %d is outside 0..1" % int(doc["carried_core"])
	if doc.has("brew") and (int(doc["brew"]) < 0 or int(doc["brew"]) > 3):
		return "brew %d is outside 0..3" % int(doc["brew"])
	for key in ["pick_opened", "landed", "carried_core", "core_seat", "brew", "brew_stage"]:
		if doc.has(key) and not bool(doc.get("cleared", false)):
			return "%s belongs to a cleared stage" % key
	if doc.has("cogs") and int(doc["cogs"]) < 0:
		return "cogs %d is negative" % int(doc["cogs"])
	for w in doc["retries_spent"]:
		if typeof(doc["retries_spent"][w]) in [TYPE_INT, TYPE_FLOAT] and int(doc["retries_spent"][w]) < 0:
			return "retries_spent[%s] is negative" % str(w)
	return ""


func from_entrance_doc(doc) -> bool:
	if validate_entrance_doc(doc) != "":
		return false
	escape_window_left = 0.0
	consumable_grace_left = 0.0
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
	panels.assign(doc.get("panels", []))
	consumables.assign(doc.get("consumables", []))
	consumable_slots = clampi(int(doc.get("consumable_slots", CONSUMABLE_SLOTS_DEFAULT)), CONSUMABLE_SLOTS_DEFAULT, CONSUMABLE_SLOTS_MAX)
	if doc.has("scrap_ingots"):
		preload("res://src/build/fabricators.gd").ingots_from_doc(self, doc["scrap_ingots"])
	else:
		preload("res://src/build/fabricators.gd").reset_ingots(self)
	relics = (doc["relics"] as Dictionary).duplicate() if doc.has("relics") else {}
	kills = int(doc["kills"])
	events_won.assign(doc["events_won"])
	run_time = float(doc["run_time"])
	_seen_wardens = {}
	for id in doc.get("seen_wardens", []):
		_seen_wardens[id] = true
	var totals: Dictionary = doc.get("run_tallies", {})
	for key in _tallies:
		_tallies[key] = int(totals.get(key, kills if key == "kills" else 0))
	retries = int(doc["retries"])
	tree_picks.assign(doc["tree_picks"])
	tree_allowed = int(doc["tree_allowed"])
	tree_late_skipped = bool(doc.get("tree_late_skipped", false))
	death_save_spent = bool(doc.get("death_save_spent", false))
	retries_spent = {}
	for w in doc["retries_spent"]:
		retries_spent[int(str(w))] = int(doc["retries_spent"][w])
	cogs = int(doc.get("cogs", 0))
	companion = preload("res://src/core/companion.gd").sanitize(doc["companion"])[0] if doc.has("companion") else {}
	carried_core = int(doc.get("carried_core", 0))
	core_seat = String(doc.get("core_seat", ""))
	brew = int(doc.get("brew", 0))
	brew_stage = int(doc.get("brew_stage", 0))
	arrived_core = clampi(int(doc.get("arrived_core", 0)), 0, 1)
	cleared = bool(doc.get("cleared", false))
	pick_opened = bool(doc.get("pick_opened", false))
	landed = bool(doc.get("landed", false))
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
	_stage_starts = {}
	pocket_draw_cache = preload("res://src/world/pockets/pocket_draw.gd").from_doc(doc.pocket_draw_cache) if doc.has("pocket_draw_cache") else {}
	trade_memory = preload("res://src/world/trade_pockets.gd").from_doc(doc.trade_memory) if doc.has("trade_memory") else preload("res://src/world/trade_pockets.gd").memory()
	_snapshot = {}
	snapshot(Vector3(p[0], p[1], p[2]), Vector3(v[0], v[1], v[2]), float(doc["camera_yaw"]))
	return true


func merge_retries_spent(other: Dictionary) -> void:
	for w in other:
		var id := int(str(w))
		retries_spent[id] = maxi(int(retries_spent.get(id, 0)), int(other[w]))
