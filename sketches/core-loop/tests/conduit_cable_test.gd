extends SceneTree

# Command cables (W46 E1-15, design-v3/WAYFINDING.md section 3, src/presentation/conduit_cable.gd), read on the real
# Dam park file and its baked ground through a stand-in context (terrain, events bus and gate), so the test drives the
# cable's own public calls and signals without booting the game:
#   (a) one cable per cable_rows row, in pip order, each one MeshInstance3D with one surface and one material (one draw),
#       no shadow, no collider, laid on the ground (no point floats over it or sinks past its sink);
#   (b) the tube is closed (every edge of every triangle shared by exactly two, castings and caps included), RADIUS
#       thick, SIDES sided; the severed cable is closed too, in more pieces;
#   (c) colour law: charcoal jacket, ANCIENT beads, never the live mint, saturation at most 0.65 on the jacket;
#   (d) the gate's pips_lit() kills cables in pip order: a dead cable takes the severed mesh and the plain material and is
#       marked visited ("cable:<id>", kind cable) on the site markers once; a lower count (retry) brings it back;
#   (e) reduced motion stops the beads, and lifting it starts them again;
#   (f) cleared drops every cable, entry (retry) rebuilds them all alive, and freeing the node leaves no orphan;
#       the script keeps no static state.
# Planted: a mesh with one triangle removed is not closed, so the closed check can fail.

const T := preload("res://tests/support/t.gd")
const ConduitCable := preload("res://src/presentation/conduit_cable.gd")
const SiteMarkers := preload("res://src/presentation/site_markers.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const ParkProps := preload("res://src/presentation/park_props.gd")
const Palette := preload("res://src/core/palette.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")

const MAP := "park_dam"
const FLOAT_MAX_M := 2.0

var t := T.new("conduit_cable_test")


class FakeTerrain extends RefCounted:
	var current
	var ground: Callable

	func map():
		return current

	func height(x: float, z: float) -> float:
		return (ground.call(x, z, 0.0) as Vector3).y


class FakeGate extends RefCounted:
	var lit := 0

	func pips_lit() -> int:
		return lit


class FakeFlow extends RefCounted:
	var gate := FakeGate.new()


class FakeCtx extends RefCounted:
	var terrain := FakeTerrain.new()
	var events
	var flow := FakeFlow.new()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var orphans_before := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var world := ParkProps.world_for(MAP)
	var ctx := FakeCtx.new()
	ctx.terrain.current = world["map"]
	ctx.terrain.ground = world["ground"]
	ctx.events = GameEvents.new()
	root.add_child(ctx.events)
	var markers := SiteMarkers.new()
	var cable := ConduitCable.new()
	root.add_child(cable)
	cable.setup(ctx, markers)
	ctx.events.stage_entered.emit(1, false)
	await process_frame
	var rows: Array = world["map"].park.get("cable_rows", [])
	_built(cable, rows, ctx)
	_closed(cable)
	_colours(cable)
	await _pips(cable, ctx, markers)
	await _motion(cable)
	await _lifecycle(cable, ctx, rows)
	cable.free()
	markers.free()
	await process_frame
	t.eq("freeing the cable node leaves no orphan node", Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), orphans_before)
	var source := FileAccess.get_file_as_string("res://src/presentation/conduit_cable.gd")
	t.check("conduit_cable.gd keeps no static state", not source.contains("static var"))
	ctx.events.queue_free()
	await process_frame
	quit(t.verdict())


