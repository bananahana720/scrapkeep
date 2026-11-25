extends RefCounted

const BUDGET := {
	"threat": 8,
	"player": 12,
	"reward": 8,
	"ui": 4,
}

const THREAT_KINDS := [
	"boss_attack_telegraphed",
	"attack_cued",
	"guard_critical",
	"hold_started",
	"vent_charging",
	"vent_erupted",
	"special_tell",
	"threat_rose",
]

const REWARD_KINDS := [
	"scrap_collected",
	"cogs_collected",
	"armor_reclaim",
	"part_gained",
	"core_gained",
	"reward_offered",
	"reward_chosen",
	"milestone_won",
	"synergy_discovered",
	"achievement_earned",
	"rescue_completed",
	"evolution_fired",
	"quick_break",
	"near_miss",
	"beacon_charge_changed",
	"beacon_unsealed",
	"stage_cleared",
	"activity_done",
	"bet_resolved",
	"ambush_ended",
]

var _live := {"threat": [], "player": [], "reward": [], "ui": []}


static func voice_class(kind: String, is_danger: bool, bus: String) -> String:
	if bus == "UI":
		return "ui"
	if is_danger or kind in THREAT_KINDS:
		return "threat"
	if kind in REWARD_KINDS:
		return "reward"
	return "player"


func reserve(cls: String, is_playing: Callable) -> Array:
	var list: Array = _live.get(cls, [])
	var kept: Array = []
	for id in list:
		if is_playing.call(id):
			kept.append(id)
	var evict: Array = []
	if cls != "threat":
		var limit: int = int(BUDGET.get(cls, BUDGET["player"]))
		while kept.size() >= limit:
			evict.append(kept.pop_front())
	_live[cls] = kept
	return evict


func record(cls: String, id: int) -> void:
	if not _live.has(cls):
		_live[cls] = []
	(_live[cls] as Array).append(id)


func live_ids(cls: String) -> Array:
	return (_live.get(cls, []) as Array).duplicate()


func clear() -> void:
	for cls in _live:
		(_live[cls] as Array).clear()
