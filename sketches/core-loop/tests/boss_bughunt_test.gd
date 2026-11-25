extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const Requisition := preload("res://src/boss/requisition.gd")
const BossModel := preload("res://src/boss/boss_model.gd")
const Rules := preload("res://src/boss/boss_rules.gd")
const BossPosture := preload("res://src/combat/boss_posture.gd")
const T := preload("res://tests/support/t.gd")


class MemoryStore extends RefCounted:
	var refusal := ""
	var last_error := ""
	var cleared := false

	func clear() -> bool:
		cleared = true
		return true

# The wave 12 boss bug hunt (BUGFIX-BOSS, 2026-10-09), one check per confirmed finding:
# scrap a magnet still holds when phase 1 ends is paid back as returned pickups (F001);
# an idle magnet rests under its pivot and above the ground (F002); a crane cable off the
# world Z axis spans the real distance without shear (F004); the magnet's signal glow keeps
# the vertex-coloured material load_scene laid over the M4 surface (F005); and track
# stripping and the side-player split both reach a node directly under the clip root
# (F007, F008), never a sibling whose name only ends the same way.

const DT := 1.0 / 90.0

var _t := T.new("boss_bughunt_test")
var _game
var _boss
var _started := false


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null or _started:
		return false
	_started = true
	Harness.install(_game)
	_boss = _game.boss
	_game.ctx.calm = false
	_game.player.source = Intent.Scripted.new()
	Harness.start_run(_game)
	Harness.enter(_game, Vector3(18.0, 0.0, 0.0))
	_magnet_rest_check()
	_cable_check()
	_signal_glow_check()
	_bare_hull_crane_damage_check()
	_held_at_phase_end_check()
	_root_track_checks()
	_crane_kill_teardown_check()
	_game.free()
	quit(_t.verdict())
	return false


func _magnet_rest_check() -> void:
	var ship = _boss.ship
	for i in Requisition.CRANE_PIVOTS.size():
		var rest: Vector3 = ship.magnet_rest(i)
		var local: Vector3 = ship.to_local(rest)
		var pivot: Vector3 = Requisition.CRANE_PIVOTS[i]
		var ground: float = _boss.arena.ground(rest)
		_t.check("F002 magnet %d rests under its pivot, above the ground" % i,
			local.y > 0.0 and local.y < pivot.y and rest.y > ground,
			"local y %.2f (pivot %.2f), world y %.2f over ground %.2f" % [local.y, pivot.y, rest.y, ground])


func _cable_check() -> void:
	var ship = _boss.ship
	var from: Vector3 = ship.pivot(0)
	for span in [Vector3(6.0, -2.0, 0.0), Vector3(-3.0, -4.0, 5.0), Vector3(0.0, -3.0, 7.0)]:
		ship.set_magnet(0, from + span, 0.0)
		var cable: MeshInstance3D = ship._cables[0]
		var basis: Basis = cable.global_transform.basis
		var along: Vector3 = basis.z
		_t.check("F004 cable spans %s at its length, unsheared" % [span],
			absf(along.length() - span.length()) < 0.01 and absf(basis.x.length() - 1.0) < 0.01 and absf(basis.y.length() - 1.0) < 0.01
				and absf(absf(along.normalized().dot(span.normalized())) - 1.0) < 0.001,
			"z %.3f (span %.3f), x %.3f, y %.3f, alignment %.4f"
				% [along.length(), span.length(), basis.x.length(), basis.y.length(), along.normalized().dot(span.normalized())])


