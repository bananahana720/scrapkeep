extends SceneTree

const Game := preload("res://src/game.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const MindHand := preload("res://src/combat/mind_hand.gd")
const T := preload("res://tests/support/t.gd")

var _t := T.new("mind_hand_surface_test")
var _game


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.ctx.spawner = _game.combat
	var hand = _game.combat.spawn_enemy("mind_hand", Vector3(100, 20, 100))
	var other = _game.combat.spawn_enemy("mind_hand", Vector3(110, 20, 100))
	hand.set_physics_process(false)
	other.set_physics_process(false)
	await process_frame
	var skin := hand._model.find_child("MindHandSkin", true, false) as MeshInstance3D if hand._model != null else null
	_t.check("live hand shows skin", skin != null and skin.visible and skin.layers != 0)
	if skin != null:
		var body: StandardMaterial3D
		var rim: StandardMaterial3D
		for i in skin.mesh.get_surface_count():
			var authored := skin.mesh.surface_get_material(i) as StandardMaterial3D
			if authored == null:
				continue
			var own := skin.get_surface_override_material(i) as StandardMaterial3D
			if authored.resource_name.begins_with("M1"):
				body = own
			elif authored.resource_name.begins_with("M4"):
				rim = own
			else:
				continue
			_t.check("instance keeps authored texture", own != null and own != authored and own.albedo_texture == authored.albedo_texture)
		_t.check("skin has both overrides", body != null and rim != null)
		if body != null and rim != null:
			var rest := body.albedo_color
			var hp: float = hand.hp
			_game.combat.strike(hand, "runner", 5.0)
			hand._update_flash(0.0)
			_t.check("live hit starts an 80 ms shared white flash", hand.hp < hp
				and is_equal_approx(hand.HIT_FLASH_SECONDS, 0.08) and hand._flash > 0.0
				and body.albedo_color == Color(1.0, 1.0, 0.85) and body.emission_enabled
				and body.emission == EventKinds.role_color("neutral"))
			_t.check("hit does not flash the other hand", other._material != body and not other._material.emission_enabled)
			hand._update_flash(hand.HIT_FLASH_SECONDS)
			_t.check("flash returns to authored rest", not body.emission_enabled and body.albedo_color == rest)
			var finish := rim.albedo_color
			for state in ["slate", "amber", ""]:
				hand.set_tint(state)
				_t.eq("plating keeps skin finish", rim.albedo_color, finish)
				_t.eq("rim enabled for plating state", rim.emission_enabled, state != "")
				if state != "":
					_t.eq("rim uses plating state colour", rim.emission, EventKinds.state_color("will_break" if state == "amber" else "glancing"))
					_t.check("rim carries light", rim.emission_energy_multiplier > 0.0)
			var mask := rim.emission_texture.get_image() if rim.emission_texture != null else null
			_t.check("blue seam has a rim mask", mask != null and mask.get_pixel(8, 72).r == 1.0)
			_t.check("working face excludes plating light", mask != null and mask.get_pixel(72, 72).r == 0.0)
			hand.set_tint("amber")
			var before: float = rim.emission_energy_multiplier
			hand._pulse_rim(0.0625)
			_t.check("live rim pulses on existing clock", rim.emission_energy_multiplier != before)
			_t.check("rim does not recolour the other hand", other._skin_rim != rim and not other._skin_rim.emission_enabled)
	var original := ResourceLoader.load(MindHand.MODEL, "PackedScene") as PackedScene
	var broken := original.instantiate()
	var broken_skin := broken.find_child("MindHandSkin", true, false) as MeshInstance3D
	if broken_skin != null and broken_skin.mesh != null:
		broken_skin.mesh = broken_skin.mesh.duplicate()
		for i in broken_skin.mesh.get_surface_count():
			var authored := broken_skin.mesh.surface_get_material(i) as StandardMaterial3D
			if authored == null or not authored.resource_name.begins_with("M1"):
				continue
			broken_skin.mesh.surface_set_material(i, null)
			break
	var bad_scene := PackedScene.new()
	bad_scene.pack(broken)
	broken.free()
	bad_scene.take_over_path(MindHand.MODEL)
	var malformed = _game.combat.spawn_enemy("mind_hand", Vector3(120, 20, 100))
	original.take_over_path(MindHand.MODEL)
	MindHand._warned_models.erase(MindHand.MODEL)
	malformed.set_physics_process(false)
	_t.check("null body material keeps primitive fallback", malformed._model == null and malformed._crew.layers != 0)
	malformed.free()
	hand.free()
	other.free()
	_game.free()
	quit(_t.verdict())
