extends SceneTree

# Replays two results of models/ParkFlood.tla on the real event director, one model step per call.
#
# held (config flood-broken-nosnap, rule FullWaterNeverHeld):
#   Land, Step x Fill with the ball out, Roll into the basin, Step.
#   REPRODUCED when the step hook is not called on that last tick although the water has risen for its whole fill time.
# parked (config flood-parked, property RiseFinishes, finding PF-1):
#   Land, Roll into the basin, Step for longer than the flood's live time.
#   REPRODUCED when the water never rises and the flood never ends while the ball stays.
#
# usage: "$GODOT_BIN" --headless --path sketches/core-loop --script <this file> [-- --only=held|parked]
# It reads the director only through advance() and the family hook, so it runs on any commit that has them.

const Director := preload("res://src/world/event_director.gd")

const FILL_S := 4.0
const LIVE_S := 20.0
const OUT := Vector3(1000.0, 1.0, 1000.0)
const IN := Vector3.UP

class Map:
	extends RefCounted
	var park := {}


func _initialize() -> void:
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	if only in ["", "held"]:
		for hz in [60.0, 90.0, 120.0, 144.0]:
			_held(hz)
	if only in ["", "parked"]:
		_parked()
	quit()


func _flood() -> Array:
	var row := {"id": "replay", "kind": "flash_flood", "family": "natural", "site": "site",
		"trigger": {"on": "clock_tier", "value": 1}, "weight": 1.0,
		"telegraph": {"lead_s": 0.1, "form": "flood_rising", "on_bar": false}, "live_s": LIVE_S,
		"effect": {"fill_s": FILL_S, "material": "water"}, "route_change": {"closes": [], "opens": []},
		"hold_clear_m": 12.0, "cooldown_s": 2.0, "once": true,
		"music_cue": {"telegraph": "riser_natural", "land": "drop_natural"}}
	var map := Map.new()
	map.park = {"map": "fixture", "event_rows": [row], "weather_rows": [],
		"park_rows": [{"id": "site", "at": [0, 0], "y": 0.0, "size": [20, 2, 20], "yaw_deg": 0}],
		"routes": [{"id": "main", "from": "drop_in", "to": "landmark", "via": []}]}
	var director = Director.new(813, {}, map, 14.0, func(_x, _z): return 0.0)
	var steps := []
	director.register_family("natural", func(action, _row, context):
		if action == "step":
			steps.append([context.ball, context.rise_s]))
	return [director, steps]


func _step(director, delta: float, ball: Vector3) -> Array:
	return director.advance(delta, ball, Vector3.ZERO, {"clock_tier": 4, "grounded": true, "bar_s": 240.0 / 172.0, "bar_origin_s": 0.0})


func _land(director, delta: float) -> bool:
	for tick in 2000:
		if _step(director, delta, OUT).any(func(fact): return fact.kind == "started"):
			return true
	return false


func _held(hz: float) -> void:
	var made := _flood()
	var director = made[0]
	var steps: Array = made[1]
	var delta := 1.0 / hz
	if not _land(director, delta):
		print("held %d Hz: the flood never landed, replay not made" % int(hz))
		return
	for tick in int(round(FILL_S * hz)):
		_step(director, delta, OUT)
	steps.clear()
	_step(director, delta, IN)
	var stepped := steps.size() == 1
	print("held %d Hz: %s (step hook calls under the ball on the first tick after the fill time: %d)" % [
		int(hz), "NOT REPRODUCED" if stepped else "REPRODUCED", steps.size()])


func _parked() -> void:
	var made := _flood()
	var director = made[0]
	var steps: Array = made[1]
	var delta := 1.0 / 60.0
	if not _land(director, delta):
		print("parked: the flood never landed, replay not made")
		return
	steps.clear()
	var ended := false
	var ticks := int((LIVE_S + 30.0) / delta)
	for tick in ticks:
		if _step(director, delta, IN).any(func(fact): return fact.kind == "ended"):
			ended = true
	var rose := steps.any(func(step): return step[1] > 0.0)
	var held := steps.is_empty() and not rose and not ended
	print("parked: %s (%.0f s with the ball in the basin, live time %.0f s: step hook calls %d, water rose %s, flood ended %s)" % [
		"REPRODUCED" if held else "NOT REPRODUCED", ticks * delta, LIVE_S, steps.size(), str(rose), str(ended)])
	if held:
		var after := 0
		for tick in int((FILL_S + 1.0) / delta):
			if _step(director, delta, OUT).any(func(fact): return fact.kind == "ended"):
				ended = true
		after = steps.size()
		print("parked: after the ball leaves for %.0f s: step hook calls %d, flood ended %s" % [FILL_S + 1.0, after, str(ended)])
