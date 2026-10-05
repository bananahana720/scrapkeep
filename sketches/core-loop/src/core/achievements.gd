extends RefCounted

# What the player did and the one thing it unlocks. A row listens to one bus signal
# (game_events.gd), counts matching emissions, or adds up a named argument, until it
# reaches count. need, min and max then compare one run fact. Nothing here evaluates a
# row; the listener unit reads this table so unlocks, the locked pilot card's hint and
# the saved record share one source.
#
# name     3 words or fewer
# text     what to do, 12 words or fewer, shown on a locked card
# on       the signal name
# where    optional: signal argument name -> the value it must carry
# sum      optional: a signal argument to add up instead of counting 1 per emission
# count    threshold, at least 1
# need     optional: a run summary key (SUMMARY_KEYS) or one of class, won, world
# min,max  optional numbers compared with the need key
# hidden   optional: the card shows no text until it is earned
# reward   {} for none, else exactly one of {"pilot": id}, {"cosmetic": id}, {"world": id};
#          a pilot id is a ClassDef id or a PENDING_PILOTS id

const FIELDS := ["name", "text", "on", "where", "sum", "count", "need", "min", "max", "hidden", "reward"]
const SUMMARY_KEYS := ["class", "stages", "scrap", "mass", "heft", "parts", "kills", "events_won", "time", "retries"]
const EVALUATOR_KEYS := ["class", "won", "world"]
const REWARD_KINDS := ["pilot", "cosmetic", "world"]
const NAME_WORDS := 3
const TEXT_WORDS := 12
const MIN_ROWS := 8
# Pilot ids a row may reward before their ClassDef row exists. The save records the unlock;
# the card appears when the row lands, and that unit removes the id here.
const PENDING_PILOTS := ["remembered_cannon", "tally"]

const ROWS := {
	"warden_broken": {"name": "Warden Breaker", "text": "Break your first Warden.", "on": "beacon_unsealed",
		"count": 1, "reward": {"cosmetic": "paint_any_night"}},
	"brindle_routed": {"name": "Brindle Routed", "text": "Rout Admiral Brindle.", "on": "enemy_killed",
		"where": {"kind": "brindle"}, "count": 1, "reward": {"pilot": "tarn"}},
	# rescue_site.gd emits rescue_completed("rivet"); Rivet is also a starter, so the row records the rescue.
	"rivet_rescued": {"name": "Runner Rescued", "text": "Rescue the stranded runner in world one.", "on": "rescue_completed",
		"where": {"quest_id": "rivet"}, "count": 1, "reward": {"pilot": "runner_gunner"}},
	# rescue_site.gd emits rescue_completed("dig") for this quest.
	"dig_rescued": {"name": "Digger Rescued", "text": "Rescue the buried digger.", "on": "rescue_completed",
		"where": {"quest_id": "dig"}, "count": 1, "reward": {"pilot": "demolitions_caster"}},
	"kills_100": {"name": "Hundred Down", "text": "Break 100 machines across all your runs.", "on": "enemy_killed",
		"count": 100, "reward": {"cosmetic": "paint_rivet_forge"}},
	"kills_1000": {"name": "Thousand Down", "text": "Break 1000 machines across all your runs.", "on": "enemy_killed",
		"count": 1000, "reward": {"cosmetic": "paint_sable_violet"}},
	"first_win": {"name": "Run Won", "text": "Win a run.", "on": "run_ended",
		"where": {"won": true}, "count": 1, "reward": {"cosmetic": "paint_kest_dusk"}},
	"clean_win": {"name": "Clean Run", "text": "Win a run without retrying a stage.", "on": "run_ended",
		"where": {"won": true}, "count": 1, "need": "retries", "max": 0, "hidden": true, "reward": {}},
	"first_event": {"name": "Event Won", "text": "Win a world event.", "on": "milestone_won",
		"count": 1, "reward": {}},
	"ten_events": {"name": "Event Regular", "text": "Win 10 world events across all your runs.", "on": "milestone_won",
		"count": 10, "reward": {}},
	# Beating the Mind remembers the cannon (ROADMAP:27); remembered_cannon is pending until its kit lands.
	"mind_quieted": {"name": "Mind Quieted", "text": "Quiet the Mind. An old cannon in the Highdraft remembers.",
		"on": "boss_defeated", "count": 1, "need": "world", "min": 3, "max": 3, "reward": {"pilot": "remembered_cannon"}},
	# Tally: three ledger leaves handed to Moss (progress.gd return_leaves); pil-G7 adds her ClassDef row.
	"ledger_balanced": {"name": "Ledger Balanced", "text": "Return one ledger leaf per world to Moss.", "on": "world_fact",
		"where": {"kind": "ledger_returned"}, "count": 3, "reward": {"pilot": "tally"}},
	"full_rack": {"name": "Full Rack", "text": "Finish a run holding 10 parts.", "on": "run_ended",
		"count": 1, "need": "parts", "min": 10, "reward": {}},
}