func _signal_glow_check() -> void:
	var scene := BossModel.load_scene(Requisition.MODEL)
	if not _t.check("F005 Brindle model loads", scene != null, "path %s" % Requisition.MODEL):
		return
	for part in ["MagnetPort", "MagnetStarboard"]:
		var mesh := scene.find_child(part, true, false) as MeshInstance3D
		var surface := -1
		for i in mesh.mesh.get_surface_count():
			var material := mesh.mesh.surface_get_material(i)
			if material is StandardMaterial3D and material.resource_name.begins_with("M4"):
				surface = i
		if not _t.check("F005 %s has an M4 surface" % part, surface >= 0, "surface %d" % surface):
			continue
		var raw := mesh.mesh.surface_get_material(surface) as BaseMaterial3D
		var laid := mesh.get_surface_override_material(surface) as BaseMaterial3D
		var drawn: bool = (laid if laid != null else raw).vertex_color_use_as_albedo
		BossModel.signal_glow(mesh, Color.RED, 2.0)
		var after := mesh.get_surface_override_material(surface) as StandardMaterial3D
		_t.check("F005 %s signal glow keeps the vertex colours load_scene drew" % part,
			drawn and after != null and after.vertex_color_use_as_albedo and after.emission_enabled,
			"raw %s vertex colours %s, load_scene override %s, after glow vertex colours %s, emission %s"
				% [raw.resource_name, raw.vertex_color_use_as_albedo, laid != null, after.vertex_color_use_as_albedo, after.emission_enabled])
	scene.free()
	# The shipped GLB's M4 surface is already vertex-coloured, so the case load_scene exists
	# for is built here: an M4 surface imported white, overridden the way load_scene does.
	var scratch := MeshInstance3D.new()
	var mesh := ArrayMesh.new()
	var arrays := BoxMesh.new().get_mesh_arrays()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var white := StandardMaterial3D.new()
	white.resource_name = "M4_signal_surface"
	mesh.surface_set_material(0, white)
	scratch.mesh = mesh
	scratch.set_surface_override_material(0, BossModel._vertex_coloured(white))
	BossModel.signal_glow(scratch, Color.RED, 2.0)
	var lit := scratch.get_surface_override_material(0) as StandardMaterial3D
	_t.check("F005 signal glow on a white-imported M4 surface keeps load_scene's vertex colours",
		lit.vertex_color_use_as_albedo and lit.emission_enabled and lit != white,
		"vertex colours %s, emission %s" % [lit.vertex_color_use_as_albedo, lit.emission_enabled])
	scratch.free()


func _held_at_phase_end_check() -> void:
	if not _t.eq("F001 fight opens in phase 1", _boss.phase, 1):
		return
	_game.run.mass = 100.0
	_game.run.scrap = 100
	var ball: Vector3 = Harness.ground_spot(_boss, 0.0, 20.0)
	Harness.put_ball(_game, ball)
	_boss._commit_crane(0, ball)
	_boss._crane_catch(0, ball, ball)
	var held: int = _boss._cranes[0].get("held", 0)
	if not _t.check("F001 the magnet holds stolen scrap", held > 0, "held %d" % held):
		return
	_boss._drip(_boss._cranes[0])
	var returned_before := _returned()
	_boss.jump_to_phase(2)
	var left: int = _boss._cranes[0].get("held", 0)
	var paid := _returned() - returned_before
	_t.check("F001 scrap still held when phase 1 ends is paid back", left == 0 and paid == held - _boss._cranes[0]["values"][0],
		"held %d, first drip %d, paid at the phase end %d, still held %d" % [held, _boss._cranes[0]["values"][0], paid, left])


func _returned() -> int:
	var total := 0
	for p in _boss._pickups:
		if p["source"] == "returned":
			total += int(p["value"])
	return total


# A scratch clip under a scratch root: "Cap0" sits directly under the root, "Hull/Cap0"
# one level down, and "OtherCap0" only shares the name's ending.
func _scratch_player() -> AnimationPlayer:
	var holder := Node3D.new()
	root.add_child(holder)
	var player := AnimationPlayer.new()
	holder.add_child(player)
	var clip := Animation.new()
	clip.length = 1.0
	for path in ["Cap0:position", "Hull/Cap0:rotation", "OtherCap0:position"]:
		var t := clip.add_track(Animation.TYPE_VALUE)
		clip.track_set_path(t, NodePath(path))
	var library := AnimationLibrary.new()
	library.add_animation("lift", clip)
	player.add_animation_library("", library)
	return player


func _paths(clip: Animation) -> Array:
	var out: Array = []
	for t in clip.get_track_count():
		out.append(String(clip.track_get_path(t)))
	return out


