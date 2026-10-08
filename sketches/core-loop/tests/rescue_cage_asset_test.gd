extends SceneTree

const Game := preload("res://src/game.gd")
const Site := preload("res://src/world/rescue_site.gd")
const Palette := preload("res://src/core/palette.gd")
const Interactables := preload("res://src/world/interactables.gd")
var failures := 0
var game
var rescued := []


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, reason: String) -> void:
	if not ok:
		failures += 1
		print("cage assertion: " + reason)


func _coloured(node: Node) -> int:
	var count := 0
	for view: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if view.mesh == null or not view.mesh is ArrayMesh:
			continue
		for s in view.mesh.get_surface_count():
			var mat := view.get_active_material(s) as BaseMaterial3D
			var arrays := view.mesh.surface_get_arrays(s)
			if mat != null and mat.vertex_color_use_as_albedo and arrays[Mesh.ARRAY_COLOR] != null:
				count += 1
	return count


func _cage_check(cage, pilot_file: String) -> void:
	_check(cage != null, "real stage builds rescue cage")
	if cage == null:
		return
	var frame := cage.find_child("CageFrame", true, false) as MeshInstance3D
	_check(frame != null and frame.mesh is ArrayMesh, "cage GLB is drawn; greybox fallback is not accepted")
	if frame == null:
		var boxes := 0
		for view: MeshInstance3D in cage.find_children("*", "MeshInstance3D", true, false):
			if view.mesh is BoxMesh and view.get_parent() == cage._bars:
				boxes += 1
		print("cage fallback: old greybox bars=%d" % boxes)
		return
	_check(_coloured(cage) >= 4, "cage consumes vertex colours")
	for part_name in Site.REQUIRED:
		var view := cage.find_child(part_name, true, false) as MeshInstance3D
		_check(view != null and view.mesh != null, "cage part " + part_name)
		if view != null and view.mesh != null:
			var mat := view.get_active_material(0) as BaseMaterial3D
			var arrays := view.mesh.surface_get_arrays(0)
			_check(mat != null and mat.vertex_color_use_as_albedo
				and arrays[Mesh.ARRAY_COLOR] != null
				and arrays[Mesh.ARRAY_COLOR].size() == arrays[Mesh.ARRAY_VERTEX].size(),
				part_name + " draws its exported vertex colours")
	_check(cage.find_children("*", "CollisionObject3D", true, false).is_empty(), "rescue has no new physics bodies")
	var pilot := cage.find_child("AnimatedPilot", true, false) as Node3D
	_check(pilot != null and pilot.scene_file_path.ends_with(pilot_file), "correct existing pilot is seated")
	if pilot != null:
		_check(_coloured(pilot) > 0, "pilot consumes vertex-colour materials")
		_check(is_equal_approx(cage._pilot.rotation.y, PI), "pilot faces the gate opening")
	_check(cage.family == "ally" and cage._signal.emission.is_equal_approx(Interactables.color("ally")), "ally role is retained")
	var latch := cage._latch.transform as Transform3D
	var locked_energy: float = cage._signal.emission_energy_multiplier
	_check(not cage.spent and not cage.breaking and cage._bars.visible, "locked gate is visible")
	_check(cage._animator != null and cage._animator.assigned_animation == "slump", "locked pilot is slumped")
	cage.fire()
	_check(cage.breaking and cage._signal.emission_energy_multiplier != locked_energy, "freeing immediately changes latch light")
	cage.tick(Site.BREAK_SECONDS * 0.5)
	_check(not cage._latch.transform.is_equal_approx(latch) and cage._bars.visible and not cage.spent, "freeing moves latch before completion")
	_check(cage._animator != null and cage._animator.assigned_animation == "heave", "freeing pilot braces against the lock")
	cage.tick(Site.BREAK_SECONDS * 0.5)
	var freed_gate := cage.find_child("CageGate", true, false) as MeshInstance3D
	_check(cage.spent and cage._bars.visible and freed_gate != null
		and absf(cage._freed_wall.rotation.x) > deg_to_rad(60.0)
		and cage._animator != null and cage._animator.assigned_animation == "big_cheer",
		"freed folds the exit wall and pilot cheers")
	_check(rescued.count(cage.quest) == 1, "rescue event emitted once")
	cage.fire()
	cage.tick(10)
	_check(rescued.count(cage.quest) == 1, "freed rescue cannot emit twice")


func _run() -> void:
	game = Game.new()
	game.test_mode = true
	game.table = "alpha"
	root.add_child(game)
	for tick in 600:
		if game.flow != null:
			break
		await physics_frame
	_check(game.flow != null, "game initialized")
	if game.flow == null:
		_finish()
		return
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.ctx.calm = true
	game.events.rescue_completed.connect(func(quest: String): rescued.append(quest))
	game.flow.press_start()
	game.flow.choose_class(0)
	for row in [[1, "rivet", "pilot_rivet_anim.glb"], [3, "dig", "pilot_kest_anim.glb"]]:
		game.world.rescue._done.clear()
		game.flow.enter_stage(row[0], Vector3.ZERO, false)
		await process_frame
		_cage_check(game.world.rescue.cage(row[1]), row[2])
	var parts: Array = Site._parts()
	var tris := 0
	var verts := 0
	for part in parts:
		var arrays: Array = part.mesh.surface_get_arrays(0)
		verts += arrays[Mesh.ARRAY_VERTEX].size()
		tris += arrays[Mesh.ARRAY_INDEX].size() / 3
	print("rescue cage budget: %d T / %d V / %d D" % [tris, verts, parts.size()])
	_check(tris > 0 and tris <= 1100 and verts <= 2100 and parts.size() == 4, "cage asset budget")
	_check(Site.BREAK_SECONDS == 2.0 and Site.RING_RADIUS == 4.0, "rescue constants unchanged")
	var source := FileAccess.get_file_as_string("res://src/world/rescue_site.gd")
	for method in GAMEPLAY_PINS:
		var body := source.get_slice("\tfunc " + method, 1).get_slice("\n\n", 0)
		body = body.replace("\n\t\t_visual_state()", "").strip_edges()
		_check(body.sha256_text() == GAMEPLAY_PINS[method], "unchanged rescue logic: " + method)
	_finish()


const GAMEPLAY_PINS := {
	"ready_now()": "0060043e7f67817e46894fe11cf978a3303acd50dceacf9b14670d76a6ef120c",
	"gauge()": "e06ffece5391077a014123fa855cf6ffc78a569453eb8c59fb73dc2f400a32cb",
	# 2026-10-08 (wave 10 ST5): terms() reads the site row's prompt.
	"terms()": "64019d70ab6e4a0d41b327aaabc14544c7e1ffa36f4b937fc4cb8ad6b9d669af",
	"fire()": "d8de13993e8a10a3e061db6f46b2107a70a7b42e95a382cd57c9387cc07ad150",
	"tick(delta: float)": "aef639e09a4397398ba5a3c0d1293ab5181c56c57360d9d4b812f578f3fef295",
}


func _finish() -> void:
	if game != null:
		game.free()
	print("rescue_cage_asset_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
