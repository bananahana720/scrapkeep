extends SceneTree

# Rule (dam f3822, unit 23 receipt on #494): the run's first moments draw no material for the
# first time mid-fight. After the first stage entry of a session, bake_warm.gd builds each first
# moment's views with its owner's own builder (the first kill's scrap pickups, the armour read's
# class icon and stamp words, the synergy ring, the arc mark, a machine word label with every glyph a
# word draws) in an inert holder out of sight, one a frame, holds their
# materials, and draws the codex category icons ahead. Fixture: the warm node on a bare event
# bus; it runs under the headless (dummy) renderer like every test here.

const T := preload("res://tests/support/t.gd")
const BakeWarm := preload("res://src/presentation/bake_warm.gd")
const ArmourMarks := preload("res://src/presentation/armour_marks.gd")
const CodexStyle := preload("res://src/presentation/codex_style.gd")
const Combat := preload("res://src/combat/combat.gd")
const ScrapField := preload("res://src/build/scrap_field.gd")
const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const MachineFx := preload("res://src/presentation/machine_fx.gd")
const Panels := preload("res://src/build/panels.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const Context := preload("res://src/core/context.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const Palette := preload("res://src/core/palette.gd")

# A row that names no kinds, so none stands: the firsts are this test's subject, the kinds that stand are bake_warm_test's.
const TABLE := {"DEFS": [{"stage": 1, "world": 1, "map": "park_test", "packs": [], "elite": {}}]}

var t := T.new("first_warm_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var events := GameEvents.new()
	root.add_child(events)
	var ctx := Context.new()
	ctx.events = events
	ctx.root = holder
	ctx.stages = TABLE

	SimClock.ticks = true
	BakeWarm.hook(ctx)
	var node: Node = holder.get_node("BakeWarm")
	events.stage_entered.emit(1, false)
	t.check("a bot run that builds stages whole queues no first moment", node._first_queue.is_empty())

	SimClock.ticks = false
	events.stage_entered.emit(1, false)
	var queued: Array = BakeWarm.firsts()
	t.check("the session's first entry queues every first moment and codex icon once",
		node._first_queue == queued and queued.size() == BakeWarm.FIRSTS.size() - 1 + _word_frames() + CodexStyle.CATEGORIES.size(), str(node._first_queue))
	events.stage_entered.emit(1, true)
	t.check("a retry queues none again", node._first_queue.size() == queued.size())

	var seen := []
	var most := 0
	var views := {}
	var placed := true
	var frames := 0
	while (not node._queue.is_empty() or not node._first_queue.is_empty()) and frames < 400:
		await process_frame
		frames += 1
		var standing := _first_warms(node)
		most = maxi(most, standing.size())
		for warm: Node3D in standing:
			var first := String(warm.get_meta("first_warm"))
			if first not in seen:
				seen.append(first)
				views[first] = warm.get_children().map(_read)
				placed = placed and warm.position == BakeWarm.OUT_OF_SIGHT and warm.process_mode == Node.PROCESS_MODE_DISABLED
	await process_frame
	t.check("each first moment with a view stands once, one at a time, and leaves",
		seen == queued.filter(func(f): return f != "hero_chunks" and not f.begins_with("codex_icon:")) and most == 1 and _first_warms(node).is_empty(), "%s, at most %d" % [seen, most])
	t.check("the views stand out of sight in a holder that never processes", placed)

	var armour: Array = views.get("armour_read", [])
	var icons := armour.filter(func(v): return v["name"] == "ArmourIcon")
	var built := _read(ArmourMarks.icon_view(ArmourMarks.icon_mesh(), ArmourMarks.icon_material()))
	t.check("the armour read's icon is the one a badge builds", icons.size() == 1 and icons[0] == built, "%s vs %s" % [icons, built])
	var words := armour.filter(func(v): return v.has("text")).map(func(v): return v["text"])
	var want := ArmourMarks.READ_STATES.values().map(func(state): return _read(ArmourMarks.word_label(state))["text"])
	t.check("and every stamp word stands beside it", words.size() == want.size() and words.all(func(w): return w in want and w != ""), "%s vs %s" % [words, want])
	var ring: Array = views.get("synergy_ring", [])
	t.check("the synergy ring is add_ring's", ring.size() == 1 and ring[0]["name"] == "SynergyRing" and ring[0]["blend"] == BaseMaterial3D.BLEND_MODE_ADD)
	var pickups: Array = views.get("scrap_pickup", [])
	var variants := ScrapField.PICKUP_VARIANTS.size()
	t.check("each scrap pickup and recovery cluster stands, in the pickup shader a field piece wears",
		pickups.size() == 2 * variants and pickups.all(func(v): return v["shader"] == ScrapField._pickup_material(Palette.ARC).shader), "%d views" % pickups.size())
	var arc: Array = views.get("arc_mark", [])
	t.check("the arc mark draws the shared ring every mark draws", arc.size() == 1 and arc[0]["mesh"] == Combat._arc_ring())
	var machine := []
	for i in _word_frames():
		machine.append_array(views.get("machine_words:%d" % i, []))
	t.check("the machine words stand at the size and outline a word draws, a few glyphs a frame, every glyph a word can draw in turn",
		machine.size() == _word_frames() and "".join(machine.map(func(v): return v["text"])) == MachineFx.WARM_GLYPHS
		and machine.all(func(v): return v["font"] == [112, 30, true] and v["text"].length() <= BakeWarm.GLYPHS_A_FRAME), str(machine))
	var drawn := MachineFx.WORDS.values()
	for table in [MachineFx.SPECIALS, MachineFx.BOSSES]:
		for row in table.values():
			for key in row:
				if String(key).ends_with("_word"):
					drawn.append(String(row[key]))
	for id in Panels.ids():
		drawn.append(Panels.pop_text(id))
	# A row with no word ("" , Brindle's phase since PF-26) draws nothing.
	drawn = drawn.filter(func(w: String): return w != "")
	var missing := drawn.filter(func(w: String): return Array(w.to_upper().replace(" ", "").split("")).any(func(c): return c not in MachineFx.WARM_GLYPHS))
	t.check("every machine word's glyphs are in the warm label", not drawn.is_empty() and missing.is_empty(), str(missing))
	t.check("the materials the views drew are held", BakeWarm._kept.size() == 3 and BakeWarm._kept.all(func(m): return is_instance_valid(m)))
	t.check("the kill chunks' glb is held, loaded on the main thread under the headless renderer, so a discovery burst reads the cache",
		ResourceLoader.has_cached(HeroAssets.CHUNKS_PATH) and BakeWarm._held.get(HeroAssets.CHUNKS_PATH) == load(HeroAssets.CHUNKS_PATH) and BakeWarm._loading.is_empty())
	# A threaded load still in flight at teardown is collected (a quit before it lands, scrapkeep#322). A script
	# stands in for the glb, whose meshes the headless renderer cannot load off the main thread.
	var standin := "res://src/core/sim_clock.gd"
	ResourceLoader.load_threaded_request(standin)
	BakeWarm._loading.append(standin)
	BakeWarm.settle()
	t.check("settle collects a load still in flight", BakeWarm._loading.is_empty() and BakeWarm._held.has(standin)
		and ResourceLoader.load_threaded_get_status(standin) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE)
	BakeWarm._held.erase(standin)
	t.check("the codex category icons are drawn ahead", CodexStyle.CATEGORIES.keys().all(func(id): return CodexStyle._icons.has(id)))

	events.stage_entered.emit(1, false)
	t.check("a later entry in the session queues none again", node._first_queue.is_empty())

	# A warm node freed before its firsts are built (a quit to the menu at once) leaves them to the next.
	BakeWarm._firsts_done = false
	events.stage_entered.emit(1, false)
	node.free()
	BakeWarm.hook(ctx)
	events.stage_entered.emit(1, false)
	t.check("a warm node freed part way leaves its firsts to the next one", holder.get_node("BakeWarm")._first_queue == BakeWarm.firsts())

	holder.queue_free()
	events.queue_free()
	await process_frame
	quit(t.verdict())


# What a view draws, read while it stands (its holder leaves the next frame).
func _read(view: Node) -> Dictionary:
	var row := {"name": String(view.name)}
	if view is Label3D:
		row["text"] = view.text
		row["font"] = [view.font_size, view.outline_size, view.uppercase]
	elif view is MeshInstance3D:
		var material: Material = view.material_override
		row["mesh"] = view.mesh if view.mesh is ArrayMesh else (view.mesh as PrimitiveMesh).get_class()
		row["box"] = view.mesh.size if view.mesh is BoxMesh else null
		row["at"] = view.position
		row["shading"] = material.shading_mode if material is BaseMaterial3D else -1
		row["blend"] = material.blend_mode if material is BaseMaterial3D else -1
		row["albedo"] = material.albedo_color if material is BaseMaterial3D else null
		row["shader"] = material.shader if material is ShaderMaterial else null
	if not view.is_inside_tree():
		view.free()
	return row


func _first_warms(node: Node) -> Array:
	return node.get_children().filter(func(child): return child.has_meta("first_warm") and not child.is_queued_for_deletion())


func _word_frames() -> int:
	return ceili(MachineFx.WARM_GLYPHS.length() / float(BakeWarm.GLYPHS_A_FRAME))
