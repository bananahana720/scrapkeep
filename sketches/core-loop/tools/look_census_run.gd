extends "res://tools/bot_run.gd"


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
