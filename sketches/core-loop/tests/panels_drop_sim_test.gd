extends SceneTree

const Panels := preload("res://src/build/panels.gd")
const T := preload("res://tests/support/t.gd")

# IL-01 drop simulation over recorded world 1 kill streams (tests/fixtures/panels_w1_kills.json:
# sixteen bot runs through the Spillway's two stages, eight seeds each of completionist and
# skipper, each kill as the drop saw it). Every stream is replayed through the real Dropper under SEEDS seeds.
# 1. World 1 pays: a run's mean panels by Brindle sits in RUN_BAND, and a completionist out-earns
#    a skipper. An explorer who also takes every rib cache (Panels.RIB_CACHES a stage) lands in
#    EXPLORER_BAND a stage on the completionist mean. The table it prints is the sim's record (panels per stage, per run).
# 2. The card's 7% row (worlds 2 and 3) pays its ordinary kills under three a stage on these
#    streams' kill volume: the per-stage grey bar belongs to the later worlds. World 1 is ruled per
#    run (RUN_BAND and RUN_CAP, DECISIONS 27 Oct): its certain elite drops and yard payouts sit on
#    top, so the whole card row reads about 4.4 a stage here and that read is printed, not judged.
# 3. Pity: each dry kill adds the pity step, a drop resets it, an elite always drops.
# 4. Determinism: one seed replays the same drops.
# Retune (when world 1's kill volume changes): re-record the streams with
#   godot --headless --fixed-fps 90 --path . --script res://tools/bot_run.gd -- --out=<dir> \
#     --policy=<completionist|skipper> --pilot=pylon_engineer --seeds=1,2,3,4,5,6,7,8 --stages=2 --table=park --gate=1 --warm-band=1 --panel-log=1
# fold each bots.ndjson record's panel_kills (as recorded: a yard lock crew's kill carries true
# as its seventh field, a cleared yard is a yard_clear row) and game_seconds into FIXTURE,
# then move Panels.DROP_BY_WORLD[1] until RUN_BAND and EXPLORER_BAND hold. All three live here.
# smoke: solo timeout=60s

const FIXTURE := "res://tests/fixtures/panels_w1_kills.json"
const SEEDS := 2000
# The band's top and the per-run cap track the measured yard-pays-once rate (DECISIONS, 27 Oct:
# 15.2 skipper and 24.0 completionist kill panels a run on 24 seeds at e6dd4fdf); a skipper that
# meets five or more elites (which always drop) lands 18-20 on the 27 Oct streams.
const RUN_BAND := [5.0, 16.0]
const RUN_CAP := 21.0
const EXPLORER_BAND := [6.0, 10.0]

var _t := T.new("panels_drop_sim_test")


func _initialize() -> void:
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	_t.check("fixture has runs", doc != null and doc["runs"].size() >= 4, FIXTURE)
	_paces(doc["runs"])
	_pity()
	_determinism(doc["runs"][0]["kills"])
	quit(_t.verdict())


# Panels dropped per stage for one replay of `kills` in `world`'s row. rolled_only counts only
# the drops an ordinary kill rolls, leaving out elite kills and yard payouts.
static func replay(kills: Array, seed: int, world := 1, rolled_only := false) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, "panels_drop_sim"])
	var dropper = Panels.Dropper.new()
	dropper.world = world
	var per := {}
	for k in kills:
		if String(k[1]) in Panels.NO_DROP_KINDS or (k.size() > 6 and bool(k[6])):
			continue
		# A cleared yard lock pays one panel without a roll (build.gd yard_cleared).
		if String(k[1]) == "yard_clear":
			if not rolled_only:
				per[int(k[0])] = int(per.get(int(k[0]), 0)) + 1
			continue
		if dropper.roll(rng, bool(k[2]), float(k[3]), bool(k[4])) and not (rolled_only and bool(k[2])):
			per[int(k[0])] = int(per.get(int(k[0]), 0)) + 1
	return per


static func mean_run(kills: Array, world := 1, rolled_only := false) -> Dictionary:
	var stages := {}
	for k in kills:
		stages[int(k[0])] = true
	var total := 0.0
	var per := {}
	for s in SEEDS:
		var got := replay(kills, s, world, rolled_only)
		for stage in stages:
			per[stage] = float(per.get(stage, 0.0)) + int(got.get(stage, 0))
			total += int(got.get(stage, 0))
	for stage in per:
		per[stage] = per[stage] / SEEDS
	return {"run": total / SEEDS, "per": per, "stages": stages.size()}


