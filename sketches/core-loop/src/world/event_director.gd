extends RefCounted

const FloodCycle := preload("res://src/world/flood_cycle.gd")
const DustSquall := preload("res://src/world/dust_squall.gd")
const SurgeRun := preload("res://src/world/surge_run.gd")
const HoldRelay := preload("res://src/world/hold_relay.gd")
const ScrapStampede := preload("res://src/world/scrap_stampede.gd")
const TerrainEvent := preload("res://src/world/terrain_event.gd")

# The event director for one stage (TADR-010): pure, stepped with a delta, drawing
# from its own seeded stream. It composes the ambient events (the flood, the dust
# squall) and the participatory ones you opt into, and returns what happened as fact
# records; the world publishes them. Every event is announced with a lead before it
# can touch the player, and a participatory event only goes live when the player
# rolls into its ring, so skipping one costs nothing and never holds the exit.
#
# Fact records, in order of occurrence:
#   {"kind": "announced", "id", "seconds"}   {"kind": "started", "id"}
#   {"kind": "ended", "id", "outcome"}       {"kind": "milestone", "id", "at": Vector2}
#   {"kind": "miniboss", "id", "at": Vector2} {"kind": "scrap", "amount", "at": Vector3}
#   {"kind": "gate", "id", "at": Vector2}     an event gate was taken
#   {"kind": "progress", "id", "fraction"}    a live event's progress moved (0 to 1)
#   {"kind": "terrain_swap", "id", "at"}      a terrain change lands this tick (v2 W6)
#   {"kind": "world", "fact", "at": Vector3}  a world_fact for the bus (v2 W6)

enum { WAITING, ANNOUNCED, ARMED, LIVE, COOLDOWN, DONE }
enum { SQUALL_CALM, SQUALL_WARNING, SQUALL_LIVE }

const PHASE_NAMES := ["waiting", "announced", "armed", "live", "cooldown", "done"]
const PARTICIPATORY := ["scrap_stampede", "surge_run", "hold_the_relay"]
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
# A surge run on a stage this threatening brings a miniboss mid-surge.
const SURGE_MINIBOSS_THREAT := 2.0
const SURGE_MINIBOSS_AT := 0.5
# A live event reports its progress when it has moved at least this far.
const PROGRESS_STEP := 0.01

var rng := RandomNumberGenerator.new()
var stage_time := 0.0
var flood: FloodCycle
var squall: DustSquall
var offers: Array[Dictionary] = []
# v2 W6: the stage's terrain-changing events (terrain_event.gd), ambient like the flood.
var terrain: Array = []

var _squall_phase := SQUALL_CALM
var _squall_timer := 0.0
var _squall_gap := Vector2.ZERO


func _init(seed_value: int, def: Dictionary, map, cruise: float, height: Callable) -> void:
	rng.seed = seed_value
	var mix: Dictionary = def.get("event_mix", {})
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


# Drawn after every other event's, so adding them left the older events' seeds alone.
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


func advance(delta: float, ball: Vector3, velocity: Vector3) -> Array:
	stage_time += delta
	var facts := []
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
				facts.append({"kind": "announced", "id": offer["id"], "seconds": OFFER_LEAD})
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


# A live event's own progress (0 to 1, from its model) as a fact whenever it has moved
# by PROGRESS_STEP since the last one, and always on reaching 1, so the music can
# follow the event the player is actually playing. The first live tick reports too.
func _note_progress(offer: Dictionary, facts: Array) -> void:
	var p: float = clampf(offer["model"].progress(), 0.0, 1.0)
	var shown: float = offer.get("shown_progress", -1.0)
	if shown < 0.0 or p - shown >= PROGRESS_STEP or (p >= 1.0 and shown < 1.0):
		offer["shown_progress"] = p
		facts.append({"kind": "progress", "id": offer["id"], "fraction": p})


# Seeded, so the same stage attempt puts the miniboss in the same place and another
# seed puts it somewhere else.
func _miniboss_spot(model) -> Vector2:
	var zone: Array = model.miniboss_zone()
	var angle := rng.randf() * TAU
	var dist := rng.randf_range(zone[1].x, zone[1].y)
	return (zone[0] as Vector2) + Vector2(cos(angle), sin(angle)) * dist


# Everything the events push the ball with this tick: the surge's tailwind and the
# squall's wind. They may steer and help and never brake, so the part of the push
# that would oppose the ball's motion is dropped here, once, for every event.
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


# What the events add to the music's pressure on top of the spawn director's.
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


# The stage is ending under whatever is live: close each one so music and HUD layers
# do not hang open into the next stage.
func end_all() -> Array:
	var facts := []
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
