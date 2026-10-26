extends SceneTree
# F6 2026-10-04: the W05 magnet row is gone; the Warden warns once.

# Rule: every roster kind has a valid wind-up row whose lead is its own attack's
# phase length. Presentation reads that row from the real phase publication/state.
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Roster := preload("res://src/combat/roster.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const WindupRows := preload("res://src/presentation/windup_rows.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const Rogue := preload("res://src/combat/rogue.gd")

var _game
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _expected(enemy, attack: String) -> float:
	match String(enemy.kind):
		"vault", "linker", "foreman": return 0.0
		"chaser": return enemy.WINDUP
		"lobber": return enemy.TELEGRAPH
		"miniboss": return enemy.slam_crouch + enemy.SLAM_LEAP if attack == "E03" else enemy.charge_brace
		"warden": return enemy.PULSE_TELEGRAPH
		"swarm_remnant": return enemy.swarm.LOCK_WARN
		"rogue_crane", "rogue_skip", "rogue_tender":
			return enemy.wind_lane if EventKinds.attack_threat(attack) == "threat_lane" else enemy.wind_ring
	return enemy.warn_seconds


func _walk() -> void:
	# 2026-10-23: the three rogue fleet machines (combat/rogue.gd) carry rows beside the roster's.
	var kinds: Array = Roster.ROWS.keys() + Rogue.ROWS.keys()
	_report("total roster", WindupRows.ROWS.size() == kinds.size(), "%d roster and rogue kinds, %d rows" % [kinds.size(), WindupRows.ROWS.size()])
	for kind in kinds:
		var present := WindupRows.ROWS.has(kind)
		_report("row " + kind, present, "every roster kind is explicit")
		if not present:
			continue
		var spec: Dictionary = WindupRows.ROWS[kind]
		_report("vocab " + kind, spec.color_role in EventKinds.COLOR_ROLES and spec.shape in EventKinds.SHAPES
			and (spec.sound == EventKinds.NONE or SfxBank.has_recipe(spec.sound)), "colour, shape and sound use the existing vocabularies")
		# A declared kind without its script yet cannot spawn; its attacks are reserved ids.
		if not Roster.built(kind):
			_reserved(kind, spec)
			continue
		var enemy = _game.combat.spawn_enemy(kind, _game.ctx.terrain.drop_point(-70.0, -70.0, 2.0))
		_report("spawn " + kind, enemy != null and enemy.kind == kind, "a built kind spawns as itself")
		if enemy == null:
			continue
		enemy.set_physics_process(false)
		for attack in spec.attacks:
			var cue := WindupRows.row(kind, enemy, attack)
			_report("resolved " + attack, not cue.is_empty(), kind)
			if cue.is_empty():
				continue
			var expected := _expected(enemy, attack)
			_report("lead " + attack, is_equal_approx(cue.lead_seconds, expected), "row %.3f s, enemy %.3f s" % [cue.lead_seconds, expected])
			_report("cue " + attack, cue.color_role in EventKinds.COLOR_ROLES and cue.shape in EventKinds.SHAPES
				and (cue.sound == EventKinds.NONE or SfxBank.has_recipe(cue.sound)), "resolved cue has a valid role, shape and bank id")
			if attack == EventKinds.NONE:
				_report("non-attacker", kind in ["vault", "linker", "foreman"] and cue.phase == "none" and cue.shape == "none" and cue.sound == "none",
					"%s explicitly has no attack" % kind)
			else:
				_report("attack " + attack, EventKinds.has_attack(attack) and cue.phase == "windup" and cue.color_role == "hazard"
					and cue.shape == EventKinds.attack_glyph(attack) and expected > 0.0, "existing attack glyph, hazard role and positive enemy timing")
		for attack in EventKinds.ATTACK_ROWS:
			var attack_row: Dictionary = EventKinds.ATTACK_ROWS[attack]
			if attack_row.owner_kind in ["roster", "rogue"] and attack_row.owner == kind:
				_report("coverage " + attack, spec.attacks.has(attack), "every attack owned by this roster kind is mapped")
		if kind == "swarm_remnant":
			for drone in enemy.swarm.alive():
				drone.set_physics_process(false)
		# Leave the rack intact until all its checks have finished, then remove it.
		if kind == "swarm_remnant":
			for drone in enemy.swarm.alive():
				drone.free()
		else:
			enemy.free()


# An unbuilt kind's reserved attack ids: each is its own, its ATTACK_ROWS row is owned by
# this kind (2026-10-04, alpha wave 8: the rows are declared ahead of the scripts), and the
# row's glyph is the wind-up shape the built kind will draw.
func _reserved(kind: String, spec: Dictionary) -> void:
	for attack in spec.attacks:
		var holders: Array = []
		for other in WindupRows.ROWS:
			if WindupRows.ROWS[other].attacks.has(attack):
				holders.append(other)
		var row := EventKinds.attack_row(attack)
		_report("reserved " + attack, holders == [kind] and row.get("owner_kind", "") == "roster" and row.get("owner", "") == kind
			and spec.shape == EventKinds.attack_glyph(attack), "%s reserves it; held by %s, owner %s" % [kind, holders, row.get("owner", "")])


func _glyphs() -> int:
	return int(_game.presentation.vfx.spawned.get("enemy_spawned", 0))


func _latest_glyph() -> Dictionary:
	for glyph in _game.presentation.vfx._glyphs:
		if glyph.t == 0.0:
			return glyph
	return {}


func _signal_path() -> void:
	var enemy = _game.combat.spawn_enemy("chaser", _game.ctx.terrain.drop_point(-70.0, -70.0, 2.0))
	var before := _glyphs()
	enemy._begin_windup(Vector3.FORWARD)
	var glyph := _latest_glyph()
	_report("real phase read", _glyphs() == before + 1 and not glyph.is_empty(), "Chaser's real windup publication draws one cue synchronously")
	if not glyph.is_empty():
		_report("row drives glyph", glyph.color == EventKinds.role_color("hazard") and is_equal_approx(glyph.life, enemy.WINDUP)
			and glyph.node.mesh == _game.presentation.vfx._meshes.bar, "row colour, bar shape and enemy lead reach Vfx.glyph")
	_game.presentation._read_windups(enemy)
	_report("idempotent subscription", _glyphs() == before + 1, "binding an already wired actor does not replay its windup")
	enemy._end_attack(enemy.State.RECOVER)
	_report("recovery is silent", _glyphs() == before + 1, "other attack phases do not start cues")
	enemy.free()
	_game.presentation.vfx.clear()
	var lobber = _game.combat.spawn_enemy("lobber", _game.ctx.terrain.drop_point(-70.0, -70.0, 2.0))
	before = _glyphs()
	_game.presentation.audio.cue_log.clear()
	lobber._facts_begin_lobber(0.5)
	glyph = _latest_glyph()
	_report("uncommitted lobber read", _glyphs() == before + 1 and is_equal_approx(glyph.get("life", 0.0), lobber.TELEGRAPH * 0.5), "charge progress shortens the row's lead without committing aim")
	var heard := false
	for cue in _game.presentation.audio.cue_log:
		heard = heard or cue[1] == "threat_whistle"
	_report("row drives sound", heard, "Lobber's early warning reaches the existing audio cue path")
	lobber.free()


func _state_path() -> void:
	var warden = _game.combat.spawn_enemy("warden", _game.ctx.terrain.drop_point(-70.0, -70.0, 2.0))
	warden.set_physics_process(false)
	warden.family = "mind"
	warden._charging = true
	warden._charge_time = 0.0
	var facts := WindupRows.state_facts(warden)
	_report("warden pulse warning", facts.size() == 1 and facts[0].row == "W04", "the pulse is the Warden's one wind-up read")
	var before := _glyphs()
	_game.presentation._physics_process(0.0)
	_game.presentation._physics_process(0.0)
	_report("state entry only", _glyphs() == before + 1, "the warning draws once across repeated state reads")
	warden._charging = false
	_game.presentation._physics_process(0.0)
	warden._charging = true
	_game.presentation._physics_process(0.0)
	_report("state re-entry", _glyphs() == before + 2, "a later pulse warns again")
	warden.free()
	var drone = _game.combat.spawn_enemy("swarm_remnant", _game.ctx.terrain.drop_point(-70.0, -70.0, 2.0))
	var swarm = drone.swarm
	for member in swarm.alive():
		member.set_physics_process(false)
	before = _glyphs()
	swarm._lock(drone.global_position + Vector3.FORWARD * 10.0)
	_game.presentation._physics_process(0.0)
	_game.presentation._physics_process(0.0)
	_report("one cue per formation", _glyphs() == before + 1, "the shared rack warning draws only on the lane owner")
	for member in swarm.alive():
		member.free()


func _run() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.player.set_frozen(true)
	await physics_frame
	for enemy in get_nodes_in_group("enemy"):
		enemy.free()
	_walk()
	_signal_path()
	_state_path()
	_game.free()
	print("windup_rows_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
