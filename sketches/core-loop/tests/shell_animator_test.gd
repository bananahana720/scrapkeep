extends SceneTree

const ShellAnimator := preload("res://src/presentation/shell_animator.gd")
const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const AbilityBar := preload("res://src/ui/ability_bar.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const GameEvents := preload("res://src/core/game_events.gd")

# The shell animator on each class's real shell, driven by a stub player at 90 Hz:
# idle breath, blinks, the class fidget and the leitmotif pulse; heading, lean and the
# brace at speed; each ability slot lighting only its own devices, the gauge glow and
# the ready pulse; landing, hit and Warden-break reactions; the kit's spool, stacks,
# mortar, vane and cloak; a Ring on a bare stand-in shell; and a shell with no parts at
# all. With SHELL_ANIM_TRACE set to a file path it also writes the posed frames the
# Blender preview renders (tools/blender/preview_anim.py), so the preview shows this
# code's motion and not a copy of it.

const HZ := 90.0
const DT := 1.0 / HZ
const SHELLS := {
	"pylon_engineer": "res://assets/models/shell_sable.glb",
	"runner_gunner": "res://assets/models/shell_rivet.glb",
	"demolitions_caster": "res://assets/models/shell_kest.glb",
}
# The parts each shell must give the animator.
const EXPECT := {
	"pylon_engineer": {"devices": ["Accent_special_smash", "Accent_weapon_movement"],
		"roles": ["body", "core", "pilot", "head", "eyes", "brace", "paws", "tap", "spin", "glass"]},
	"runner_gunner": {"devices": ["Accent_movement_special_L", "Accent_movement_special_R", "Accent_weapon_special",
		"Accent_movement_visor"], "roles": ["body", "core", "pilot", "head", "brace", "paws", "puff", "glass"]},
	"demolitions_caster": {"devices": ["Accent_special_smash_0", "Accent_special_smash_1", "Accent_special_smash_2",
		"Accent_weapon"], "roles": ["body", "core", "pilot", "head", "eyes", "brace", "recoil", "swing", "vane", "glass"]},
}
# Which device answers each slot, and one device that must stay dark for it.
const LIGHTS := {
	"pylon_engineer": {"weapon": ["Accent_weapon_movement", "Accent_special_smash"],
		"special": ["Accent_special_smash", "Accent_weapon_movement"]},
	"runner_gunner": {"movement": ["Accent_movement_special_L", "Accent_weapon_special"],
		"weapon": ["Accent_weapon_special", "Accent_movement_visor"]},
	"demolitions_caster": {"weapon": ["Accent_weapon", "Accent_special_smash_0"],
		"special": ["Accent_special_smash_1", "Accent_weapon"]},
}


class StubState:
	var velocity := Vector3.ZERO
	var grounded := true


class StubKit:
	var hooked := false
	var gliding := false
	var mounted := false
	var cloaked := false


class StubPlayer:
	extends Node3D
	var state := StubState.new()
	var kit := StubKit.new()
	var abilities := AbilityState.new()
	var drive_basis := Basis.IDENTITY


var _failures := 0
var _checks := 0
var _trace := {}


func _report(label: String, ok: bool, detail: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _initialize() -> void:
	for id in SHELLS:
		_check_class(id)
	_check_rings()
	_check_bare()
	var path := OS.get_environment("SHELL_ANIM_TRACE")
	if path != "":
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(_trace))
		file.close()
		print("trace written to %s" % path)
	print("shell_animator_test: %s (%d checks)" % ["PASS" if _failures == 0 else "FAIL (%d)" % _failures, _checks])
	quit(0 if _failures == 0 else 1)


func _rig(id: String) -> Dictionary:
	var scene: Node = (load(SHELLS[id]) as PackedScene).instantiate()
	var hook := HeroAssets.new()
	hook.paint(scene, {"class": ClassDef.by_id(id).color})
	hook.free()
	root.add_child(scene)
	var player := StubPlayer.new()
	root.add_child(player)
	player.abilities.fit(ClassDef.by_id(id))
	var events := GameEvents.new()
	root.add_child(events)
	var anim := ShellAnimator.new()
	scene.add_child(anim)
	var core := scene.find_child("Core", true, false)
	var pod := scene.find_child("Pod", true, false)
	anim.bind([core, pod], id, player, events)
	return {"scene": scene, "player": player, "events": events, "anim": anim, "pod": pod}


static func _run(anim, seconds: float) -> void:
	for i in roundi(seconds * HZ):
		anim.step(DT)


static func _node(rig: Dictionary, node_name: String) -> Node3D:
	return (rig["scene"] as Node).find_child(node_name, true, false) as Node3D


func _check_class(id: String) -> void:
	var rig := _rig(id)
	var anim = rig["anim"]
	var player: StubPlayer = rig["player"]
	var events = rig["events"]
	var names: PackedStringArray = anim.device_names()
	var missing: Array = EXPECT[id]["devices"].filter(func(n): return not (n in names))
	_report(id + " devices", missing.is_empty(), "accent devices found %s (missing %s)" % [names, missing])
	var empty_roles: Array = EXPECT[id]["roles"].filter(func(r): return anim.role_nodes(r).is_empty())
	_report(id + " roles", empty_roles.is_empty(), "every role the shell has parts for is bound (empty %s)" % [empty_roles])
	var frames: Array = []
	_trace[id] = frames

	var pod: Node3D = rig["pod"]
	var eyes := _node(rig, "Eyes")
	var y_min := INF
	var y_max := -INF
	var eye_min := INF
	var glow_min := INF
	var glow_max := -INF
	var fidget_seen := false
	var probe: String = EXPECT[id]["devices"][0]
	_capture(rig, frames, "rest")
	for i in roundi(14.0 * HZ):
		anim.step(DT)
		y_min = minf(y_min, pod.position.y)
		y_max = maxf(y_max, pod.position.y)
		if eyes != null:
			eye_min = minf(eye_min, eyes.scale.y)
		var glow := _energy(rig, probe)
		glow_min = minf(glow_min, glow)
		glow_max = maxf(glow_max, glow)
		fidget_seen = fidget_seen or _fidgeting(rig, id)
		if i == roundi(2.0 * HZ):
			_capture(rig, frames, "breath")
		if fidget_seen and frames.size() < 3 and anim._fidget_left > 0.0 and anim._fidget_left < 0.63 * ShellAnimator.FIDGET_SECONDS:
			_capture(rig, frames, "fidget")
	_report(id + " breath", y_max - y_min > 0.02, "the pod breathes at rest (bob %.3f m)" % (y_max - y_min))
	if eyes != null:
		_report(id + " blink", eye_min < 0.2, "the pilot blinks (eyes to %.2f)" % eye_min)
	_report(id + " fidget", fidget_seen, "the %s fidget plays at rest" % ShellAnimator.FIDGETS[id])
	_report(id + " idle pulse", glow_max - glow_min > 0.1, "accents pulse on the motif at rest (%.2f to %.2f)" % [glow_min, glow_max])

	var steps: Array = ShellAnimator.MOTIFS[id]
	anim.clock = func() -> float: return float(steps[-1][0])
	var peak: float = anim.motif_level()
	anim.clock = func() -> float: return float(steps[-1][0]) + 12.0
	var later: float = anim.motif_level()
	anim.clock = Callable()
	_report(id + " motif", absf(peak - float(steps[-1][1])) < 0.01 and later < 0.1 * peak,
		"the last motif note lights at %.2f on its sixteenth and fades to %.2f" % [peak, later])

	player.drive_basis = Basis(Vector3.UP, 1.0)
	_run(anim, 0.8)
	var head := _node(rig, "Head")
	_report(id + " look", head != null and absf(anim._look_yaw) > 0.5, "the head turns toward the aim (%.2f rad)" % anim._look_yaw)
	_capture(rig, frames, "look")
	player.drive_basis = Basis.IDENTITY

	player.state.velocity = Vector3(12.0, 0.0, 0.0)
	_run(anim, 0.6)
	var facing := -pod.transform.basis.z
	_report(id + " heading", Vector3(facing.x, 0.0, facing.z).normalized().dot(Vector3.RIGHT) > 0.95, "the pod yaws to the heading")
	for i in roundi(0.3 * HZ):
		player.state.velocity = Basis(Vector3.UP, 0.02 * i) * Vector3(12.0, 0.0, 0.0)
		anim.step(DT)
	_report(id + " lean", absf(pod.rotation.z) > 0.02, "the pod leans into the turn (%.3f rad)" % pod.rotation.z)
	_capture(rig, frames, "lean")
	player.state.velocity = Vector3(30.0, 0.0, 0.0)
	_run(anim, 0.8)
	var brace_ok := true
	for part_name in ShellAnimator.BRACE:
		var part := _node(rig, part_name)
		if part != null:
			var want: float = ShellAnimator.BRACE[part_name]
			brace_ok = brace_ok and absf(part.rotation.x - want) < 0.05
	_report(id + " brace", brace_ok, "ears, visor or crest fold back at top speed")
	_capture(rig, frames, "brace")
	player.state.velocity = Vector3.ZERO
	_run(anim, 1.0)

	for slot_name in LIGHTS[id]:
		var lit: String = LIGHTS[id][slot_name][0]
		var dark: String = LIGHTS[id][slot_name][1]
		var slot: AbilityState.Slot = player.abilities.slot(slot_name)
		var gauge: AbilityState.Gauge = player.abilities.gauge(slot_name)
		if gauge != null:
			gauge.begin()
			var levels := PackedFloat32Array()
			for i in 5:
				gauge.step(gauge.charge_max * 0.18, true)
				anim.step(DT)
				levels.append(anim.device_level(lit))
			var rising := true
			for i in range(1, levels.size()):
				rising = rising and levels[i] > levels[i - 1]
			_report(id + " " + slot_name + " gauge", rising and anim.device_level(dark) < ShellAnimator.ACTIVE_GLOW * 0.5,
				"%s glows up with the %s gauge %s while %s stays dark" % [lit, slot_name, levels, dark])
			_capture(rig, frames, "charge")
			gauge.cancel()
		else:
			slot.active = true
			anim.step(DT)
			_report(id + " " + slot_name + " active", anim.device_level(lit) >= ShellAnimator.ACTIVE_GLOW
				and anim.device_level(dark) < ShellAnimator.ACTIVE_GLOW * 0.5,
				"%s lights while %s works (%.2f) and %s stays dark (%.2f)" % [lit, slot_name, anim.device_level(lit), dark, anim.device_level(dark)])
			_capture(rig, frames, "active")
			slot.active = false
		anim.step(DT)
		slot.charges = 0
		slot.max_charges = maxi(1, slot.max_charges)
		anim.step(DT)
		slot.charges = slot.max_charges
		var peak_level := 0.0
		var peak_scale := 1.0
		var lit_node := _node(rig, lit)
		for i in roundi(AbilityBar.PULSE_SECONDS * HZ) + 2:
			anim.step(DT)
			peak_level = maxf(peak_level, anim.device_level(lit))
			if lit_node != null:
				peak_scale = maxf(peak_scale, lit_node.scale.length() / Vector3.ONE.length())
			if i == roundi(AbilityBar.PULSE_SECONDS * HZ * 0.5):
				_capture(rig, frames, "ready")
		_report(id + " " + slot_name + " ready", peak_level > ShellAnimator.PULSE_GLOW * 0.9 and peak_scale > 1.08,
			"ready-again pulses %s once (glow %.2f, swell %.3f)" % [lit, peak_level, peak_scale])
		_run(anim, 0.3)

	var pilot := _node(rig, "Pilot")
	var pilot_rest := pilot.position.y
	events.landed.emit(20.0)
	var dip := 0.0
	for i in 20:
		anim.step(DT)
		dip = minf(dip, pilot.position.y - pilot_rest)
		if i == 6:
			_capture(rig, frames, "land")
	_report(id + " land", dip < -0.01, "the pilot settles on a landing (%.3f m)" % dip)
	_run(anim, 0.6)
	events.player_hit.emit(10.0, "test")
	var glint := 0.0
	var shut := 1.0
	for i in 16:
		anim.step(DT)
		glint = maxf(glint, anim._glass_mats[0].emission_energy_multiplier if not anim._glass_mats.is_empty() else 0.0)
		if eyes != null:
			shut = minf(shut, eyes.scale.y)
		if i == 12:
			_capture(rig, frames, "hit")
	_report(id + " hit", glint > 1.0 and (eyes == null or shut < 0.5), "the pilot flinches and the dome glints (%.2f)" % glint)
	_run(anim, 0.5)
	events.beacon_unsealed.emit(1)
	var hop := 0.0
	for i in roundi(ShellAnimator.CHEER_SECONDS * HZ):
		anim.step(DT)
		hop = maxf(hop, pilot.position.y - pilot_rest)
		if i == roundi(ShellAnimator.CHEER_SECONDS * HZ * 0.37):
			_capture(rig, frames, "cheer")
	_report(id + " cheer", hop > 0.03, "the pilot cheers on a Warden break (hop %.3f m)" % hop)

	_check_kit(rig, id)
	for node in [rig["scene"], rig["player"], rig["events"]]:
		root.remove_child(node)
		node.free()


func _check_kit(rig: Dictionary, id: String) -> void:
	var anim = rig["anim"]
	var player: StubPlayer = rig["player"]
	match id:
		"pylon_engineer":
			var spool := _node(rig, "Spool")
			var before := spool.basis
			player.kit.hooked = true
			_run(anim, 0.3)
			_report(id + " spool", not spool.basis.is_equal_approx(before), "the rope spool spins on the grapple")
			player.kit.hooked = false
			player.kit.mounted = true
			_run(anim, 0.2)
			_report(id + " crackle", anim.device_level("Accent_special_smash") > 0.1, "collar and mast crackle on the pylon")
			player.kit.mounted = false
		"runner_gunner":
			var stack := _node(rig, "StackL")
			var rest := stack.scale.y
			(rig["events"] as Node).boosted.emit(Vector3.FORWARD)
			var puff := 0.0
			for i in 20:
				anim.step(DT)
				puff = maxf(puff, stack.scale.y / rest)
			_report(id + " stacks", puff > 1.2, "the exhaust stacks puff on a boost (x%.2f)" % puff)
		"demolitions_caster":
			var mortar := _node(rig, "Mortar")
			var rest := mortar.position
			(rig["events"] as Node).shot_fired.emit("sticky_charge", Vector3.ZERO, Vector3.FORWARD)
			anim.step(DT)
			_report(id + " recoil", mortar.position.distance_to(rest) > 0.03, "the mortar kicks on a throw")
			player.kit.gliding = true
			player.state.velocity = Vector3(0.0, 0.0, -20.0)
			_run(anim, 1.0)
			var vane := _node(rig, "VaneL")
			_report(id + " vane", absf(vane.rotation.z - PI * 0.5) < 0.1, "the vane opens and flutters while gliding")
			player.kit.gliding = false
			player.kit.cloaked = true
			anim.step(DT)
			var pod := rig["pod"] as GeometryInstance3D
			_report(id + " cloak", pod.transparency > 0.1, "the shell shimmers while cloaked (%.2f)" % pod.transparency)
			player.kit.cloaked = false


# A redesigned shell with only a Ring and one accent still animates.
func _check_rings() -> void:
	var shell := Node3D.new()
	var ring := MeshInstance3D.new()
	ring.name = "Ring0"
	ring.mesh = _lit_mesh()
	shell.add_child(ring)
	var accent := MeshInstance3D.new()
	accent.name = "Accent_weapon"
	accent.mesh = _lit_mesh()
	shell.add_child(accent)
	root.add_child(shell)
	var player := StubPlayer.new()
	root.add_child(player)
	player.abilities.fit(ClassDef.by_id("pylon_engineer"))
	var anim := ShellAnimator.new()
	shell.add_child(anim)
	anim.bind([shell], "pylon_engineer", player)
	player.state.velocity = Vector3(25.0, 0.0, 0.0)
	var before := ring.basis
	_run(anim, 0.5)
	_report("ring spin", not ring.basis.is_equal_approx(before), "a Ring spins with speed")
	var slot: AbilityState.Slot = player.abilities.slot("weapon")
	slot.charges = 0
	anim.step(DT)
	slot.charges = slot.max_charges
	var flash := 0.0
	for i in 12:
		anim.step(DT)
		flash = maxf(flash, (ring.get_surface_override_material(0) as StandardMaterial3D).emission_energy_multiplier)
	_report("ring ready", flash > ShellAnimator.PULSE_GLOW * 0.9, "a Ring flashes on ready-again (%.2f)" % flash)
	for node in [shell, player]:
		root.remove_child(node)
		node.free()


# A shell with none of the parts binds and runs at 90 Hz without errors.
func _check_bare() -> void:
	var shell := Node3D.new()
	root.add_child(shell)
	var player := StubPlayer.new()
	root.add_child(player)
	var anim := ShellAnimator.new()
	shell.add_child(anim)
	anim.bind([shell], "unknown_class", player)
	_run(anim, 2.0)
	_report("bare shell", anim.device_names().is_empty(), "a shell with no parts runs 180 steps quietly")
	for node in [shell, player]:
		root.remove_child(node)
		node.free()


static func _lit_mesh() -> ArrayMesh:
	var box := BoxMesh.new()
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, box.get_mesh_arrays())
	var mat := StandardMaterial3D.new()
	mat.resource_name = "class_accent"
	mat.emission_enabled = true
	mat.emission_energy_multiplier = 0.5
	mesh.surface_set_material(0, mat)
	return mesh


