extends SceneTree

const BotFairness := preload("res://tools/bot_fairness.gd")
const T := preload("res://tests/support/t.gd")

# How the fairness test reads its plain baseline (BotFairness.baseline). The recorder writes "stop_tax": null when a run spent
# no time slow or lost no hull at cruise; that must come back as a named miss and never a script error.

var _t := T.new("bot_fairness_baseline_test")


func _init() -> void:
	var seg := {"s1": {"first_hit_s": 4.5}}
	var miss := "plain baseline measured no stop tax"
	var nulled: Dictionary = BotFairness.baseline({"telegraph_share": 0.8, "stop_tax": null, "first_hit": seg})
	_t.eq("a null stop tax is the named miss", nulled["miss"], miss)
	var absent: Dictionary = BotFairness.baseline({"telegraph_share": 0.8, "first_hit": seg})
	_t.eq("a missing stop tax is the named miss", absent["miss"], miss)
	var empty: Dictionary = BotFairness.baseline({})
	_t.eq("an empty record is the named miss", empty["miss"], miss)
	var good: Dictionary = BotFairness.baseline({"telegraph_share": 0.8, "stop_tax": 1.25, "first_hit": seg})
	_t.eq("a measured record has no miss", good["miss"], "")
	_t.near("the stop tax is returned", good["stop_tax"], 1.25)
	_t.near("the share is returned", good["share"], 0.8)
	_t.near("the first hit is returned", good["first_hit"], 4.5)
	_t.near("an unmeasured share reads -1", BotFairness.baseline({"telegraph_share": null})["share"], -1.0)
	_t.near("an unmeasured first hit reads -1", empty["first_hit"], -1.0)
	quit(_t.verdict())
