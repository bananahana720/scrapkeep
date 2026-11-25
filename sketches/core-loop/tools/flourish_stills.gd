extends SceneTree


const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Rows := preload("res://src/presentation/flourish_rows.gd")

const SEED := 7


func _initialize() -> void:
	_run()


func _arg(key: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % key):
			return arg.get_slice("=", 1)
	return fallback


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _busiest(id: String, short: bool) -> float:
	var best := 0.0
	var most := -1
	for piece in Rows.pieces(id, short):
		var at := float(piece.at) + 0.3
		var live := Rows.pieces(id, short).filter(func(p): return float(p.at) <= at and at < float(p.at) + float(p["for"])).size()
		if live > most:
			most = live
			best = at
	return best


func _run() -> void:
	var out := _arg("out", "res://../../artifacts/local/flourish-stills")
	var size := _arg("size", "1920x1080").split("x")
	root.size = Vector2i(int(size[0]), int(size[1]))
	DirAccess.make_dir_recursive_absolute(out)
	var game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(0)
	await _frames(90)
	var player = game.presentation.flourish
	for id in Rows.ROWS:
		for form in ["full", "short"]:
			player.stop_all()
			player.play(id, SEED, {}, form)
			player.advance(_busiest(id, form == "short"))
			player.set_process(false)
			await _frames(12)
			var path := "%s/%s-%s.png" % [out, id, form]
			var err: int = root.get_texture().get_image().save_png(path)
			print("flourish still %s %s" % [path, "ok" if err == OK else "error %d" % err])
	player.stop_all()
	game.free()
	await _frames(2)
	quit(0)
