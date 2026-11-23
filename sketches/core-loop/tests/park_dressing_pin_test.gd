# smoke: solo timeout=300s (builds every park stage synchronously)
extends SceneTree

# SWAP-HITCH-2 moved the set dressing's placement draw into a static plan() a worker can run. The
# draw must stay the one the old builder made, draw for draw, or every park stage's clutter moves.
# This test builds the dressing of every park stage on the park table and holds each batch's submitted
# instance buffer (name and buffer, in build order) against a pin, first recorded with the builder at 7dbdebae
# (artifacts/local/alpha/push/w14/swaphitch2/dress-pin-base.log). Since 16 Nov 2026 the buffers are pinned in
# tests/fixtures/pins/park_dressing_<stage>.pin through tests/support/pin_hash.gd (rounded, so the pin holds on the
# Linux build and the Mac; record with PIN_RECORD=1), and PINS keeps the map and batch count.
# set_dressing_test covers the old maps on the default table; this covers the park maps.

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const PinHash := preload("res://tests/support/pin_hash.gd")

# Stage -> [map, batch count], from the 7dbdebae builder; the hashes below are the old exact pins.
# 2026-11-22 stage 1 re-recorded (E1-05, w46/e1-05-dam-ramp-shelf at 104d803c7 on stage/alpha-w46 49b4dbbb5): the intake
# takeoff kicker joins the scatter keep-out and the takeoff and Pump Yard shelf stamps rebake the dam ground; stages 2 to 6 re-record byte-identical.
# 2026-11-17 flume butte gap table re-pin (W1-102): tests/fixtures/pins/park_dressing_2.pin re-recorded with PIN_RECORD=1
# on the Mac, because gap_table's plateau rebakes the flume ground and it and its kicker join the scatter keep-out; the
# pin is rounded to hold on both machines (pin_hash.gd), stages 1 and 3 to 6 unchanged.
# 2026-11-18 stage 2 re-recorded again at 4ddb8e828 on stage/alpha-w44 c9d55d7c: the pin from f47b5e827 was already red
# on the branch at 371ea873 (a shape change, after the gap table rows moved); the merged footings do not feed the
# dressing; stages 1 and 3 to 6 unchanged.
# 2026-10-22 crown sentinel re-pin: stage 6 park_crown 74019119 -> 2943158398, because sentinel_50 moved from [-150, 420] to
# [-185, 398] (its spire stamp rebakes the ground) and sentinel_50 and sentinel_36 ([-135, 438] -> [-156, 446]) both move their
# scatter keep-outs; stages 1 to 5 unchanged.
# 2026-10-17 islands authored pass re-pin: stage 5 park_islands 3297821718 -> 3681139656 and stage 6 park_crown
# 452118366 -> 74019119, because the new lips and nets join the scatter keep-out (park_map.gd); stages 1 to 4 unchanged.
# 2026-10-17 crown authored pass re-pin: stage 6 park_crown 3361994924 -> 452118366, because the new lips,
# hammocks and mooring deck join the scatter keep-out (park_map.gd); stages 1 to 5 unchanged.
# 2026-10-16 PARK-WIN re-pin: stage 6 park_crown 1104816985 -> 3361994924, because its dressing
# follows the PW2 rebaked ground (passes on the 699fded6 ground.bin); stages 1 to 5 unchanged.
# 2026-10-17 sinkhole re-pin: stage 4 park_sinkhole 2757620411 -> 3017710206, because its dressing
# follows the 20 m bowl rebake and the scatter now dresses the trough, pump_gallery and east_mesa
# (recipe "scatter"); the others unchanged.
# 2026-10-17 pit authored pass re-pin: stage 3 park_pit 3689678730 -> 2247843387, because the four west drifts
# rebake the ground and the scatter now dresses floor_sump and tailings_bench_east and keeps out of the new
# cut adits; the others unchanged.
# 2026-10-17 flume authored pass re-pin: stage 2 park_flume 1284262125 -> 1448453723, because siphon_camp moved from
# [-28, 176] to [-26, 174] (inside the 12 m reach of the momentum line on the flume) and its 11 m activity keep-out
# moves with it; with the camp at its old spot the 1284262125 pin still holds. The others unchanged.
# 2026-10-23 sinkhole elbow re-pin (#359): stage 4 park_sinkhole 3017710206 -> 2334293701, because #359 reshapes
# lava_channel_12, 13 and 21 and rebakes the sinkhole ground; no dressing spot moves. The others unchanged.
# 2026-10-24 flume pass two re-pin (#432, which carries #431): stage 2 park_flume 1448453723 -> 1001921675, because
# the new activity rows (weir_surge, canal_altar), the spill-leap kicker and butte, and bend_cache's move to [42, -96]
# move their keep-outs and the rebaked ground. The others unchanged.
# 2026-10-26 dam canyon walls re-pin (unit 10): stage 1 park_dam 2427938025 -> 3700432063, because the four
# canyon_wall rows rebake the ground at the square's edge (the scatter reads it) and eighteen outskirts anchor fields stop
# 12 m short of the walls' feet. No dressing spot moves. The others unchanged.
# 2026-10-27 dam south play rect re-pin (w20 line-rider): stage 1 park_dam 3700432063 -> 3312363204, because the play
# rect's south edge moves from z 700 to 760, the south wall's foot less 5 m as east and west, and the scatter now dresses
# the 60 m of flat plateau between. Stage 2 park_flume 1001921675 -> 3830422007 in the same PR, because five east-west
# washes now end 12 m short of the new east canyon wall's foot and the scatter reads the rebaked ground. The others
# unchanged.
const PINS := {
	1: ["park_dam", 13],
	2: ["park_flume", 13],
	3: ["park_pit", 13],
	4: ["park_sinkhole", 13],
	5: ["park_islands", 13],
	6: ["park_crown", 13],
}

var _t := T.new("park_dressing_pin_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game := Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	await process_frame
	await process_frame
	game.ctx.calm = true
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(0)
	await physics_frame
	var terrain = game.ctx.terrain
	var dressing = game.presentation.set_dressing
	if not _t.check("the park table carries the set dressing", dressing != null):
		quit(_t.verdict())
		return
	var checked := 0
	for stage in range(1, terrain.maps.size() + 1):
		var map = terrain.map_for(stage)
		if not "park" in map or map.park.is_empty():
			continue
		terrain.use(stage)
		dressing._build_stage()
		var parts := []
		for batch in dressing.batches:
			parts.append([String(batch.name), batch.get_meta("instance_buffer")])
		var got := [String(map.park.map), parts.size()]
		var pin_error := PinHash.check("res://tests/fixtures/pins/park_dressing_%d.pin" % stage, parts)
		print("park_dressing_pin_test: stage %d %s rounding margin %.2f" % [stage, var_to_str(got), PinHash.margin(parts)])
		checked += 1
		_t.check("stage %d (%s) dressing equals the 7dbdebae builder" % [stage, got[0]], PINS.get(stage) == got and pin_error.is_empty(),
			"got %s, want %s; %s" % [str(got), str(PINS.get(stage)), pin_error])
	_t.check("every park stage was pinned", checked > 0 and checked == PINS.size(), "%d stages built, %d pinned" % [checked, PINS.size()])
	game.queue_free()
	await physics_frame
	quit(_t.verdict())
