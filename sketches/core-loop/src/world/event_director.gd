extends RefCounted

const FloodCycle := preload("res://src/world/flood_cycle.gd")
const DustSquall := preload("res://src/world/dust_squall.gd")
const SurgeRun := preload("res://src/world/surge_run.gd")
const HoldRelay := preload("res://src/world/hold_relay.gd")
const ScrapStampede := preload("res://src/world/scrap_stampede.gd")
const TerrainEvent := preload("res://src/world/terrain_event.gd")
const ParkSchema := preload("res://src/world/park/park_schema.gd")
const NaturalFootprint := preload("res://src/world/events/natural_footprint.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")


enum { WAITING, ANNOUNCED, ARMED, LIVE, COOLDOWN, DONE }
enum { SQUALL_CALM, SQUALL_WARNING, SQUALL_LIVE }

const PHASE_NAMES := ["waiting", "announced", "armed", "live", "cooldown", "done"]
const PARTICIPATORY := EventKinds.PARTICIPATORY
const OFFER_LEAD := 4.0
const FIRST_OFFER := Vector2(6.0, 10.0)
const OFFER_GAP := Vector2(16.0, 24.0)
const RETRY_COOLDOWN := 12.0
const SQUALL_LEAD := 6.0
const SQUALL_SECONDS := 16.0
const SQUALL_FIRST := Vector2(25.0, 45.0)
const SQUALL_GAP := Vector2(50.0, 80.0)
const FLOOD_FIRST := Vector2(30.0, 50.0)
const FLOOD_DRY := Vector2(45.0, 65.0)
const SURGE_MINIBOSS_THREAT := 2.0
const SURGE_MINIBOSS_AT := 0.5
const PROGRESS_STEP := 0.01
const PARK_QUIET_S := 20.0
const PARK_TRAVEL_S := 2.0
const PARK_CORRIDOR_M := 8.0
const PARK_BAR_S := 240.0 / 172.0
const PARK_GROUND_CAP := 2
const PARK_FAMILY_CAP := 1
const PARK_CLOCK_SLACK_S := 0.00000001
const PARK_FLOOD_HOLD_CAP_S := 2.0
const PARK_LAND_FACTS := {
	"ground_slump": "ground_slump_landed",
	"flood_rising": "flood_landed", "fleet_inbound": "fleet_landed",
	"cage_rising": "cage_landed", "zipline_inbound": "zipline_landed",
	"ancient_stirring": "ancient_erupted", "boiler_pressure": "boiler_landed",
	"lightning_charge": "lightning_landed",
	"cave_in_crumble": "cave_in_swap", "impact_incoming": "impact_swap",
	"crust_crack": "crust_crack_landed", "drain_gurgle": "drain_landed", "trestle_groan": "trestle_landed",
	"lightning_mark": "lightning_mark_landed", "reactor_overload": "reactor_landed",
	"sluice_siren": "sluice_landed",
}

const FAMILIES_SCRIPT_PATH := "res://src/world/events/families.gd"
const NATURAL_SCRIPT_PATH := "res://src/world/events/natural.gd"
static var _prewarmed_stages := {}
static var _prewarmed_scripts := {}


static func reset_prewarm() -> void:
	_prewarmed_stages.clear()
	_prewarmed_scripts.clear()


static func prewarm_status(stage: int) -> Dictionary:
	return _prewarmed_stages.get(stage, {})


static func prewarm_stage_families(terrain, next_stage: int) -> Dictionary:
	if _prewarmed_scripts.is_empty():
		var families_script = load(FAMILIES_SCRIPT_PATH)
		if families_script != null and "SCRIPTS" in families_script:
			for family in families_script.SCRIPTS:
				var path: String = String(families_script.SCRIPTS[family])
				if ResourceLoader.exists(path):
					_prewarmed_scripts[family] = load(path)
	var result := {"stage": next_stage, "scripts_loaded": _prewarmed_scripts.size(), "status": "scripts_only", "key": 0}
	if terrain == null or next_stage < 1 or not ("maps" in terrain) or next_stage > terrain.maps.size():
		_prewarmed_stages[next_stage] = result
		return result
	if terrain.has_method("is_ready") and not terrain.is_ready(next_stage):
		if terrain.has_method("prepare"):
			terrain.prepare(next_stage)
		result["status"] = "terrain_preparing"
		_prewarmed_stages[next_stage] = result
		return result
	var natural_script = _prewarmed_scripts.get("natural", load(NATURAL_SCRIPT_PATH))
	if natural_script == null:
		_prewarmed_stages[next_stage] = result
		return result
	var pre: Dictionary = natural_script.prewarm(terrain, next_stage)
	result["key"] = int(pre.get("key", 0))
	result["status"] = String(pre.get("status", "non_park"))
	_prewarmed_stages[next_stage] = result
	return result


