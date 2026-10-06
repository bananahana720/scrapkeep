extends SceneTree

# WHE: the game builds the real Tarn, Tally and cannon pilots and shells and the four Warden
# mantles, and keeps the fallback (reskin pilot, bare kit) when a GLB is missing. Rule broken by
# pointing a table row or a mantle row at a path that does not load.

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Hero := preload("res://src/presentation/hero_assets.gd")
const Warden := preload("res://src/combat/warden.gd")
const NEW := {
	"tarn": ["pilot_tarn_anim.glb", "world_one/shell_tarn.glb"],
	"tally": ["pilot_tally_anim.glb", "world_one/shell_tally.glb"],
	"remembered_cannon": ["pilot_cannon_anim.glb", "world_one/shell_cannon.glb"],
}
const MANTLES := {
	3: ["reactor", "MeltRearShell", "Body"],
	4: ["swarm", "BroodRibs", "Body"],
	5: ["mind", "HandWrist", "Body"],
	6: ["mind", "ChoirFiveHorns", "Body"],
}

class MissingMantles extends Hero:
	func _warden_scene(path: String) -> Node3D:
		return null if path.contains("warden_mantle_") else super._warden_scene(path)

var _t := T.new("dress_whe_assets_test")
var game


func _initialize() -> void:
	game = Game.new()
	game.test_mode = true
	game.table = "alpha"
	root.add_child(game)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	for id in NEW:
		_t.eq(id + " pilot path", Hero.PILOTS[id], "res://assets/models/" + NEW[id][0])
		_t.eq(id + " shell path", Hero.SHELLS[id], "res://assets/models/" + NEW[id][1])
		var pod := Node3D.new()
		var fitted: Dictionary = game.presentation.hero_assets.fit_pilot_into(pod, id, Color.WHITE)
		var pilot = fitted.get("pilot")
		_t.check(id + " builds the real pilot", pilot != null and pilot.scene_file_path == Hero.PILOTS[id], "scene %s" % (pilot.scene_file_path if pilot != null else "none"))
		pod.free()
		var shell = game.presentation.hero_assets._scene(Hero.SHELLS[id])
		_t.check(id + " shell loads with Core/Pod", shell != null and shell.find_child("Core", true, false) != null and shell.find_child("Pod", true, false) != null, Hero.SHELLS[id])
		if shell != null:
			shell.free()
	var gone := Node3D.new()
	# The fallback: an unavailable pilot scene returns {} and seats nothing.
	var broken := BrokenPilot.new()
	root.add_child(broken)
	var fixed: Dictionary = broken.fit_pilot_into(gone, "tarn", Color.WHITE)
	_t.check("missing pilot GLB seats nothing", fixed.is_empty() and gone.get_node_or_null("AnimatedPilot") == null, "returned %s" % [fixed])
	gone.free()
	broken.free()
	for stage in MANTLES:
		var spec: Array = MANTLES[stage]
		var warden := await _warden(spec[0], stage)
		var rec: Dictionary = game.presentation.hero_assets.warden_of(warden)
		var kit: Node = rec.get("kit")
		var hull: Node = kit.find_child(spec[1], true, false) if kit != null else null
		_t.check("stage %d %s mounts %s" % [stage, spec[0], spec[1]], hull != null and hull.get_parent().get_parent() == kit.get_node(spec[2]) and rec.mantle != null, "mantle %s" % [rec.get("mantle")])
		if stage == 3:
			_t.check("stage 3 vents carry bells", kit.get_node("Vent2").find_child("MeltVentBell2", true, false) != null, "Vent2")
		if stage == 6:
			_t.check("stage 6 shoes on both arms", kit.get_node("ArmL").find_child("ChoirShoeL", true, false) != null and kit.get_node("ArmR").find_child("ChoirShoeR", true, false) != null, "arms")
		_t.check("stage %d tool material stays out of rec.materials" % stage, rec.mantle_tool != null and not rec.materials.values().has(rec.mantle_tool), "own instance")
		warden.free()
	var bare := await _warden("swarm", 2)
	var bare_rec: Dictionary = game.presentation.hero_assets.warden_of(bare)
	_t.check("stage 2 stays bare", not bare_rec.is_empty() and bare_rec.mantle == null, "no mantle row")
	bare.free()
	# Fallback: the same stage-3 Warden under a loader whose mantle files are missing keeps the bare kit.
	var old = game.presentation.hero_assets
	game.presentation.remove_child(old)
	old.queue_free()
	var lacking := MissingMantles.new()
	game.presentation.add_child(lacking)
	game.presentation.hero_assets = lacking
	lacking.setup(game.ctx)
	var warden := await _warden("reactor", 3)
	var rec: Dictionary = lacking.warden_of(warden)
	_t.check("missing mantle GLB keeps the bare kit", not rec.is_empty() and rec.mantle == null and rec.kit.find_child("MeltRearShell", true, false) == null, "dressed kit without mantle")
	warden.free()
	quit(_t.verdict())


class BrokenPilot extends Hero:
	func _scene(path: String) -> Node:
		return null if path == Hero.PILOTS["tarn"] else super._scene(path)


func _warden(family: String, stage: int) -> Warden:
	var warden := Warden.new()
	game.add_child(warden)
	warden.setup(game.player, game.ctx.terrain, game, func(): return false, 1.0,
		{"family": family, "variant": "", "stage": stage, "plating": 30.0, "hp": 800.0})
	warden.set_physics_process(false)
	await process_frame
	await process_frame
	return warden
