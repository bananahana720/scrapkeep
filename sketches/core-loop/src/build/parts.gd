extends RefCounted

# Placeholder stat parts so a gate has something to grant. Writer B replaces this with
# the real catalogue of typed Resources (TADR-008). Every effect is recomputed from the
# run's part list, so a retry that restores the list restores the build with it.

const CATALOGUE := {
	"tread_plating": {"label": "Tread plating", "text": "+8% cruise speed", "knob": "cruise", "scale": 1.08},
	"boost_coil": {"label": "Boost coil", "text": "boost and dash recharge 15% faster", "knob": "", "scale": 0.85},
	"dash_vane": {"label": "Dash vane", "text": "+15% air dash", "knob": "dash_impulse", "scale": 1.15},
}


static func ids() -> Array:
	return CATALOGUE.keys()


static func apply_all(tuning, parts: Array) -> void:
	tuning.clear_mods()
	for id in parts:
		if not CATALOGUE.has(id):
			continue
		var row: Dictionary = CATALOGUE[id]
		if row["knob"] == "":
			tuning.boost_cooldown_scale *= row["scale"]
		else:
			tuning.set_mod(row["knob"], tuning.mod(row["knob"]) * row["scale"])