static func settle_prewarm() -> void:
	var natural_script = _prewarmed_scripts.get("natural")
	if natural_script != null and natural_script.has_method("settle_plans"):
		natural_script.settle_plans()
	_prewarmed_stages.clear()


var rng := RandomNumberGenerator.new()
var stage_time := 0.0
var flood: FloodCycle
var squall: DustSquall
var offers: Array[Dictionary] = []
var terrain: Array = []

var _squall_phase := SQUALL_CALM
var _squall_timer := 0.0
var _squall_gap := Vector2.ZERO
var _park := {}
var _park_states: Array[Dictionary] = []
var _park_sites := {}
var _park_pilot_lines: Array = []
var _park_families := {}
var _park_height: Callable
var _park_tier := 0
var _park_quiet_until := -INF


func _init(seed_value: int, def: Dictionary, map, cruise: float, height: Callable) -> void:
	rng.seed = seed_value
	if "park" in map and not map.park.is_empty():
		_build_park(map.park, height)
		return
	var mix: Dictionary = def.get("event_mix", {})
	if mix.is_empty():
		return
	if mix.has("flood") and not map.basin.is_empty():
		var w: float = maxf(0.1, mix["flood"])
		flood = FloodCycle.new()
		flood.first_dry = rng.randf_range(FLOOD_FIRST.x, FLOOD_FIRST.y) / w
		flood.dry_seconds = rng.randf_range(FLOOD_DRY.x, FLOOD_DRY.y) / w
	if mix.has("dust_squall"):
		var w: float = maxf(0.1, mix["dust_squall"])
		var angle := rng.randf() * TAU
		squall = DustSquall.new(Vector2(cos(angle), sin(angle)))
		_squall_gap = SQUALL_GAP / w
		_squall_timer = rng.randf_range(SQUALL_FIRST.x, SQUALL_FIRST.y) / w
	_build_offers(mix, def.get("threat", 1.0), map, cruise, height)
	_build_terrain(mix, map, cruise, height)


func _build_terrain(mix: Dictionary, map, cruise: float, height: Callable) -> void:
	if not "terrain_sites" in map:
		return
	for id in ["cave_in", "impact"]:
		if not mix.has(id) or not map.terrain_sites.has(id):
			continue
		var site: Dictionary = map.terrain_sites[id]
		var first: Vector2 = site.get("first", Vector2(30.0, 60.0))
		var at := rng.randf_range(first.x, first.y) / maxf(0.1, mix[id])
		terrain.append(TerrainEvent.new(id, site, at, cruise, height))


func terrain_event(id: String):
	for t in terrain:
		if t.id == id:
			return t
	return null


func _build_offers(mix: Dictionary, threat: float, map, cruise: float, height: Callable) -> void:
	var weighted := []
	for id in PARTICIPATORY:
		if not map.sites.has(id):
			continue
		var weight := -1.0
		if mix.has(id):
			weight = mix[id]
		elif id in map.unique_events:
			weight = 1.0
		if weight <= 0.0:
			continue
		weighted.append([weight + rng.randf() * 0.3, id])
	weighted.sort_custom(func(a, b): return a[0] > b[0])
	var at := rng.randf_range(FIRST_OFFER.x, FIRST_OFFER.y)
	for entry in weighted:
		var id: String = entry[1]
		var model = _model(id, map.sites[id], threat, cruise, height)
		offers.append({"id": id, "model": model, "phase": WAITING, "timer": at, "miniboss_sent": false})
		at += rng.randf_range(OFFER_GAP.x, OFFER_GAP.y)


