extends RefCounted

# The viewer's settings, saved beside the codex and the UI profile as settings.json:
# the music and effects levels, comfort levels (screen shake, hit-stop) and look settings.
# Only levels a player chose are stored, so an untouched game keeps the
# defaults. Storage failures never throw; the settings keep working in memory, as the
# UI profile does.

const SafeStore := preload("res://src/core/safe_store.gd")
const Bindings := preload("res://src/core/bindings.gd")

const FILE := "settings.json"
# Comfort numbers the settings page keeps: fullscreen 0 off, 1 on (the default, so a fresh
# install starts fullscreen and the monitor's variable refresh can follow the game); quality 0
# High, 1 Low.
const FULLSCREEN := "fullscreen"
const QUALITY := "quality"
# Reduced motion, 0 off and 1 on: damps camera shake, FOV kicks, hit-edge flashes and decorative
# motion. Telegraphs are gameplay information and keep their timing and read.
const REDUCED_MOTION := "reduced_motion"
# A reduced-motion edge flash keeps this share of its alpha (the hit read stays visible).
const REDUCED_FLASH := 0.25
# Reduce flashes, 0 off and 1 on: cuts the brightness of flashes, white pops and strobes
# (FlashGuard holds the shares). Separate from reduced motion: a player may want either alone.
const REDUCE_FLASHES := "reduce_flashes"
# Frame smoothing, 1 on (the default) and 0 off: the ball is drawn between physics ticks, so it
# moves every frame on a display that is not 90 Hz, about one tick (11 ms) behind the sim.
const FRAME_SMOOTHING := "frame_smoothing"
# Wide picture, 1 on (the default) and 0 off: on a screen wider than 16:9 the world fills it (same
# height of view, wider across) and the HUD sits in the true corners; off keeps the 16:9 picture
# with a black bar each side (the PC check on the 3440x1440 monitor, 10 Nov 2026: +2.1% median
# frame time, p99 at most 9.51 ms).
const WIDE_PICTURE := "wide_picture"
# The one line the settings page shows under a row while it has the focus (eight words at most).
const HELPERS := {
	FRAME_SMOOTHING: "Smoother motion, about 11 ms added input lag",
	WIDE_PICTURE: "Fills ultrawide screens; off keeps black bars",
}
const STICK_SENSITIVITY := "stick_sensitivity"
const INVERT_Y := "invert_y"
const STICK_DEADZONE := "stick_deadzone"
const MOUSE_SENSITIVITY := "mouse_sensitivity"
const AIM_ASSIST := "aim_assist"
# Stick sensitivity is the full-deflection yaw rate in rad/s; pitch keeps its 1.6/2.6 ratio.
# Invert uses the comfort rows' numeric toggle convention, 0 off and 1 on. Aim assist is how hard
# the stick turn slows over a hookable target, 0 off to 1 full (stick only, never the mouse).
const LOOK_DEFAULTS := {
	STICK_SENSITIVITY: 2.6,
	INVERT_Y: 0.0,
	STICK_DEADZONE: 0.2,
	MOUSE_SENSITIVITY: 0.0022,
	AIM_ASSIST: 0.5,
}

var path := ""
var volumes := {}
var comfort := {}
var look := {}
# Action name to a comma-separated token list (Bindings.encode); only actions a player rebound.
var bindings := {}
var last_error := ""
var _save_blocked := false


func _init(storage_dir := "user://") -> void:
	path = storage_dir.path_join(FILE)
	load_saved()


func load_saved() -> void:
	volumes = {}
	comfort = {}
	look = {}
	bindings = {}
	if not FileAccess.file_exists(path):
		return
	var parsed = SafeStore.parse(FileAccess.get_file_as_string(path), TYPE_DICTIONARY, {"volumes": SafeStore.NUMBERS, "comfort": SafeStore.NUMBERS, "look": SafeStore.NUMBERS, "bindings": SafeStore.STRING_MAP})
	if parsed == null:
		var kept := SafeStore.quarantine(path)
		if kept.is_empty():
			_save_blocked = true
			last_error = "unreadable %s and could not be moved aside; not saving this session" % path
		else:
			last_error = "unreadable %s; kept as %s" % [path, kept]
		return
	_save_blocked = false
	var saved: Dictionary = parsed.get("volumes", {})
	for bus in saved:
		volumes[String(bus)] = clampf(float(saved[bus]), 0.0, 1.0)
	var feel: Dictionary = parsed.get("comfort", {})
	for id in feel:
		comfort[String(id)] = clampf(float(feel[id]), 0.0, 1.0)
	var aiming: Dictionary = parsed.get("look", {})
	for id in aiming:
		look[String(id)] = _look_value(String(id), float(aiming[id]))
	var rebound: Dictionary = parsed.get("bindings", {})
	for action in rebound:
		bindings[String(action)] = String(rebound[action])


