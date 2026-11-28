extends SceneTree

# Count subject types, not spawned instances or decorative cue meshes. Lower this
# ceiling when a model lands. A GLB on disk clears nothing unless its loader uses it.
const MAX_FALLBACKS := 0
# Warnings that match a dress word but are not dress faults, one per line with its reason.
const IGNORED_WARNINGS: Array[String] = [
	"audio fallback", # headless runs have no audio device and the mixer says so
]
const DressWarning := preload("res://src/presentation/dress_warning.gd")
const Game := preload("res://src/game.gd")
const Roster := preload("res://src/combat/roster.gd")
const Worlds := preload("res://src/core/worlds.gd")
const Alpha := preload("res://src/core/alpha_defs.gd")
const Hero := preload("res://src/presentation/hero_assets.gd")
const WardenDress := preload("res://src/presentation/warden_dress.gd")
const Warden := preload("res://src/combat/warden.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Companion := preload("res://src/core/companion.gd")

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
var warnings_claimed := 0
var totals := {}
var fallbacks := 0
var glbs := {}
var glb_meshes := {}


func _initialize() -> void:
	OS.add_logger(error_log)
	game = Game.new()
	game.test_mode = true
	game.table = "alpha"
	root.add_child(game)
	_run.call_deferred()


func _require(ok: bool, reason: String) -> void:
	if not ok:
		failures.append(reason)
		print("coverage assertion: %s" % reason)


func _claim_warnings(subject: String) -> void:
	while warnings_claimed < error_log.dress_warnings.size():
		_require(false, "%s: dress warning: %s" % [subject, error_log.dress_warnings[warnings_claimed]])
		warnings_claimed += 1


func _row(category: String, subject: String, result: Dictionary) -> void:
	_claim_warnings(subject)
	if not totals.has(category):
		totals[category] = {"subjects": 0, "fallbacks": 0}
	totals[category].subjects += 1
	if not result.real:
		fallbacks += 1
		totals[category].fallbacks += 1
	print("%s %s %s %s" % [subject, category, "REAL" if result.real else "FALLBACK", result.reason])


func _result(real: bool, reason: String) -> Dictionary:
	return {"real": real, "reason": reason}


func _glb(path: String) -> bool:
	if glbs.has(path):
		return glbs[path]
	var good := false
	if path.ends_with(".glb") and FileAccess.file_exists(path) and ResourceLoader.exists(path):
		var packed := load(path) as PackedScene
		if packed != null:
			var node := packed.instantiate()
			var signatures: Array = []
			for mesh in _meshes(node):
				if mesh.mesh is ArrayMesh:
					signatures.append(_signature(mesh.mesh))
			good = not signatures.is_empty()
			glb_meshes[path] = signatures
			node.free()
	glbs[path] = good
	return good


func _signature(mesh: Mesh) -> Array:
	var signature: Array = []
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		signature.append([hash(arrays[Mesh.ARRAY_VERTEX]), hash(arrays[Mesh.ARRAY_INDEX])])
	return signature


func _meshes(node: Node) -> Array:
	var out: Array = []
	if node is MeshInstance3D and node.mesh != null:
		out.append(node)
	for child in node.get_children():
		out.append_array(_meshes(child))
	return out


func _visible(mesh: MeshInstance3D) -> bool:
	if mesh.layers == 0:
		return false
	var node: Node = mesh
	while node != null:
		if node is Node3D and not node.visible:
			return false
		node = node.get_parent()
	return true


# Literal resource references are parsed from executable lines, never comments.
# Inherited loaders and instantiated GLB scene roots are included. Copied GLB
# meshes (the Fleet's shared parts) still require a successful source GLB load.
func _paths(node: Node) -> Array:
	var paths: Array = []
	var quoted := RegEx.new()
	quoted.compile('["\\\'](res://[^"\\\']+\\.glb)["\\\']')
	var script := node.get_script() as Script
	while script != null:
		for line in script.source_code.split("\n"):
			if line.strip_edges().begins_with("#"):
				continue
			for found in quoted.search_all(line):
				var path: String = found.get_string(1)
				if not paths.has(path):
					paths.append(path)
		script = script.get_base_script()
	if node.scene_file_path.ends_with(".glb"):
		paths.append(node.scene_file_path)
	for child in node.get_children():
		for path in _paths(child):
			if not paths.has(path):
				paths.append(path)
	return paths


func _body(node: Node, extra_paths: Array = []) -> Dictionary:
	if not is_instance_valid(node):
		return _result(false, "no body")
	var paths := _paths(node)
	for path in extra_paths:
		if not paths.has(path):
			paths.append(path)
	for path in paths:
		if not _glb(path):
			return _result(false, "missing or unloadable GLB %s" % path)
	var meshes := _meshes(node).filter(func(mesh): return _visible(mesh))
	if meshes.is_empty():
		return _result(false, "no visible body")
	if meshes.any(func(mesh): return mesh.mesh is CapsuleMesh):
		return _result(false, "visible capsule fallback")
	for mesh in meshes:
		if mesh.mesh is ArrayMesh:
			var signature := _signature(mesh.mesh)
			for path in paths:
				if glb_meshes[path].has(signature):
					return _result(true, "loaded GLB body %s" % ",".join(paths))
	return _result(false, "primitive body (%s)" % meshes[0].mesh.get_class())


func _warden_paths(warden: Node) -> Array:
	var painter = game.presentation.hero_assets
	if painter.warden_of(warden).is_empty():
		return []
	return [WardenDress.BASE, "res://assets/models/warden_kit_%s.glb" % WardenDress.KITS[warden.family]]


func _table_minimums() -> void:
	_require(Roster.BASE_ROWS.size() >= 19, "base enemy table needs at least 19 rows")
	for file in DirAccess.get_files_at("res://src/combat"):
		if file.begins_with("roster_") and file.ends_with(".gd"):
			var table = load("res://src/combat/" + file)
			# The specials table grows one kill-first enemy per unit (Splitter first, wave 18).
			var least := 1 if file == "roster_specials.gd" else 3
			_require(table.ROWS.size() >= least, "%s needs at least %d rows" % [file, least])
			for kind in table.ROWS:
				_require(Roster.ROWS.has(kind), "%s absent from merged enemy roster" % kind)
	_require(Roster.ROWS.size() >= 25, "merged enemy table needs at least 25 rows")
	_require(Worlds.BOSSES.size() >= 3, "boss table needs at least 3 rows")
	_require(WardenDress.KITS.size() >= 3, "Warden kit table needs at least 3 rows")
	_require(Alpha.DEFS.size() >= 6, "alpha stage table needs at least 6 rows")
	_require(Hero.PILOTS.size() >= 6 and Hero.SHELLS.size() >= 6, "pilot and shell tables need at least 6 rows each")
	_require(ClassDef.all().size() >= 6, "class table needs at least 6 rows")
	_require(Companion.CHASSIS != "" and Companion.PIECES.size() >= 6, "companion needs a chassis and at least 6 pieces")


func _enemies() -> void:
	var kinds := Roster.ROWS.keys()
	for file in DirAccess.get_files_at("res://src/combat"):
		if file.begins_with("roster_") and file.ends_with(".gd"):
			for kind in load("res://src/combat/" + file).ROWS:
				if not kinds.has(kind):
					kinds.append(kind)
	for kind in game.ctx.spawner.KINDS + game.ctx.spawner.fleet.SCRIPTS.keys():
		if not kinds.has(kind):
			kinds.append(kind)
	for stage in Alpha.DEFS:
		var declared: Array = [stage.get("ancient", "")]
		for pack in stage.get("packs", []) + [stage.get("elite", {})]:
			declared.append_array(pack.get("kinds", []))
		for kind in declared:
			if kind != "" and not kinds.has(kind):
				kinds.append(kind)
	kinds.sort()
	for kind in kinds:
		if not kind in game.ctx.spawner.KINDS and not game.ctx.spawner.fleet.makes(kind):
			_row("enemy", kind, _result(false, "no spawnable body for roster kind"))
			continue
		var enemy = game.ctx.spawner.spawn_enemy(kind, Vector3(100, 20, 100))
		enemy.set_physics_process(false)
		await process_frame
		_row("enemy", kind, _body(enemy, _warden_paths(enemy) if enemy is Warden else []))
		enemy.free()


func _wardens() -> void:
	for family in WardenDress.KITS:
		await _warden("warden_kit", family, {"warden_family": family, "warden_variant": "", "stage": 1})
	for stage in Alpha.DEFS:
		await _warden("warden_stage", "stage_%s/%s/%s" % [stage.stage, stage.warden_family,
			stage.get("warden_variant", "")], stage)


func _warden(category: String, subject: String, row: Dictionary) -> void:
	var family := String(row.warden_family)
	_require(WardenDress.KITS.has(family), "%s has no Warden kit mapping" % subject)
	var warden := Warden.new()
	game.add_child(warden)
	warden.setup(game.player, game.ctx.terrain, game, func(): return false, 1.0,
		{"family": family, "variant": row.get("warden_variant", ""), "stage": row.stage,
		"plating": row.get("warden_plating", 30.0), "hp": row.get("warden_hp", 800.0)})
	warden.set_physics_process(false)
	await process_frame
	_row(category, subject, _body(warden, _warden_paths(warden)))
	warden.free()


func _characters(category: String, table: Dictionary) -> void:
	var owners := {}
	var ids: Array = table.keys()
	for def in ClassDef.all():
		if not ids.has(def.id):
			ids.append(def.id)
	# First declaration owns a path; subsequent classes borrowing it are reskins.
	for id in ids:
		var path := String(table.get(id, ""))
		var result := _result(false, "no model mapping")
		if path != "":
			if not _glb(path):
				result = _result(false, "missing or unloadable GLB %s" % path)
			elif owners.has(path):
				result = _result(false, "reuses %s model %s" % [owners[path], path])
			else:
				var scene = game.presentation.hero_assets._scene(path)
				result = _body(scene, [path])
				if category == "shell" and scene != null:
					if scene.find_child("Core", true, false) == null or scene.find_child("Pod", true, false) == null:
						result = _result(false, "shell lacks Core/Pod; loader keeps primitive fallback")
				if scene != null:
					scene.free()
			if not owners.has(path):
				owners[path] = id
		_row(category, id, result)


func _bosses() -> void:
	for id in Worlds.BOSSES:
		var row: Dictionary = Worlds.BOSSES[id]
		var module = game.boss if row.script == game.boss.get_script().resource_path else load(row.script).new()
		if module != game.boss:
			game.add_child(module)
			module.setup(game.ctx)
		module.enter_arena(Vector3.ZERO)
		module.set_physics_process(false)
		await process_frame
		if "ship" in module:
			_row("boss", id, _body(module.ship))
		elif "warden" in module and module.warden is Warden and _paths(module).is_empty():
			_row("boss", id, _result(false, "reuses Warden body via %s" % row.script))
		else:
			_row("boss", id, _body(module.warden if "warden" in module else module, _paths(module)))
		# Brindle's phase body and returned scrap are separate visible subjects.
		# Discover these seams from the module, not from a hardcoded boss roster.
		if module.has_method("_spawn_pickup") and module.has_method("pickups_left"):
			module._spawn_pickup(Vector3(100, 20, 100), 1, "kill")
			for pickup in module._pickups:
				_row("boss_prop", id + "/pickup", _body(pickup.node, ["res://assets/models/bosses/boss_pickup.glb"]))
		if module.has_method("_begin_eject"):
			module._begin_eject()
			await process_frame
			_row("boss_prop", id + "/" + String(module.scooter.role), _body(module.scooter))
		module.exit_arena()
		if module != game.boss:
			module.free()
		await process_frame


func _companion() -> void:
	var model := Companion.new()
	var sockets: Array = []
	var families: Array = []
	for piece in Companion.PIECES:
		model.acquire(piece.id)
		if not families.has(piece.family) and sockets.size() < Companion.SOCKETS:
			families.append(piece.family)
			sockets.append(piece.id)
	_require(model.assemble(sockets) == "", "companion fixture must assemble")
	game.run.companion = model.to_dict()
	await process_frame
	await process_frame
	var bodies: Array = game.find_children("*Companion*", "Node3D", true, false)
	bodies.append_array(game.find_children("*" + Companion.CHASSIS + "*", "Node3D", true, false))
	_row("companion", Companion.CHASSIS, _body(bodies[0]) if not bodies.is_empty() else
		_result(false, "no body for assembled chassis; data and HUD cues only"))


func _run() -> void:
	for tick in 600:
		if game.flow != null:
			break
		await physics_frame
	_require(game.flow != null, "game did not initialize within 600 physics frames")
	if game.flow != null:
		game.ctx.calm = true
		game.flow.press_start()
		game.flow.choose_class(0)
		_table_minimums()
		await _enemies()
		await _wardens()
		_characters("pilot", Hero.PILOTS)
		_characters("shell", Hero.SHELLS)
		await _bosses()
		await _companion()
	var subjects := 0
	for category in totals:
		var count: Dictionary = totals[category]
		subjects += int(count.subjects)
		print("coverage %s: subjects=%d real=%d fallbacks=%d" % [category, count.subjects,
			int(count.subjects) - int(count.fallbacks), count.fallbacks])
	_require(subjects >= 52, "coverage needs at least 52 subjects")
	_require(int(totals.get("boss", {}).get("subjects", 0)) == Worlds.BOSSES.size(), "every boss needs a coverage row")
	_require(int(totals.get("boss_prop", {}).get("subjects", 0)) >= 2, "boss phase body and scrap pickup need coverage rows")
	_require(fallbacks <= MAX_FALLBACKS, "fallbacks %d exceed MAX_FALLBACKS %d" % [fallbacks, MAX_FALLBACKS])
	print("coverage total: subjects=%d real=%d fallbacks=%d MAX_FALLBACKS=%d" %
		[subjects, subjects - fallbacks, fallbacks, MAX_FALLBACKS])
	game.free()
	_claim_warnings("(after the last subject)")
	_require(error_log.errors == 0, "%d engine or script errors" % error_log.errors)
	OS.remove_logger(error_log)
	print("dress_coverage_test: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
