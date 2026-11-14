extends SceneTree

const Game := preload("res://src/game.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")
const T := preload("res://tests/support/t.gd")

var _t := T.new("title_stage_test")
var _capture_dir := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_capture_dir = OS.get_environment("TTL_CAPTURE_DIR")
	if _capture_dir != "":
		if DisplayServer.get_name() == "headless":
			_t.check("capture requires coordinator's rendered display", false)
			quit(_t.verdict())
			return
		root.size = Vector2i(1600, 900)
		DirAccess.make_dir_recursive_absolute(_capture_dir)
	var game := Game.new()
	game.test_mode = true
	game.table = "alpha"
	root.add_child(game)
	await process_frame
	await physics_frame
	_t.eq("boots to title", game.flow.state_name(), "title")
	var display = game.presentation.get_node_or_null("TitleStage")
	if not _t.check("title stage exists", display != null):
		game.free()
		quit(_t.verdict())
		return
	_t.check("title stage is shown", display.active and display.stage.visible and display._layer.visible)
	_t.eq("baseline alpha title body count preserved", _bodies(root), 61)
	_t.eq("stage has no collision objects", _colliders(display), 0)
	# W1-47: the deck is the game's finished models, never shapes built in code (the audit counted 20).
	var built: Array = display.stage.find_children("*", "MeshInstance3D", true, false).filter(
		func(view): return view.is_visible_in_tree() and view.layers != 0 and view.mesh is PrimitiveMesh)
	_t.eq("the deck draws no code-built shapes", built.map(func(view): return String(view.name)), [])
	for row in display.DECK:
		_t.check(String(row[0]) + " is on the deck from its model", display.stage.get_node_or_null(String(row[0])) != null)
	for pilot in ["SableShell", "RivetShell", "KestShell"]:
		var shell: Node = display.stage.get_node_or_null(pilot)
		_t.check(pilot + " has real core, pod and seated pilot", shell != null and shell.find_child("Core", true, false) != null
			and shell.find_child("Pod", true, false) != null and shell.find_child("AnimatedPilot", true, false) != null)
	var companion: Node = display.stage.get_node_or_null("SPIL9")
	var rigs: Array[Node] = companion.find_children("*", "Skeleton3D", true, false) if companion != null else []
	var rig: Skeleton3D = rigs[0] as Skeleton3D if not rigs.is_empty() else null
	_t.check("SPIL-9 has its assembled model and both module mounts", companion != null and companion.find_child("CompanionMesh", true, false) != null
		and rig != null and rig.find_bone("M1.ModuleRoot") >= 0 and rig.find_bone("M2.ModuleRoot") >= 0
		and companion.find_child("CompanionHullFallback", true, false) == null)
	_t.check("isolated world leaves chase camera current", display.viewport.own_world_3d and game.camera.cam.current)
	var main_camera: int = game.camera.cam.get_instance_id()
	var before: Transform3D = display.camera.transform
	await process_frame
	await process_frame
	_t.check("high preset drifts", display.is_processing() and not display.camera.transform.is_equal_approx(before))
	await _capture(game, "title")
	GraphicsPreset.apply("low")
	before = display.camera.transform
	await process_frame
	await process_frame
	_t.check("low preset holds a static frame", not display.is_processing() and display.camera.transform.is_equal_approx(before))
	_t.check("low disables costly lighting", not display._environment.ssao_enabled and not display._environment.glow_enabled and not display._sun.shadow_enabled)
	_t.eq("low respects viewport MSAA", display.viewport.msaa_3d, GraphicsPreset.PRESETS.low.msaa)
	GraphicsPreset.apply("high")
	_t.check("preset change resumes drift", display.is_processing())
	if _capture_dir != "":
		game.screens.toggle_help()
		await _capture(game, "help-controls")
		game.screens._help.page_button.pressed.emit()
		await _capture(game, "help-pictures")
		game.screens.toggle_help()
	game.flow.press_start()
	_t.eq("opens class select", game.flow.state_name(), "class_select")
	_t.check("class select retains title stage", display.active and display.stage.visible and display._layer.visible)
	await _capture(game, "class-select")
	game.flow.choose_class(0)
	_t.check("class choice starts a run", game.flow.in_play())
	_t.check("play hides stage and backdrop", not display.active and not display.stage.visible and not display._layer.visible)
	_t.check("play disables stage render and motion", not display.is_processing() and display.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED)
	_t.eq("play keeps chase camera", game.camera.cam.get_instance_id(), main_camera)
	game.flow.show_title()
	_t.check("return to title restores stage", display.active and display.stage.visible and display._layer.visible)
	game.free()
	await process_frame
	quit(_t.verdict())


func _capture(game: Node, label: String) -> void:
	if _capture_dir == "":
		return
	for frame in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	var display = game.presentation.title_stage
	_t.eq(label + " screenshot saved", root.get_texture().get_image().save_png(_capture_dir.path_join(label + ".png")), OK)
	_t.eq(label + " stage image saved", display.viewport.get_texture().get_image().save_png(_capture_dir.path_join(label + "-stage.png")), OK)
	var note := FileAccess.open(_capture_dir.path_join(label + ".json"), FileAccess.WRITE)
	if note != null:
		note.store_string(JSON.stringify({"flow": game.flow.state_name(), "preset": GraphicsPreset.current,
			"godot": Engine.get_version_info().string, "stage_camera": var_to_str(display.camera.transform),
			"fov": display.camera.fov, "pixels": var_to_str(display.viewport.size), "body_count": _bodies(root)}, "\t"))
	_t.check(label + " capture metadata saved", note != null)


func _bodies(node: Node) -> int:
	var count := 1 if node is PhysicsBody3D else 0
	for child in node.get_children():
		count += _bodies(child)
	return count


func _colliders(node: Node) -> int:
	var count := 1 if node is CollisionObject3D else 0
	for child in node.get_children():
		count += _colliders(child)
	return count
