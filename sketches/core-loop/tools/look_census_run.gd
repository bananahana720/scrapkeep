extends "res://tools/bot_run.gd"

# The look census over a bot run: tools/bot_run.gd (same flags) plus a scan of the tree every
# --census-every ticks (default 3), printing one line for each look first drawn
# (tools/look_census.gd says what a look is):
#   NEW <tick> <owner> <path> <key>
# A look first drawn after the stage warm is a pipeline the 4080 builds in play. Replay a PC frame
# read with the PC's own arguments, so the ticks line up, for example
#   godot --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/look_census_run.gd -- \
#     --out=artifacts/local/census --table=park --policy=skipper --pilot=pylon_engineer --seeds=40317 \
#     --until=1 --threaded-stages=1 --warm-band=1 --ticks=5000
# --census-from=<tick> prints only looks first drawn from that tick on (all are still recorded).

const LookCensus := preload("res://tools/look_census.gd")

var _census := LookCensus.new()


func _physics_process(delta: float) -> bool:
	var out := super._physics_process(delta)
	if _game != null and _ticks % int(_settings.get("census-every", "3")) == 0:
		var from := int(_settings.get("census-from", "0"))
		for row in _census.scan(root, _ticks):
			if row.tick >= from:
				print("NEW %d %s %s %s" % [row.tick, row.owner, row.path, row.key])
	return out