static func _model(id: String, site: Dictionary, threat: float, cruise: float, height: Callable):
	match id:
		"surge_run":
			var run = SurgeRun.new(site, cruise)
			if threat >= SURGE_MINIBOSS_THREAT:
				run.miniboss_at = SURGE_MINIBOSS_AT
			return run
		"hold_the_relay":
			var relay: Vector2 = site["relay"]
			return HoldRelay.new(site, float(height.call(relay.x, relay.y)))
		_:
			return ScrapStampede.new(site, cruise, height)


func advance(delta: float, ball: Vector3, velocity: Vector3, context: Dictionary = {}) -> Array:
	stage_time += delta
	var facts := []
	if not _park.is_empty():
		_advance_park(delta, ball, velocity, context, facts)
		return facts
	_advance_flood(delta, facts)
	_advance_squall(delta, facts)
	for offer in offers:
		_advance_offer(offer, delta, ball, velocity, facts)
	for t in terrain:
		facts.append_array(t.advance(delta, ball, velocity))
	return facts


func _advance_flood(delta: float, facts: Array) -> void:
	if flood == null:
		return
	var before := flood.phase
	flood.advance(delta)
	if flood.phase == before:
		return
	match flood.phase:
		FloodCycle.WARNING:
			facts.append({"kind": "announced", "id": "flood", "seconds": flood.seconds_to_flood()})
		FloodCycle.RISING:
			facts.append({"kind": "started", "id": "flood"})
		FloodCycle.FALLING:
			facts.append({"kind": "ended", "id": "flood", "outcome": "passed"})


func _advance_squall(delta: float, facts: Array) -> void:
	if squall == null:
		return
	match _squall_phase:
		SQUALL_CALM:
			_squall_timer -= delta
			if _squall_timer <= 0.0:
				_squall_phase = SQUALL_WARNING
				_squall_timer = SQUALL_LEAD
				facts.append({"kind": "announced", "id": squall.id, "seconds": SQUALL_LEAD})
		SQUALL_WARNING:
			_squall_timer -= delta
			if _squall_timer <= 0.0:
				_squall_phase = SQUALL_LIVE
				squall.begin(SQUALL_SECONDS)
				facts.append({"kind": "started", "id": squall.id})
		SQUALL_LIVE:
			if squall.step(delta):
				_squall_phase = SQUALL_CALM
				_squall_timer = rng.randf_range(_squall_gap.x, _squall_gap.y)
				facts.append({"kind": "ended", "id": squall.id, "outcome": "passed"})


func squall_warning() -> float:
	if _squall_phase != SQUALL_WARNING:
		return 0.0
	return 1.0 - _squall_timer / SQUALL_LEAD


func _advance_offer(offer: Dictionary, delta: float, ball: Vector3, velocity: Vector3, facts: Array) -> void:
	var model = offer["model"]
	match offer["phase"]:
		WAITING, COOLDOWN:
			offer["timer"] -= delta
			if offer["timer"] <= 0.0:
				offer["phase"] = ANNOUNCED
				offer["timer"] = OFFER_LEAD
				facts.append({"kind": "announced", "id": offer["id"], "seconds": OFFER_LEAD, "at": model.ring})
		ANNOUNCED:
			offer["timer"] -= delta
			if offer["timer"] <= 0.0:
				offer["phase"] = ARMED
		ARMED:
			if Vector2(ball.x, ball.z).distance_to(model.ring) <= model.ring_radius:
				offer["phase"] = LIVE
				offer["miniboss_sent"] = false
				offer["shown_progress"] = -1.0
				model.begin()
				facts.append({"kind": "started", "id": offer["id"]})
		LIVE:
			var gate_before = model.get("next_gate")
			var outcome: String = model.step(delta, ball, velocity)
			facts.append_array(model.take_facts())
			if gate_before != null and model.next_gate > gate_before:
				var g: Vector2 = model.gates[gate_before]
				facts.append({"kind": "gate", "id": offer["id"], "at": g})
			_note_progress(offer, facts)
			if model.miniboss_at >= 0.0 and not offer["miniboss_sent"] and model.progress() >= model.miniboss_at:
				offer["miniboss_sent"] = true
				facts.append({"kind": "miniboss", "id": offer["id"], "at": _miniboss_spot(model)})
			if outcome != "":
				facts.append({"kind": "ended", "id": offer["id"], "outcome": outcome})
				if outcome == "won":
					facts.append({"kind": "milestone", "id": offer["id"], "at": model.ring})
					offer["phase"] = DONE
				else:
					offer["phase"] = COOLDOWN
					offer["timer"] = RETRY_COOLDOWN