func _paces(runs: Array) -> void:
	var by_policy := {}
	var explorers := []
	var cards := []
	var card_rolls := []
	for run in runs:
		var kills: Array = run["kills"]
		var got := mean_run(kills)
		var card := mean_run(kills, 2)
		var name := "%s %s seed %d" % [run["policy"], run["pilot"], int(run["seed"])]
		var explorer: float = got["run"] / maxf(got["stages"], 1) + Panels.RIB_CACHES
		print("  %-36s %2d kills in %3.0f s: world 1 row %.1f a run %s; with every cache %.1f a stage; card row %.1f" % [
			name, kills.size(), float(run["game_seconds"]), got["run"], _per_text(got["per"]), explorer, card["run"]])
		if String(run["policy"]) == "completionist":
			explorers.append(explorer)
		_t.check("world 1 run pays (%s)" % name, got["run"] >= RUN_BAND[0] - 2.0 and got["run"] <= RUN_CAP,
			"%.1f panels by Brindle" % got["run"])
		cards.append(card["run"] / maxf(card["stages"], 1))
		var rolled := mean_run(kills, 2, true)
		card_rolls.append(rolled["run"] / maxf(rolled["stages"], 1))
		by_policy.get_or_add(String(run["policy"]), []).append(got["run"])
	# Explorer and card-row reads are means over the recorded runs: eight seeds a policy put a
	# completionist's kills anywhere from 11 to 28 over the two stages, wider than one band holds
	# run by run (2026-10-23, Spillway roster re-record).
	var explore := _mean(explorers)
	_t.check("explorer pays", explore >= EXPLORER_BAND[0] and explore <= EXPLORER_BAND[1], "%.1f a stage over %d completionist runs" % [explore, explorers.size()])
	var card_rolled := _mean(card_rolls)
	_t.check("card row's ordinary kills stay under three a stage", card_rolled < 3.0,
		"%.2f a stage from ordinary kills over %d runs (whole card row with elites and yards %.1f)" % [card_rolled, card_rolls.size(), _mean(cards)])
	var comp := _mean(by_policy.get("completionist", []))
	# A completionist's edge is the rib caches it takes (ruling ah): its kill panels plus every cache.
	var comp_with_caches := comp + Panels.RIB_CACHES * _stages(runs, "completionist")
	var skip := _mean(by_policy.get("skipper", []))
	_t.check("mean run inside the band", (comp + skip) * 0.5 >= RUN_BAND[0] and (comp + skip) * 0.5 <= RUN_BAND[1],
		"completionist %.1f, skipper %.1f, band %.0f to %.0f" % [comp, skip, RUN_BAND[0], RUN_BAND[1]])
	_t.check("completionist out-earns skipper", comp_with_caches > skip, "%.1f with its caches (%.1f from kills) vs %.1f" % [comp_with_caches, comp, skip])


func _pity() -> void:
	var row: Dictionary = Panels.DROP_BY_WORLD[1]
	var dropper = Panels.Dropper.new()
	dropper.world = 1
	var never := RandomNumberGenerator.new()
	_t.near("first kill is the base chance", dropper.chance(false, 1.0, false), row["chance"], 0.00001)
	dropper.dry = 3
	_t.near("three dry kills add three pity steps", dropper.chance(false, 1.0, false), row["chance"] + 3 * row["pity"], 0.00001)
	_t.near("jackpot doubles", dropper.chance(false, 1.0, true), minf((row["chance"] + 3 * row["pity"]) * Panels.DROP["jackpot"], 1.0), 0.00001)
	_t.eq("an elite always drops", dropper.chance(true, 1.0, false), 1.0)
	var dry_cap := ceili((1.0 - row["chance"]) / row["pity"])
	dropper.dry = dry_cap
	_t.near("pity reaches certainty", dropper.chance(false, 1.0, false), 1.0, 0.00001)
	never.seed = 5
	while dropper.roll(never, false, 1.0, false) == false:
		pass
	_t.eq("a drop resets pity", dropper.dry, 0)
	dropper.world = 3
	dropper.dry = 0
	_t.near("untuned worlds keep the card row", dropper.chance(false, 1.0, false), Panels.DROP["chance"], 0.00001)


func _determinism(kills: Array) -> void:
	_t.eq("same seed, same drops", replay(kills, 11), replay(kills, 11))


# The stages a policy's recorded runs crossed (the most any one run did).
static func _stages(runs: Array, policy: String) -> int:
	var most := 0
	for run in runs:
		if String(run["policy"]) != policy:
			continue
		var seen := {}
		for k in run["kills"]:
			seen[int(k[0])] = true
		most = maxi(most, seen.size())
	return most


static func _mean(values: Array) -> float:
	return values.reduce(func(a, v): return a + v, 0.0) / maxf(values.size(), 1.0)


static func _per_text(per: Dictionary) -> String:
	var parts := []
	for stage in per:
		parts.append("s%d %.1f" % [stage, per[stage]])
	return "(" + ", ".join(parts) + ")"
