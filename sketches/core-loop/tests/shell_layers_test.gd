extends SceneTree
# 2026-10-10 (PD-TARN): the "default with no layers" case no longer leans on Tarn's shipped
# GLBs, which now have layers. BARE_PILOT's default base is a fixture with no _cN files.

# CUSTOMIZE.md sections 6 and 9: the one loader path for a pilot's shell. The lookup, the
# fallback table, mounting, visibility by heft class, holder instance-id stability, light
# stripping, paint on plates, Replace_ on layers and outfits, and the ready glow. Fixtures are
# scenes this test packs and saves under user://, fed to shell_path through its paths map.

const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const BallLooks := preload("res://src/presentation/ball_looks.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const ClassPreview := preload("res://src/ui/class_preview.gd")
const T := preload("res://tests/support/t.gd")

const DIR := "user://shell_layers_test/"
const PILOT := "pylon_engineer"
const VARIANT := "shell_fix_var"
# shell_path only answers for a SHELLS key; the fixture map overrides this one's base, so the
# real pilot's layers never reach the no-layers case.
const BARE_PILOT := "tarn"
const TINT := Color("3f6b4f")
const CLASS_TINT := Color("2fc6b5")


class StubState:
	var velocity := Vector3.ZERO


class StubKit:
	var gliding := false


class StubPlayer:
	extends Node3D
	var class_def: Resource
	var state := StubState.new()
	var kit := StubKit.new()
	var _juice := Node3D.new()
	var _mesh := MeshInstance3D.new()
	var _roll := Node3D.new()

	func _init() -> void:
		var visual := Node3D.new()
		add_child(visual)
		visual.add_child(_juice)
		_mesh.mesh = SphereMesh.new()
		_juice.add_child(_mesh)
		_mesh.add_child(_roll)

	func roll_node() -> Node3D:
		return _roll

	func juice_node() -> Node3D:
		return _juice

	func class_color() -> Color:
		return class_def.color if class_def != null else ClassDef.SABLE_COLOR


var _t := T.new("shell_layers_test")
var _paths := {}


func _initialize() -> void:
	_clear()
	DirAccess.make_dir_recursive_absolute(DIR)
	_make_fixtures()
	_lookup()
	await _fit_and_fallback()
	await _stability()
	_outfit_replace()
	await _game_swap()
	_class_preview()
	_clear()
	quit(_t.verdict())


func _clear() -> void:
	if DirAccess.dir_exists_absolute(DIR):
		for f in DirAccess.get_files_at(DIR):
			DirAccess.remove_absolute(DIR + f)
		DirAccess.remove_absolute(DIR)


func _mat(slot: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = slot
	return m


func _box(node_name: String, slot: String, at := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var box := BoxMesh.new()
	box.material = _mat(slot)
	mi.mesh = box
	mi.position = at
	return mi


func _own(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		_own(child, root)


# A shell scene: root > Core (paint plate) and Pod (class_accent machinery), plus extras.
func _save_shell(file: String, tag: String, extras := {}) -> String:
	var root := Node3D.new()
	root.name = "Shell"
	var core := Node3D.new()
	core.name = "Core"
	root.add_child(core)
	core.add_child(_box("Plate" + tag, "paint", Vector3(0, 0, 0.5)))
	var pod := Node3D.new()
	pod.name = "Pod"
	root.add_child(pod)
	pod.add_child(_box("Machine" + tag, "class_accent", Vector3(0.3, 0.2, 0)))
	if extras.get("cap", false):
		pod.add_child(_box("Cap", "paint", Vector3(0, 0.6, 0)))
	if extras.get("replace_cap", false):
		var r := Node3D.new()
		r.name = "Replace_Cap"
		pod.add_child(r)
		r.add_child(_box("SteadyCap", "paint", Vector3(0, 0.6, 0)))
	if extras.get("light", false):
		var lamp := OmniLight3D.new()
		lamp.name = "BadLamp"
		pod.add_child(lamp)
	_own(root, root)
	var packed := PackedScene.new()
	packed.pack(root)
	root.free()
	var path := DIR + file
	_t.check("fixture %s saved" % file, ResourceSaver.save(packed, path) == OK)
	return path


func _make_fixtures() -> void:
	_paths[PILOT] = _save_shell("def.scn", "DefC1", {"cap": true})
	for n in [2, 3, 4, 5]:
		_save_shell("def_c%d.scn" % n, "DefC%d" % n, {"replace_cap": n == 2})
	_paths[VARIANT] = _save_shell("var.scn", "VarC1", {"cap": true})
	_save_shell("var_c2.scn", "VarC2", {"replace_cap": true})
	_save_shell("var_c3.scn", "VarC3", {"light": true})
	# var_c4.scn is missing on purpose: the default C4 shows in its place.
	_save_shell("var_c5.scn", "VarC5")
	# A default base with no bare_c2 to bare_c5 beside it.
	_save_shell("bare.scn", "BareC1")
	# An outfit: a top-level node per bone, one replacing the pilot's Cap.
	var outfit := Node3D.new()
	outfit.name = "Outfit"
	var head := Node3D.new()
	head.name = "head"
	outfit.add_child(head)
	var rep := Node3D.new()
	rep.name = "Replace_Cap"
	head.add_child(rep)
	rep.add_child(_box("SteadyCap", "paint"))
	var lamp := OmniLight3D.new()
	lamp.name = "OutfitLamp"
	head.add_child(lamp)
	_own(outfit, outfit)
	var packed := PackedScene.new()
	packed.pack(outfit)
	outfit.free()
	_t.check("outfit fixture saved", ResourceSaver.save(packed, DIR + "outfit.scn") == OK)


func _lookup() -> void:
	for pilot in HeroAssets.SHELLS:
		var base: String = HeroAssets.SHELLS[pilot]
		_t.eq("shell_path %s default class 1" % pilot, HeroAssets.shell_path(pilot, "", 1, {}), base)
		for n in [2, 3, 4, 5]:
			_t.eq("shell_path %s default class %d" % [pilot, n], HeroAssets.shell_path(pilot, "", n, {}), base.trim_suffix(".glb") + "_c%d.glb" % n)
		_t.eq("shell_path %s class 0" % pilot, HeroAssets.shell_path(pilot, "", 0, {}), "")
		_t.eq("shell_path %s class 6" % pilot, HeroAssets.shell_path(pilot, "", 6, {}), "")
	for n in [1, 2, 3, 4, 5]:
		var want: String = DIR + ("var.scn" if n == 1 else "var_c%d.scn" % n)
		_t.eq("shell_path fixture variant class %d" % n, HeroAssets.shell_path(PILOT, VARIANT, n, _paths), want)
	_t.eq("shell_path unknown pilot", HeroAssets.shell_path("nobody", "", 1, _paths), "")
	_t.eq("shell_path unknown variant", HeroAssets.shell_path(PILOT, "shell_nobody", 1, _paths), "")
	_t.eq("shell_path a paint is not a shell variant", HeroAssets.shell_path(PILOT, "paint_any_night", 1, {"paint_any_night": DIR + "var.scn"}), "")
	_t.eq("shell_path variant class 0", HeroAssets.shell_path(PILOT, VARIANT, 0, _paths), "")
	_t.eq("shell_path variant class 6", HeroAssets.shell_path(PILOT, VARIANT, 6, _paths), "")


func _hero() -> Node:
	var hero := HeroAssets.new()
	hero.shell_assets = _paths.duplicate()
	return hero


func _no_lights_or_overrides(label: String, roots: Array) -> void:
	var lights := 0
	var overrides := 0
	var checked := 0
	for root in roots:
		var nodes: Array = [root]
		nodes.append_array(root.find_children("*", "", true, false))
		for node in nodes:
			checked += 1
			if node is Light3D:
				lights += 1
			if node is GeometryInstance3D and node.material_override != null:
				overrides += 1
	_t.check("%s: no Light3D" % label, lights == 0 and checked > 0, "%d lights over %d nodes" % [lights, checked])
	_t.eq("%s: no material_override" % label, overrides, 0)


func _fit_and_fallback() -> void:
	var hero := _hero()
	var ball := Node3D.new()
	root.add_child(ball)
	var tints := {"class": CLASS_TINT, "paint": TINT}
	var rec: Dictionary = hero.fit_shell_into(ball, PILOT, VARIANT, 4, tints)
	_t.check("fit_shell_into builds the variant", not rec.is_empty() and rec.core.find_child("PlateVarC1", true, false) != null)
	_t.check("HeroCore and HeroPod mount under ball", rec.core.name == "HeroCore" and rec.pod.name == "HeroPod" and rec.core.get_parent() == ball and rec.pod.get_parent() == ball)
	for n in [2, 3, 4, 5]:
		_t.check("holder HeftC%d under Core and Pod" % n, rec.core.get_node_or_null("HeftC%d" % n) == rec.layers[n].core and rec.pod.get_node_or_null("HeftC%d" % n) == rec.layers[n].pod)
		_t.eq("class 4 shows layer %d" % n, rec.layers[n].core.visible, n <= 4)
	_t.check("the variant's own C2 and C3 show", rec.layers[2].core.find_child("PlateVarC2", true, false) != null and rec.layers[3].core.find_child("PlateVarC3", true, false) != null)
	_t.check("a variant missing C4 borrows the default C4", rec.layers[4].core.find_child("PlateDefC4", true, false) != null and rec.layers[4].core.visible)
	_t.check("the variant's C5 is its own", rec.layers[5].core.find_child("PlateVarC5", true, false) != null)
	_no_lights_or_overrides("variant fit with a lamp in C3", [rec.core, rec.pod])
	_t.check("the C3 lamp warned", hero.warning_log.any(func(w): return w.contains("var_c3.scn")), str(hero.warning_log))
	# Paint on every paint surface of every visible layer.
	var painted := 0
	var wrong := 0
	var calm: Material = hero.material("paint", TINT)
	for mi in rec.core.find_children("*", "MeshInstance3D", true, false) + rec.pod.find_children("*", "MeshInstance3D", true, false):
		if not mi.is_visible_in_tree():
			continue
		for s in mi.mesh.get_surface_count():
			if HeroAssets.slot_of(mi.mesh, s) == "paint":
				painted += 1
				if mi.get_surface_override_material(s) != calm:
					wrong += 1
	_t.check("equipped paint reaches every visible paint surface", painted >= 5 and wrong == 0, "%d painted, %d wrong" % [painted, wrong])
	# Replace_Cap in the variant C2 hides the base Cap while C2 shows.
	var cap := rec.pod.find_child("Cap", false, false) as MeshInstance3D
	_t.check("Replace_Cap hides the base Cap at class IV", cap != null and cap.layers == 0)
	hero.set_heft_class(rec, 1, false)
	_t.check("dropping to class I restores the Cap's layers", cap.layers == 1)
	_t.check("class I hides every layer", not rec.layers[2].core.visible and not rec.layers[5].pod.visible)
	hero.set_heft_class(rec, 2, false)
	_t.check("class II hides the Cap again", cap.layers == 0)
	# The ready glow: two cached materials per class colour.
	var calm_accent: Material = hero.material("class_accent", CLASS_TINT)
	var lit: Material = hero.ready_material(CLASS_TINT)
	_t.check("the ready material is cached", hero.ready_material(CLASS_TINT) == lit and lit != calm_accent)
	var swapped: int = hero._glow_rec(rec, true)
	var machine := rec.pod.find_child("MachineVarC1", true, false) as MeshInstance3D
	_t.check("ready glow swaps class_accent to the ready material", swapped > 0 and machine.get_surface_override_material(0) == lit)
	hero._glow_rec(rec, false)
	_t.check("ready glow swaps back to the calm material", machine.get_surface_override_material(0) == calm_accent)
	_t.check("ready material emits brighter", (lit as StandardMaterial3D).emission_energy_multiplier > (calm_accent as StandardMaterial3D).emission_energy_multiplier)
	# 100 refits of the variant missing C4: one warning.
	ball.remove_child(rec.core)
	ball.remove_child(rec.pod)
	rec.core.free()
	rec.pod.free()
	for i in 100:
		var again: Dictionary = hero.fit_shell_into(ball, PILOT, VARIANT, 4, tints)
		again.core.free()
		again.pod.free()
	var c4_warnings: Array = hero.warning_log.filter(func(w): return w.contains("class 4 layer"))
	_t.eq("a variant missing C4 warns once over 100 refits", c4_warnings.size(), 1)
	# A missing variant base shows the default base and layers.
	hero.shell_assets["shell_fix_gone"] = DIR + "gone.scn"
	var gone: Dictionary = hero.fit_shell_into(ball, PILOT, "shell_fix_gone", 5, tints)
	_t.check("a missing variant base shows the default shell", not gone.is_empty() and gone.core.find_child("PlateDefC1", true, false) != null and gone.layers[3].core.find_child("PlateDefC3", true, false) != null)
	gone.core.free()
	gone.pod.free()
	# A pilot whose default has no layers shows nothing for those classes, warned once per class.
	hero.shell_assets[BARE_PILOT] = DIR + "bare.scn"
	var bare: Dictionary = hero.fit_shell_into(ball, BARE_PILOT, "", 5, tints)
	_t.check("a default with no layers fits its base", not bare.is_empty() and bare.core.find_child("PlateBareC1", true, false) != null and bare.layers[2].core.get_child_count() == 0)
	_t.check("a missing default layer warns", hero.warning_log.any(func(w): return w.contains("%s has no class 2 layer" % BARE_PILOT)))
	_no_lights_or_overrides("default shell fit", [bare.core, bare.pod])
	bare.core.free()
	bare.pod.free()
	ball.free()
	hero.free()
	await process_frame


func _stability() -> void:
	var hero := _hero()
	root.add_child(hero)
	var ball := Node3D.new()
	root.add_child(ball)
	var rec: Dictionary = hero.fit_shell_into(ball, PILOT, VARIANT, 1, {"class": CLASS_TINT})
	var ids := {}
	for n in [2, 3, 4, 5]:
		ids[n] = [rec.layers[n].core.get_instance_id(), rec.layers[n].pod.get_instance_id()]
	var steps := [5, 2, 4, 1, 3]
	for step in steps:
		hero.set_heft_class(rec, step, true)
		await process_frame
		# Step each holder's slam or fling to its end on the sim clock, not the wall clock.
		for n in [2, 3, 4, 5]:
			for key in ["core", "pod"]:
				var holder: Node3D = rec.layers[n][key]
				if holder.has_meta("heft_tween"):
					var tween = holder.get_meta("heft_tween")
					if tween is Tween and tween.is_valid():
						tween.custom_step(1.0)
		for n in [2, 3, 4, 5]:
			_t.eq("class %d: layer %d visible" % [step, n], rec.layers[n].core.visible and rec.layers[n].pod.visible, n <= step)
	var same := true
	for n in [2, 3, 4, 5]:
		if not is_instance_valid(rec.layers[n].core) or rec.layers[n].core.get_instance_id() != ids[n][0] or rec.layers[n].pod.get_instance_id() != ids[n][1]:
			same = false
	_t.check("five class changes keep every holder's instance id", same)
	var rest_ok := true
	for mi in rec.core.find_children("*", "MeshInstance3D", true, false):
		if mi.has_meta("heft_rest") and not (mi as Node3D).position.is_equal_approx(mi.get_meta("heft_rest")):
			rest_ok = false
	_t.check("after the slams and flings every plate is at rest", rest_ok)
	ball.free()
	hero.queue_free()
	await process_frame


func _outfit_replace() -> void:
	var hero := _hero()
	var pilot := Node3D.new()
	pilot.name = "AnimatedPilot"
	var skeleton := Skeleton3D.new()
	skeleton.add_bone("head")
	pilot.add_child(skeleton)
	var cap := _box("Cap", "pilot")
	cap.layers = 5
	pilot.add_child(cap)
	root.add_child(pilot)
	var mounts: Array = hero.fit_outfit_scene(pilot, DIR + "outfit.scn", {"class": CLASS_TINT})
	_t.check("the outfit mounts one BoneAttachment3D on head", mounts.size() == 1 and mounts[0] is BoneAttachment3D and mounts[0].bone_name == "head" and mounts[0].get_parent() == skeleton)
	_t.eq("Replace_Cap hides the pilot's Cap while worn", cap.layers, 0)
	_no_lights_or_overrides("outfit", [skeleton])
	hero.remove_outfit(pilot)
	_t.eq("removing the outfit restores the Cap's layers", cap.layers, 5)
	_t.eq("an outfit with no art mounts nothing", hero.fit_outfit(pilot, "outfit_nobody"), [])
	pilot.free()
	hero.free()


# Through the game path: the heft signal never frees a holder; only a pilot swap does.
func _game_swap() -> void:
	var hero := HeroAssets.new()
	root.add_child(hero)
	var player := StubPlayer.new()
	player.class_def = ClassDef.by_id(PILOT)
	root.add_child(player)
	hero.attach_player(player)
	var shell: Dictionary = hero.shell_of(player).get("shell", {})
	_t.check("the game path fits through fit_shell_into", not shell.is_empty() and shell.layers.size() == 4)
	if shell.is_empty():
		player.free()
		hero.free()
		return
	var holder_id: int = shell.layers[3].core.get_instance_id()
	for step in [3, 5, 1, 4, 2]:
		hero._on_heft_class(step, 0.0)
		hero._process(0.016)
	_t.check("heft changes in play keep the holder", is_instance_valid(shell.layers[3].core) and shell.layers[3].core.get_instance_id() == holder_id)
	var old_holder: Node = shell.layers[3].core
	player.class_def = ClassDef.by_id("runner_gunner")
	hero._process(0.016)
	await process_frame
	var swapped: Dictionary = hero.shell_of(player).get("shell", {})
	_t.check("a pilot swap builds new holders", not swapped.is_empty() and swapped.layers[3].core.get_instance_id() != holder_id)
	_t.check("a pilot swap frees the old holders", not is_instance_valid(old_holder))
	_no_lights_or_overrides("game shell", [swapped.core, swapped.pod])
	player.free()
	hero.free()


func _paint_material(node: Node, mesh_name: String) -> Material:
	var mi := node.find_child(mesh_name, true, false) as MeshInstance3D
	if mi == null:
		return null
	for s in mi.mesh.get_surface_count():
		if HeroAssets.slot_of(mi.mesh, s) == "paint":
			return BallLooks.unwindowed(mi.get_surface_override_material(s))
	return null


# The class card's preview builds through fit_shell_into, so it shows the equipped variant and
# paint (CUSTOMIZE.md section 7, the live preview, last bullet).
func _class_preview() -> void:
	var def = ClassDef.by_id(PILOT)
	var plain = ClassPreview.new(def)
	plain._painter.shell_assets = _paths
	plain.variant = VARIANT
	var preview = ClassPreview.new(def)
	preview._painter.shell_assets = _paths
	preview.paint_id = "paint_any_night"
	preview.variant = VARIANT
	_t.check("class preview fits through fit_shell_into", not preview._shell_rec.is_empty() and preview._shell_rec.layers.size() == 4)
	_t.eq("class preview shows the equipped variant", String(preview._shell_rec.get("variant", "")), VARIANT)
	_t.check("class preview mounts the variant's lattice", preview._core.find_child("PlateVarC1", true, false) != null and preview._core.find_child("PlateDefC1", true, false) == null)
	var plate: Material = _paint_material(preview._core, "PlateVarC1")
	var cap: Material = _paint_material(preview._pod, "Cap")
	_t.check("class preview paints the variant with the equipped paint", plate != null and plate == cap and plate != _paint_material(plain._core, "PlateVarC1"))
	preview.heft_class = 3
	_t.check("class preview shows layers up to its heft class", preview._shell_rec.layers[3].core.visible and not preview._shell_rec.layers[4].core.visible)
	_no_lights_or_overrides("class preview", [preview._core, preview._pod])
	preview.variant = ""
	_t.check("class preview returns to the default lattice", preview._core.find_child("PlateDefC1", true, false) != null)
	plain.free()
	preview.free()