func _note_progress(offer: Dictionary, facts: Array) -> void:
	var p: float = clampf(offer["model"].progress(), 0.0, 1.0)
	var shown: float = offer.get("shown_progress", -1.0)
	if shown < 0.0 or p - shown >= PROGRESS_STEP or (p >= 1.0 and shown < 1.0):
		offer["shown_progress"] = p
		facts.append({"kind": "progress", "id": offer["id"], "fraction": p})


func _miniboss_spot(model) -> Vector2:
	var zone: Array = model.miniboss_zone()
	var angle := rng.randf() * TAU
	var dist := rng.randf_range(zone[1].x, zone[1].y)
	return (zone[0] as Vector2) + Vector2(cos(angle), sin(angle)) * dist


func push(ball: Vector3, velocity: Vector3) -> Vector3:
	var total := Vector3.ZERO
	for offer in offers:
		if offer["phase"] == LIVE:
			total += offer["model"].push(ball, velocity)
	if squall != null:
		total += squall.accel()
	return never_brake(total, velocity)


static func never_brake(push_accel: Vector3, velocity: Vector3) -> Vector3:
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if flat.length() < 0.5:
		return push_accel
	var along := flat.normalized()
	var against := push_accel.dot(along)
	if against < 0.0:
		push_accel -= along * against
	return push_accel


func spike() -> bool:
	for offer in offers:
		if offer["phase"] == LIVE and offer["model"].spike():
			return true
	return false


func pressure_bonus() -> float:
	var bonus := 0.0
	for offer in offers:
		if offer["phase"] == LIVE:
			bonus += 0.25
	if squall != null:
		bonus += 0.1 * squall.intensity()
	if flood != null and (flood.phase == FloodCycle.RISING or flood.phase == FloodCycle.HIGH):
		bonus += 0.1
	for t in terrain:
		if t.phase == TerrainEvent.ANNOUNCED or t.phase == TerrainEvent.HOLDING:
			bonus += 0.1
	return minf(bonus, 0.4)


func offer(id: String) -> Dictionary:
	for o in offers:
		if o["id"] == id:
			return o
	return {}


func end_all() -> Array:
	var facts := []
	if not _park.is_empty():
		for state in _park_states:
			if state.phase in [ANNOUNCED, LIVE]:
				_park_end(state, facts)
			state.phase = DONE
		return facts
	for o in offers:
		if o["phase"] == LIVE:
			o["phase"] = DONE
			facts.append({"kind": "ended", "id": o["id"], "outcome": "passed"})
	if flood != null and (flood.phase == FloodCycle.RISING or flood.phase == FloodCycle.HIGH):
		facts.append({"kind": "ended", "id": "flood", "outcome": "passed"})
	if squall != null and _squall_phase == SQUALL_LIVE:
		facts.append({"kind": "ended", "id": squall.id, "outcome": "passed"})
	for t in terrain:
		if t.phase == TerrainEvent.CHANGED:
			t.phase = TerrainEvent.DONE
			facts.append({"kind": "ended", "id": t.id, "outcome": "passed"})
	return facts


func register_family(family: String, handler: Callable) -> void:
	assert(handler.is_valid(), "event_director: invalid handler for family '%s'" % family)
	_park_families[family] = handler


func set_clock_tier(effective_tier: int) -> void:
	_park_tier = effective_tier


func pilot_lines() -> Array:
	return _park_pilot_lines


func is_park_land_fact(kind: String) -> bool:
	return not _park.is_empty() and (PARK_LAND_FACTS.has(kind) or PARK_LAND_FACTS.values().has(kind))


func park_event_state(event_id: String) -> Dictionary:
	var state := _park_state_for(event_id)
	if state.is_empty():
		return {}
	return {"row": state.row, "phase": state.phase, "due_s": state.due_s, "holding": state.holding, "time_s": stage_time}


