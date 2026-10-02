extends SceneTree

const Ace := preload("res://src/presentation/ace_sequencer.gd")
const T := preload("res://tests/support/t.gd")

# A fresh level starts from a clean per-level state: the bay lounge mix and the last heard
# pressure of the previous level do not reach the restarted stage 1. Driven through
# start_level directly: a retry undocks without bay_left and the band drops pressure
# while it is not playing, so the sequencer still holds both facts at the restart.


func _initialize() -> void:
	var t := T.new("ace_restart_state_test")
	var probe := Ace.new()
	if not probe.missing.is_empty():
		print("[ace restart state] %s is missing; run tools/ace/package_music.py -> SKIP" % probe.missing)
		quit(0)
		return

	var docked := Ace.new()
	docked.set_bay(true)
	docked.start_level(0)
	var full: Dictionary = docked.manifest["profiles"][docked.sections["calm"]["profile"]]
	t.check("retry while docked", not docked.in_bay and docked._profile("calm") == full, "in_bay=%s, calm profile is the full mix: %s" % [docked.in_bay, docked._profile("calm") == full])

	var loud := Ace.new()
	loud.set_pressure(0.8)
	loud.start_level(0)
	t.check("stale pressure", loud.pressure == 0.0 and loud._desired() == "calm", "pressure=%s desired=%s, want 0.0 and calm" % [loud.pressure, loud._desired()])
	quit(t.verdict())
