extends SceneTree

# W1-70 (critique finding 9): an authored activity row may list alternatives, and each run draws one per site
# from its seed, so run five does not meet run one's sites. An alternative brings its own activity and pack and
# keeps the row's place, site, pay and pocket role (PARK.md 2.12), so every map check on the row holds for each.
#   dam    domes_camp   three chasers | a trapper camp (chaser, mag_trapper, chaser)
#          bench_altar  ambush altar | a hauler bounty on the rim bench
#   flume  siphon_camp  three lobbers | a winch camp (lobber, winch_drone, lobber)
#          bench_bounty hauler bounty | an ambush altar on the south bench (chaser, lobber, lobber)
# Checks:
#   (a) both parks validate; the four rows carry their alts on the map's sites.
#   (b) the draw: one seed always draws the same site; over 24 seeds every row shows each of its options; an
#       alt keeps the row's place, row id and pay and takes its own kind and pack.
#   (c) in the game: entering the flume builds, at each row's place, the kind and pack its seed draws, and a
#       retry builds the same.
# Planted: an alt that turns a camp into an altar, an alt that moves the place or sets its own pay, and alts on a
# cache each fail (a).

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Activities := preload("res://src/world/activities.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const ParkSchema := preload("res://src/world/park/park_schema.gd")

const PARKS := {
	"park_dam": ["domes_camp", "bench_altar"],
	"park_flume": ["siphon_camp", "bench_bounty"],
}
const SEEDS := 24
const AT_EPS_M := 3.0

var _t := T.new("site_variants_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var flume_park := {}
	for map_id in PARKS:
		var path := "res://src/world/park/%s.json" % map_id
		var park: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		if map_id == "park_flume":
			flume_park = park
		_t.eq("%s validates" % map_id, ParkSchema.validate(park), [])
		var map := ParkMap.new(path)
		for row_id in PARKS[map_id]:
			var site := _site(map, row_id)
			_t.check("%s %s carries its alts" % [map_id, row_id], not site.get("alts", []).is_empty())
			_t.eq("%s %s: a seed draws the same site twice" % [map_id, row_id], Activities.variant(site, 7), Activities.variant(site, 7))
			var seen := {}
			var kept := true
			for seed in SEEDS:
				var drawn := Activities.variant(site, seed)
				seen[JSON.stringify([drawn["id"], drawn.get("pack", [])])] = true
				kept = kept and drawn["at"] == site["at"] and drawn["row"] == row_id and drawn.get("pay") == site.get("pay") and drawn.has("alts") == (drawn == site)
			_t.eq("%s %s: %d seeds show every option" % [map_id, row_id, SEEDS], seen.size(), 1 + site["alts"].size())
			_t.check("%s %s: every draw keeps the row's place" % [map_id, row_id], kept)

	_t.check("planted: a camp alt that is an altar fails", _breaks(flume_park, "siphon_camp", {"activity": "ambush_altar", "pack": []}))
	_t.check("planted: an alt that moves the place fails", _breaks(flume_park, "bench_bounty", {"activity": "ambush_altar", "pack": [], "at": [0, 0]}))
	_t.check("planted: an alt with its own pay fails", _breaks(flume_park, "bench_bounty", {"activity": "ambush_altar", "pack": [], "pay": {"rarities": ["rare"]}}))
	_t.check("planted: alts on a cache fail", _breaks(flume_park, "bend_cache", {"activity": "cracked_cache", "pack": []}))

	var game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	game.flow.force_warden = false
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(1)
	var stage := -1
	for i in game.ctx.terrain.maps.size():
		var m = game.ctx.terrain.maps[i]
		if "park" in m and String(m.park.get("map", "")) == "park_flume":
			stage = i + 1
	var map = game.ctx.terrain.maps[stage - 1]
	# A run seed that draws both flume rows' alternatives, so the live check sees the alts built.
	var want := {}
	for k in 64:
		game.ctx.run.run_seed = 1000 + k
		want = {}
		for row_id in PARKS["park_flume"]:
			var authored := _site(map, row_id)
			var drawn: Dictionary = game.world.activities.drawn(authored)
			if drawn != authored:
				want[row_id] = drawn
		if want.size() == PARKS["park_flume"].size():
			break
	if not _t.check("a run seed draws both flume alts", want.size() == 2):
		quit(_t.verdict())
		return
	game.flow.enter_stage(stage, Vector3.ZERO, false)
	await physics_frame
	await physics_frame
	for row_id in want:
		var built = _built_at(game, want[row_id]["at"])
		_t.eq("%s builds the drawn kind" % row_id, String(built.id) if built != null else "nothing", String(want[row_id]["id"]))
		if built != null:
			_t.eq("%s builds the drawn pack" % row_id, built.rule.get("pack", []), want[row_id]["pack"])
	game.flow.enter_stage(stage, Vector3.ZERO, true)
	await physics_frame
	await physics_frame
	for row_id in want:
		var again = _built_at(game, want[row_id]["at"])
		_t.eq("a retry builds %s's drawn kind again" % row_id, String(again.id) if again != null else "nothing", String(want[row_id]["id"]))
	_t.eq("expected check count", _t.checks + 1, 30)
	quit(_t.verdict())


func _built_at(game, at: Vector2):
	for s in game.world.activities.sites:
		if is_instance_valid(s) and not s.drawn and Vector2(s.global_position.x, s.global_position.z).distance_to(at) <= AT_EPS_M:
			return s
	return null


func _site(map, row_id: String) -> Dictionary:
	for s in map.activity_sites:
		if s["row"] == row_id:
			return s
	return {}


# True when the park fails its schema once `alt` is listed on the row.
func _breaks(park: Dictionary, row_id: String, alt: Dictionary) -> bool:
	var planted: Dictionary = park.duplicate(true)
	for r in planted["activity_rows"]:
		if r["id"] == row_id:
			r["alts"] = [alt]
	return not ParkSchema.validate(planted).is_empty()
