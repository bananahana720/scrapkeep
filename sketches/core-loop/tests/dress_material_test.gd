extends SceneTree

# Surface counts per visible draw node, including MultiMesh batches once, rather
# than once per instance. Lower these ceilings as the materials and props land.
const MAX_WHITE_SURFACES := 0
const MAX_GREYBOX_SURFACES := 0
# Warnings that match a dress word but are not dress faults, one per line with its reason.
const IGNORED_WARNINGS: Array[String] = [
	"audio fallback", # headless runs have no audio device and the mixer says so
]
const DressWarning := preload("res://src/presentation/dress_warning.gd")
const Game := preload("res://src/game.gd")
const Alpha := preload("res://src/core/alpha_defs.gd")
const Worlds := preload("res://src/core/worlds.gd")
const Palette := preload("res://src/core/palette.gd")
const PaletteMaterials := preload("res://src/presentation/palette_materials.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const ActivityView := preload("res://src/world/activity_view.gd")
const Device := preload("res://src/world/device.gd")

class ErrorLog extends Logger:
	var errors := 0
	var dress_warnings: Array[String] = []

	func _log_error(_function: String, _file: String, _line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != Logger.ERROR_TYPE_WARNING:
			errors += 1
			return
		var text := (code + " " + rationale).strip_edges()
		if DressWarning.is_dress(text, IGNORED_WARNINGS):
			dress_warnings.append(text)

var game
var error_log := ErrorLog.new()
var failures: Array[String] = []
var totals := {"white": 0, "greybox": 0, "striped": 0, "solid_box": 0}
var offenders := {}
var scanned_stages := 0
var scanned_bosses := 0


func _initialize() -> void:
	OS.add_logger(error_log)
	_run.call_deferred()


func _require(ok: bool, reason: String) -> void:
	if not ok:
		failures.append(reason)
		print("material assertion: " + reason)


func _mesh(view: GeometryInstance3D) -> Mesh:
	if view is MeshInstance3D:
		return view.mesh
	if view is MultiMeshInstance3D and view.multimesh != null:
		var count: int = view.multimesh.instance_count
		if view.multimesh.visible_instance_count >= 0:
			count = mini(count, view.multimesh.visible_instance_count)
		return view.multimesh.mesh if count > 0 else null
	return null


func _material(view: GeometryInstance3D, mesh: Mesh, surface: int) -> Material:
	if view.material_override != null:
		return view.material_override
	if view is MeshInstance3D:
		var override: Material = view.get_surface_override_material(surface)
		if override != null:
			return override
	return mesh.surface_get_material(surface)


# Threat.GROUP identifies hostile hazards. Telegraphs also include friendly and
# harmless fields; Threat.Painter owns their deliberately flat grammar meshes.
# Exclude these ancestors, never a colour: a HAZARD-coloured prop still counts.
# ActivityView's columns, glyphs and dashed rings are signs, not modelled props.
# Device.ground_ring's twenty 0.35 x 0.08 box dashes are interaction cues too.
func _excluded(view: Node) -> bool:
	var node := view
	while node != null:
		if node.is_in_group(Threat.GROUP) or node.is_in_group("telegraph") or node is Threat.Painter:
			return true
		if node.get_script() == ActivityView:
			return true
		if _device_ring(node):
			return true
		node = node.get_parent()
	return false


func _device_ring(node: Node) -> bool:
	if not node.get_parent() is Device or node.get_child_count() != 20:
		return false
	for child in node.get_children():
		if not child is MeshInstance3D or not child.mesh is BoxMesh:
			return false
		if not is_equal_approx(child.mesh.size.x, 0.35) or not is_equal_approx(child.mesh.size.y, 0.08):
			return false
	return true


func _visible(view: GeometryInstance3D) -> bool:
	if view.layers == 0:
		return false
	var node: Node = view
	while node != null:
		if node is Node3D and not node.visible:
			return false
		node = node.get_parent()
	return true


func _reasons(mesh: Mesh, surface: int, material: Material) -> Array[String]:
	var reasons: Array[String] = []
	if material == null:
		return reasons
	if material.get_meta("greybox_checker", false):
		reasons.append("striped")
	if material is BaseMaterial3D:
		var vertex_colours: bool = mesh is ArrayMesh and (mesh.surface_get_format(surface) & Mesh.ARRAY_FORMAT_COLOR) != 0
		if vertex_colours and material.albedo_color.is_equal_approx(Color.WHITE) \
				and not material.vertex_color_use_as_albedo and material.albedo_texture == null:
			reasons.append("white")
		# PaletteMaterials.solid creates an opaque material with no albedo map and roughness 0.8,
		# marked palette_solid (its surface grain is not a texture of the prop). Treat a
		# BoxMesh with that signature as a placeholder regardless of tint or emission.
		# The meta survives duplicate(), so copies count too.
		if mesh is BoxMesh and material.albedo_texture == null \
				and (material.get_meta("palette_solid", false) or is_equal_approx(material.roughness, 0.8)) \
				and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED \
				and not material.vertex_color_use_as_albedo:
			reasons.append("solid_box")
	return reasons


func _subject(view: Node, mesh: Mesh) -> String:
	if mesh.resource_path != "":
		return mesh.resource_path.get_slice("::", 0).trim_prefix("res://")
	var node := view
	while node != null and node != game:
		if node.scene_file_path != "":
			return node.scene_file_path.trim_prefix("res://")
		node = node.get_parent()
	node = view.get_parent()
	while node != game and String(node.name).begins_with("@"):
		node = node.get_parent()
	return str(game.get_path_to(node))


func _walk(node: Node, label: String, counts: Dictionary) -> void:
	if node is GeometryInstance3D and _visible(node) and not _excluded(node):
		var mesh := _mesh(node)
		if mesh != null:
			counts.meshes += 1
			for surface in mesh.get_surface_count():
				counts.surfaces += 1
				var reasons := _reasons(mesh, surface, _material(node, mesh, surface))
				if not reasons.is_empty():
					print("material offender: %s %s surface=%d reason=%s" %
						[label, game.get_path_to(node), surface, ",".join(reasons)])
					var subject := _subject(node, mesh)
					offenders[subject] = int(offenders.get(subject, 0)) + 1
				for reason in reasons:
					counts[reason] += 1
				if reasons.has("striped") or reasons.has("solid_box"):
					counts.greybox += 1
	for child in node.get_children():
		_walk(child, label, counts)


func _scan(label: String) -> void:
	var counts := {"white": 0, "greybox": 0, "striped": 0, "solid_box": 0, "meshes": 0, "surfaces": 0}
	_walk(game, label, counts)
	_require(counts.meshes > 0 and counts.surfaces > 0, label + " needs visible meshes and surfaces")
	for category in totals:
		totals[category] += counts[category]
	print("material stage %s: white=%d greybox=%d striped=%d solid_box=%d meshes=%d surfaces=%d" %
		[label, counts.white, counts.greybox, counts.striped, counts.solid_box, counts.meshes, counts.surfaces])


func _detector_checks() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(Palette.RUST)
	for at in [Vector3.ZERO, Vector3.RIGHT, Vector3.UP]:
		st.add_vertex(at)
	var mesh := st.commit()
	var white := StandardMaterial3D.new()
	_require(_reasons(mesh, 0, white) == ["white"], "vertex colours ignored by a white material must count")
	white.vertex_color_use_as_albedo = true
	_require(_reasons(mesh, 0, white).is_empty(), "enabled vertex colours must not count as white")
	white.vertex_color_use_as_albedo = false
	white.albedo_texture = PaletteMaterials.checker_texture(Palette.RUST, Palette.COPPER, 2, 4)
	_require(_reasons(mesh, 0, white).is_empty(), "textured white material must not count")
	white.albedo_texture = null
	white.albedo_color = Palette.RUST
	_require(_reasons(mesh, 0, white).is_empty(), "tinted material must not count as white")
	_require(_reasons(mesh, 0, null).is_empty(), "missing material must not crash")
	var box := BoxMesh.new()
	_require(_reasons(box, 0, StandardMaterial3D.new()).is_empty(), "uncoloured mesh must not count as white")
	var checker := PaletteMaterials.striped(Palette.RUST, Palette.CHARCOAL)
	_require(_reasons(box, 0, checker) == ["striped"], "striped material must carry its marker")
	_require(_reasons(box, 0, checker.duplicate()) == ["striped"], "duplicated striped marker must survive")
	_require(_reasons(box, 0, PaletteMaterials.solid(Palette.HAZARD)) == ["solid_box"], "a flat HAZARD prop must count")
	var view := MeshInstance3D.new()
	mesh.surface_set_material(0, checker)
	view.mesh = mesh
	view.set_surface_override_material(0, PaletteMaterials.solid(Palette.COPPER))
	_require(_material(view, mesh, 0) == view.get_surface_override_material(0), "surface override must win")
	view.material_override = white
	_require(_material(view, mesh, 0) == white, "node override must win")
	var painter := Threat.Painter.new()
	painter.add_child(view)
	_require(_excluded(view), "threat painter meshes must be excluded")
	painter.visible = false
	_require(not _visible(view), "hidden ancestor must hide its meshes")
	view.mesh = null
	painter.free()
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = MultiMesh.new()
	batch.multimesh.mesh = mesh
	batch.multimesh.instance_count = 2
	_require(_mesh(batch) == mesh, "batched meshes must be scanned")
	batch.multimesh.visible_instance_count = 0
	_require(_mesh(batch) == null, "empty batches must not count")
	batch.free()
	var device := Device.new()
	var ring := device.ground_ring(10.0, Palette.HAZARD)
	_require(_excluded(ring.get_child(0)), "interaction ring dashes must not count as props")
	var cap := device.box(Vector3.ONE, Vector3.ZERO, checker)
	_require(not _excluded(cap), "striped device bodies must still count")
	device.free()


func _run() -> void:
	_detector_checks()
	game = Game.new()
	game.test_mode = true
	game.table = "alpha"
	root.add_child(game)
	for tick in 600:
		if game.flow != null:
			break
		await physics_frame
	_require(game.flow != null, "game did not initialize within 600 physics frames")
	if game.flow != null:
		# Freeze simulation while the real entry callbacks build each scene. This
		# fixes the sampled pose and prevents enemies or hazards arriving mid-scan.
		game.process_mode = Node.PROCESS_MODE_DISABLED
		game.ctx.calm = true
		game.flow.press_start()
		game.flow.choose_class(0)
		for row in Alpha.DEFS:
			game.flow.enter_stage(int(row.stage), Vector3.ZERO, false)
			await process_frame
			var stage_root: Node3D = game.ctx.terrain.geometry_root(int(row.stage))
			_require(stage_root != null and stage_root.visible, "entered stage %d must be visible" % row.stage)
			_scan("%d/%s" % [row.stage, game.ctx.terrain.map().get_script().resource_path.get_file().get_basename()])
			scanned_stages += 1
			if Alpha.is_world_last(int(row.stage)):
				game.flow.enter_boss(Vector3.ZERO)
				await process_frame
				var boss_id: String = Worlds.row(int(row.world)).boss
				_require(game.ctx.boss != null and game.ctx.boss.active(), "boss %s must have an active arena" % boss_id)
				_scan("boss/" + boss_id)
				scanned_bosses += 1
	_require(scanned_stages == Alpha.DEFS.size(), "every alpha stage must be scanned")
	_require(scanned_bosses == Worlds.BOSSES.size(), "every boss arena must be scanned")
	for category in totals:
		print("material category %s: surfaces=%d" % [category, totals[category]])
	var names: Array = offenders.keys()
	names.sort_custom(func(a, b): return offenders[a] > offenders[b] if offenders[a] != offenders[b] else a < b)
	for name in names.slice(0, 5):
		print("material largest: %s surfaces=%d" % [name, offenders[name]])
	print("material total: white=%d MAX_WHITE_SURFACES=%d greybox=%d MAX_GREYBOX_SURFACES=%d" %
		[totals.white, MAX_WHITE_SURFACES, totals.greybox, MAX_GREYBOX_SURFACES])
	_require(totals.white <= MAX_WHITE_SURFACES, "white surfaces %d exceed MAX_WHITE_SURFACES %d" % [totals.white, MAX_WHITE_SURFACES])
	_require(totals.greybox <= MAX_GREYBOX_SURFACES, "greybox surfaces %d exceed MAX_GREYBOX_SURFACES %d" % [totals.greybox, MAX_GREYBOX_SURFACES])
	game.free()
	for text in error_log.dress_warnings:
		_require(false, "dress warning: %s" % text)
	_require(error_log.errors == 0, "%d engine or script errors" % error_log.errors)
	OS.remove_logger(error_log)
	print("dress_material_test: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
