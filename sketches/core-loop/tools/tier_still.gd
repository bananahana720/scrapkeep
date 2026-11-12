extends SceneTree

const ItemGen := preload("res://src/build/item_gen.gd")
const TierMark := preload("res://src/build/tier_mark.gd")
const Accretion := preload("res://src/build/accretion.gd")
const CrackedCache := preload("res://src/world/cracked_cache.gd")
const ShopTile := preload("res://src/ui/shop_tile.gd")
const Palette := preload("res://src/core/palette.gd")
const Parts := preload("res://src/build/parts.gd")

# W1-26 proof still: the four item tiers side by side, left to right common, rare, relic,
# evolved. Top row the pedestal gems, middle row one part piece on a ball, bottom row the
# shop frames. tools/tier_cvd.py then applies the Machado deuteranopia matrix to it.
#
#   xvfb-run -a godot --rendering-driver opengl3 --path sketches/core-loop \
#     --script res://tools/tier_still.gd -- --out=<png> [--part=<id per tier, comma list>]

const SIZE := Vector2i(1600, 900)
const PIECES := ["hot_rivets", "load_dividend", "tempest_core", "breaker_drive"]

var _out := "user://tier_still.png"
var _frames := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
	root.size = SIZE
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Palette.CHARCOAL
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	world.add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 7.0
	cam.look_at_from_position(Vector3(0.0, 4.0, 6.0), Vector3(0.0, 0.6, 0.0))
	world.add_child(cam)
	var acc := Accretion.new()
	for i in ItemGen.RARITIES.size():
		var rarity: String = ItemGen.RARITIES[i]
		var x := (i - 1.5) * 2.6
		var gem := TierMark.mark(rarity, Palette.solid(CrackedCache.gem_color(rarity), 2.0))
		gem.position = Vector3(x, 2.4, 0.0)
		world.add_child(gem)
		var ball := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		ball.mesh = sphere
		sphere.radius = 0.9
		sphere.height = 1.8
		ball.material_override = Palette.solid(Palette.VERDIGRIS)
		ball.position = Vector3(x, -0.4, 0.0)
		world.add_child(ball)
		var piece: Node3D = acc._piece(PIECES[i])
		piece.position = Vector3(0.0, 0.92, 0.0)
		piece.rotation_degrees = Vector3(25.0, 0.0, 0.0)
		ball.add_child(piece)
	acc.free()
	var ui := CanvasLayer.new()
	root.add_child(ui)
	for i in ItemGen.RARITIES.size():
		var tile := ShopTile.new({"kind": "shelf", "rarity": ItemGen.RARITIES[i], "icon": "cat_utility"})
		tile.position = Vector2(SIZE.x * 0.5 + (i - 1.5) * 330.0 - 56.0, SIZE.y - 190.0)
		ui.add_child(tile)
	process_frame.connect(_tick)


func _tick() -> void:
	_frames += 1
	if _frames < 20:
		return
	var img := root.get_texture().get_image()
	img.save_png(_out)
	print("tier_still: wrote %s" % _out)
	quit(0)
