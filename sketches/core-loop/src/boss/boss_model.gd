extends RefCounted

const BakeLook := preload("res://src/presentation/bake_look.gd")
const InkOutline := preload("res://src/presentation/ink_outline.gd")


static var _scenes := {}


static func load_scene(path: String, dressed := true) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var packed := _scenes.get(path) as PackedScene
	if packed == null:
		packed = load(path) as PackedScene
		if packed == null:
			return null
		_scenes[path] = packed
	var scene := packed.instantiate() as Node3D
	if scene != null and dressed:
		for view: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			colour_view(view)
		BakeLook.dress(scene)
		InkOutline.apply(scene, "boss")
	return scene


static func reset_for_tests() -> void:
	_scenes.clear()
	_coloured.clear()


static func colour_view(view: MeshInstance3D) -> void:
	if view.mesh == null:
		return
	for i in view.mesh.get_surface_count():
		var source := view.mesh.surface_get_material(i)
		var drawn := _vertex_coloured(source)
		if drawn != source:
			view.set_surface_override_material(i, drawn)


static var _coloured := {}


static func _vertex_coloured(source: Material) -> Material:
	if not (source is BaseMaterial3D):
		return source
	var base := source as BaseMaterial3D
	if base.vertex_color_use_as_albedo or base.albedo_texture != null:
		return source
	var key := base.get_instance_id()
	if not _coloured.has(key):
		var copy := base.duplicate() as BaseMaterial3D
		copy.vertex_color_use_as_albedo = true
		_coloured[key] = copy
	return _coloured[key]


static func player_of(root: Node) -> AnimationPlayer:
	return root.find_child("AnimationPlayer", true, false) as AnimationPlayer


static func hide_primitive(mesh: GeometryInstance3D) -> void:
	mesh.layers = 0
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func own_clips(player: AnimationPlayer) -> void:
	var library := player.get_animation_library("")
	if library == null:
		return
	library = library.duplicate(true) as AnimationLibrary
	player.remove_animation_library("")
	player.add_animation_library("", library)


static func loop_clip(player: AnimationPlayer, clip: String) -> void:
	if player != null and player.has_animation(clip):
		player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR


static func strip_tracks(player: AnimationPlayer, node_name: String, clips: Array = []) -> void:
	for clip in player.get_animation_list():
		if not clips.is_empty() and not clips.has(String(clip)):
			continue
		var animation := player.get_animation(clip)
		for t in range(animation.get_track_count() - 1, -1, -1):
			if _names(String(animation.track_get_path(t)).get_slice(":", 0), node_name):
				animation.remove_track(t)


static func _names(node_path: String, node_name: String) -> bool:
	return node_path == node_name or node_path.ends_with("/" + node_name)


static func strip_except(player: AnimationPlayer, node_name: String, keep: Array) -> void:
	for clip in player.get_animation_list():
		if not keep.has(String(clip)):
			strip_tracks(player, node_name, [String(clip)])


static func split_player(player: AnimationPlayer, clips: Array, node_names: Array) -> AnimationPlayer:
	var side := AnimationPlayer.new()
	side.name = "Side" + String(player.name)
	player.get_parent().add_child(side)
	side.root_node = player.root_node
	var library := AnimationLibrary.new()
	for clip in clips:
		if not player.has_animation(clip):
			continue
		var source := player.get_animation(clip)
		var part := Animation.new()
		part.length = source.length
		for t in source.get_track_count():
			if _on_node(source.track_get_path(t), node_names):
				source.copy_track(t, part)
		library.add_animation(clip, part)
	side.add_animation_library("", library)
	for name in node_names:
		strip_tracks(player, name)
	return side


static func _on_node(path: NodePath, node_names: Array) -> bool:
	var node := String(path).get_slice(":", 0)
	for name in node_names:
		if _names(node, String(name)):
			return true
	return false


