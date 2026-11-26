extends Node

const Combat := preload("res://src/combat/combat.gd")
const Rogue := preload("res://src/combat/rogue.gd")
const Fleet := preload("res://src/combat/fleet.gd")
const Roster := preload("res://src/combat/roster.gd")
const EliteAffixes := preload("res://src/combat/elite_affixes.gd")

const RING_MIN := 9.0
const RING_STEP := 2.2
const AHEAD := 14.0
const BIG_CLEARANCE := 3.6
const MOB_CLEARANCE := 2.4
const BIG_KINDS := ["miniboss", "warden", "vault"]
const MAX_COUNT := 40
const TIME_MIN := 0.0
const TIME_MAX := 4.0
const TIME_FLOOR := 0.05

var game
var god := false
var _time_scale := 1.0
var _frozen := false
var _held_hook := Callable()
var _spawned := 0


func setup(game_ref) -> void:
	game = game_ref
	name = "DevFight"
	process_mode = Node.PROCESS_MODE_ALWAYS


func ctx():
	return game.ctx


func kinds(world := 0) -> Array[String]:
	var found: Array[String] = []
	for kind in Combat.KINDS + Rogue.ROWS.keys() + Fleet.SCRIPTS.keys() + Roster.ROWS.keys():
		if kind in found:
			continue
		if Roster.has(kind) and not Fleet.SCRIPTS.has(kind) and not kind in Combat.KINDS and not Rogue.ROWS.has(kind):
			if not Roster.row(kind).has("script") or not Roster.built(kind):
				continue
		if world == 0 or world_of(kind) in [0, world]:
			found.append(kind)
	return found


func world_of(kind: String) -> int:
	if Rogue.ROWS.has(kind):
		return int(Rogue.ROWS[kind].get("world", 0))
	return int(Roster.row(kind).get("world", 0))


func label(kind: String) -> String:
	if Rogue.ROWS.has(kind):
		return String(Rogue.ROWS[kind].name)
	var named := Roster.name_of(kind) if Roster.has(kind) else ""
	return named if named != "" else kind.replace("_", " ")


func spawn(kind: String, count := 1, affix := "") -> String:
	var c = ctx()
	if c == null or c.spawner == null or c.terrain == null:
		return "!no fight running yet: start a run first"
	if not game.flow.in_play():
		return "!spawn works during a run, not on the %s screen" % game.flow.state_name()
	if not (kind in Combat.KINDS or Rogue.ROWS.has(kind) or c.spawner.fleet.makes(kind)):
		var near := kinds().filter(func(k: String): return k.begins_with(kind))
		if near.size() != 1:
			return "!no enemy '%s'%s" % [kind, (" (did you mean %s?)" % ", ".join(near.slice(0, 5))) if not near.is_empty() else ""]
		kind = near[0]
	if affix != "" and not affix in EliteAffixes.IDS and affix != EliteAffixes.PLATED:
		return "!no affix '%s' (%s, %s)" % [affix, ", ".join(EliteAffixes.IDS), EliteAffixes.PLATED]
	count = clampi(count, 1, MAX_COUNT)
	var ball: Vector3 = c.player.ball_position()
	var forward: Vector3 = -game.camera.yaw_basis().z
	var centre := ball + Vector3(forward.x, 0.0, forward.z).normalized() * AHEAD
	var clearance := BIG_CLEARANCE if kind in BIG_KINDS else MOB_CLEARANCE
	for i in count:
		var at := centre
		if count > 1:
			var angle := TAU * float(i) / float(count)
			var radius := RING_MIN * 0.5 + RING_STEP * sqrt(float(count))
			at += Vector3(cos(angle), 0.0, sin(angle)) * radius
		var dropped: Vector3 = c.terrain.drop_point(at.x, at.z, clearance)
		c.spawner.spawn_enemy(kind, dropped, affix)
		_spawned += 1
	return "spawned %d %s%s ahead of the ball" % [count, label(kind), (" [%s]" % affix) if affix != "" else ""]


func living() -> Array:
	return game.get_tree().get_nodes_in_group("enemy").filter(func(e): return is_instance_valid(e) and not e.is_queued_for_deletion())


