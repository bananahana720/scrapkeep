extends SceneTree
# W1-109: one film row says where the lens is, whether the ball is on screen, what stopped the
# camera arm and what each ability slot reads, so a jammed picture or a grey slot can be
# diagnosed from film.ndjson alone. The film cannot start under --headless (it needs a picture),
# so this reads the row's view fields through view_truth(), the call _truth() merges in.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const EyeFilm := preload("res://tools/eye_film.gd")

var _game
var _film
var _wall: StaticBody3D
var _phase := "boot"
var _wait := 0
var _failures := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _finish() -> bool:
	print("eye_film_view_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
	return true


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_wait += 1
	match _phase:
		"boot":
			_game.ctx.calm = true
			_game.player.source = Intent.Scripted.new()
			_game.flow.press_start()
			_game.flow.choose_class(1)
			_film = EyeFilm.new()
			_film._game = _game
			_phase = "lens"
			_wait = 0
		"lens":
			if _wait == 40:
				if not _film.has_method("view_truth"):
					_report("view_truth", false, "the film has no view_truth call")
					return _finish()
				var row: Dictionary = _film.view_truth()
				var lens: Array = row["lens"] if row["lens"] != null else []
				var at: Vector3 = _game.camera.cam.global_position
				_report("lens", lens.size() == 3 and Vector3(lens[0], lens[1], lens[2]).distance_to(at) < 0.1, "lens %s, camera at %s" % [lens, at])
				_report("ball on screen", row["ball_on_screen"] == true, "camera behind the ball: %s" % row["ball_on_screen"])
				var arm: Dictionary = row["arm"] if row["arm"] != null else {}
				_report("arm open", arm.has("wanted") and arm["wanted"] > 1.0 and arm["body"] == null
					and arm.get("easing") == (arm["hit"] < arm["wanted"] - 0.01), "arm %s" % [arm])
				var truth: Dictionary = _film._truth()
				_report("truth merges", truth.has("lens") and truth.has("slots") and truth.has("pos"), "keys %s" % [truth.keys()])
				_game.camera.set_process(false)
				# A still ball, or the lens aims at where it was a tick ago.
				_game.player._rigid.freeze = true
				_phase = "away"
				_wait = 0
		"away":
			# Only the lens turns (the rig would swing it round the pivot): each tick aims it away. The
			# lens's transform reaches the camera a frame after it is set, hence the wait.
			var rig = _game.camera
			var to: Vector3 = (_game.player.ball_position() - rig.cam.global_position).normalized()
			rig.cam.global_basis = Basis.looking_at(-to, Vector3.UP)
			if _wait == 4:
				var row_away: Dictionary = _film.view_truth()
				_report("ball off screen", row_away["ball_on_screen"] == false, "lens turned away from the ball: %s" % row_away["ball_on_screen"])
				rig.set_process(true)
				_game.player._rigid.freeze = false
				_phase = "wall"
				_wait = 0
		"wall":
			if _wait == 20:
				var arm: SpringArm3D = _game.camera.arm
				var dir: Vector3 = arm.global_basis * Vector3.BACK
				_wall = StaticBody3D.new()
				_wall.name = "FilmTestWall"
				var shape := CollisionShape3D.new()
				var box := BoxShape3D.new()
				box.size = Vector3(30, 30, 0.5)
				shape.shape = box
				_wall.add_child(shape)
				_wall.collision_layer = 1
				root.add_child(_wall)
				_wall.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP), arm.global_position + dir * 3.0)
			if _wait == 40:
				var row: Dictionary = _film.view_truth()
				var arm: Dictionary = row["arm"]
				_report("arm hit named", arm["body"] != null and String(arm["body"]).contains("FilmTestWall") and arm["hit"] < arm["wanted"] - 0.5
					and arm.get("easing") == false, "arm %s" % [arm])
				_wall.queue_free()
				_phase = "ease"
				_wait = 0
		"ease":
			# The wall is gone and the arm is open. It wants 3 m more than it reached last tick, with
			# nothing in the way: the arm is easing out, so no body is named and the row says so.
			if _wait == 6:
				var rig = _game.camera
				rig.set_process(false)
				rig.arm.spring_length += 3.0
				var arm: Dictionary = _film.view_truth()["arm"]
				_report("arm easing out", arm["body"] == null and arm.get("easing") == true and arm["hit"] < arm["wanted"] - 2.5, "arm %s" % [arm])
				rig.arm.spring_length -= 3.0
				rig.set_process(true)
				_phase = "slots"
				_wait = 0
		"slots":
			if _wait == 10:
				var abilities = _game.player.abilities
				abilities.spend("special")
				abilities._slots["movement"].available = false
				_phase = "read"
				_wait = 0
		"read":
			if _wait == 6:
				var words: Dictionary = _film.view_truth()["slots"]
				_report("slot cooling", words.get("special") == "cooling", "slots %s" % [words])
				_report("slot ready", words.get("weapon") == "ready", "weapon %s" % words.get("weapon"))
				_report("slot unavailable", words.get("movement") == "unavailable", "movement %s" % words.get("movement"))
				_report("slots counted", words.size() >= 5, "%d slots" % words.size())
				_game.player.abilities.jam(5.0)
				_phase = "jam"
				_wait = 0
		"jam":
			if _wait == 6:
				var words: Dictionary = _film.view_truth()["slots"]
				_report("slot jammed", words.get("line") == "jammed", "line %s" % words.get("line"))
				_game.hud.ability_bar.set_piece = true
				var dim: Dictionary = _film.view_truth()["slots"]
				_report("slot dimmed", dim.get("weapon") == "dimmed-for-set-piece", "weapon %s" % dim.get("weapon"))
				_game.hud.ability_bar.set_piece = false
				return _finish()
	return false