func park_booking_safe(event_id: String, ball: Vector3, velocity: Vector3) -> bool:
	var state := _park_state_for(event_id)
	if state.is_empty():
		return false
	return not state.holding and stage_time >= _park_quiet_until \
		and _park_capacity(state) and _park_route_safe(state) \
		and _park_clear(state, ball, velocity, state.context)


func _park_state_for(event_id: String) -> Dictionary:
	for state in _park_states:
		if state.row.id == event_id and not state.weather:
			return state
	return {}


func notify_warden_phase(phase: String) -> void:
	if phase == "broken":
		_park_quiet_until = stage_time + PARK_QUIET_S
	for state in _park_states:
		var trigger: Dictionary = state.row.trigger
		if trigger.get("on") == "warden_phase" and trigger.get("value") == phase:
			state.pending += 1


func notify_activity(row_id: String) -> void:
	for state in _park_states:
		var trigger: Dictionary = state.row.trigger
		if trigger.get("on") == "activity" and trigger.get("value") == row_id:
			state.pending += 1


func finish_activity(row_id: String) -> Array:
	var facts := []
	for state in _park_states:
		var trigger: Dictionary = state.row.trigger
		if trigger.get("on") == "activity" and trigger.get("value") == row_id:
			state.pending = 0
			if state.phase == ANNOUNCED:
				_park_end(state, facts)
			else:
				facts.append_array(finish_row(state.row.id))
	return facts


func finish_row(id: String) -> Array:
	var facts := []
	for state in _park_states:
		if state.row.id == id and state.phase == LIVE and (state.weather or float(state.row.live_s) > 0.0) and _park_can_end(state):
			_park_end(state, facts)
	return facts


func _build_park(park: Dictionary, height: Callable) -> void:
	_park = park.duplicate(true)
	_park_height = height
	for site in _park.get("park_rows", []):
		_park_sites[site.id] = site
	for row in _park.get("event_rows", []):
		if not _park_sites.has(row.site) or EventKinds.world_row(row.telegraph.form).is_empty() or not PARK_LAND_FACTS.has(row.telegraph.form):
			push_error("event_director: unsupported park site or form for " + str(row.id))
			continue
		if (row.kind in ParkSchema.WATER_KINDS or row.effect.get("material") == "water") and row.effect.has("depth_m"):
			row.effect.depth_m = minf(float(row.effect.depth_m), ParkSchema.MAX_EVENT_WATER_M)
		_park_states.append(_park_state(row, false))
	for row in _park.get("weather_rows", []):
		_park_states.append(_park_state(row, true))
	_park_read_lines()


func _park_state(row: Dictionary, weather: bool) -> Dictionary:
	return {"row": row, "weather": weather, "phase": WAITING, "ready_s": 0.0,
		"due_s": 0.0, "holding": false, "pending": 0, "live_elapsed_s": 0.0,
		"rise_s": 0.0, "collapse_s": 0.0, "waited_s": 0.0, "context": {}}