func _built(cable, rows: Array, ctx) -> void:
	var list: Array = cable.cables()
	t.eq("one cable per cable_rows row", list.size(), rows.size())
	t.check("the Dam names five cables, one per pack its gate asks for", list.size() == 5, "%d" % list.size())
	var pips := []
	for c: Dictionary in list:
		pips.append(int(c["pip"]))
	var sorted := pips.duplicate()
	sorted.sort()
	t.eq("cables stand in pip order", pips, sorted)
	for c: Dictionary in list:
		var view: MeshInstance3D = c["view"]
		var id := String(c["id"])
		t.check("%s is alive on entry" % id, not bool(c["dead"]))
		t.eq("%s is one surface (one draw)" % id, view.mesh.get_surface_count(), 1)
		t.check("%s has one material over it" % id, view.material_override is ShaderMaterial)
		t.eq("%s casts no shadow" % id, view.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		t.eq("%s has no collider" % id, view.find_children("*", "CollisionObject3D", true, false).size(), 0)
		var worst_float := 0.0
		var worst_sink := 0.0
		var faces: PackedVector3Array = view.mesh.get_faces()
		for k in range(0, faces.size(), 7):
			var v := faces[k]
			var below: float = v.y - ctx.terrain.height(v.x, v.z)
			worst_float = maxf(worst_float, below)
			worst_sink = minf(worst_sink, below)
		# A casting stands CASTING.y - CAST_BURY_M over the ground; nothing of a cable stands much higher (a slope under
		# a casting adds its fall across the casting, a convex edge between two samples a little), nor sinks deeper than
		# its end's sink and casting bury.
		t.check("%s floats nowhere over the ground" % id, worst_float <= FLOAT_MAX_M, "%.2f m" % worst_float)
		t.check("%s sinks nowhere past its ends" % id, worst_sink >= -(ConduitCable.SINK_M + ConduitCable.CAST_BURY_M + 2.0), "%.2f m" % worst_sink)


func _closed(cable) -> void:
	var flat := func(_x: float, _z: float) -> float: return 0.0
	var line := PackedVector2Array([Vector2(0, 0), Vector2(20, 0), Vector2(40, 10)])
	var live: ArrayMesh = ConduitCable.cable_mesh(line, flat, -1.0)
	var dead: ArrayMesh = ConduitCable.cable_mesh(line, flat, ConduitCable.BREAK_FROM_CLAMP_M)
	t.eq("a live cable is closed (open edges)", _open_edges(live.get_faces()), 0)
	t.eq("a severed cable is closed (open edges)", _open_edges(dead.get_faces()), 0)
	var planted := live.get_faces()
	planted.resize(planted.size() - 3)
	t.check("planted: a cable missing one triangle is not closed", _open_edges(planted) > 0)
	# Its thickness: on the flat ground a mid-span slice of the tube stands LIFT_M - RADIUS to LIFT_M + RADIUS.
	var lo := INF
	var hi := -INF
	for v: Vector3 in live.get_faces():
		if v.x > 8.0 and v.x < 12.0:
			lo = minf(lo, v.y)
			hi = maxf(hi, v.y)
	t.near("the tube is RADIUS * 2 thick", hi - lo, ConduitCable.RADIUS * 2.0, 0.02)
	t.near("the tube rests on the ground", lo, ConduitCable.LIFT_M - ConduitCable.RADIUS, 0.02)
	var ring := {}
	for v: Vector3 in live.get_faces():
		if absf(v.x - 10.0) < 0.001:
			ring["%.3f,%.3f" % [v.y, v.z]] = true
	t.eq("the tube has SIDES sides", ring.size(), ConduitCable.SIDES)


func _colours(cable) -> void:
	var live: ShaderMaterial = cable.cables()[0]["view"].material_override
	var bead: Color = live.get_shader_parameter("bead")
	t.check("the beads are ANCIENT", bead.is_equal_approx(Palette.ANCIENT))
	t.check("the beads are never the live mint", not bead.is_equal_approx(Palette.ARC))
	var arrays: Array = (cable.cables()[0]["view"].mesh as ArrayMesh).surface_get_arrays(0)
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var worst := 0.0
	var mint := false
	for c: Color in colours:
		worst = maxf(worst, c.s)
		mint = mint or _close(c, Palette.ARC)
	t.check("the jacket and castings are charcoal and cast iron (saturation at most 0.65)", worst <= 0.65, "%.2f" % worst)
	t.check("no vertex of a cable is the live mint", not mint)


func _pips(cable, ctx, markers) -> void:
	ctx.flow.gate.lit = 2
	cable.refresh()
	for c: Dictionary in cable.cables():
		var want_dead: bool = int(c["pip"]) <= 2
		t.eq("pips lit 2: %s dead" % c["id"], bool(c["dead"]), want_dead)
		if want_dead:
			t.check("%s takes the plain severed material" % c["id"], c["view"].material_override is StandardMaterial3D)
			t.check("%s is marked visited" % c["id"], markers.is_visited("cable:" + String(c["id"])))
			t.eq("%s is marked severed" % c["id"], String(markers.visited_state("cable:" + String(c["id"]))["mark"]), "severed")
	t.check("a dark pip's cable is not marked", not markers.is_visited("cable:" + String(cable.cables()[4]["id"])))
	t.eq("refresh again marks nothing twice", markers.visited_sites().size(), 2)
	ctx.flow.gate.lit = 5
	await process_frame
	var all_dead: bool = cable.cables().all(func(c: Dictionary) -> bool: return bool(c["dead"]))
	t.check("every pip lit (the camp or the clock): every cable dead, read each frame", all_dead)
	ctx.flow.gate.lit = 0
	await process_frame
	var all_live: bool = cable.cables().all(func(c: Dictionary) -> bool: return not bool(c["dead"]))
	t.check("pips back to 0 (retry): every cable alive again", all_live)


func _motion(cable) -> void:
	var live: ShaderMaterial = cable.cables()[0]["view"].material_override
	t.near("the beads run", float(live.get_shader_parameter("speed")), ConduitCable.BEAD_SPEED)
	UiTokens.reduced_motion = true
	await process_frame
	t.near("reduced motion: the beads stand still", float(live.get_shader_parameter("speed")), 0.0)
	UiTokens.reduced_motion = false
	await process_frame
	t.near("motion back on: the beads run again", float(live.get_shader_parameter("speed")), ConduitCable.BEAD_SPEED)


func _lifecycle(cable, ctx, rows: Array) -> void:
	ctx.events.stage_content_cleared.emit("test")
	await process_frame
	t.eq("cleared: no cable stands", cable.cables().size(), 0)
	t.eq("cleared: no cable view is left", cable.get_child_count(), 0)
	ctx.flow.gate.lit = 0
	ctx.events.stage_entered.emit(1, true)
	await process_frame
	t.eq("retry: every cable is rebuilt", cable.cables().size(), rows.size())
	t.eq("retry: one view per cable, no leftovers", cable.get_child_count(), rows.size())


# Edges of a triangle soup (positions rounded to a millimetre) used by other than exactly two triangles.
func _open_edges(faces: PackedVector3Array) -> int:
	var count := {}
	for k in range(0, faces.size(), 3):
		for e in 3:
			var a := _key(faces[k + e])
			var b := _key(faces[k + (e + 1) % 3])
			var edge := a + "|" + b if a < b else b + "|" + a
			count[edge] = int(count.get(edge, 0)) + 1
	var open := 0
	for edge in count:
		if int(count[edge]) != 2:
			open += 1
	return open


func _key(v: Vector3) -> String:
	return "%d,%d,%d" % [roundi(v.x * 1000.0), roundi(v.y * 1000.0), roundi(v.z * 1000.0)]


func _close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.08
