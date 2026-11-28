extends "res://tests/park_natural_test.gd"

const Bank := preload("res://src/presentation/sfx_bank.gd")
const Rows := preload("res://src/presentation/rows.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const LIVE_KEY := 3


func _run() -> void:
	t = T.new("park_natural_cue_test")
	var cases := []
	for k in KINDS.size():
		cases.append(_row(KINDS[k], FORMS[k]))
	var alternate := _row("cave_in", "ancient_stirring")
	alternate.id = "alternate_cave_in"
	cases.append(alternate)
	var alternate_water := _row("flash_flood", "lightning_charge")
	alternate_water.id = "alternate_flash_flood"
	cases.append(alternate_water)
	var slump := _row("collapse", "ground_slump")
	slump.id = "authored_slump_form"
	slump.effect.depth_m = 20.0
	slump.effect.fill_s = 4.0
	cases.append(slump)
	for family in [["fleet", "fleet_landing", "fleet_inbound"], ["ancient", "machine_eruption", "ancient_stirring"], ["industrial", "boiler_burst", "boiler_pressure"]]:
		var row := _row(family[1], family[2])
		row.family = family[0]
		cases.append(row)
	for row in cases:
		var kind: String = row.kind
		var fixture := _fixture(row, true)
		var w = fixture[0]
		var handler = fixture[1]
		var audio = w.presentation.audio
		audio.engine.key = LIVE_KEY
		audio.cue_log.clear()
		var phases := []
		var legacy_count: int = w.events.terrain.size()
		if row.family == "natural":
			t.eq(row.id + " avoids legacy fixed terrain presentation", legacy_count, 0)
		for i in 93:
			for fact in w.events.advance(0.1, FAR, Vector3.ZERO, {"clock_tier": 1, "grounded": true}):
				if fact.kind != "world":
					continue
				audio._last_start.clear()
				w.ctx.events.world_fact.emit(fact.fact, fact.at)
				phases.append(fact)
				if row.family == "natural":
					_check_mark(row.id + " " + fact.phase, handler.active[row.id].mark, EventKinds.world_row(fact.fact), row, w.events._park.park_rows[0], 0.0 if fact.phase == "telegraph" else 1.0)
			if row.telegraph.form == "ground_slump" and i == ceili(float(row.telegraph.lead_s) / 0.1 * 0.5):
				handler._process(0.0)
				_check_mark(row.id + " half warning", handler.active[row.id].mark,
					EventKinds.world_row(row.telegraph.form), row, w.events._park.park_rows[0], 0.5)
		t.eq(kind + " both cue phases", phases.size(), 2)
		var cues: Array = audio.cue_log.filter(func(c): return c[0] == "world_fact" and c[2] == "now")
		t.eq(kind + " one sound per phase", cues.size(), 2)
		for p in mini(2, cues.size()):
			var cue: Array = cues[p]
			var spec: Dictionary = EventKinds.world_row(phases[p].fact)
			t.eq(kind + " row chooses sound", cue[1], Rows.heard(spec, audio.cue_context()))
			t.near(kind + " bank and priority level", cue[5], Bank.trim_db(cue[1]) + Audio.PRIORITY_DB[Rows.priority(cue[0])])
			t.near(kind + " follows live key", cue[4], Harmony.ratio(LIVE_KEY))
		var audio_connected := func() -> bool:
			return w.ctx.events.get_signal_connection_list("world_fact").any(func(c): return c.callable.get_object() == audio)
		var handler_connected := func() -> bool:
			return w.ctx.events.get_signal_connection_list("world_fact").any(func(c): return c.callable.get_object() == handler)
		t.check(kind + " leaves world_fact owned by audio", audio_connected.call() and not handler_connected.call())
		handler.release()
		t.check(kind + " keeps audio listener after release", audio_connected.call() and not handler_connected.call())
		w.free()
	t.check("seven natural, alternate forms and shared family cue paths checked", cases.size() == 13)
	quit(t.verdict())


func _check_mark(label: String, mark: Node3D, spec: Dictionary, row: Dictionary, site: Dictionary, progress := 1.0) -> void:
	var meshes := mark.get_children().filter(func(child): return child is MeshInstance3D)
	var shape_ok := not meshes.is_empty()
	var color_ok := shape_ok
	var min_radius := INF
	var max_radius := -INF
	var max_cross := 0.0
	var half := Vector2(float(site.size[2]), float(site.size[0])) * 0.5
	var yaw := deg_to_rad(float(site.yaw_deg))
	if row.kind == "lightning":
		half = Vector2.ONE * float(row.effect.strike_m)
		yaw = 0.0
	for mesh: MeshInstance3D in meshes:
		var material := mesh.material_override as StandardMaterial3D
		color_ok = color_ok and material != null and material.albedo_color == spec.color
		shape_ok = shape_ok and mesh.mesh is ArrayMesh
		var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var low := INF
		var min_clearance := INF
		var dust_lift := -INF
		var crack_heights := {}
		if spec.get("pattern", "") == "dust_crack":
			for point in _mesh_vertices(mark.get_node("CrawlingCrack")):
				crack_heights[Vector2(point.x, point.z)] = point.y
		var high := -INF
		for vertex in vertices:
			var point: Vector3 = mesh.global_transform * vertex
			var local := Vector2(point.x, point.z).rotated(yaw)
			min_radius = minf(min_radius, (local / half).length())
			max_radius = maxf(max_radius, (local / half).length())
			max_cross = maxf(max_cross, minf(absf(local.x), absf(local.y)))
			min_clearance = minf(min_clearance, point.y - mark.get_parent().world.terrain.height(point.x, point.z))
			dust_lift = maxf(dust_lift, point.y - mark.get_parent().world.terrain.height(point.x, point.z) - 0.15)
			low = minf(low, point.y)
			high = maxf(high, point.y)
			if spec.get("pattern", "") == "dust_crack":
				var edge := 3.0 if mesh.name == "CrawlingCrack" else half.x
				shape_ok = shape_ok and local.x >= edge - float(spec.crack_width_m) - 0.0001 and local.x <= edge + 0.0001 and absf(local.y) <= half.y + 0.0001
			match spec.shape:
				"cross": shape_ok = shape_ok and (absf(local.x) <= 0.1501 or absf(local.y) <= 0.1501)
				"burst": shape_ok = shape_ok and (local / half).length() <= 1.0001
				"ring": shape_ok = shape_ok and (local / half).length() >= 0.9649 and (local / half).length() <= 1.0001
		if spec.get("pattern", "") == "dust_crack":
			if mesh.name == "DustCurtain":
				if progress == 0.0:
					t.check(label + " curtain begins below authored full height", dust_lift > 0.0 and dust_lift < float(spec.dust_height_m), str(dust_lift))
				else:
					t.near(label + " curtain height above crack reads canonical record", dust_lift, float(spec.dust_height_m) * progress)
			else:
				t.check(label + " crawling crack retains terrain clearance", min_clearance >= 0.1499, str(min_clearance))
		if spec.shape == "wave":
			shape_ok = shape_ok and high - low > 0.05
	t.check(label + " actual mesh follows WORLD_ROWS shape " + spec.shape, shape_ok, "radius=%s..%s cross=%s" % [min_radius, max_radius, max_cross])
	t.check(label + " actual material follows WORLD_ROWS color", color_ok)