func _energy(rig: Dictionary, device: String) -> float:
	var node := _node(rig, device) as MeshInstance3D
	if node == null:
		return 0.0
	for i in node.mesh.get_surface_count():
		var mat := node.get_surface_override_material(i) as StandardMaterial3D
		if mat != null and mat.emission_enabled:
			return mat.emission_energy_multiplier
	return 0.0


func _fidgeting(rig: Dictionary, id: String) -> bool:
	match id:
		"pylon_engineer":
			var ear := _node(rig, "EarL")
			if ear == null or rig["anim"]._fidget_left <= 0.0:
				return false
			var rest: Transform3D = rig["anim"]._rest[ear]
			return absf(ear.rotation.z - rest.basis.get_euler().z) > 0.2
		"runner_gunner":
			var paw := _node(rig, "PawR")
			return paw != null and rig["anim"]._fidget_left > 0.0 and rig["anim"]._fidget_left < 0.6
		"demolitions_caster":
			var crest := _node(rig, "Crest")
			return crest != null and crest.scale.x > 1.05
	return false


# One posed frame: every named node's local transform under the shell, and each lit
# material's energy, for preview_anim.py.
func _capture(rig: Dictionary, frames: Array, label: String) -> void:
	var nodes := {}
	var stack: Array[Node] = [rig["scene"]]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node is Node3D and node != rig["scene"]:
			var t := (node as Node3D).transform
			nodes[String(node.name)] = [t.basis.x.x, t.basis.x.y, t.basis.x.z, t.basis.y.x, t.basis.y.y, t.basis.y.z,
				t.basis.z.x, t.basis.z.y, t.basis.z.z, t.origin.x, t.origin.y, t.origin.z]
	var glow := {}
	for device_name in rig["anim"].device_names():
		glow[device_name] = _energy(rig, device_name)
	var glass: Array = rig["anim"]._glass_mats
	var pod := rig["pod"] as GeometryInstance3D
	frames.append({"label": label, "nodes": nodes, "glow": glow,
		"glint": glass[0].emission_energy_multiplier if not glass.is_empty() else 0.0,
		"shimmer": pod.transparency if pod != null else 0.0})