func _advance_park(delta: float, ball: Vector3, velocity: Vector3, context: Dictionary, facts: Array) -> void:
	_park_tier = int(context.get("clock_tier", _park_tier))
	for phase in context.get("warden_phases", []):
		notify_warden_phase(phase)
	var ctx := context.duplicate(true)
	ctx.merge({"clock_s": stage_time, "ball": ball, "velocity": velocity, "delta_s": delta,
		"grounded": context.get("grounded", ball.y <= float(_park_height.call(ball.x, ball.z)) + float(context.get("ball_radius_m", 1.2)))}, true)
	for state in _park_states:
		state.context = ctx
		if state.phase == LIVE:
			_park_step_live(state, delta, ball, velocity, ctx, facts)
	for state in _park_states:
		if state.phase != ANNOUNCED or stage_time < state.due_s:
			continue
		if stage_time < _park_quiet_until or not _park_capacity(state) or not _park_clear(state, ball, velocity, ctx) or not _park_route_safe(state):
			state.holding = true
			continue
		if state.holding and not state.weather and state.row.telegraph.on_bar:
			state.due_s = _park_downbeat(stage_time, ctx)
			state.holding = false
			if stage_time < state.due_s:
				continue
		state.phase = LIVE
		state.live_elapsed_s = 0.0
		state.rise_s = 0.0
		state.waited_s = 0.0
		state.collapse_s = 0.0
		_park_hook("land", state, ctx)
		if not state.weather:
			facts.append(_park_world(state, PARK_LAND_FACTS[state.row.telegraph.form], "land"))
		facts.append(_park_fact(state, "started"))
	if stage_time < _park_quiet_until:
		return
	var candidates := []
	var total := 0.0
	for state in _park_states:
		if state.phase not in [WAITING, COOLDOWN] or stage_time < state.ready_s or not _park_triggered(state):
			continue
		var weight := _park_weight(state)
		if weight > 0.0:
			total += weight
			candidates.append([state, weight])
	if candidates.is_empty():
		return
	var pick := rng.randf() * total
	var selected: Dictionary = candidates[-1][0]
	for candidate in candidates:
		pick -= float(candidate[1])
		if pick < 0.0:
			selected = candidate[0]
			break
	var lead := float(selected.row.lead_s) if selected.weather else maxf(float(selected.row.telegraph.lead_s), ParkSchema._lead_floor(selected.row))
	selected.phase = ANNOUNCED
	selected.pending = maxi(0, int(selected.pending) - 1)
	selected.holding = false
	selected.due_s = stage_time + lead
	if not selected.weather and selected.row.telegraph.on_bar:
		selected.due_s = _park_downbeat(selected.due_s, ctx)
	_park_hook("telegraph", selected, ctx)
	var announced := _park_fact(selected, "announced")
	announced.seconds = selected.due_s - stage_time
	facts.append(announced)
	if not selected.weather:
		facts.append(_park_world(selected, selected.row.telegraph.form, "telegraph"))


func _park_triggered(state: Dictionary) -> bool:
	match state.row.trigger.on:
		"always": return true
		"clock_tier": return _park_tier >= int(state.row.trigger.value)
		"warden_phase", "activity": return state.pending > 0
	return false


func _park_weight(state: Dictionary) -> float:
	if state.weather:
		return 1.0
	var weight := float(state.row.weight)
	for weather in _park_states:
		if weather.weather and weather.phase == LIVE:
			weight *= float(weather.row.event_odds.get(state.row.id, 1.0))
	return weight


static func _park_ground(row: Dictionary) -> bool:
	return row.kind in ParkSchema.GROUND_KINDS or row.family in ParkSchema.ARRIVAL_FAMILIES or str(row.effect.get("swap", "")) != ""


func _park_capacity(candidate: Dictionary) -> bool:
	var ground := int(not candidate.weather and _park_ground(candidate.row))
	var family := 1
	for state in _park_states:
		if state == candidate or state.phase != LIVE:
			continue
		if candidate.weather:
			if state.weather and state.row.kind != "clear" and candidate.row.kind != "clear":
				return false
		elif not state.weather:
			var progress_s: float = state.live_elapsed_s
			if state.row.kind in ["collapse", "cave_in"]:
				progress_s = state.collapse_s
			elif state.row.kind != "drain" and (state.row.kind in ["flood_fill", "flash_flood"] or state.row.effect.get("material") == "water"):
				progress_s = state.rise_s
			var settled := float(state.row.live_s) == 0.0 and progress_s >= maxf(0.0, float(state.row.effect.get("fill_s", 0.0)))
			ground += int(_park_ground(state.row) and not settled)
			family += int(state.row.family == candidate.row.family)
	if candidate.weather:
		return true
	return ground <= PARK_GROUND_CAP and (candidate.row.family not in ParkSchema.ARRIVAL_FAMILIES or family <= PARK_FAMILY_CAP)


static func _park_downbeat(time_s: float, context: Dictionary) -> float:
	var bar := maxf(0.000001, float(context.get("bar_s", PARK_BAR_S)))
	var origin := float(context.get("bar_origin_s", 0.0))
	return origin + ceil((time_s - origin - PARK_CLOCK_SLACK_S) / bar) * bar


