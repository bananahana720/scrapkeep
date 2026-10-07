extends "res://tools/bot_run.gd"

class PresentationNoise:
	extends Node
	var draws := 0

	func _ready() -> void:
		_process(0.0)

	func _process(_delta: float) -> void:
		for i in draws:
			randf()


func _next() -> void:
	super._next()
	if _game != null:
		var noise := PresentationNoise.new()
		noise.draws = int(_settings.get("presentation-draws", "0"))
		_game.add_child(noise)


func _snapshot(delta: float) -> Dictionary:
	var row := super._snapshot(delta)
	var wardens := []
	for enemy in get_nodes_in_group("enemy"):
		if enemy.has_method("integrity"):
			wardens.append(enemy.integrity())
	row["warden_integrity"] = wardens
	row["parts"] = _game.run.parts.duplicate()
	row["cogs"] = _game.run.cogs
	return row
