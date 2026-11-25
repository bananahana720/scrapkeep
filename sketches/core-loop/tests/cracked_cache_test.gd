extends SceneTree

# The keeper flag a spent cracked cache puts up (W46 E1-15, design-v3/WAYFINDING.md section 4; CrackedCache.raise_flag,
# raised by the cache device's take() and, for the park's cracked pockets, by site_markers.gd on their activity_done):
#   (a) the flag is the keeper_flag model: a spring pole and one cloth, no collider, no light, no shadow;
#   (b) colour law: the cloth is SAND and the pole iron and copper, saturation at most 0.65, never the live mint;
#   (c) it springs up from its coil and settles at FLAG_SCALE within FLAG_SETTLE_S (plus a frame), and its cloth sways;
#       under reduced motion it stands at once and its cloth is still;
#   (d) the device: take() raises one flag over the cache's roof; another cache's spent fact raises none on it;
#   (e) site markers: a cracked_cache activity_done raises one flag on the pocket's roof line and marks the site visited
#       (kind cache, mark flag); a repeat raises none; another activity raises none; leaving the stage (cleared or
#       entry) frees every flag, and freeing the markers leaves no orphan.
# Planted: a flag raised under a parent freed at once is gone, so the "frees every flag" read can fail.

const T := preload("res://tests/support/t.gd")
const CrackedCache := preload("res://src/world/cracked_cache.gd")
const SiteMarkers := preload("res://src/presentation/site_markers.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const Palette := preload("res://src/core/palette.gd")

var t := T.new("cracked_cache_test")


# Flat at 2 m with a cliff (20 m) everywhere north of z 395: a pocket at z 400 cut into its face opens south.
class FakeTerrain extends RefCounted:
	func height(_x: float, z: float) -> float:
		return 2.0 if z > 395.0 else 20.0


class FakeRun extends RefCounted:
	func add_part(_id: String, _from: String) -> void: pass


class FakeCtx extends RefCounted:
	var events
	var terrain := FakeTerrain.new()
	var run := FakeRun.new()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var orphans_before := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	await _model()
	await _settle()
	await _device()
	await _markers()
	await process_frame
	t.eq("no orphan node is left", Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), orphans_before)
	quit(t.verdict())


