extends Node

const Combat := preload("res://src/combat/combat.gd")
const EliteAffixes := preload("res://src/combat/elite_affixes.gd")
const DevCommands := preload("res://src/dev/dev_commands.gd")
const Parts := preload("res://src/build/parts.gd")
const Panels := preload("res://src/build/panels.gd")
const Relics := preload("res://src/build/relics.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const FloodCycle := preload("res://src/world/flood_cycle.gd")

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
const STAGE_ALIASES := {"dam": 1, "flume": 2, "pit": 3, "sinkhole": 4, "islands": 5, "crown": 6}

var game
var god := false
var _time_scale := 1.0
var _frozen := false
var _stepping := false
var _phys_steps := 0
var _spawned := 0


func setup(game_ref) -> void:
	game = game_ref
	name = "DevFight"
	process_mode = Node.PROCESS_MODE_ALWAYS


func _exit_tree() -> void:
	if _frozen and is_instance_valid(game):
		game.freeze_for_dev(false)
	_frozen = false
	_stepping = false
	Engine.time_scale = 1.0
	if god and is_instance_valid(game) and ctx() != null and ctx().run != null:
		set_god(false)


func ctx():
	return game.ctx if is_instance_valid(game) else null


func kinds(world := 0) -> Array[String]:
	return Combat.spawnable_kinds(world)


func label(kind: String) -> String:
	return Combat.kind_label(kind)


func spawn(kind: String, count := 1, affix := "") -> String:
	var c = ctx()
	if c == null or c.spawner == null or c.terrain == null:
		return "!no fight running yet: start a run first"
	if not game.flow.in_play():
		return "!spawn works during a run, not on the %s screen" % game.flow.state_name()
	var all_kinds := Combat.spawnable_kinds()
	if not kind in all_kinds:
		var near := all_kinds.filter(func(k: String): return k.begins_with(kind))
		if near.size() != 1:
			return "!no enemy '%s'%s" % [kind, (" (did you mean %s?)" % ", ".join(near.slice(0, 5))) if not near.is_empty() else ""]
		kind = near[0]
	if affix != "" and not affix in EliteAffixes.IDS and affix != EliteAffixes.PLATED:
		return "!no affix '%s' (%s, %s)" % [affix, ", ".join(EliteAffixes.IDS), EliteAffixes.PLATED]
	count = clampi(count, 1, MAX_COUNT)
	var ball: Vector3 = c.player.ball_position()
	var centre := ball + c.heading() * AHEAD
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
	c.run.invulnerable = on
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
	if on and is_instance_valid(game) and game.flow != null:
		game.flow.force_warden = false
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


func step_physics(ticks: int) -> Dictionary:
	if not is_inside_tree() or not is_instance_valid(game):
		return {"ok": false, "text": "!game is not inside the scene tree", "data": {}}
	ticks = clampi(ticks, 1, 3600)
	if game.pause_wanted():
		return {"ok": false, "text": "!game is paused by menu or workshop; run 'pick 1' or 'unpause' first", "data": {"paused": true}}
	var was_frozen := _frozen
	_stepping = true
	if was_frozen:
		game.freeze_for_dev(false)
	var start_steps := _phys_steps
	var target := start_steps + ticks
	var guard := 0
	while is_inside_tree() and _phys_steps < target:
		if not is_instance_valid(game) or game.pause_wanted():
			break
		await get_tree().physics_frame
		guard += 1
		if guard > ticks + 60:
			break
	_stepping = false
	if was_frozen and is_instance_valid(game):
		game.freeze_for_dev(true)
	var ran := _phys_steps - start_steps
	var run_time := float(ctx().run.run_time) if ctx() != null and ctx().run != null else 0.0
	if ran < ticks and is_instance_valid(game) and game.pause_wanted():
		return {"ok": false, "text": "!game is paused by menu or workshop; run 'pick 1' or 'unpause' first",
			"data": {"ticks": ran, "requested": ticks, "paused": true, "run_time": run_time}}
	return {"ok": true, "text": "stepped %d ticks" % ran, "data": {"ticks": ran, "run_time": run_time}}


func _process(_delta: float) -> void:
	if _frozen and not _stepping and not get_tree().paused:
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
	if not get_tree().paused:
		_phys_steps += 1
	if god and ctx() != null and ctx().run != null and ctx().run.alive():
		ctx().run.heal(ctx().run.max_hp)
	if not _frozen and not is_equal_approx(_time_scale, 1.0) and not is_equal_approx(Engine.time_scale, _time_scale):
		Engine.time_scale = _time_scale


func register_extra(commands) -> void:
	commands.add("stage", "<1..6|dam|flume|pit|sinkhole|islands|crown>", "jump directly to a stage by index or park alias", _cmd_stage)
	commands.add("retry", "", "retry the current stage or boss arena", _cmd_retry)
	commands.add("seed", "<n>", "set deterministic run seed override and RNG seed", _cmd_seed)
	commands.add("pilot", "<index|id>", "launch a run from the title screen with a pilot by 1-based index or id", _cmd_pilot)
	commands.add("warp", "<x> <z> | spawn | beacon | landmark | moss | vault | warden | ahead [m]", "move the ball safely to a point or landmark", _cmd_warp)
	commands.add("vel", "<vx> <vy> <vz>", "set the ball's velocity vector directly", _cmd_vel)
	commands.add("speed", "<m/s>", "launch the ball forward along camera heading at m/s", _cmd_speed)
	commands.add("give", "<part_id> [count]", "grant a build part and recompute the build", _cmd_give)
	commands.add("parts", "[list|clear]", "list held parts or clear all held parts", _cmd_parts)
	commands.add("panel", "<panel_id> [count]", "grant a hull panel by id", _cmd_panel)
	commands.add("drop_scale", "<mult>", "scale panel drop rate (0..50)", _cmd_drop_scale)
	commands.add("relic", "<relic_id>", "grant a pilot relic and sync abilities", _cmd_relic)
	commands.add("tune", "[key [value] | reset | dump | interp [on|off]]", "read or override movement and gameplay tuning", _cmd_tune)
	commands.add("quality", "<high|low|target>", "apply a graphics quality preset", _cmd_quality)
	commands.add("damage", "<amount>", "deal damage to the player hull", _cmd_damage)
	commands.add("hurt", "<amount>", "alias for damage", _cmd_damage)
	commands.add("warden", "[engage|stagger|break]", "inspect or drive the stage Warden", _cmd_warden)
	commands.add("beacon", "[unseal]", "inspect or unseal the stage beacon", _cmd_beacon)
	commands.add("flood", "[on|off]", "inspect or toggle the stage flood cycle", _cmd_flood)


func _cmd_stage(args: Array[String]):
	var c = ctx()
	if c == null or game.flow == null:
		return "!no flow yet"
	if not game.flow.in_play():
		return "!start a run first"
	if args.is_empty():
		return "!stage <1..%d|dam|flume|pit|sinkhole|islands|crown>" % int(c.stages.COUNT)
	var raw := args[0].to_lower()
	var idx := raw.to_int() if raw.is_valid_int() else int(STAGE_ALIASES.get(raw, -1))
	if idx < 1 or idx > int(c.stages.COUNT):
		return "!unknown stage '%s' (1..%d or dam|flume|pit|sinkhole|islands|crown)" % [args[0], int(c.stages.COUNT)]
	game.flow.enter_stage(idx, Vector3.ZERO, false)
	var def: Dictionary = game.flow.stage_def()
	var map_name := String(def.get("map", ""))
	return {"ok": true, "text": "stage %d (%s)" % [idx, map_name],
		"data": {"stage": idx, "world": int(c.stages.world_of(idx)), "map": map_name}}


func _cmd_retry(_args: Array[String]):
	var c = ctx()
	if c == null or game.flow == null or c.run == null:
		return "!no flow yet"
	if not c.run.has_snapshot() or game.flow.state_name() in ["title", "class_select", "summary", "victory", "lap"]:
		return "!cannot retry from %s" % game.flow.state_name()
	game.flow.retry_stage()
	return {"ok": true, "text": "retried (%s)" % game.flow.state_name(),
		"data": {"state": game.flow.state_name(), "stage": int(c.run.stage)}}


func _cmd_seed(args: Array[String]):
	var c = ctx()
	if c == null or c.run == null or c.rng == null:
		return "!no run context yet"
	if args.is_empty() or not args[0].is_valid_int():
		return "!seed <integer>"
	var n := args[0].to_int()
	c.run.run_seed_override = n
	c.rng.seed = n
	return {"ok": true, "text": "seed %d" % n, "data": {"seed": n}}


func _cmd_pilot(args: Array[String]):
	if game.flow == null:
		return "!no flow yet"
	if game.flow.state_name() != "title":
		return "!pilot starts a run from the title screen (currently %s)" % game.flow.state_name()
	if args.is_empty():
		var ids: Array[String] = []
		for def in game.flow.classes:
			ids.append(String(def.id))
		return "!pilot <1..%d|id> (%s)" % [game.flow.classes.size(), ", ".join(ids)]
	var raw := args[0]
	var chosen: Resource = null
	if raw.is_valid_int():
		var idx := raw.to_int() - 1
		if idx < 0 or idx >= game.flow.classes.size():
			return "!no pilot %d (1..%d)" % [idx + 1, game.flow.classes.size()]
		chosen = game.flow.classes[idx]
	else:
		var needle := raw.to_lower()
		var exact: Array[Resource] = []
		var prefix: Array[Resource] = []
		for def in game.flow.classes:
			var cid := String(def.id).to_lower()
			var dname := String(def.display_name).to_lower()
			if cid == needle or dname == needle:
				exact.append(def)
			elif cid.begins_with(needle) or dname.begins_with(needle):
				prefix.append(def)
		if exact.size() == 1:
			chosen = exact[0]
		elif exact.is_empty() and prefix.size() == 1:
			chosen = prefix[0]
		else:
			var ids: Array[String] = []
			for def in game.flow.classes:
				ids.append(String(def.id))
			return "!unknown pilot '%s' (%s)" % [raw, ", ".join(ids)]
	if not game.flow.launch_from_title(chosen):
		return "!failed to launch pilot %s" % String(chosen.id)
	return {"ok": true, "text": "launched pilot %s" % String(chosen.id),
		"data": {"pilot": String(chosen.id), "name": String(chosen.display_name)}}


func _cmd_warp(args: Array[String]):
	var c = ctx()
	if c == null or c.player == null or c.terrain == null or game.flow == null:
		return "!no world yet"
	if not game.flow.in_play():
		return "!warp works during a run, not on %s" % game.flow.state_name()
	if args.is_empty():
		return "!warp <x> <z> | spawn | beacon | landmark | moss | vault | warden | ahead [m]"
	var pt := Vector3.INF
	var label_name := args[0].to_lower()
	if args.size() >= 2 and args[0].is_valid_float() and args[1].is_valid_float():
		pt = c.terrain.drop_point(args[0].to_float(), args[1].to_float(), 2.2)
		label_name = "coords"
	else:
		match label_name:
			"spawn":
				pt = c.terrain.spawn_point(c.run.stage)
			"beacon":
				var bp: Vector3 = c.terrain.beacon_point(c.run.stage)
				pt = c.terrain.drop_point(bp.x, bp.z, 2.2)
			"landmark":
				var lp: Vector3 = c.terrain.landmark_point(c.run.stage)
				if not lp.is_finite():
					return "!no landmark on stage %d" % c.run.stage
				pt = c.terrain.drop_point(lp.x, lp.z, 2.2)
			"moss":
				var mp: Vector3 = c.terrain.moss_point()
				if not mp.is_finite():
					return "!Moss bay is not docked on this stage"
				pt = mp + Vector3.UP * 2.0
			"vault":
				if not c.stages.has_vault():
					return "!no vault on this stage table"
				var vp: Vector3 = c.terrain.vault_point(c.run.stage)
				if not vp.is_finite():
					return "!no vault on stage %d" % c.run.stage
				pt = c.terrain.drop_point(vp.x, vp.z, 2.2)
			"warden":
				if not is_instance_valid(game.flow.warden):
					return "!no warden active"
				var wp: Vector3 = game.flow.warden.global_position
				var offset: Vector3 = c.player.ball_position() - wp
				offset.y = 0.0
				var side: Vector3 = offset.normalized() * 6.0 if offset.length() > 0.1 else Vector3(0.0, 0.0, 6.0)
				pt = c.terrain.drop_point(wp.x + side.x, wp.z + side.z, 2.2)
			"ahead":
				var dist := DevCommands.number(args, 1, 20.0)
				var dest: Vector3 = c.player.ball_position() + c.heading() * dist
				pt = c.terrain.drop_point(dest.x, dest.z, 2.2)
			_:
				return "!warp <x> <z> | spawn | beacon | landmark | moss | vault | warden | ahead [m]"
	if not pt.is_finite():
		return "!warp destination is not finite"
	game.player.reset_to(pt, Vector3.ZERO)
	return {"ok": true, "text": "warped to %s (%.1f, %.1f, %.1f)" % [label_name, pt.x, pt.y, pt.z],
		"data": {"target": label_name, "pos": [pt.x, pt.y, pt.z]}}


func _cmd_vel(args: Array[String]):
	if game.player == null or game.flow == null or not game.flow.in_play():
		return "!vel works during a run"
	if args.size() < 3 or not args[0].is_valid_float() or not args[1].is_valid_float() or not args[2].is_valid_float():
		return "!vel <vx> <vy> <vz>"
	var v := Vector3(args[0].to_float(), args[1].to_float(), args[2].to_float())
	if not v.is_finite():
		return "!velocity must be finite"
	game.player.set_velocity_now(v, "dev")
	return {"ok": true, "text": "vel (%.1f, %.1f, %.1f)" % [v.x, v.y, v.z],
		"data": {"vel": [v.x, v.y, v.z], "speed": v.length()}}


func _cmd_speed(args: Array[String]):
	if game.player == null or game.flow == null or not game.flow.in_play():
		return "!speed works during a run"
	if args.is_empty() or not args[0].is_valid_float():
		return "!speed <m/s>"
	var s := args[0].to_float()
	if not is_finite(s):
		return "!speed must be finite"
	var c = ctx()
	var fwd: Vector3 = c.heading() if c != null else Vector3.FORWARD
	var v := fwd * s
	game.player.set_velocity_now(v, "dev")
	return {"ok": true, "text": "speed %.1f m/s" % s,
		"data": {"vel": [v.x, v.y, v.z], "speed": s}}


func _cmd_give(args: Array[String]):
	if game.run == null or game.build == null:
		return "!no run state yet"
	if args.is_empty():
		return "!give <part_id> [count]"
	var all_rows: Dictionary = _parts_rows()
	var id := _resolve_id(args[0], all_rows.keys())
	if id == "":
		var near := all_rows.keys().filter(func(k: String): return String(k).begins_with(args[0]))
		return "!unknown part '%s'%s" % [args[0], (" (did you mean %s?)" % ", ".join(near.slice(0, 6))) if not near.is_empty() else ""]
	var count := clampi(DevCommands.whole(args, 1, 1), 1, 20)
	for i in count:
		game.run.add_part(id, "dev")
	game.build.recompute()
	game.build.sync_relics()
	return {"ok": true, "text": "gave %dx %s (%d parts)" % [count, id, game.run.parts.size()],
		"data": {"part": id, "count": count, "parts": game.run.parts.duplicate()}}


func _cmd_parts(args: Array[String]):
	if game.run == null or game.build == null:
		return "!no run state yet"
	var action := DevCommands.word(args, 0, "list").to_lower()
	if action == "clear":
		game.run.clear_parts()
		game.build.recompute()
		game.build.sync_relics()
		return {"ok": true, "text": "cleared parts", "data": {"parts": []}}
	if action != "list":
		return "!parts [list|clear]"
	var held: Array = game.run.parts.duplicate()
	return {"ok": true, "text": ("parts (%d): %s" % [held.size(), ", ".join(held)]) if not held.is_empty() else "no parts held",
		"data": {"count": held.size(), "parts": held}}


func _cmd_panel(args: Array[String]):
	if game.run == null or game.build == null:
		return "!no run state yet"
	if args.is_empty():
		return "!panel <panel_id> [count] (%s)" % ", ".join(Panels.ROWS.keys())
	var id := _resolve_id(args[0], Panels.ROWS.keys())
	if id == "":
		return "!unknown panel '%s' (%s)" % [args[0], ", ".join(Panels.ROWS.keys())]
	var count := clampi(DevCommands.whole(args, 1, 1), 1, 20)
	for i in count:
		game.build.grant_panel(id)
	return {"ok": true, "text": "granted %dx panel %s" % [count, id],
		"data": {"panel": id, "count": count, "panel_counts": game.run.panel_counts()}}


func _cmd_drop_scale(args: Array[String]):
	if game.build == null or game.build.dropper == null:
		return "!no build dropper yet"
	if args.is_empty() or not args[0].is_valid_float():
		return "!drop_scale <mult>"
	game.build.dropper.scale = clampf(args[0].to_float(), 0.0, 50.0)
	return {"ok": true, "text": "drop_scale %.2f" % game.build.dropper.scale,
		"data": {"drop_scale": game.build.dropper.scale}}


func _cmd_relic(args: Array[String]):
	if game.run == null or game.build == null:
		return "!no run state yet"
	if args.is_empty():
		return "!relic <relic_id>"
	var id := args[0]
	if not Relics.has(id):
		id = _resolve_id(args[0], _relic_ids())
	if id == "" or not Relics.has(id):
		return "!unknown relic '%s'" % args[0]
	if not game.run.add_relic(id, "dev"):
		return "!relic '%s' cannot be held by pilot '%s' (slot '%s')" % [id, game.run.class_id(), Relics.slot_of(id)]
	game.build.sync_relics()
	return {"ok": true, "text": "added relic %s" % id,
		"data": {"relic": id, "slot": Relics.slot_of(id)}}


func _cmd_tune(args: Array[String]):
	if game.tuning == null:
		return "!no tuning yet"
	if args.is_empty():
		var keys: Array[String] = []
		for spec in Tuning.SPECS:
			keys.append(String(spec["key"]))
		return {"ok": true, "text": "tuning (%d keys): %s" % [keys.size(), ", ".join(keys.slice(0, 12))],
			"data": {"keys": keys, "interpolating": game.interpolating()}}
	var sub := args[0].to_lower()
	if sub == "reset":
		game.tuning.reset()
		return {"ok": true, "text": "tuning reset", "data": {}}
	if sub == "dump":
		var saved: String = game.dump_tuning()
		if saved == "":
			return "!tuning dump failed"
		return {"ok": true, "text": "tuning dumped -> %s" % saved, "data": {"path": saved}}
	if sub == "interp":
		var want := DevCommands.flag(args, 1, game.interpolating())
		if want != game.interpolating():
			game.toggle_interpolation()
		return {"ok": true, "text": "interpolation %s" % ("on" if game.interpolating() else "off"),
			"data": {"interpolating": game.interpolating()}}
	var found := false
	for spec in Tuning.SPECS:
		if String(spec["key"]) == args[0]:
			found = true
			break
	if not found:
		return "!unknown tuning key '%s'" % args[0]
	var key := args[0]
	var opts: Array = game.tuning.options_of(key)
	if args.size() == 1:
		var val = game.tuning.option(key) if not opts.is_empty() else game.tuning.base(key)
		return {"ok": true, "text": "%s = %s" % [key, str(val)], "data": {"key": key, "value": val}}
	var raw := args[1]
	if not opts.is_empty() and not raw.is_valid_float():
		if not game.tuning.set_option(key, raw):
			return "!invalid option '%s' for %s (%s)" % [raw, key, ", ".join(opts)]
		return {"ok": true, "text": "%s = %s" % [key, game.tuning.option(key)],
			"data": {"key": key, "value": game.tuning.option(key)}}
	if not raw.is_valid_float():
		return "!tune %s expects a number" % key
	game.tuning.set_value(key, raw.to_float())
	var after = game.tuning.option(key) if not opts.is_empty() else game.tuning.base(key)
	return {"ok": true, "text": "%s = %s" % [key, str(after)], "data": {"key": key, "value": after}}


func _cmd_quality(args: Array[String]):
	if args.is_empty():
		return {"ok": true, "text": "quality %s (%s)" % [GraphicsPreset.current, ", ".join(GraphicsPreset.PRESETS.keys())],
			"data": {"preset": GraphicsPreset.current}}
	var preset := args[0].to_lower()
	if not GraphicsPreset.apply(preset):
		return "!unknown quality preset '%s' (%s)" % [args[0], ", ".join(GraphicsPreset.PRESETS.keys())]
	return {"ok": true, "text": "quality %s" % GraphicsPreset.current, "data": {"preset": GraphicsPreset.current}}


func _cmd_damage(args: Array[String]):
	var c = ctx()
	if c == null or c.run == null:
		return "!no run state yet"
	if args.is_empty() or not args[0].is_valid_float():
		return "!damage <amount>"
	var amount := args[0].to_float()
	if amount <= 0.0 or not is_finite(amount):
		return "!damage amount must be positive"
	c.run.damage(amount, "dev")
	return {"ok": true, "text": "damaged %.1f (hull %.1f/%.1f)" % [amount, c.run.hp, c.run.max_hp],
		"data": {"amount": amount, "hp": c.run.hp, "max_hp": c.run.max_hp, "alive": c.run.alive()}}


func _cmd_warden(args: Array[String]):
	if game.flow == null or not game.flow.in_play():
		return "!start a run first"
	var action := DevCommands.word(args, 0, "status").to_lower()
	var w = game.flow.warden
	if action == "engage":
		game.flow.force_warden = true
		if not is_instance_valid(w):
			return "!no warden active (force_warden armed)"
		if game.combat != null:
			game.combat.strike(w, "ram", 1.0)
		return {"ok": true, "text": "warden engaged",
			"data": {"engaged": game.flow.engaged(), "hp": float(w.hp) if "hp" in w else 0.0}}
	if not is_instance_valid(w):
		return "!no warden active"
	if action == "status":
		var info := {
			"engaged": game.flow.engaged(),
			"hp": float(w.hp) if "hp" in w else 0.0,
			"max_hp": float(w.max_hp) if "max_hp" in w else 0.0,
			"posture": float(w.posture()) if w.has_method("posture") else 0.0,
			"staggered": bool(w.staggered()) if w.has_method("staggered") else false,
			"chunks_left": int(w.chunks_left()) if w.has_method("chunks_left") else 0,
		}
		return {"ok": true, "text": "warden hp %.0f/%.0f posture %.0f staggered=%s chunks=%d" % [
			info.hp, info.max_hp, info.posture, str(info.staggered), info.chunks_left], "data": info}
	if action == "stagger":
		if w.has_method("apply_posture_hit"):
			w.apply_posture_hit({"gain": 100.0, "crack": false, "shatter": false, "dealt": 0.0})
		var is_stag := bool(w.staggered()) if w.has_method("staggered") else false
		return {"ok": is_stag, "text": "warden staggered" if is_stag else "!warden stagger gated",
			"data": {"staggered": is_stag, "posture": float(w.posture()) if w.has_method("posture") else 0.0}}
	if action == "break":
		if w.has_method("apply_posture_hit"):
			if w.has_method("staggered") and not w.staggered():
				w.apply_posture_hit({"gain": 100.0, "crack": false, "shatter": false, "dealt": 0.0})
			var take: int = maxi(int(w.chunks_left()), 1) if w.has_method("chunks_left") else 4
			w.apply_posture_hit({"shatter": true, "take": take, "dealt": float(w.hp) + 1.0})
		if is_instance_valid(w) and w.has_method("take_damage") and "hp" in w:
			w.take_damage(float(w.hp) + 1.0)
		if game.flow.sealed:
			game.flow.force_unseal()
		return {"ok": true, "text": "warden broken; beacon unsealed", "data": {"sealed": game.flow.sealed}}
	return "!warden [engage|stagger|break]"


func _cmd_beacon(args: Array[String]):
	if game.flow == null or not game.flow.in_stage() or game.beacon == null:
		return "!beacon works during a stage"
	var action := DevCommands.word(args, 0, "status").to_lower()
	if action == "status":
		var info := {
			"phase": int(game.beacon.phase),
			"progress": float(game.beacon.progress),
			"duration": float(game.beacon.duration),
			"fraction": float(game.beacon.fraction()),
			"sealed": bool(game.flow.sealed),
		}
		return {"ok": true, "text": "beacon %.0f%% sealed=%s" % [info.fraction * 100.0, str(info.sealed)], "data": info}
	if action == "unseal":
		if is_instance_valid(game.flow.warden):
			_cmd_warden(["break"])
		else:
			game.flow.force_unseal()
		return {"ok": true, "text": "beacon unsealed (%s)" % game.flow.state_name(),
			"data": {"state": game.flow.state_name(), "sealed": game.flow.sealed}}
	return "!beacon [unseal]"


func _cmd_flood(args: Array[String]):
	if game.world == null or game.world.flood == null:
		return "!no flood system yet"
	var f = game.world.flood
	if f.basin.is_empty() or f.cycle == null:
		return "!this stage has no flood"
	var action := DevCommands.word(args, 0, "status").to_lower()
	if action == "on":
		f.set_phase(FloodCycle.HIGH)
	elif action == "off":
		f.set_phase(FloodCycle.DRY)
	elif action != "status":
		return "!flood [on|off]"
	var phase_name: String = FloodCycle.PHASE_NAMES[clampi(int(f.cycle.phase), 0, FloodCycle.PHASE_NAMES.size() - 1)]
	var sy: float = f.surface_y()
	return {"ok": true, "text": "flood %s (surface_y=%.2f)" % [phase_name, sy],
		"data": {"phase": phase_name, "elapsed": float(f.cycle.elapsed), "surface_y": sy if is_finite(sy) else null, "visible": bool(f.visible)}}


static func _resolve_id(raw: String, pool: Array) -> String:
	if raw in pool:
		return raw
	var near := pool.filter(func(k): return String(k).begins_with(raw))
	return String(near[0]) if near.size() == 1 else ""


static func _parts_rows() -> Dictionary:
	var script_ref: Script = Parts
	if script_ref.has_method("all_rows"):
		return script_ref.call("all_rows") as Dictionary
	var cat = script_ref.get("CATALOGUE")
	return cat as Dictionary if cat is Dictionary else {}


static func _relic_ids() -> Array:
	var script_ref: Script = Relics
	if script_ref.has_method("all_ids"):
		return script_ref.call("all_ids") as Array
	var rows = script_ref.get("ROWS")
	return (rows as Dictionary).keys() if rows is Dictionary else []
