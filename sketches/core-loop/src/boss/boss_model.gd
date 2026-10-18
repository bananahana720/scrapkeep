extends RefCounted

const BakeLook := preload("res://src/presentation/bake_look.gd")

# Shared helpers for the boss GLBs (assets/models/bosses/). Every boss keeps its primitive
# body as the fallback: load_scene returns null when a GLB is missing or unloadable, and the
# caller then leaves the primitives visible. Nothing here moves a collider or sets a timer;
# a clip is only ever cued from state the boss script already tracks.


static func load_scene(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var scene := packed.instantiate() as Node3D
	if scene != null:
		for view: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			if view.mesh != null:
				for i in view.mesh.get_surface_count():
					var source := view.mesh.surface_get_material(i)
					var drawn := _vertex_coloured(source)
					if drawn != source:
						view.set_surface_override_material(i, drawn)
		# The polish bake's UV2 shade (tools/blender/POLISH.md); a caller that swaps in its own
		# materials afterwards calls BakeLook.dress again with them as `owned`.
		BakeLook.dress(scene)
	return scene


# Boss GLBs keep colour in vertex colours and import with white materials that ignore them,
# so the Waking and the Mind drew white. One shared copy per source material.
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


# The placeholder stays in the tree, its state flags untouched; only its render layer goes.
static func hide_primitive(mesh: GeometryInstance3D) -> void:
	mesh.layers = 0
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# Gives this instance its own copy of every clip, so a loop flag or a stripped track never
# leaks into the next instance through the shared imported resource.
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


# Drops every track on a node whose path ends in `node_name`, from the named clips (all
# clips when `clips` is empty). Used where code owns a part the clips would otherwise reset.
static func strip_tracks(player: AnimationPlayer, node_name: String, clips: Array = []) -> void:
	for clip in player.get_animation_list():
		if not clips.is_empty() and not clips.has(String(clip)):
			continue
		var animation := player.get_animation(clip)
		for t in range(animation.get_track_count() - 1, -1, -1):
			if _names(String(animation.track_get_path(t)).get_slice(":", 0), node_name):
				animation.remove_track(t)


# A track's node path names `node_name` when it is that node directly under the clip root
# or ends in it one or more levels down; a sibling that only ends the same way is not it.
static func _names(node_path: String, node_name: String) -> bool:
	return node_path == node_name or node_path.ends_with("/" + node_name)


# Drops the node's tracks from every clip not named in `keep`: a part a clip would reset to
# its authored rest (a shed collar, a retracted spine) keeps the pose its own clip left.
static func strip_except(player: AnimationPlayer, node_name: String, keep: Array) -> void:
	for clip in player.get_animation_list():
		if not keep.has(String(clip)):
			strip_tracks(player, node_name, [String(clip)])


# Moves the tracks of `node_names`, from the named clips, onto a second AnimationPlayer that
# shares the first one's root, and removes them from every clip of the first. Two cues that
# must coexist (a pulse beside a family attack, an open lens beside a floor drop) then each
# own a player. Returns the new player.
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


# Hides a boss Warden's own body: the placeholder look, its family kit and the painted
# HeroWarden, so the boss model is the only body. Colliders and cues are untouched.
static func hide_warden_body(warden: Node) -> void:
	var hero := warden.get_node_or_null("HeroWarden") as Node3D
	if hero != null:
		hero.visible = false
	for key in ["_look", "_kit"]:
		var part = warden.get(key)
		if part is Node3D:
			(part as Node3D).visible = false


# Plays `clip` from its start; false when the clip does not exist.
# The player is untyped on purpose: a kit under a Warden is freed with it, and a freed
# AnimationPlayer must be a no-op here, not a type error at the call.
static func play(player, clip: String, backwards := false) -> bool:
	if not is_instance_valid(player) or not player.has_animation(clip):
		return false
	player.stop()
	if backwards:
		player.play_backwards(clip)
	else:
		player.play(clip)
	return true


# Lights the M4 signal surface of one mesh instance. The drawn material (load_scene's
# vertex-coloured override, else the imported one) is shared, so the instance gets its own
# copy of it the first time. Mint and blue are never passed in here: only the
# hazard working face and the live target glow, and the caller picks which.
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