func _park_step_live(state: Dictionary, delta: float, ball: Vector3, velocity: Vector3, ctx: Dictionary, facts: Array) -> void:
	var live_s := float(state.row.live_s)
	var expired: bool = live_s > 0.0 and state.live_elapsed_s >= live_s - PARK_CLOCK_SLACK_S
	if expired and _park_can_end(state):
		_park_end(state, facts)
		return
	var dt := delta if expired or live_s <= 0.0 else minf(delta, maxf(0.0, live_s - float(state.live_elapsed_s)))
	if not expired:
		state.live_elapsed_s += dt
	if not state.weather and (_park_rising(state) or _park_collapsing(state)) and not _park_clear(state, ball, velocity, ctx):
		var inside := _park_in_footprint(state, ball)
		if not (inside and _park_hold_spent(state)):
			if inside:
				state.waited_s += dt
			return
	var step_ctx := ctx.duplicate(true)
	step_ctx.delta_s = dt
	step_ctx.rise_s = state.rise_s
	_park_hook("step", state, step_ctx)
	if state.phase != LIVE:
		return
	if not state.weather:
		var fill_s := float(state.row.effect.get("fill_s", 0.0))
		if state.row.kind in ["collapse", "cave_in"]:
			state.collapse_s = _park_clock(state.collapse_s, dt, fill_s)
		if _park_rising(state):
			state.rise_s = _park_clock(state.rise_s, dt, fill_s)
	if live_s > 0.0 and state.live_elapsed_s >= live_s - PARK_CLOCK_SLACK_S and _park_can_end(state):
		_park_end(state, facts)


static func _park_clock(elapsed_s: float, dt: float, target_s: float) -> float:
	var next_s := elapsed_s + dt
	return target_s if next_s >= target_s - PARK_CLOCK_SLACK_S else next_s


static func _park_collapsing(state: Dictionary) -> bool:
	return state.row.kind in ["collapse", "cave_in"] and state.collapse_s < float(state.row.effect.get("fill_s", 0.0))


static func _park_rising(state: Dictionary) -> bool:
	return state.row.kind != "drain" and (state.row.kind in ["flood_fill", "flash_flood"] or state.row.effect.get("material") == "water") and state.rise_s < float(state.row.effect.get("fill_s", 0.0))


func _park_half(state: Dictionary, site: Dictionary) -> Vector2:
	var half := ParkMap.footprint_half_extents(site)
	if state.row.effect.has("footprint_m"):
		var footprint = state.row.effect.footprint_m
		half = (footprint if footprint is Vector2 else Vector2(float(footprint[0]), float(footprint[1]))).abs() * 0.5
	return half


func _park_in_footprint(state: Dictionary, ball: Vector3) -> bool:
	if state.weather or not _park_rising(state):
		return false
	var site: Dictionary = NaturalFootprint.resolve(state.row, _park_sites[state.row.site])
	return ParkMap.footprint_contains(site, Vector2(ball.x, ball.z), 0.0, Vector2.INF, _park_half(state, site))


static func _park_hold_spent(state: Dictionary) -> bool:
	return state.phase == LIVE and float(state.waited_s) >= PARK_FLOOD_HOLD_CAP_S - PARK_CLOCK_SLACK_S and _park_rising(state)


func _park_can_end(state: Dictionary) -> bool:
	return _park_clear(state, state.context.ball, state.context.velocity, state.context) and _park_route_safe(state, true)


func _park_end(state: Dictionary, facts: Array) -> void:
	state.phase = DONE if not state.weather and state.row.once else COOLDOWN
	state.ready_s = stage_time + float(state.row.gap_s if state.weather else state.row.cooldown_s)
	_park_hook("end", state, state.context)
	var ended := _park_fact(state, "ended")
	ended.outcome = "passed"
	facts.append(ended)


func _park_hook(action: String, state: Dictionary, context: Dictionary) -> void:
	var family: String = "weather" if state.weather else state.row.family
	var handler: Callable = _park_families.get(family, Callable())
	if handler.is_valid():
		var ctx := context.duplicate(true)
		ctx.at = _park_at(state)
		handler.call(action, state.row.duplicate(true), ctx)


