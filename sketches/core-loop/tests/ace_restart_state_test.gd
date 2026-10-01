extends SceneTree

const Ace := preload("res://src/presentation/ace_sequencer.gd")

# A fresh level starts from a clean per-level state: the bay lounge mix and the last heard
# pressure of the previous level do not reach the restarted stage 1. Driven through
# start_level directly: a retry undocks without bay_left and the band drops pressure
# while it is not playing, so the sequencer still holds both facts at the restart.


func _initialize() -> void:
	var failures := 0
	var probe := Ace.new()
	if not probe.missing.is_empty():
		print("[ace restart state] %s is missing; run tools/ace/package_music.py -> SKIP" % probe.missing)
		quit(0)
		return

	var docked := Ace.new()
	docked.set_bay(true)
	docked.start_level(0)
	var full: Dictionary = docked.manifest["profiles"][docked.sections["calm"]["profile"]]
	if docked.in_bay or docked._profile("calm") != full:
		failures += 1
		printerr("FAIL retry while docked: in_bay=%s, calm profile is not the full mix" % docked.in_bay)

	var loud := Ace.new()
	loud.set_pressure(0.8)
	loud.start_level(0)
	if loud.pressure != 0.0 or loud._desired() != "calm":
		failures += 1
		printerr("FAIL stale pressure: pressure=%s desired=%s, want 0.0 and calm" % [loud.pressure, loud._desired()])

	if failures > 0:
		printerr("ace restart state: %d failure(s)" % failures)
		quit(1)
		return
	print("ace restart state: ok")
	quit(0)
