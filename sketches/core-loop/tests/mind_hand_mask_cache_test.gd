extends SceneTree

const Game := preload("res://src/game.gd")
const T := preload("res://tests/support/t.gd")
var _t := T.new("mind_hand_mask_cache_test")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game := Game.new()
	game.test_mode = true
	root.add_child(game)
	game.ctx.calm = true
	var masks := {}
	var materials := {}
	var hands := []
	for i in 4:
		var hand = game.combat.spawn_enemy("mind_hand", Vector3(100 + i * 10, 20, 100))
		hand.set_physics_process(false)
		hands.append(hand)
		if _t.check("spawn %d has a signal material" % i, hand._skin_rim != null):
			masks[hand._skin_rim.emission_texture.get_instance_id()] = true
			materials[hand._skin_rim.get_instance_id()] = true
	_t.eq("four hand spawns build one shared mask", masks.size(), 1)
	_t.eq("four hands retain private signal materials", materials.size(), 4)
	var image := Image.create_empty(2, 1, false, Image.FORMAT_RGB8)
	image.set_pixel(0, 0, Color(0.0, 0.0, 1.0))
	image.set_pixel(1, 0, Color(1.0, 0.0, 0.0))
	var texture := ImageTexture.create_from_image(image)
	var mask: ImageTexture = hands[0]._skin_rim_mask(texture)
	_t.check("source texture gets its own mask", not masks.has(mask.get_instance_id()))
	_t.check("another hand reuses the source mask", hands[1]._skin_rim_mask(texture) == mask)
	_t.eq("mask keeps blue seams lit", mask.get_image().get_pixel(0, 0), Color.WHITE)
	_t.eq("mask keeps working face dark", mask.get_image().get_pixel(1, 0), Color.BLACK)
	for hand in hands:
		hand.free()
	game.free()
	quit(_t.verdict())