func set_volume(bus: String, level: float) -> void:
	volumes[bus] = clampf(level, 0.0, 1.0)
	save()


func set_comfort(id: String, level: float) -> void:
	comfort[id] = clampf(level, 0.0, 1.0)
	save()


func set_look(id: String, value: float) -> void:
	look[id] = _look_value(id, value)
	save()


func stick_sensitivity() -> float:
	return float(look.get(STICK_SENSITIVITY, LOOK_DEFAULTS[STICK_SENSITIVITY]))


func invert_y() -> bool:
	return float(look.get(INVERT_Y, LOOK_DEFAULTS[INVERT_Y])) >= 0.5


func stick_deadzone() -> float:
	return float(look.get(STICK_DEADZONE, LOOK_DEFAULTS[STICK_DEADZONE]))


func mouse_sensitivity() -> float:
	return float(look.get(MOUSE_SENSITIVITY, LOOK_DEFAULTS[MOUSE_SENSITIVITY]))


func aim_assist() -> float:
	return float(look.get(AIM_ASSIST, LOOK_DEFAULTS[AIM_ASSIST]))


func _look_value(id: String, value: float) -> float:
	if not is_finite(value):
		return float(LOOK_DEFAULTS.get(id, 0.0))
	if id == INVERT_Y or id == STICK_DEADZONE or id == AIM_ASSIST:
		return clampf(value, 0.0, 1.0)
	if id == STICK_SENSITIVITY or id == MOUSE_SENSITIVITY:
		return maxf(0.0, value)
	return value


func fullscreen() -> bool:
	return float(comfort.get(FULLSCREEN, 1.0)) >= 0.5


func reduced_motion() -> bool:
	return float(comfort.get(REDUCED_MOTION, 0.0)) >= 0.5


func reduce_flashes() -> bool:
	return float(comfort.get(REDUCE_FLASHES, 0.0)) >= 0.5


func frame_smoothing() -> bool:
	return float(comfort.get(FRAME_SMOOTHING, 1.0)) >= 0.5


func wide_picture() -> bool:
	return float(comfort.get(WIDE_PICTURE, 1.0)) >= 0.5


# 0 for High, 1 for Low.
func quality() -> int:
	return 1 if float(comfort.get(QUALITY, 0.0)) >= 0.5 else 0


func binding(action: String) -> String:
	return String(bindings.get(action, ""))


# The decoded events of `action`; [] for an action this build does not hold.
func binding_events(action: String) -> Array:
	if not Bindings.actions().has(action):
		return []
	return Bindings.decode(binding(action))


# Mouse look is not rebindable, and an empty binding means no override, so it clears.
func set_binding(action: String, events: Array) -> void:
	if Bindings.actions().get(action, {}).get("motion", false):
		return
	var text := Bindings.encode(events)
	if text.is_empty():
		clear_binding(action)
		return
	bindings[action] = text
	save()


# Saves `events` over the saved events of the same kind only (keys and mouse buttons, pad
# buttons, trigger axes), so a pad rebind keeps a saved key rebind and the reverse.
func merge_binding(action: String, events: Array) -> void:
	var kept := []
	for old in binding_events(action):
		var replaced := false
		for event in events:
			replaced = replaced or Bindings.kind_of(old) == Bindings.kind_of(event)
		if not replaced:
			kept.append(old)
	kept.append_array(events)
	set_binding(action, kept)


func clear_binding(action: String) -> void:
	bindings.erase(action)
	save()


func save() -> void:
	if _save_blocked:
		return
	var data := {"volumes": volumes, "comfort": comfort}
	if not look.is_empty():
		data["look"] = look
	if not bindings.is_empty():
		data["bindings"] = bindings
	var err := SafeStore.write_atomic(path, JSON.stringify(data, "  "))
	if err != OK:
		last_error = error_string(err)
