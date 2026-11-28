extends SceneTree

const Game := preload("res://src/game.gd")
const BossPosture := preload("res://src/core/boss_posture.gd")
const Intent := preload("res://src/movement/intent.gd")

const SIDES := {"front": Vector3(8.5, 9.0, 0.0), "side": Vector3(0.0, 9.0, 8.5), "rear": Vector3(-8.5, 9.0, 0.0)}
const EXPECT := {
	"fresh": [4, false, false],
	"open": [4, false, true],
	"cracked": [4, true, false],
	"one_gone": [3, false, false],
	"two_gone": [2, false, false],
}
const ORDER := [4, 13, 7, 1, 10, 15, 3, 9, 12, 6, 2, 14, 8, 11, 5]

var _tt := T.new()
var _game
var _warden
var _hook
var _combat
var _source := Intent.Scripted.new()
var _smashed := 0
var _cam: Camera3D
var _out := ""
var _table := "slice"
var _taken: Array = []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		if arg.begins_with("--table="):
			_table = arg.trim_prefix("--table=")
	if _out == "":
		push_error("warden_states_capture: --out=<dir> is required")
		quit(2)
		return
	root.size = Vector2i(1280, 720)
	_run()


class T:
	var failures := 0


	func check(n, ok, extra = ""):
		print("check ", n, ": ", ok, " ", extra)
		if not ok:
			failures += 1
		return ok


	func eq(n, a, b):
		print("eq ", n, ": ", a, " vs ", b)
		if a != b:
			failures += 1
		return a == b


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _seconds(seconds: float) -> void:
	await _frames(roundi(seconds * Engine.physics_ticks_per_second))


func _start(table: String) -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = table
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.flow.force_warden = true
	_game.player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(1)
	_game.events.harpoon_smashed.connect(func(_e: Node3D, _at: Vector3, _speed: float): _smashed += 1)
	await _seconds(0.4)
	if not is_instance_valid(_game.flow.warden):
		print("warden_states_capture: FAIL (no Warden on the table)")
		quit(1)
		return
	_bind()


func _bind() -> void:
	_warden = _game.flow.warden
	_hook = _game.presentation.hero_assets
	_combat = _game.ctx.spawner
	_combat.heft_override = 1.0
	_game.run.set_max_hp(99999.0)
	_game.player.reset_to(_ground(58.0))
	for enemy in get_nodes_in_group("enemy"):
		if enemy != _warden and enemy.get("kind") != "vault":
			enemy.queue_free()


func _ground(out: float) -> Vector3:
	return _game.ctx.terrain.drop_point(_warden.global_position.x + out, _warden.global_position.z, 1.5)


func _fill() -> void:
	var force := 1.0
	while _combat.punch_of("ram", force) < _warden.plating:
		force += 0.05
	for hit in 20:
		if _warden.staggered():
			break
		_combat.strike(_warden, "ram", force)
		await physics_frame
	await _frames(2)
	_tt.check("real fight opened", _warden.staggered())


func _smash() -> void:
	_smashed = 0
	var at: Vector3 = _warden.global_position + Vector3.UP * _warden.HALF_HEIGHT
	_game.player.reset_to(at + Vector3(-6.0, 6.0, 0.0))
	_game.player.grapple_to(at, Vector3.UP, _warden)
	_source.hold = {"harpoon_held": true}
	await _seconds(0.02)
	_source.hold = {"harpoon_held": true, "brake_held": true}
	for tick in roundi(1.5 * Engine.physics_ticks_per_second):
		await physics_frame
		if _smashed > 0:
			break
	_source.hold = {}
	_tt.eq("real harpoon contact landed", _smashed, 1)


func _shot(state: String) -> void:
	if not _tt.check("warden alive for " + state, is_instance_valid(_warden)):
		return
	var want: Array = EXPECT[state]
	_tt.check("%s: fight is posture" % state, _warden.fight() == "posture")
	_tt.eq("%s: chunks left" % state, _warden.chunks_left(), want[0])
	_tt.eq("%s: cracked" % state, _warden.chunk_cracked(), want[1])
	_tt.eq("%s: staggered" % state, _warden.staggered(), want[2])
	var ring = _warden.get_node_or_null("WardenRing")
	_tt.check("%s: ring present" % state, ring != null)
	if ring != null:
		_tt.eq("%s: lit arcs" % state, ring.lit_count(), want[0])
	var w: Vector3 = _warden.global_position
	for side in SIDES:
		_game.player.reset_to(_ground(58.0))
		_cam.global_position = w + SIDES[side]
		_cam.look_at(w + Vector3(0.0, 0.0, 0.0), Vector3.UP)
		_cam.current = true
		for i in 6:
			await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		var name := "%s_%s.png" % [state, side]
		img.save_png(_out.path_join(name))
		_taken.append({"file": name, "state": state, "side": side})
		print("saved ", name, " fight=", _warden.fight(), " chunks=", _warden.chunks_left(), " cracked=", _warden.chunk_cracked(), " staggered=", _warden.staggered())


func _blind() -> void:
	DirAccess.make_dir_recursive_absolute(_out.path_join("blind"))
	var key := {}
	for i in _taken.size():
		var n := "%02d.png" % ORDER[i]
		DirAccess.copy_absolute(_out.path_join(_taken[i].file), _out.path_join("blind").path_join(n))
		key[n] = {"state": _taken[i].state, "side": _taken[i].side}
	var f := FileAccess.open(_out.path_join("blind/key.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(key, "  "))
	f.close()


func _charge_shot() -> void:
	_game.player.reset_to(_ground(14.0))
	var waited := 0
	while not _warden._charging and waited < 600:
		await physics_frame
		waited += 1
	_tt.check("a pulse is charging", _warden._charging)
	await _seconds(0.9)
	var w: Vector3 = _warden.global_position
	_cam.global_position = w + SIDES["front"]
	_cam.look_at(w, Vector3.UP)
	_cam.current = true
	for i in 6:
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out.path_join("charging_front.png"))
	print("saved charging_front.png charging=", _warden._charging)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	await _start(_table)
	if not is_instance_valid(_warden):
		return
	for node in root.find_children("*", "CanvasLayer", true, false):
		node.visible = false
	_cam = Camera3D.new()
	_cam.fov = 56.0
	_cam.far = 600.0
	_game.add_child(_cam)
	await _shot("fresh")
	await _fill()
	await _shot("open")
	_combat.strike(_warden, "ram", 1.0)
	await _frames(2)
	await _seconds(BossPosture.STAGGER_SECONDS + 0.3)
	await _shot("cracked")
	await _fill()
	await _smash()
	await _seconds(1.0)
	await _shot("one_gone")
	await _fill()
	await _smash()
	await _seconds(1.0)
	await _shot("two_gone")
	_blind()
	await _charge_shot()
	print("warden_states_capture: ", "PASS" if _tt.failures == 0 else "FAIL (%d)" % _tt.failures)
	quit(1 if _tt.failures > 0 else 0)
