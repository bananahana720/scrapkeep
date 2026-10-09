# smoke: solo (boots the alpha table and walks stage 1, a stage change, the first boss and the Dig)
extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const T := preload("res://tests/support/t.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")
const Preset := preload("res://src/presentation/graphics_preset.gd")

# The stage-freed light rule (wave 9 cage light, wave 11 cache light, SEEDS:113): a Light3D freed
# with a node a stage change frees made Godot 4.7.2 Forward+ segfault on the next boss entry, GPU
# only, so the headless gate never saw the crash. This lint walks the real flow headless and records
# every Light3D in the tree before each transition; after the transition each one must still exist,
# unless its name is in ALLOWED. A planted light under a node the walk frees proves the detector.
# Allowed: lights whose owner is a menu screen that is closed, never a stage or a boss.
const ALLOWED := {
	# The class card's preview stage closes with the class select screen, before any stage.
	"PreviewSun": "class_preview.gd: the class select screen's own directional key",
	"PreviewRim": "class_preview.gd: the class select screen's own directional rim",
}
const PLANTED := "LintPlantedLight"
const SETTLE_FRAMES := 30

var _t := T.new("light_lifetime_lint_test")
var _game
var _seen := {}


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _record() -> void:
	for light: Light3D in root.find_children("*", "Light3D", true, false):
		_seen[light.get_instance_id()] = {"name": String(light.name), "path": String(light.get_path())}


func _check(label: String) -> Array:
	await _frames(SETTLE_FRAMES)
	var freed := []
	for id in _seen:
		if instance_from_id(id) == null and not ALLOWED.has(_seen[id].name):
			freed.append(_seen[id].path)
	for id in _seen.keys():
		if instance_from_id(id) == null:
			_seen.erase(id)
	_record()
	var planted := freed.filter(func(path: String) -> bool: return path.contains(PLANTED))
	var real := freed.filter(func(path: String) -> bool: return not path.contains(PLANTED))
	_t.check(label + ": no light freed with its node", real.is_empty(), ", ".join(real))
	return planted


# A per-instance light under a node the next transition frees, as the Warden's cool fill was.
func _plant(parent: Node) -> void:
	var host := Node3D.new()
	host.name = PLANTED + "Host"
	parent.add_child(host)
	var light := OmniLight3D.new()
	light.name = PLANTED
	host.add_child(light)
	_seen[light.get_instance_id()] = {"name": PLANTED, "path": String(light.get_path())}
	host.queue_free.call_deferred()


func _run() -> void:
	seed(280928)
	_game = Game.new()
	_game.name = "Game"
	_game.test_mode = true
	_game.table = "alpha"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	await process_frame
	_record()
	_game.ctx.calm = true
	_game.flow.force_warden = true
	_game.flow.press_start()
	await _frames(SETTLE_FRAMES)
	await _check("title to class select")
	_game.flow.choose_class(1)
	_game.run.set_max_hp(999999.0)
	_game.player.source = Intent.Scripted.new()
	await _check("class select to stage 1")
	_t.check("stage 1 spawned its Warden", is_instance_valid(_game.flow.warden))
	var env: Environment = _game.ctx.terrain.environment
	_t.check("the game enters the Spillway row and its air on stage entry (shipped high)", Preset.current == "high" and env.volumetric_fog_enabled
		and is_equal_approx(env.volumetric_fog_density, WorldLook.ROWS[1].air.volumetric_fog_density), Preset.current)
	_plant(_game.flow.warden)
	_game.flow.enter_stage(2, Vector3.ZERO, false)
	var planted := await _check("stage 1 to stage 2 (the Warden is freed)")
	_t.check("the lint catches a light freed with its node", planted.size() == 1, str(planted))
	_game.flow.enter_boss(Vector3(18, 0, 0))
	await _check("stage 2 to the first boss")
	_game.flow.enter_stage(_game.ctx.stages.first_of(2), Vector3.ZERO, false)
	await _check("the first boss to the Dig")
	_t.check("the Dig closes its dome", env.background_mode == Environment.BG_COLOR and env.background_color == WorldLook.ROWS[2].background)
	var pool: Node = _game.ctx.terrain.geometry_root(_game.ctx.stages.first_of(2)).get_node_or_null("WorldLook/LampPool")
	var lamps: Array = pool.find_children("*", "OmniLight3D", false, false) if pool != null else []
	_t.check("the Dig's lamp pool is stage-owned with its fixed count", lamps.size() == WorldLook.ROWS[2].lamps.count, "%d lamps" % lamps.size())
	_t.check("the lamp pool lights the lamps nearest the ball", lamps.any(func(l): return l.visible))
	_game.flow.enter_stage(_game.ctx.stages.first_of(2) + 1, Vector3.ZERO, false)
	await _check("Dig stage change")
	_t.check("the walk saw lights", _seen.size() >= 3, "%d lights" % _seen.size())
	_game.free()
	quit(_t.verdict())
