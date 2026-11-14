extends SceneTree

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Activities := preload("res://src/world/activities.gd")
const ActivityView := preload("res://src/world/activity_view.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const Rows := preload("res://src/core/event_kinds.gd")
const LIBRARY := "res://src/world/pockets/pocket_library.gd"
const SIZES := {"small": 24.0, "medium": 32.0, "large": 44.0}
const SCALE := {1: 1.0, 5: 2.0, 10: 3.0}
const ARENAS := ["arena", "elite_arena", "round_arena", "ambush", "enemy_camp"]
var t := T.new("pocket_library_test")
var library
var game
var acts

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not t.check("authored library exists", FileAccess.file_exists(LIBRARY)):
		quit(t.verdict())
		return
	library = load(LIBRARY)
	var entries: Array = library.rows()
	_schema(entries)
	game = Game.new()
	game.test_mode = true
	game.table = "alpha"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.flow.press_start()
	game.flow.choose_class(0)
	await physics_frame
	game.world.set_physics_process(false)
	game.flow.set_physics_process(false)
	game.player.set_physics_process(false)
	game.player.active_body().freeze = true
	acts = game.world.activities
	acts.set_physics_process(false)
	acts.clear()
	var audio_frames := 0
	while not game.presentation.audio.sound_ready and audio_frames < 2700:
		await physics_frame
		audio_frames += 1
	await _built_stock(entries)
	var probe: Dictionary = entries.filter(func(entry): return entry.id == "runner_yard")[0].duplicate(true)
	probe.tell = {"word": "Selected record", "record": "cracked_cache"}
	var selected = _build(probe)
	_tell_on_entry(probe, selected)
	acts.clear()
	await physics_frame
	await _wiring(entries)
	await _unchanged()
	game.free()
	quit(t.verdict())

func _schema(entries: Array) -> void:
	var split := {"arena": 0, "trade": 0, "secret": 0}
	var ids := {}
	var assignments := {}
	for entry in entries:
		var keys := ["id", "kind", "activity", "footprint", "entrances", "entry_spot", "entry_radius", "difficulty", "weight", "density", "tell", "pack", "terrain", "hazards", "safe_path"]
		var complete: bool = keys.all(func(key): return entry.has(key))
		t.check("%s complete schema" % entry.get("id", "missing"), complete)
		if not complete:
			continue
		t.check(entry.id + " unique id and valid kind", not ids.has(entry.id) and split.has(entry.kind))
		ids[entry.id] = true
		if split.has(entry.kind):
			split[entry.kind] += 1
		var dims: bool = SIZES.has(entry.footprint) and SCALE.has(int(entry.difficulty))
		t.check(entry.id + " footprint and difficulty", dims)
		if not dims:
			continue
		t.check(entry.id + " positive default or rare weight", entry.weight in [1.0, 0.1])
		var d: Dictionary = entry.density
		t.check(entry.id + " start density shares", d.get("start", false) and d.get("terrain", 0) >= 60 and d.get("terrain", 0) <= 70 and d.get("enemies", 0) >= 20 and d.get("enemies", 0) <= 30 and d.get("pickups", 0) >= 5 and d.get("pickups", 0) <= 10 and d.get("terrain", 0) + d.get("enemies", 0) + d.get("pickups", 0) == 100)
		var side: float = SIZES[entry.footprint]
		var doors: bool = not entry.entrances.is_empty()
		for door in entry.entrances:
			doors = doors and door.get("marked", false) and door.get("width", 0) >= 4 and door.at.size() == 2 and absf(float(door.at[0])) <= side * 0.5 and absf(float(door.at[1])) <= side * 0.5 and is_equal_approx(maxf(absf(door.at[0]), absf(door.at[1])), side * 0.5)
		t.check(entry.id + " marked boundary entrances", doors)
		t.check(entry.id + " 40 metre clear entry radius", entry.entry_radius == 40.0 and Vector2(entry.entry_spot[0], entry.entry_spot[1]).length() <= side * 0.5)
		var tell: Dictionary = entry.tell
		t.check(entry.id + " tell uses an existing sight and sound record", not String(tell.get("word", "")).is_empty() and Rows.ACTIVITY_ROWS.has(tell.get("record", "")))
		t.check(entry.id + " allowed live family or inert trade", entry.activity in ARENAS if entry.kind == "arena" else entry.activity == "cracked_cache" if entry.kind == "secret" else entry.activity == "" and not entry.has("assigned"))
		t.check(entry.id + " no library position or pay", not entry.has("at") and not entry.has("pay"))
		if entry.has("assigned"):
			var key: String = entry.assigned.map + "/" + entry.assigned.row
			t.check(entry.id + " unique assignment", not assignments.has(key))
			assignments[key] = entry.id
	t.eq("25 interiors", entries.size(), 25)
	# The ninth secret is the dam's blazing cache room (W1-76), assigned and so never drawn.
	t.eq("eight per kind, nine secrets", split, {"arena": 8, "trade": 8, "secret": 9})
	t.eq("nine live world-one assignments", assignments.size(), 9)
	var copy: Array = library.rows()
	copy[0].tell.word = "mutated caller"
	t.check("callers cannot mutate cached library", library.rows()[0].tell.word != "mutated caller")
	t.eq("unknown site has no interior", library.for_site("unknown", "unknown"), {})

func _build(entry: Dictionary, kind := ""):
	var activity: String = entry.activity if kind == "" else kind
	var spec: Dictionary = library.site_spec(entry)
	spec["site"] = "library_test"
	var s = acts._build(activity, Vector2(100, 100), spec)
	acts.sites.append(s)
	return s

func _built_stock(entries: Array) -> void:
	var bands := {1: [], 5: [], 10: []}
	for entry in entries:
		if entry.kind == "trade":
			continue
		var built_entry: Dictionary = entry.duplicate(true)
		if "--substitute-tell" in OS.get_cmdline_user_args():
			built_entry.tell.record = "enemy_camp" if Rows.ACTIVITY_ROWS[entry.tell.record].shape == "diamond" else "cracked_cache"
		var s = _build(built_entry)
		var side: float = SIZES[entry.footprint]
		t.check(entry.id + " built ring scale footprint and tell", s.rule.ring == entry.ring and s.difficulty == SCALE[int(entry.difficulty)] and s.footprint == Vector3(side, 8, side) and s.view.word.text.begins_with(entry.tell.word))
		var dash: Vector3 = s.view.ring.get_child(0).position
		t.near(entry.id + " rendered ring radius", Vector2(dash.x, dash.z).length(), entry.ring)
		var interior = s.get_node("Interior_" + String(entry.id))
		t.eq(entry.id + " built authored terrain and entrance markers", interior.get_child_count(), entry.terrain.size() + entry.entrances.size() * 2)
		_tell_on_entry(entry, s)
		if entry.kind == "arena":
			t.eq(entry.id + " built authored pack", s.rule.pack, entry.pack)
			acts._spawn_pocket_pack(s, s.rule.pack)
			var health := 0.0
			for enemy in s.pack:
				health += enemy.max_hp
				var local: Vector3 = s.to_local(enemy.global_position)
				var start := Vector2(entry.entry_spot[0], entry.entry_spot[1])
				var point := Vector2(local.x, local.z)
				var closest := start * clampf(point.dot(start) / start.length_squared(), 0.0, 1.0)
				t.check(entry.id + " enemy body clears four metre entry corridor", point.distance_to(closest) >= 2.0 + enemy.radius, "point=%s entry=%s radius=%s" % [point, start, enemy.radius])
			bands[int(entry.difficulty)].append({"id": entry.id, "count": s.pack.size(), "health": health})
			t.eq(entry.id + " built hazard footprints", s.hazards.size(), entry.hazards.size())
			for i in s.hazards.size():
				var box: Dictionary = entry.hazards[i]
				t.eq(entry.id + " hazard box " + str(i), s.hazards[i]._size, Vector3(box.size[0], box.size[1], box.size[2]))
		acts.clear()
		await physics_frame
	for difficulty in [5, 10]:
		var previous: Array = bands[1 if difficulty == 5 else 5]
		for current in bands[difficulty]:
			var rises: bool = not previous.is_empty() and current.count > 0
			for lower in previous:
				rises = rises and current.count > lower.count and current.health > lower.health and current.health / lower.health >= float(current.count) / lower.count - 0.000001
			t.check(current.id + " health rises at least as fast as count", rises, JSON.stringify({"current": current, "previous": previous}))
	print("pocket health bands: " + JSON.stringify(bands))

func _tell_on_entry(entry: Dictionary, s) -> void:
	var expected: Dictionary = Rows.ACTIVITY_ROWS[entry.tell.record]
	var audio = game.presentation.audio
	audio._last_start.clear()
	var since: int = audio.cue_log.size()
	var at: Vector3 = s.to_global(Vector3(entry.entry_spot[0], 0, entry.entry_spot[1]))
	s.view.near(at)
	var cues: Array = audio.cue_log.slice(since).filter(func(c): return c[0] == "interaction_found")
	t.check(entry.id + " authored word visible at transformed entry", s.view.word.visible and s.view.word.text.split(" — Tier ")[0] == entry.tell.word, "at=%s text=%s" % [at, s.view.word.text])
	t.check(entry.id + " rendered entry glyph matches selected record", _glyph_matches(s.view.glyph, String(expected.shape)), "expected=%s" % expected.shape)
	t.check(entry.id + " entry audio request matches selected record", cues.size() == 1 and cues[0][1] == expected.sound and cues[0][2] == "now", "cues=%s expected=%s" % [cues, expected.sound])
	var after: int = audio.cue_log.size()
	s.view.near(at)
	t.eq(entry.id + " entry cue sounds once", audio.cue_log.size(), after)

func _glyph_matches(glyph: Node3D, shape: String) -> bool:
	if not glyph.visible:
		return false
	if shape == "cross":
		if glyph.get_child_count() != 3:
			return false
		for axis in 3:
			var part = glyph.get_child(axis)
			var size := Vector3.ONE * ActivityView.GLYPH_SIZE * 0.3
			size[axis] = ActivityView.GLYPH_SIZE
			if not part is MeshInstance3D or not part.mesh is BoxMesh or not part.mesh.size.is_equal_approx(size):
				return false
		return true
	if glyph.get_child_count() != 1 or not glyph.get_child(0) is MeshInstance3D:
		return false
	var mesh = glyph.get_child(0).mesh
	if shape == "diamond":
		return mesh is SphereMesh and mesh.radial_segments == 4 and mesh.rings == 2 and is_equal_approx(mesh.radius, ActivityView.GLYPH_SIZE * 0.55) and is_equal_approx(mesh.height, ActivityView.GLYPH_SIZE * 1.1)
	return shape == "square" and mesh is BoxMesh and mesh.size.is_equal_approx(Vector3.ONE * ActivityView.GLYPH_SIZE * 0.8)

func _wiring(entries: Array) -> void:
	var index: int = game.ctx.terrain.stage - 1
	var previous = game.ctx.terrain.maps[index]
	var covered := 0
	for definition in ParkDefs.DEFS.duplicate(true) + StageDefs.DEFS.duplicate(true):
		if StageDefs.world_of(int(definition.stage)) != 1:
			continue
		var stage_index: int = int(definition.stage) - 1
		var held_map = game.ctx.terrain.maps[stage_index]
		var map = game.ctx.terrain.map_named(definition.map, definition.stage)
		game.ctx.terrain.maps[stage_index] = map
		game.ctx.terrain.stage = int(definition.stage)
		acts._on_stage_entered(game.run.stage, false)
		for i in map.activity_sites.size():
			# The site this run built: the row, or the alt its seed drew (W1-70), which keeps the row's interior.
			var spec: Dictionary = acts.drawn(map.activity_sites[i])
			if not spec.id in ARENAS and spec.id != "cracked_cache":
				continue
			var row_id: String = spec.get("row", spec.id)
			var entry: Dictionary = library.for_site(definition.map, row_id)
			t.check(row_id + " assigned library interior exists", not entry.is_empty())
			if entry.is_empty():
				continue
			var s = acts.sites[i]
			var side: float = SIZES[entry.footprint]
			var authored_pack: Array = spec.get("pack", [])
			var expected_pack: Array = entry.pack if authored_pack.is_empty() else authored_pack
			var expected_word: String = entry.tell.word if authored_pack.is_empty() else Rows.ACTIVITY_ROWS[spec.id].word
			if not authored_pack.is_empty():
				t.eq(row_id + " stage-authored named pack survives library merge", s.rule.pack, authored_pack)
				t.eq(row_id + " stage-authored pack keeps baseline word", s.view.word.text, expected_word)
			t.check(row_id + " stage-entry merge reaches built pocket", s.interior.get("id", "") == entry.id and s.rule.ring == entry.ring and s.difficulty == SCALE[int(entry.difficulty)] and s.footprint == Vector3(side, 8, side) and s.view.word.text.begins_with(expected_word) and (expected_pack.is_empty() or s.rule.pack == expected_pack))
			t.eq(row_id + " stage-entry hazard footprints", s.hazards.size(), entry.hazards.size())
			var expected_at: Vector3 = game.ctx.terrain.drop_point(spec.at.x, spec.at.y, 0)
			if spec.id == "cracked_cache":
				expected_at += s.global_basis.z * Activities.CACHE_LANE_OFFSET
				expected_at.y = game.ctx.terrain.height(expected_at.x, expected_at.z)
			t.eq(row_id + " position stays stage-owned", s.global_position, expected_at)
			for key in ["rarities", "named"]:
				if spec.get("pay", {}).has(key):
					t.eq(row_id + " pay stays stage-owned " + key, s.rule.pay[key], spec.pay[key])
			covered += 1
		game.ctx.terrain.maps[stage_index] = held_map
		game.ctx.terrain.stage = index + 1
		acts.clear()
		await physics_frame
	t.eq("world one live coverage", covered, 9)
	game.ctx.terrain.maps[index] = previous

func _unchanged() -> void:
	var index: int = game.ctx.terrain.stage - 1
	var previous = game.ctx.terrain.maps[index]
	game.ctx.terrain.maps[index] = ParkMap.new("res://src/world/park/park_test.json")
	acts._on_stage_entered(game.run.stage, false)
	var s = acts.site("enemy_camp")
	# 2026-11-09 (ruling bu): the camp rule's own pay is a common roll with no named part, so a row that
	# names no rarities reads ["common"] where it read ["common", "rare"]. This row still names hot_rivets,
	# which every table offers, so what the camp pays is the same; the pay table check below holds that.
	var want := {"starts": "ring", "ring": 8.0, "pack": ["chaser", "chaser", "chaser"], "finishes": "pack_dead", "pay": {"scrap": 180, "named": "hot_rivets", "rarities": ["common"], "source": "activity_camp", "where": "camp"}}
	t.eq("unassigned wash_camp rule equals c81cec4 but for the rule's own rarities", s.rule, want)
	t.eq("unassigned wash_camp pays its named part as at c81cec4", acts.pay_table(s), {"named": "hot_rivets", "rarities": ["common"]})
	t.check("unassigned wash_camp footprint equals c81cec4", s.footprint == Vector3(32, 8, 32) and s.fog._size == Vector3(32, 8, 32))
	t.check("unassigned wash_camp state and view equal c81cec4", s.interior.is_empty() and s.difficulty == 1.0 and not s.started and not s.done and not s.failed and s.view.word.text == "Camp" and s.hazards.size() == 1 and s.pack.is_empty())
	t.eq("unassigned camp location equals c81cec4", s.global_position, game.ctx.terrain.drop_point(-150, -300, 0))
	print("unchanged-site c81cec4 wash_camp: ring=8; difficulty=1; pack=chaser/chaser/chaser; footprint=32x8x32; tell=Camp; pay=180/named hot_rivets; at=(-150,-300); unstarted, unfinished, no enemies")
	acts.clear()
	await physics_frame
	game.ctx.terrain.maps[index] = previous
