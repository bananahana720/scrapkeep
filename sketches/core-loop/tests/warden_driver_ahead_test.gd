extends SceneTree

const T := preload("res://tests/support/t.gd")
const Warden := preload("res://src/combat/warden.gd")
const Roster := preload("res://src/combat/roster.gd")

# A later world's first Warden loaded its family driver (warden_swarm.gd) on the main thread, 20 ms of
# the Dig's entry tick (cloud, 13 Nov 2026). The first Warden set up starts every family's driver
# loading on a worker, once a session; the driver a Warden then reads is the script that load gave.
# smoke: timeout=60s

func _initialize() -> void:
	var t := T.new("warden_driver_ahead_test")
	var paths: Array = []
	for fam in Roster.WARDEN_FAMILIES:
		var path: String = Warden._driver_path(fam)
		if ResourceLoader.exists(path):
			paths.append(path)
	t.check("the session starts with no driver requested", not Warden._drivers_requested)
	Warden._request_drivers()
	var started := paths.filter(func(path: String): return ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE)
	t.eq("every family driver starts loading on a worker", started.size(), paths.size())
	t.check("there is a driver to load", paths.size() >= 2, str(paths))
	var deadline := Time.get_ticks_msec() + 20000
	var loaded := 0
	while loaded < paths.size() and Time.get_ticks_msec() < deadline:
		loaded = paths.filter(func(path: String): return ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED).size()
		OS.delay_msec(5)
	t.eq("every driver finishes loading", loaded, paths.size())
	var same := paths.filter(func(path: String): return load(path) == ResourceLoader.load_threaded_get(path))
	t.eq("a Warden's load() takes the script the worker loaded", same.size(), paths.size())
	Warden._request_drivers()
	t.check("a second Warden requests nothing more", Warden._drivers_requested)
	quit(t.verdict())