static func ids() -> Array:
	return ROWS.keys()


static func row(id: String) -> Dictionary:
	return ROWS.get(id, {})


static func reward_of(id: String) -> Dictionary:
	return row(id).get("reward", {})


static func for_pilot(pilot_id: String) -> String:
	for id in ROWS:
		if ROWS[id].get("reward", {}).get("pilot", "") == pilot_id and pilot_id != "":
			return id
	return ""


# The bus as signal name -> argument names, for validate.
static func bus_signals() -> Dictionary:
	var out := {}
	var script: Script = load("res://src/core/game_events.gd")
	for info in script.get_script_signal_list():
		var args: Array = []
		for arg in info["args"]:
			args.append(arg["name"])
		out[info["name"]] = args
	return out


static func _words(s: String) -> int:
	return s.split(" ", false).size()


# signals: signal name -> argument names. pilots and cosmetics: arrays of ids.
static func validate(rows: Dictionary, signals: Dictionary, pilots: Array, cosmetics: Array) -> Array:
	var problems: Array = []
	var pilot_rewards := {}
	if rows.size() < MIN_ROWS:
		problems.append("table: needs at least %d rows, has %d" % [MIN_ROWS, rows.size()])
	for id in rows:
		var r: Dictionary = rows[id]
		for key in r:
			if not FIELDS.has(key):
				problems.append("%s: unknown field %s" % [id, key])
		var title: String = str(r.get("name", ""))
		if title == "" or _words(title) > NAME_WORDS:
			problems.append("%s: name must be 1 to %d words" % [id, NAME_WORDS])
		var text: String = str(r.get("text", ""))
		if text == "" or _words(text) > TEXT_WORDS:
			problems.append("%s: text must be 1 to %d words" % [id, TEXT_WORDS])
		var on: String = str(r.get("on", ""))
		var args: Array = signals.get(on, [])
		if not signals.has(on):
			problems.append("%s: on %s is not a declared signal" % [id, on])
		var where = r.get("where", {})
		if not (where is Dictionary):
			problems.append("%s: where must be a dictionary of argument to value" % id)
		else:
			for key in where:
				if signals.has(on) and not args.has(key):
					problems.append("%s: where key %s is not an argument of %s" % [id, key, on])
		if r.has("sum") and signals.has(on) and not args.has(r["sum"]):
			problems.append("%s: sum %s is not an argument of %s" % [id, r["sum"], on])
		if not (r.get("count", 0) is int) or int(r.get("count", 0)) < 1:
			problems.append("%s: count must be an integer of at least 1" % id)
		if r.has("need") and not (SUMMARY_KEYS.has(r["need"]) or EVALUATOR_KEYS.has(r["need"])):
			problems.append("%s: need %s is not a summary key, class, won or world" % [id, r.get("need")])
		for bound in ["min", "max"]:
			if r.has(bound):
				if not (r[bound] is int or r[bound] is float):
					problems.append("%s: %s must be a number" % [id, bound])
				elif not r.has("need"):
					problems.append("%s: %s needs a need key to compare" % [id, bound])
		if r.has("hidden") and not (r["hidden"] is bool):
			problems.append("%s: hidden must be a bool" % id)
		var reward = r.get("reward")
		if not (reward is Dictionary):
			problems.append("%s: reward must be a dictionary" % id)
			continue
		if reward.size() > 1:
			problems.append("%s: reward must carry at most one kind" % id)
		for kind in reward:
			var target := str(reward[kind])
			if not REWARD_KINDS.has(kind):
				problems.append("%s: reward kind %s is unknown" % [id, kind])
			elif kind == "pilot":
				if not pilots.has(target) and not PENDING_PILOTS.has(target):
					problems.append("%s: reward pilot %s does not resolve" % [id, target])
				elif pilots.has(target) and PENDING_PILOTS.has(target):
					problems.append("%s: reward pilot %s has a ClassDef row; remove it from PENDING_PILOTS" % [id, target])
				elif pilot_rewards.has(target):
					problems.append("%s: reward pilot %s is already the reward of %s" % [id, target, pilot_rewards[target]])
				else:
					pilot_rewards[target] = id
			elif kind == "cosmetic" and not cosmetics.has(target):
				problems.append("%s: reward cosmetic %s does not resolve" % [id, target])
			elif kind == "world" and target == "":
				problems.append("%s: reward world must name a world" % id)
	return problems