static func hide_warden_body(warden: Node) -> void:
	var hero := warden.get_node_or_null("HeroWarden") as Node3D
	if hero != null:
		hero.visible = false
	for key in ["_look", "_kit"]:
		var part = warden.get(key)
		if part is Node3D:
			(part as Node3D).visible = false


const FALLBACK_BLEND := 0.12
const BLENDS := {
	"idle_roll": 0.2, "chase": 0.2, "attention": 0.2, "still_track": 0.25, "sleeping": 0.2,
	"enter_furnace": 0.15, "enter_scuttle": 0.15, "wake": 0.2, "phase_break": 0.12, "phase_break_2": 0.12,
	"phase_break_3": 0.12, "final_quiet": 0.2, "pit_defeat": 0.2,
	"crane_warn": 0.3, "charge_warn": 0.2, "slag_warn": 0.15, "drone_deploy": 0.1, "magnet_hold_drip": 0.08,
	"floor_warn": 0.15, "floor_warn_seam": 0.15, "floor_warn_bedrock": 0.15,
	"pulse_warn": 0.15, "pulse": 0.1, "recovery": 0.15, "hand_send": 0.1, "recover": 0.2,
	"lane_warn": 0.15, "split_lane_warn": 0.15, "rush_warn": 0.15, "plate_warn": 0.15, "quote_warn": 0.15,
	"brace": 0.05, "choir_change": 0.12, "choir_change_1_2": 0.12, "choir_change_2_0": 0.12,
	"floor_drop": 0.04, "floor_drop_seam": 0.04, "floor_drop_bedrock": 0.04,
	"crane_sweep": 0.0, "family_strike": 0.0, "exact_strike": 0.0, "wall_stun": 0.0, "eject": 0.0,
	"lens_break": 0.0, "stagger_open": 0.0, "core_open": 0.0,
}


static func blend_for(clip: String) -> float:
	return float(BLENDS.get(clip, FALLBACK_BLEND))


# Untyped: Godot throws a runtime type error if a freed AnimationPlayer is passed to a typed parameter.
static func play(player, clip: String, backwards := false, blend := -1.0, speed := 1.0) -> bool:
	if not is_instance_valid(player) or not player.has_animation(clip):
		return false
	var seconds: float = blend if blend >= 0.0 else blend_for(clip)
	var from := -1.0
	if player.assigned_animation == clip and player.is_playing():
		if player.current_animation_position <= 0.0 and (player.get_playing_speed() < 0.0) == backwards:
			return true
		# Godot AnimationPlayer.play() restarts instead of crossfading when re-playing an already-running clip.
		seconds = 0.0
		if (player.get_playing_speed() < 0.0) != backwards:
			from = player.current_animation_position
	if seconds <= 0.0:
		player.stop()
	else:
		player.clear_queue()
	if backwards:
		player.play(clip, seconds, -speed, true)
	else:
		player.play(clip, seconds, speed, false)
	if from >= 0.0:
		player.seek(from, true)
	return true


static func signal_glow(mesh: MeshInstance3D, color: Color, energy: float) -> void:
	if mesh == null or mesh.mesh == null:
		return
	if not mesh.has_meta("signal_surface"):
		var found := -1
		for i in mesh.mesh.get_surface_count():
			var material := mesh.mesh.surface_get_material(i)
			if material is StandardMaterial3D and material.resource_name.begins_with("M4"):
				found = i
		mesh.set_meta("signal_surface", found)
		if found >= 0:
			var drawn := mesh.get_surface_override_material(found)
			if drawn == null:
				drawn = mesh.mesh.surface_get_material(found)
			mesh.set_surface_override_material(found, drawn.duplicate())
	var surface: int = mesh.get_meta("signal_surface")
	if surface < 0:
		return
	var own := mesh.get_surface_override_material(surface) as StandardMaterial3D
	own.emission_enabled = energy > 0.0
	own.emission = color
	own.emission_energy_multiplier = energy
