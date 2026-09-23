extends RefCounted

const Tuning := preload("res://src/tuning.gd")

# Buffs are stored as stack counts; the tuned values are always recomputed from
# the accepted defaults, so a buff can never drift the baseline feel by accumulation.


static func default_of(key: String) -> float:
	for spec in Tuning.SPECS:
		if spec["key"] == key:
			return spec["value"]
	return 0.0


static func apply(tuning, run_state) -> void:
	tuning.set_value("cruise", default_of("cruise") * pow(1.10, run_state.stacks("cruise")))
	tuning.set_value("jump_speed", default_of("jump_speed") + run_state.stacks("jump"))
	tuning.boost_cooldown_scale = pow(0.85, run_state.stacks("boost"))


static func impact_multiplier(run_state) -> float:
	return 1.0 + 0.25 * run_state.stacks("impact")
