extends SceneTree

const Game := preload("res://src/game.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
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
			_t.check("live hit starts an 80 ms white flash tween", hand.hp < hp and hand._flash_tween is Tween
				and is_equal_approx(hand.HIT_FLASH_SECONDS, 0.08)
				and body.albedo_color == Color.WHITE and body.emission_enabled
				and body.emission == Color.WHITE)
			_t.check("hit does not flash the other hand", other._material != body and not other._material.emission_enabled)
			hand._flash_tween.custom_step(hand.HIT_FLASH_SECONDS + 0.02)
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
		for i in skin.mesh.get_surface_count():
			var authored := skin.mesh.surface_get_material(i) as StandardMaterial3D
			if authored == null or not authored.resource_name.begins_with("M1"):
				continue
			skin.mesh.surface_set_material(i, null)
			var malformed = _game.combat.spawn_enemy("mind_hand", Vector3(120, 20, 100))
			skin.mesh.surface_set_material(i, authored)
			malformed.set_physics_process(false)
			_t.check("null body material keeps primitive fallback", malformed._model == null and malformed._crew.layers != 0)
			malformed.free()
			break
	hand.free()
	other.free()
	_game.free()
	quit(_t.verdict())