func _park_at(state: Dictionary) -> Vector3:
	if state.weather:
		return Vector3.ZERO
	var site: Dictionary = NaturalFootprint.resolve(state.row, _park_sites[state.row.site])
	var at := Vector2(float(site.at[0]), float(site.at[1]))
	return Vector3(at.x, float(site.y) if site.y != null else float(_park_height.call(at.x, at.y)), at.y)


func _park_fact(state: Dictionary, kind: String) -> Dictionary:
	var fact := {"kind": kind, "id": state.row.id, "family": "weather" if state.weather else state.row.family,
		"event_kind": state.row.kind, "time_s": stage_time, "landing_s": state.due_s,
		"at": _park_at(state), "row": state.row.duplicate(true)}
	if not state.weather:
		fact.route_change = state.row.route_change.duplicate(true)
	return fact


func _park_world(state: Dictionary, form: String, phase: String) -> Dictionary:
	var fact := _park_fact(state, "world")
	fact.fact = form
	fact.phase = phase
	fact.music_cue = state.row.music_cue[phase]
	return fact


func _park_clear(state: Dictionary, ball: Vector3, velocity: Vector3, context: Dictionary) -> bool:
	if state.weather:
		return true
	var site: Dictionary = NaturalFootprint.resolve(state.row, _park_sites[state.row.site])
	var half := _park_half(state, site)
	var point := Vector2(ball.x, ball.z)
	if _park_rising(state) and context.grounded and _park_in_footprint(state, ball):
		return false
	if not _park_ground(state.row):
		return true
	var end := point + Vector2(velocity.x, velocity.z) * PARK_TRAVEL_S
	var margin := maxf(0.0, float(state.row.hold_clear_m))
	if ParkMap.footprint_contains(site, point, margin, end, half):
		return false
	if state.row.family in ParkSchema.ARRIVAL_FAMILIES and state.row.route_change.opens.is_empty():
		for line in context.get("pilot_lines", _park_pilot_lines):
			for i in range(1, line.size()):
				if ParkMap.footprint_contains(site, line[i - 1], PARK_CORRIDOR_M, line[i], half):
					return false
	return true


func route_open(route_id: String) -> bool:
	return bool(_park_routes_open().get(route_id, false))


func _park_routes_open(proposed: Dictionary = {}, withdrawing := false) -> Dictionary:
	var open := {}
	for route in _park.get("routes", []):
		open[route.id] = true
	for row in _park.get("event_rows", []):
		for id in row.route_change.opens:
			open[id] = false
	var changes := []
	for state in _park_states:
		if not state.weather and (state.phase == LIVE or state == proposed) and not (withdrawing and state == proposed):
			changes.append(state.row.route_change)
	for change in changes:
		for id in change.opens:
			open[id] = true
	for change in changes:
		for id in change.closes:
			open[id] = false
	return open


func _park_route_safe(proposed: Dictionary, withdrawing := false) -> bool:
	var open := _park_routes_open(proposed, withdrawing)
	var reached := {"drop_in": true}
	var pending := ["drop_in"]
	while not pending.is_empty():
		var node: String = pending.pop_back()
		for route in _park.get("routes", []):
			if open[route.id] and route.from == node and not reached.has(route.to):
				reached[route.to] = true
				pending.append(route.to)
	return reached.has("landmark")


func _park_read_lines() -> void:
	var path := "res://assets/park/%s/lines.json" % _park.get("map", "")
	if not FileAccess.file_exists(path):
		return
	var read := ParkSchema.read_file(path)
	for pilot in read.data.get("pilots", {}).values():
		var points := []
		for point in pilot.get("waypoints", []):
			if point is Array:
				points.append(Vector2(float(point[0]), float(point[1])))
			elif point == "drop_in":
				points.append(Vector2(float(_park.spawn.at[0]), float(_park.spawn.at[1])))
			elif point == "landmark":
				points.append(Vector2(float(_park.landmark.beacon[0]), float(_park.landmark.beacon[1])))
			elif _park_sites.has(point):
				var at: Array = _park_sites[point].at
				points.append(Vector2(float(at[0]), float(at[1])))
			else:
				for activity in _park.get("activity_rows", []):
					if activity.id == point:
						points.append(Vector2(float(activity.at[0]), float(activity.at[1])))
		_park_pilot_lines.append(points)
