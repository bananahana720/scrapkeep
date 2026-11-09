extends SceneTree

# boot_card_test's build whose game does not load, run in its own process because the boot's answer
# is an error line and an exit code. The first user argument picks the case:
#   sync     no card; the game scene's script does not parse
#   missing  no card; the game scene is not there
#   play     the card, then its button
#   close    the card, then a window close
# The broken scene is written under user:// at run time (a script that does not parse cannot live in
# the repository), in a folder named for this process because user:// is shared by every worktree.
# The process leaves with the boot's own exit code; 3 means the boot never answered.

const BOOT_SCENE := "res://src/boot/boot.tscn"
const FRAMES_MAX := 2000

var _dir := "user://boot-broken-%d" % OS.get_process_id()
var _frames := 0


func _initialize() -> void:
	_run.call_deferred()


# The watchdog counts frames here, not at the end of _run: a boot that goes wrong can end that
# coroutine, and the process would then never leave.
func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == FRAMES_MAX:
		print("BOOT_CHILD the boot never left")
		quit(3)
	return false


func _finalize() -> void:
	for file in ["game.gd", "game.tscn"]:
		DirAccess.remove_absolute(_dir.path_join(file))
	DirAccess.remove_absolute(_dir)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0] if not args.is_empty() else "sync"
	var boot = load(BOOT_SCENE).instantiate()
	boot.game_scene = "res://no_such_game.tscn" if mode == "missing" else _broken_scene()
	boot.force_card = mode in ["play", "close"]
	boot.force_sync = not boot.force_card
	root.add_child(boot)
	if not boot.force_card:
		return
	while is_instance_valid(boot) and boot._play.text != "Quit":
		await process_frame
	# A card that never said so is left to the watchdog: its button would start a game that is not there.
	if not is_instance_valid(boot):
		return
	print("BOOT_CHILD play=%s disabled=%s focus=%s game=%s status=%s" % [boot._play.text, boot._play.disabled, boot._play.has_focus(), root.get_node_or_null("Game") != null, boot._status.text])
	if mode == "play":
		boot._play.pressed.emit()
	else:
		boot.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)


func _broken_scene() -> String:
	DirAccess.make_dir_recursive_absolute(_dir)
	var script := FileAccess.open(_dir.path_join("game.gd"), FileAccess.WRITE)
	script.store_string("extends Node3D\n\nfunc _ready() -> void:\n\tvar broken: int =\n")
	script.close()
	var scene := FileAccess.open(_dir.path_join("game.tscn"), FileAccess.WRITE)
	scene.store_string("[gd_scene load_steps=2 format=3]\n\n[ext_resource type=\"Script\" path=\"%s\" id=\"1\"]\n\n[node name=\"Game\" type=\"Node3D\"]\nscript = ExtResource(\"1\")\n" % _dir.path_join("game.gd"))
	scene.close()
	return _dir.path_join("game.tscn")