func _model() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var flag: Node3D = CrackedCache.raise_flag(holder, Vector3(3.0, 1.0, -2.0), true)
	t.check("the flag model loads", flag != null)
	if flag == null:
		holder.free()
		return
	t.eq("the flag stands under its parent", flag.get_parent(), holder)
	t.check("its foot is where it was raised", flag.global_position.is_equal_approx(Vector3(3.0, 1.0, -2.0)))
	var views: Array = flag.find_children("*", "MeshInstance3D", true, false)
	var names := views.map(func(v: MeshInstance3D) -> String: return String(v.name))
	t.check("a pole and one cloth", names.has("FlagPole") and names.has(CrackedCache.FLAG_CLOTH) and views.size() == 2, str(names))
	t.eq("no collider", flag.find_children("*", "CollisionObject3D", true, false).size(), 0)
	t.eq("no light", flag.find_children("*", "Light3D", true, false).size(), 0)
	var worst := 0.0
	var mint := false
	var cloth_sand := false
	for view: MeshInstance3D in views:
		t.eq("%s casts no shadow" % view.name, view.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		var mesh: Mesh = view.mesh
		for s in mesh.get_surface_count():
			var colours = mesh.surface_get_arrays(s)[Mesh.ARRAY_COLOR]
			if colours == null:
				continue
			for c: Color in colours:
				var srgb := c.linear_to_srgb()
				worst = maxf(worst, srgb.s)
				mint = mint or _close(srgb, Palette.ARC)
				if String(view.name) == CrackedCache.FLAG_CLOTH and _close(srgb, Palette.SAND):
					cloth_sand = true
	t.check("the cloth is sand", cloth_sand)
	t.check("saturation at most 0.65", worst <= 0.65, "%.2f" % worst)
	t.check("never the live mint", not mint)
	t.near("still: it stands at FLAG_SCALE at once", flag.scale.y, CrackedCache.FLAG_SCALE)
	var cloth: MeshInstance3D = views.filter(func(v: MeshInstance3D) -> bool: return String(v.name) == CrackedCache.FLAG_CLOTH)[0]
	t.near("still: its cloth does not sway", float((cloth.material_override as ShaderMaterial).get_shader_parameter("sway")), 0.0)
	holder.free()
	await process_frame


func _settle() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var flag: Node3D = CrackedCache.raise_flag(holder, Vector3.ZERO)
	t.check("it starts low on its coil", flag.scale.y < CrackedCache.FLAG_SCALE * 0.5, "%.2f" % flag.scale.y)
	var cloth: MeshInstance3D = flag.find_child(CrackedCache.FLAG_CLOTH, true, false)
	t.near("its cloth sways", float((cloth.material_override as ShaderMaterial).get_shader_parameter("sway")), 1.0)
	# Step frames on the tree's own process delta (the clock the tween runs on) past the settle time.
	var stepped := 0.0
	while stepped < CrackedCache.FLAG_SETTLE_S + 0.1:
		await process_frame
		stepped += holder.get_process_delta_time()
	t.near("it has settled at FLAG_SCALE by FLAG_SETTLE_S", flag.scale.y, CrackedCache.FLAG_SCALE, 0.01)
	holder.free()
	await process_frame


func _device() -> void:
	var ctx := FakeCtx.new()
	ctx.events = GameEvents.new()
	root.add_child(ctx.events)
	var cache := CrackedCache.new()
	cache.ctx = ctx
	cache.relic_guaranteed = true
	cache.offers = ["x"]
	root.add_child(cache)
	cache.global_position = Vector3(10.0, 2.0, 10.0)
	cache.build()
	ctx.events.world_fact.emit("cache_spent", Vector3(-50.0, 2.0, 10.0))
	t.check("another cache's spent fact raises no flag here", cache.flag == null)
	cache.take(0)
	t.check("take() raises the keeper flag", cache.flag != null and cache.flag.get_parent() == cache)
	if cache.flag != null:
		t.check("it stands over the roof", cache.flag.global_position.y > cache.global_position.y + CrackedCache.HEIGHT,
			"y %.1f" % cache.flag.global_position.y)
		var first: Node3D = cache.flag
		ctx.events.world_fact.emit("cache_spent", cache.global_position)
		t.check("a repeat of its own fact raises no second flag", cache.flag == first and cache.find_children("KeeperFlag", "", false, false).size() == 1)
	cache.free()
	ctx.events.free()
	await process_frame


func _markers() -> void:
	var ctx := FakeCtx.new()
	ctx.events = GameEvents.new()
	root.add_child(ctx.events)
	var markers := SiteMarkers.new()
	root.add_child(markers)
	markers.setup(ctx)
	var at := Vector3(-210.0, 2.0, 400.0)
	ctx.events.activity_done.emit("cracked_cache", at)
	t.eq("a spent pocket raises one flag", markers.flags.size(), 1)
	var key := "cracked_cache:-210,400"
	t.check("the pocket is marked visited", markers.is_visited(key))
	t.eq("as a cache, its mark the flag", String(markers.visited_state(key).get("mark", "")), "flag")
	if markers.flags.size() == 1:
		var foot: Vector3 = markers.flags[0].global_position
		t.near("the flag stands on the ground", foot.y, 2.0)
		t.check("the flag stands before the pocket's mouth, not in the cliff", foot.z > at.z + 4.0, "z %.1f" % foot.z)
		t.near("the flag stands FLAG_OUT_M out and FLAG_ASIDE_M aside", Vector2(foot.x - at.x, foot.z - at.z).length(),
			Vector2(SiteMarkers.FLAG_OUT_M, SiteMarkers.FLAG_ASIDE_M).length(), 0.01)
	ctx.events.activity_done.emit("cracked_cache", at)
	t.eq("a repeat raises none", markers.flags.size(), 1)
	ctx.events.activity_done.emit("enemy_camp", Vector3(10.0, 0.0, 10.0))
	t.eq("another activity raises none", markers.flags.size(), 1)
	var first: Node3D = markers.flags[0]
	ctx.events.stage_content_cleared.emit("test")
	await process_frame
	t.check("cleared: the flag is freed", not is_instance_valid(first))
	t.eq("cleared: no flag is kept", markers.flags.size(), 0)
	ctx.events.activity_done.emit("cracked_cache", at)
	t.eq("a fresh attempt can raise it again", markers.flags.size(), 1)
	var second: Node3D = markers.flags[0]
	ctx.events.stage_entered.emit(1, true)
	await process_frame
	t.check("entry (retry): the flag is freed", not is_instance_valid(second))
	var planted := Node3D.new()
	root.add_child(planted)
	var gone: Node3D = CrackedCache.raise_flag(planted, Vector3.ZERO, true)
	planted.free()
	t.check("planted: a flag under a freed parent is gone", not is_instance_valid(gone))
	markers.free()
	ctx.events.free()
	await process_frame


func _close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.08
