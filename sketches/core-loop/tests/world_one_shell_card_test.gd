extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")

# The S4, K5 and R6 pick cards under --world-one-builds=on. Their rows name the Riveted Shell
# inversion, which build.gd's shell_air_factor() applies only with --hotwire-shell=on, so with
# the shell unfitted a card must describe what the pick does alone and say nothing of fins.

const CASES := [
	["pylon_engineer", "s_static_flutter", "s_cannonball", "s_face_runner", "Kick off a wall to jump again.", "Kick off a wall to jump again. Steer sharper after each kick."],
	["demolitions_caster", "k_keg", "k_ghost", "k_smoke_trail", "Glide cloaked.", "Glide cloaked. Steer sharper while you glide."],
	["runner_gunner", "r_big_iron", "r_juggernaut", "r_second_wind", "Bank two sprints.", "Bank two sprints. Sprinting, you steer freely midair."],
]

var _game
var _player
var _ws
var _failures := 0
var _booted := false


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	if not _booted:
		_booted = true
		_game.ctx.calm = true
		_game.player.source = Intent.Scripted.new()
		_game.flow.press_start()
		_game.flow.choose_class(0)
		_player = _game.player
		_ws = _game.get_node("Workshop")
		return false
	for row in CASES:
		_card(row[0], row[1], row[2], row[3], row[4], row[5])
	print("world_one_shell_card_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


func _line(class_id: String, parent: String, node_id: String, world_one: bool, shell: bool) -> String:
	var def: Resource = ClassDef.by_id(class_id)
	_game.run.class_def = def
	_player.fit_class(def)
	_game.ctx.tuning.set_option("world_one_builds", "on" if world_one else "off")
	_game.ctx.tuning.set_option("hotwire_shell", "on" if shell else "off")
	var tree = _player.tree
	tree.reset(class_id)
	tree.max_depth = UpgradeTree.WORLD_ONE_DEPTHS
	tree.world_one = world_one
	tree.open_checkpoint()
	tree.pick(parent)
	tree.open_checkpoint()
	_ws.open_pick()
	var text := ""
	for card in _ws.pick.cards():
		if card.node_id() == node_id:
			text = card.effect_text()
	_ws.close_pick()
	return text


func _card(class_id: String, wo_parent: String, base_parent: String, node_id: String, alone: String, with_shell: String) -> void:
	var off := _line(class_id, wo_parent, node_id, true, false)
	_check("%s, shell off: no fins promise" % node_id, off == alone and not off.to_lower().contains("fins"), "'%s'" % off)
	var on := _line(class_id, wo_parent, node_id, true, true)
	_check("%s, shell on: inversion line" % node_id, on == with_shell, "'%s'" % on)
	var base := _line(class_id, base_parent, node_id, false, true)
	_check("%s, world-one off, shell on: no fins promise" % node_id, not base.to_lower().contains("fins"), "'%s'" % base)
