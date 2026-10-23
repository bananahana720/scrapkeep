extends SceneTree

const EventGround := preload("res://src/world/events/event_ground.gd")
const T := preload("res://tests/support/t.gd")

# A stage entry's OverlayMap built ahead on a worker (EventGround.build_ahead, queued by natural.gd with the next
# stage's plan) is the map a fresh OverlayMap.new(path) makes on the main thread, and the entry takes it once.

const PATHS := ["res://src/world/park/park_islands.json", "res://src/world/park/park_sinkhole.json"]

var _t := T.new("overlay_ahead_test")


func _initialize() -> void:
	for path: String in PATHS:
		EventGround.build_ahead(path)
		EventGround.build_ahead(path)
		_t.eq("one build queued for %s" % path.get_file(), EventGround._ahead.size(), PATHS.find(path) + 1)
	for path: String in PATHS:
		var fresh := EventGround.OverlayMap.new(path)
		var taken := EventGround._overlay_map_for(path)
		_t.check("the worker built %s" % path.get_file(), taken != null and taken.ok, "ok %s" % (taken.ok if taken != null else null))
		var differ := _differ(fresh, taken)
		_t.check("the built map equals a fresh one for %s" % path.get_file(), differ.is_empty(), "differ: %s" % [differ])
		_t.check("the entry takes it once (%s)" % path.get_file(), not EventGround._ahead.has(path))
	var fallback := EventGround._overlay_map_for(PATHS[0])
	_t.check("with nothing built ahead the entry makes its own", fallback != null and fallback.ok)
	EventGround.build_ahead(PATHS[1])
	EventGround.release_ahead()
	_t.check("teardown waits on and drops a build nobody took", EventGround._ahead.is_empty())
	quit(_t.verdict())


func _differ(a, b) -> Array:
	var out := []
	for property in a.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE and str(a.get(property.name)) != str(b.get(property.name)):
			out.append(property.name)
	return out
