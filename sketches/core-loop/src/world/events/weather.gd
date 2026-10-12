extends RefCounted

# Weather rows (KE7; PARK.md section 6; the six stage pages' weather_rows). The module owns a row's
# cycle (announce, lead, live, gap, then the next announce), the fog, sky and sound a row carries,
# and the fog it writes to the environment. A weather row's handling is "none" (ParkSchema rejects
# anything else), so nothing here reads or writes ball tuning or physics.

const WorldLook := preload("res://src/presentation/world_look.gd")

const EPS := 0.0001


# One row's cycle. step returns the event this tick: "announced" when the lead starts, "started"
# when the row goes live, "ended" when the live window closes, or "" for no event. An "always" row
# is live from its first tick and never cycles. armed is the row's trigger state for this tick.
class Cycle extends RefCounted:
	const WAIT := 0
	const LEAD := 1
	const LIVE := 2
	const GAP := 3

	var _row: Dictionary
	var _always := false
	var _phase := WAIT
	var _t := 0.0

	func _init(row: Dictionary) -> void:
		_row = row
		_always = row.get("trigger", {}).get("on") == "always"

	func is_live() -> bool:
		return _phase == LIVE

	func step(delta: float, armed: bool) -> String:
		if _always:
			if _phase != LIVE:
				_phase = LIVE
				return "started"
			return ""
		match _phase:
			WAIT:
				if armed:
					_begin(LEAD)
					return "announced"
			LEAD:
				_t += delta
				if _t >= float(_row.lead_s) - EPS:
					_begin(LIVE)
					return "started"
			LIVE:
				_t += delta
				if _t >= float(_row.live_s) - EPS:
					_begin(GAP)
					return "ended"
			GAP:
				_t += delta
				if _t >= float(_row.gap_s) - EPS:
					_begin(WAIT)
					if armed:
						_begin(LEAD)
						return "announced"
		return ""

	func _begin(phase: int) -> void:
		_phase = phase
		_t = 0.0


# The look a row carries: fog density and colour from the row, the sky id with its tint and
# cloud amount from WorldLook.WEATHER_SKY, and the sound and music layer ids as the row names them.
static func look(row: Dictionary) -> Dictionary:
	var fog: Dictionary = row.fog
	var sky: Dictionary = WorldLook.WEATHER_SKY.get(row.sky, {})
	return {
		"fog_density": float(fog.density),
		"fog_color": Color(String(fog.color)),
		"sky": row.sky,
		"sky_tint": sky.get("tint", Color.WHITE),
		"cloud": float(sky.get("cloud", 0.0)),
		"sound": row.sound,
		"music_layer": row.music_layer,
	}


# Writes the row's fog to the environment. The environment's other values, and the ball, are not
# touched.
static func apply(env: Environment, row: Dictionary) -> void:
	var values := look(row)
	env.fog_enabled = true
	env.fog_density = values.fog_density
	env.fog_light_color = values.fog_color
