# smoke: solo timeout=300s (builds every park stage synchronously)
extends SceneTree

# SWAP-HITCH-2 moved the set dressing's placement draw into a static plan() a worker can run. The
# draw must stay the one the old builder made, draw for draw, or every park stage's clutter moves.
# This test builds the dressing of every park stage on the park table and holds a hash of each
# batch's exact submitted instance buffer (name and buffer, in build order) against PINS, recorded
# with the builder at 7dbdebae (artifacts/local/alpha/push/w14/swaphitch2/dress-pin-base.log).
# set_dressing_test covers the old maps on the default table; this covers the park maps.

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")

# Stage -> [map, batch count, hash], from the 7dbdebae builder.
# 2026-10-16 PARK-WIN re-pin: stage 6 park_crown 1104816985 -> 3361994924, because its dressing
# follows the PW2 rebaked ground (passes on the 699fded6 ground.bin); stages 1 to 5 unchanged.
# 2026-10-17 PARK-SINKHOLE-BAKE re-pin: stage 4 park_sinkhole 2757620411 -> 176046084, because its dressing
# follows the rebaked ground after the rim and fill rows stopped stacking; the other stages are unchanged.
const PINS := {
	1: ["park_dam", 13, 2427938025],
	2: ["park_flume", 13, 1284262125],
	3: ["park_pit", 13, 3689678730],
	4: ["park_sinkhole", 13, 176046084],
	5: ["park_islands", 13, 3297821718],
	6: ["park_crown", 13, 3361994924],
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
		var got := [String(map.park.map), parts.size(), hash(var_to_bytes(parts))]
		print("park_dressing_pin_test: stage %d %s" % [stage, var_to_str(got)])
		checked += 1
		_t.check("stage %d (%s) dressing equals the 7dbdebae builder" % [stage, got[0]], PINS.get(stage) == got,
			"got %s, want %s" % [str(got), str(PINS.get(stage))])
	_t.check("every park stage was pinned", checked > 0 and checked == PINS.size(), "%d stages built, %d pinned" % [checked, PINS.size()])
	game.queue_free()
	await physics_frame
	quit(_t.verdict())
