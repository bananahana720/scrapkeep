extends RefCounted

# A trial's events.ndjson (the closed event kinds in tools/jev-player/protocol/
# PROTOCOL.md), ported from ball-lab's telemetry.gd for Spillway Drop (JL-27). It reads
# the stage through a JevState view and writes through a JevIO, or only keeps `events`
# in memory when there is no JevIO. It never writes gameplay state.
#
# Usage: after `Scenarios.place()` call `placed()`; then once per physics tick, after
# `view.advance()`, call `intent_applied()` when an intent applies and then `step()`.
#
# Knocks. The game emits one `enemy_struck` per contact tick. Strikes on one enemy form
# one contact stretch while each follows the previous strike on that enemy within
# KNOCK_GAP_TICKS; each stretch is one `knock` event, stamped with its first strike's
# tick and strength (0.6 stomp, 1.0 ram).

const Terrain := preload("res://src/terrain.gd")
const SpeedTier := preload("res://src/speed_tier.gd")
const Geo := preload("res://src/jev/geo.gd")

const TRACE_HZ := 10
const KNOCK_GAP_TICKS := 30

var view
var io
var agent
var events: Array = []
var errors: Array = []
var knocks: Array = []
var raw_waves := 0

var _trace_every := 9
var _placed_tick := -1
var _primed := false
var _grounded := false
var _tier := ""
var _stuck := false
var _anomalies: Array = []
var _seen_waves := 0
var _last_wave := {}
var _open_knock := {}


func _init(view_ref, io_ref = null, agent_ref = null) -> void:
	view = view_ref
	io = io_ref
	agent = agent_ref
	var hz: int = view.tick_hz if view != null else Engine.physics_ticks_per_second
	_trace_every = maxi(1, hz / TRACE_HZ)


func placed() -> void:
	_placed_tick = view.tick
	_primed = false


func intent_applied(seq: int, intent: String) -> void:
	drain_knocks()
	_append({"tick": view.tick, "kind": "intent", "seq": seq, "intent": intent})


func step() -> void:
	drain_knocks()
	if view.tick <= _placed_tick:
		return
	var player = view.stage.player
	record(view.tick, view.position(), view.velocity(), view.grounded(),
		SpeedTier.label(player.state.tier), agent != null and agent.stuck)


func record(tick: int, at: Vector3, v: Vector3, grounded: bool, tier: String, stuck: bool) -> void:
	if _primed:
		if tier != _tier:
			_append({"tick": tick, "kind": "tier", "from": _tier, "to": tier})
		if grounded != _grounded:
			_append({"tick": tick, "kind": "landing" if grounded else "takeoff"})
	_primed = true
	_tier = tier
	_grounded = grounded
	if stuck != _stuck:
		_append({"tick": tick, "kind": "stuck_begin" if stuck else "stuck_end"})
		_stuck = stuck
	var now := anomalies_at(at, v)
	for what in now:
		if not _anomalies.has(what):
			_append({"tick": tick, "kind": "anomaly", "what": what})
	_anomalies = now
	if tick % _trace_every == 0 and at.is_finite() and v.is_finite():
		_append({"tick": tick, "kind": "trace", "pos": [at.x, at.y, at.z], "vel": [v.x, v.y, v.z],
			"tier": tier, "grounded": grounded})


static func anomalies_at(at: Vector3, v: Vector3) -> Array:
	if not (at.is_finite() and v.is_finite()):
		return ["nan"]
	var out := []
	if at.y < Terrain.height(at.x, at.z) - Geo.TUNNEL_DEPTH:
		out.append("tunnel")
	if absf(at.x) > Terrain.HALF or absf(at.z) > Terrain.HALF:
		out.append("out_of_bounds")
	if v.length() > Geo.OVERSPEED:
		out.append("overspeed")
	return out


func knock_count(kind: String) -> int:
	return knocks.filter(func(knock): return knock["kind"] == kind).size()


func drain_knocks() -> void:
	if view == null:
		return
	while _seen_waves < view.knocks.size():
		var wave: Dictionary = view.knocks[_seen_waves]
		_seen_waves += 1
		raw_waves += 1
		var enemy: int = wave["enemy"]
		var tick: int = wave["tick"]
		var open := _last_wave.has(enemy) and tick - int(_last_wave[enemy]) <= KNOCK_GAP_TICKS
		_last_wave[enemy] = tick
		if open:
			knocks[_open_knock[enemy]]["waves"] += 1
			continue
		_open_knock[enemy] = knocks.size()
		knocks.append({"tick": tick, "enemy": enemy, "strength": wave["strength"], "kind": wave["kind"], "waves": 1})
		_append({"tick": tick, "kind": "knock", "strength": wave["strength"]})


func _append(event: Dictionary) -> void:
	events.append(event)
	if io != null:
		errors.append_array(io.append_event(event))
