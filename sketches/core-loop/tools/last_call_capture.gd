extends SceneTree

const Intent := preload("res://src/movement/intent.gd")
const MakerSets := preload("res://src/build/maker_sets.gd")
const ShopCounter := preload("res://src/ui/shop_counter.gd")
const AppShell := preload("res://src/core/app_shell.gd")


class TwoWorldGame extends "res://src/game.gd":
	func _chosen_table():
		return preload("res://tests/doubles/two_world_defs.gd")


var _out := ""
var _game
var _counter
var _ticks := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
	if AppShell.headless() or _out == "":
		printerr("last_call_capture: needs a rendered display and -- --out=<absolute dir>")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_game = TwoWorldGame.new()
	_game.test_mode = true
	root.add_child(_game)


func _process(_delta: float) -> bool:
	if _game == null or _game.flow == null:
		return false
	_ticks += 1
	match _ticks:
		2:
			_game.player.source = Intent.Scripted.new()
			_game.ctx.calm = true
			_game.flow.press_start()
			_game.flow.choose_class(0)
		60:
			var shop = _game.ctx.build.shop
			_game.run.stage = 1
			shop.enter()
			shop.leave()
		90:
			_shot("hud_hook_pin")
			var shop = _game.ctx.build.shop
			var counts: Dictionary = _game.ctx.build.maker_counts()
			var pool: Array = []
			for m in MakerSets.SETS:
				if pool.is_empty() and int(counts.get(m, 0)) == 0 and int(MakerSets.SETS[m]["pieces"]) == 3:
					pool = shop._set_pool(m, [])
			_game.run.add_part(pool[0], "capture")
			_game.run.add_part(pool[1], "capture")
			_game.run.add_cogs(1200)
			_game.run.stage = 3
			shop.enter()
			_counter = ShopCounter.new()
			_counter.setup(_game)
			_game.hud.add_child(_counter)
			_counter.open(shop, 0.0)
		120:
			_shot("counter_last_call")
			_game.ctx.build.shop.buy_brew()
			_game.ctx.build.shop.buy_brew()
			_counter.refresh()
		140:
			_shot("counter_two_pours")
			quit(0)
			return true
	return false


func _shot(name: String) -> void:
	var image := root.get_texture().get_image()
	var path := _out.path_join(name + ".png")
	image.save_png(path)
	print("last_call_capture: %s" % path)