func clear(hard := false) -> String:
	var killed := 0
	var held := 0
	for enemy in living():
		if enemy.has_method("take_damage") and "hp" in enemy:
			enemy.take_damage(float(enemy.hp) + 1.0)
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and "hp" in enemy and float(enemy.hp) > 0.0:
			if hard:
				enemy.queue_free()
				killed += 1
			else:
				held += 1
		else:
			killed += 1
	if held > 0:
		return "cleared %d; %d posture-gated (Warden, boss parts) still standing: 'clear hard' removes them without credit" % [killed, held]
	return "cleared %d enemies" % killed


func set_god(on: bool) -> String:
	var c = ctx()
	if c == null or c.run == null:
		return "!no run state yet"
	if on and not god:
		_held_hook = c.run.defend_hook
		c.run.defend_hook = func(_amount: float, _hp: float) -> float: return 0.0
	elif not on and god:
		c.run.defend_hook = _held_hook
		_held_hook = Callable()
	god = on
	if on:
		c.run.heal(c.run.max_hp)
	return "god mode %s" % ("on: hull refills and hits deal nothing" if on else "off")


func heal() -> String:
	var c = ctx()
	if c == null or c.run == null:
		return "!no run state yet"
	c.run.heal(c.run.max_hp)
	return "hull %d / %d" % [int(c.run.hp), int(c.run.max_hp)]


func scrap(amount: int) -> String:
	var c = ctx()
	if c == null or c.run == null or c.player == null:
		return "!no run state yet"
	c.run.add_scrap(amount, c.player.ball_position())
	return "scrap +%d (now %d)" % [amount, c.run.scrap]


func cogs(amount: int) -> String:
	var c = ctx()
	if c == null or c.run == null:
		return "!no run state yet"
	c.run.add_cogs(amount)
	return "cogs +%d" % amount


func set_calm(on: bool) -> String:
	var c = ctx()
	if c == null:
		return "!no context yet"
	c.calm = on
	return "calm %s" % ("on: no packs, no Warden, no flood or event push" if on else "off: the director runs again")


func set_time(scale: float) -> String:
	scale = clampf(scale, TIME_MIN, TIME_MAX)
	var freeze := scale < TIME_FLOOR
	if freeze != _frozen:
		_frozen = freeze
		game.freeze_for_dev(freeze)
	if _frozen:
		return "time frozen: photo mode (the dev camera and looks still move; 'time 1' resumes)"
	_time_scale = scale
	Engine.time_scale = _time_scale
	return "time x%.2f" % _time_scale


func _process(_delta: float) -> void:
	if _frozen and not get_tree().paused:
		game.freeze_for_dev(true)


func toggle_freeze() -> String:
	return set_time(1.0 if _frozen else 0.0)


func time_scale() -> float:
	return _time_scale


func frozen() -> bool:
	return _frozen


func boss(phase := 0) -> String:
	var c = ctx()
	if c == null or game.flow == null:
		return "!no flow yet"
	if not game.flow.in_play():
		return "!start a run first"
	if phase > 0:
		if c.boss == null or not c.boss.has_method("jump_to_phase") or not c.boss.active():
			return "!no boss is awake: 'boss' enters the arena first"
		c.boss.jump_to_phase(phase)
		return "boss phase %d%s" % [phase, " (4 ejects: the defeat path)" if phase >= 4 else ""]
	if c.stages.BOSS == "":
		return "!this stage table has no boss"
	game.flow.enter_boss(Vector3.ZERO)
	return "into the boss arena of this world"


func summary() -> String:
	var c = ctx()
	var alive := living().size()
	var hull := "%d/%d" % [int(c.run.hp), int(c.run.max_hp)] if c != null and c.run != null else "-"
	return "enemies %d  hull %s  god %s  calm %s  time x%.2f" % [alive, hull, "on" if god else "off",
		"on" if c != null and c.calm else "off", _time_scale]


func _physics_process(_delta: float) -> void:
	if god and ctx() != null and ctx().run != null and ctx().run.alive():
		ctx().run.heal(ctx().run.max_hp)
	if not _frozen and not is_equal_approx(_time_scale, 1.0) and not is_equal_approx(Engine.time_scale, _time_scale):
		Engine.time_scale = _time_scale