func _root_track_checks() -> void:
	var stripped := _scratch_player()
	BossModel.strip_tracks(stripped, "Cap0")
	_t.eq("F007 strip_tracks reaches a root-level node", _paths(stripped.get_animation("lift")), ["OtherCap0:position"])
	var split := _scratch_player()
	var side := BossModel.split_player(split, ["lift"], ["Cap0"])
	_t.eq("F008 split_player moves a root-level node's tracks", _paths(side.get_animation("lift")), ["Cap0:position", "Hull/Cap0:rotation"])
	_t.eq("F008 split_player leaves the rest on the main player", _paths(split.get_animation("lift")), ["OtherCap0:position"])
	stripped.get_parent().free()
	split.get_parent().free()


func _bare_hull_crane_damage_check() -> void:
	if not _t.eq("W46-S1 bare-hull check starts in phase 1", _boss.phase, 1):
		return
	var ball: Vector3 = Harness.ground_spot(_boss, 0.0, 20.0)
	Harness.put_ball(_game, ball, Vector3.ZERO)
	_game.run.mass = 0.0
	_game.run.scrap = 0
	_game.run.hp = _game.run.max_hp
	var expected: float = ChallengeDials.damage("brindle", Rules.CRANE_DAMAGE, 1)
	_boss._commit_crane(0, ball)
	_boss._crane_catch(0, ball, ball)
	var lost_normal: float = _game.run.max_hp - _game.run.hp
	_t.check("W46-S1 phase 1 crane catch at mass 0 deals CRANE_DAMAGE when not reeling",
		is_equal_approx(lost_normal, expected) and _boss._cranes[0].get("held", 0) == 0,
		"lost %.2f (expected %.2f), held %d" % [lost_normal, expected, _boss._cranes[0].get("held", 0)])
	_game.run.hp = _game.run.max_hp
	_game.run.mass = 0.0
	_boss._posture.chunks = BossPosture.CHUNKS - 1
	var was_reeling: bool = _boss.reeling()
	_boss._commit_crane(1, ball)
	_boss._crane_catch(1, ball, ball)
	var lost_reeling: float = _game.run.max_hp - _game.run.hp
	_t.check("W46-S1 phase 1 crane catch at mass 0 deals 0 damage while reeling",
		was_reeling and is_equal_approx(lost_reeling, 0.0) and _boss._cranes[1].get("held", 0) == 0,
		"reeling %s, lost %.2f, held %d" % [was_reeling, lost_reeling, _boss._cranes[1].get("held", 0)])
	_boss.jump_to_phase(1)
	_game.run.hp = _game.run.max_hp


func _crane_kill_teardown_check() -> void:
	_boss.jump_to_phase(1)
	var store := MemoryStore.new()
	_game.flow.store = store
	_boss._next_attack = _boss.clock + 100.0
	var pivot: Vector3 = _boss.ship.pivot(0)
	var raw := Vector3(pivot.x + 10.0, 0.0, pivot.z)
	var ball := Vector3(raw.x, _boss.arena.ground(raw) + 1.0, raw.z)
	Harness.put_ball(_game, ball, Vector3.ZERO)
	_game.run.mass = 0.0
	_game.run.scrap = 0
	_game.run.hp = 1.0
	var committed: bool = _boss._commit_crane(0, ball)
	var h = _boss._cranes[0].get("hazard")
	if h != null:
		h.step(h.warn_seconds)
		h.step(h.live_seconds * 0.5)
	_boss._step_cranes(DT, ball)
	_t.check("W46-S1 killing phase 1 crane hit inside _step_cranes tears down cleanly with store != null",
		committed and not _game.flow.in_play() and _game.flow.state_name() == "summary"
			and _boss.ship == null and _boss.arena == null and _boss.state_name() == "idle"
			and store.cleared and _game.run.hp <= 0.0,
		"committed %s, flow %s (in_play %s), ship null %s, arena null %s, boss %s, cleared %s, hp %.2f"
			% [committed, _game.flow.state_name(), _game.flow.in_play(), _boss.ship == null,
				_boss.arena == null, _boss.state_name(), store.cleared, _game.run.hp])
	_game.flow.store = null
