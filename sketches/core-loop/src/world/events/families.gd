extends RefCounted

const SCRIPTS := {
	"natural": "res://src/world/events/natural.gd",
	"fleet": "res://src/world/events/fleet.gd",
	"ancient": "res://src/world/events/ancient.gd",
	"industrial": "res://src/world/events/industrial.gd",
}


static func build(world, director) -> Dictionary:
	var handlers := {}
	var map = world.terrain.map()
	if not "park" in map or map.park.is_empty():
		return handlers
	for family in SCRIPTS:
		var path: String = SCRIPTS[family]
		if not FileAccess.file_exists(path):
			continue
		var script: Script = load(path)
		var handler = script.new()
		if handler is Node:
			world.add_child(handler)
		handler.setup(world)
		director.register_family(family, Callable(handler, "handle"))
		handlers[family] = handler
	return handlers


static func release(director, handlers: Dictionary) -> void:
	if director != null:
		director.clear_families()
	for handler in handlers.values():
		handler.release()
		if handler is Node:
			handler.free()
	handlers.clear()
