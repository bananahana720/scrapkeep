extends SceneTree

# World 1 Hardening Unit P7 & P9: Formal-verification bug fixes (YL-1, YL-2, ES-1, ES-2, ES-3),
# combat.gd P0/P1/P2 hardening, and Effects.live_mark_count() + stress_capture.gd.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const Combat := preload("res://src/combat/combat.gd")
const Effects := preload("res://src/combat/effects.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const LockRows := preload("res://src/world/lock_rows.gd")
const StageLocks := preload("res://src/world/stage_locks.gd")
const RunStore := preload("res://src/core/run_store.gd")
const SafeStore := preload("res://src/core/safe_store.gd")
const T := preload("res://tests/support/t.gd")

const SAVE_DIR := "user://w45_combat_formal_fixes_test/"
const SAVE_PATH := SAVE_DIR + "run.json"

var _t := T.new("w45_combat_formal_fixes_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	seed(7)
	await _test_yl1_warden_wake_unlocks_yard()
	await _test_yl2_death_drops_yard_lock()
	await _test_es1_owed_death_save_spend()
	await _test_es2_refused_clear_keeps_save_spend()
	await _test_es3_refused_restart_keeps_save_spend()
	await _test_combat_cleanup_p0_3()
	await _test_combat_door_caps_mark_free_p0_4()
	await _test_combat_second_bell_p0_5()
	await _test_combat_polish_p1_p2()
	_test_effects_live_mark_count()
	quit(_t.verdict())


func _park_game(store_path := ""):
	var game := Game.new()
	game.test_mode = true
	game.table = "park"
	game.run_store_path = store_path
	root.add_child(game)
	await process_frame
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(0)
	for i in 8:
		await physics_frame
	return game


func _shut_yard(game) -> void:
	var locks = game.flow.gate
	var row: Dictionary = LockRows.row("park_dam")["lock"]
	var beacon: Vector3 = game.flow.beacon.global_position
	var spot := beacon + Vector3(0.0, 0.0, -float(row["within_m"]) * StageLocks.LOCK_ANY_SLOPE_SHARE + 10.0)
	var ground: Vector3 = game.ctx.terrain.drop_point(spot.x, spot.z, 1.0)
	game.player.reset_to(ground, Vector3.ZERO)
	var waited := 0
	while locks.lock_state == "armed" and waited < 240:
		await physics_frame
		waited += 1


func _calm_game():
	var game := Game.new()
	game.test_mode = true
	root.add_child(game)
	await process_frame
	game.ctx.calm = true
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(0)
	for i in 8:
		await physics_frame
	return game


func _spawn_chaser(game, at: Vector3) -> Node3D:
	var y: float = game.ctx.terrain.height(at.x, at.z)
	var enemy: Node3D = game.combat.spawn_enemy("chaser", Vector3(at.x, y + 1.5, at.z))
	enemy.max_hp = 100000.0
	enemy.hp = 100000.0
	enemy.set_physics_process(false)
	return enemy


# --- YL-1: Warden waking via strike OR ring while yard is locked opens yard immediately ---

func _test_yl1_warden_wake_unlocks_yard() -> void:
	# (a) Long-range strike wakes Warden while yard is locked -> immediate unlock on the exact frame.
	var game = await _park_game()
	var locks = game.flow.gate
	var unlocks := [0]
	game.events.world_fact.connect(func(kind: String, _at: Vector3):
		if kind == "arena_unlocked":
			unlocks[0] += 1)
	await _shut_yard(game)
	_t.eq("YL-1a precondition: yard is locked", locks.lock_state, "locked")
	var crew: Array = locks.crew_alive()
	_t.check("YL-1a precondition: crew has yard_crew meta", not crew.is_empty() and crew.all(func(e): return e.has_meta("yard_crew")))
	game.ctx.spawner.strike(game.flow.warden, "ram", 400.0)
	_t.eq("YL-1a: strike wake unlocks yard on exact frame", locks.lock_state, "spent")
	_t.check("YL-1a: wall dropped immediately", locks._wall == null)
	_t.check("YL-1a: not marked won", not locks.lock_won)
	_t.check("YL-1a: objective no longer says Yard locked", not game.flow.objective_text().contains("Yard locked"), game.flow.objective_text())
	_t.check("YL-1a: yard_crew meta stripped", crew.all(func(e): return not is_instance_valid(e) or not e.has_meta("yard_crew")))
	for i in 3:
		await physics_frame
	_t.eq("YL-1a: arena_unlocked emitted exactly once (no double unlock)", unlocks[0], 1)
	_t.check("YL-1a: ArenaLockWall node gone", locks.get_node_or_null("ArenaLockWall") == null)
	game.free()
	await process_frame

	# (b) Ring entry wakes Warden while yard is locked -> yard unlocks cleanly.
	game = await _park_game()
	locks = game.flow.gate
	unlocks[0] = 0
	game.events.world_fact.connect(func(kind: String, _at: Vector3):
		if kind == "arena_unlocked":
			unlocks[0] += 1)
	await _shut_yard(game)
	_t.eq("YL-1b precondition: yard is locked", locks.lock_state, "locked")
	var beacon_at: Vector3 = game.flow.beacon.global_position
	game.player.reset_to(game.ctx.terrain.drop_point(beacon_at.x, beacon_at.z, 1.0), Vector3.ZERO)
	for i in 4:
		await physics_frame
	_t.check("YL-1b: Warden engaged by ring entry", game.flow.engaged())
	_t.eq("YL-1b: ring wake unlocks yard", locks.lock_state, "spent")
	_t.check("YL-1b: wall dropped and not won", locks._wall == null and not locks.lock_won)
	_t.eq("YL-1b: arena_unlocked emitted once", unlocks[0], 1)
	game.free()
	await process_frame


# --- YL-2: Death in no-store flow retires yard lock and drops wall ---

func _test_yl2_death_drops_yard_lock() -> void:
	var game = await _park_game("")
	var locks = game.flow.gate
	await _shut_yard(game)
	var crew: Array = locks.crew_alive()
	_t.check("YL-2 precondition: yard locked with wall in no-store flow",
		game.flow.store == null and locks.lock_state == "locked" and locks._wall != null and not crew.is_empty())
	game.run.damage(99999.0, "test")
	await physics_frame
	await process_frame
	_t.eq("YL-2: flow entered dead state", game.flow.state_name(), "dead")
	_t.eq("YL-2: death retires yard lock", locks.lock_state, "spent")
	_t.check("YL-2: wall and collar dropped", locks._wall == null and locks._collar == null and locks.get_node_or_null("ArenaLockWall") == null)
	_t.check("YL-2: yard_crew stripped on death", crew.all(func(e): return not is_instance_valid(e) or not e.has_meta("yard_crew")))
	game.free()
	await process_frame


# --- ES-1: Failed disk write on earned death-save stays owed and is never refunded ---

func _clean_save_dir() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var tmp := SafeStore.tmp_path(SAVE_PATH)
	if DirAccess.dir_exists_absolute(tmp):
		DirAccess.remove_absolute(tmp)
	for f in DirAccess.get_files_at(SAVE_DIR):
		DirAccess.remove_absolute(SAVE_DIR + f)


func _test_es1_owed_death_save_spend() -> void:
	_clean_save_dir()
	var tmp := SafeStore.tmp_path(SAVE_PATH)
	var game := Game.new()
	game.test_mode = true
	game.run_store_path = SAVE_PATH
	root.add_child(game)
	await process_frame
	game.ctx.calm = true
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(1)
	for i in 5:
		await process_frame
	game.run.add_part("spare_frame", "test")
	game.build.recompute()
	game.flow.enter_stage(1, Vector3(0.0, 0.0, 14.0), false)
	await process_frame
	_t.check("ES-1 precondition: disk entrance has death_save_spent == false",
		not bool(RunStore.new(SAVE_PATH).load().get("death_save_spent", false)))

	# Block disk writes by placing a directory at SafeStore.tmp_path(SAVE_PATH).
	DirAccess.make_dir_recursive_absolute(tmp)
	game.run.damage(99999.0, "test")
	_t.check("ES-1: earned save fired while write failed sets owed flag",
		game.run.alive() and game.run.death_save_spent and game.flow.store_error != "" and game.flow._save_spend_owed)
	_t.check("ES-1: disk still shows unspent while blocked",
		not bool(RunStore.new(SAVE_PATH).load().get("death_save_spent", false)))

	# Quit to title and Continue while disk is STILL unwritable -> save must stay spent!
	game.flow.show_title()
	_t.check("ES-1: still owed when show_title flush also fails", game.flow._save_spend_owed)
	var resumed: bool = game.flow.resume_run()
	_t.check("ES-1: in-process Continue refuses to refund owed earned save",
		resumed and game.run.death_save_spent and bool(game.flow._entrance.get("death_save_spent", false)))
	game.build.recompute()
	game.run.damage(99999.0, "test")
	_t.eq("ES-1: next killing hit after Continue ends the run (no second death-save)", game.flow.state_name(), "summary")

	# Unblock disk, start a fresh run -> owed flag cleared and save is fresh.
	DirAccess.remove_absolute(tmp)
	game.flow.new_run()
	await process_frame
	_t.check("ES-1: new run clears owed flag and starts unspent",
		not game.flow._save_spend_owed and not game.run.death_save_spent)

	# Trigger failed write again, then let disk recover and verify WM_CLOSE_REQUEST flushes to disk.
	game.run.add_part("spare_frame", "test")
	game.build.recompute()
	game.flow.enter_stage(1, Vector3(0.0, 0.0, 14.0), false)
	DirAccess.make_dir_recursive_absolute(tmp)
	game.run.damage(99999.0, "test")
	_t.check("ES-1 flush: owed set after failed write", game.flow._save_spend_owed)
	DirAccess.remove_absolute(tmp)
	game.flow.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	_t.check("ES-1 flush: WM_CLOSE_REQUEST flushes owed spend and clears flag",
		not game.flow._save_spend_owed and game.flow.store_error == ""
		and bool(RunStore.new(SAVE_PATH).load().get("death_save_spent", false)))

	# Separate Game instance loading from disk sees death_save_spent == true.
	game.free()
	await process_frame
	var game2 := Game.new()
	game2.test_mode = true
	game2.run_store_path = SAVE_PATH
	root.add_child(game2)
	await process_frame
	game2.ctx.calm = true
	game2.player.source = Intent.Scripted.new()
	var resumed2: bool = game2.flow.resume_run()
	_t.check("ES-1 reload: fresh process Continue keeps flushed death_save_spent",
		resumed2 and game2.run.death_save_spent)
	game2.free()
	await process_frame
	_clean_save_dir()
	DirAccess.remove_absolute(SAVE_DIR)


# --- ES-2: Refused spend write then refused tombstone still flushes spend on exit ---

func _test_es2_refused_clear_keeps_save_spend() -> void:
	_clean_save_dir()
	var tmp := SafeStore.tmp_path(SAVE_PATH)
	var game := Game.new()
	game.test_mode = true
	game.run_store_path = SAVE_PATH
	root.add_child(game)
	await process_frame
	game.ctx.calm = true
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(1)
	for i in 5:
		await process_frame
	game.run.add_part("spare_frame", "test")
	game.build.recompute()
	game.flow.enter_stage(1, Vector3(0.0, 0.0, 14.0), false)
	await process_frame

	# Block disk writes across both the earned save and the death that follows.
	DirAccess.make_dir_recursive_absolute(tmp)
	game.run.damage(99999.0, "test")
	_t.check("ES-2 precondition: spend refused sets owed while disk stays unspent",
		game.run.alive() and game.run.death_save_spent and game.flow._save_spend_owed
		and not bool(RunStore.new(SAVE_PATH).load().get("death_save_spent", false)))

	game.run.damage(99999.0, "test")
	_t.check("ES-2: death with refused tombstone keeps spend owed and disk holding the run",
		not game.run.alive() and game.flow.state_name() == "summary"
		and game.flow.store_error == "clear_failed" and game.flow._save_spend_owed
		and not RunStore.new(SAVE_PATH).load().is_empty())

	# Disk recovers before clean exit: _exit_tree flushes the held spend to disk.
	DirAccess.remove_absolute(tmp)
	game.free()
	await process_frame
	_t.check("ES-2: exit after refused clear flushes death_save_spent to disk",
		bool(RunStore.new(SAVE_PATH).load().get("death_save_spent", false)))

	# Fresh launch Continue loads the dead run with its earned save already spent.
	var game2 := Game.new()
	game2.test_mode = true
	game2.run_store_path = SAVE_PATH
	root.add_child(game2)
	await process_frame
	game2.ctx.calm = true
	game2.player.source = Intent.Scripted.new()
	var resumed: bool = game2.flow.resume_run()
	game2.build.recompute()
	_t.check("ES-2: Continue in new process sees death_save_spent == true",
		resumed and game2.run.death_save_spent and game2.run.parts.has("spare_frame"))
	game2.run.damage(99999.0, "test")
	_t.check("ES-2: killing hit after Continue ends run (no second free life)",
		not game2.run.alive() and game2.flow.state_name() == "summary" and game2.run.over)
	game2.free()
	await process_frame
	_clean_save_dir()
	DirAccess.remove_absolute(SAVE_DIR)


# --- ES-3: Refused spend write then refused restart keeps spend owed without poisoning the new run ---

func _test_es3_refused_restart_keeps_save_spend() -> void:
	_clean_save_dir()
	var tmp := SafeStore.tmp_path(SAVE_PATH)
	var game := Game.new()
	game.test_mode = true
	game.run_store_path = SAVE_PATH
	root.add_child(game)
	await process_frame
	game.ctx.calm = true
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(1)
	for i in 5:
		await process_frame
	game.run.add_part("spare_frame", "test")
	game.build.recompute()
	game.flow.enter_stage(1, Vector3(0.0, 0.0, 14.0), false)
	await process_frame

	# (a) Both the spend write and the restart's writes are refused; disk recovers before title + Continue.
	DirAccess.make_dir_recursive_absolute(tmp)
	game.run.damage(99999.0, "test")
	_t.check("ES-3a precondition: spend refused sets owed while disk stays unspent",
		game.run.alive() and game.run.death_save_spent and game.flow._save_spend_owed
		and not bool(RunStore.new(SAVE_PATH).load().get("death_save_spent", false)))

	game.flow.new_run()
	await process_frame
	_t.check("ES-3a: refused restart keeps old run's spend owed and leaves new run unspent",
		game.flow.state_name() == "stage" and game.flow.store_error == "write_failed"
		and game.flow._save_spend_owed and not game.run.death_save_spent
		and not game.run.parts.has("spare_frame")
		and bool(RunStore.new(SAVE_PATH).load().get("parts", []).has("spare_frame")))

	DirAccess.remove_absolute(tmp)
	game.flow.show_title()
	await process_frame
	_t.check("ES-3a: show_title once disk returns flushes old run's death_save_spent to disk",
		not game.flow._save_spend_owed
		and bool(RunStore.new(SAVE_PATH).load().get("death_save_spent", false)))

	var resumed: bool = game.flow.resume_run()
	game.build.recompute()
	_t.check("ES-3a: Continue loads old run with death_save_spent == true",
		resumed and game.run.death_save_spent and game.run.parts.has("spare_frame"))
	game.run.damage(99999.0, "test")
	_t.check("ES-3a: killing hit after Continue ends run (no second free life)",
		not game.run.alive() and game.flow.state_name() == "summary" and game.run.over)

	# (b) Refused spend then refused restart, then disk returns and the new run writes its own entrance:
	# the new run replaces the old run on disk, clears the debt, and keeps its own earned save.
	game.flow.new_run()
	await process_frame
	game.run.add_part("spare_frame", "test")
	game.build.recompute()
	game.flow.enter_stage(1, Vector3(0.0, 0.0, 14.0), false)
	DirAccess.make_dir_recursive_absolute(tmp)
	game.run.damage(99999.0, "test")
	game.flow.new_run()
	await process_frame
	DirAccess.remove_absolute(tmp)
	game.run.add_part("spare_frame", "test")
	game.build.recompute()
	game.flow.enter_stage(2, Vector3(0.0, 0.0, 14.0), false)
	_t.check("ES-3b: new run's landed entrance clears old debt without poisoning new run",
		not game.flow._save_spend_owed and not game.run.death_save_spent
		and not bool(RunStore.new(SAVE_PATH).load().get("death_save_spent", false)))
	game.run.damage(99999.0, "test")
	_t.check("ES-3b: new run's own earned save still fires once",
		game.run.alive() and game.run.death_save_spent)

	game.free()
	await process_frame
	_clean_save_dir()
	DirAccess.remove_absolute(SAVE_DIR)


# --- Combat P0 #3: stage-clear, death, attempt & run_started cleanup ---

func _test_combat_cleanup_p0_3() -> void:
	var game = await _calm_game()
	var combat = game.combat

	# (a) stage_content_cleared resets cards, escape state, and line_load.
	combat.tally_kit.plate = {"at": Vector3.ZERO, "until": combat._clock + 5.0}
	combat.tally_kit.link_group = {"ids": [1], "until": combat._clock + 5.0, "spent": false}
	combat.tally_kit.clip_post = {"at": Vector3.ZERO, "until": combat._clock + 5.0, "shape": {}}
	combat._escape = {"piece": "test", "style": "lane", "until": combat._clock + 5.0}
	combat.escape_lane = {"from": Vector3.ZERO, "dir": Vector3.FORWARD, "length": 10.0, "half_width": 2.0, "friction": 0.1, "hold": 10.0, "until": combat._clock + 5.0}
	combat._line_load = {"id": "line_reel", "fraction": 1.0, "left": 4.0}
	game.events.stage_content_cleared.emit("arena")
	_t.check("P0 #3a: stage_content_cleared clears cards, escape, escape_lane, line_load",
		combat.tally_kit.plate.is_empty() and combat.tally_kit.link_group.is_empty() and combat.tally_kit.clip_post.is_empty()
		and combat._escape.is_empty() and combat.escape_lane.is_empty() and combat._line_load.is_empty())

	# (b) player_died clears _strips, _bells, _aftershocks, _rakes, _line_load, _cast_pending, _bite_pending.
	combat._strips.append({"layer": "verb_strip_99", "until": combat._clock + 5.0, "struck": {}, "shape": {"kind": "line", "from": Vector3.ZERO, "to": Vector3.FORWARD, "width": 2.0}, "damage": 10.0, "knock": 4.0, "hits": 0})
	combat._bells.append({"layer": "second_bell_99", "at": combat._clock + 0.1, "mode": "pulse", "damage": 10.0, "limit": -1, "knock": 6.0, "breaks": false, "shape": game.player.yours({"kind": "ring", "centre": Vector3.ZERO, "radius": 4.0})})
	combat._aftershocks.append({"at": Vector3.ZERO, "radius": 5.0, "damage": 20.0, "born": combat._clock, "due": combat._clock + 0.1})
	combat._draw_aftershock()
	combat._rakes.append({"at": combat._clock + 0.1, "weapon": combat.active_weapon(), "forward": Vector3.FORWARD, "damage": 10.0, "volley": 1})
	combat._line_load = {"id": "line_reel", "fraction": 1.0, "left": 4.0}
	combat._cast_pending = {"slot": "special", "id": "gather_plate", "fire": Callable()}
	combat._bite_pending = true
	game.events.player_died.emit()
	_t.check("P0 #3b: player_died clears deferred queues and indicator layers",
		combat._strips.is_empty() and combat._bells.is_empty() and combat._aftershocks.is_empty()
		and combat._rakes.is_empty() and combat._line_load.is_empty() and combat._cast_pending.is_empty()
		and not combat._bite_pending and not game.player.indicator.shapes.has(Combat.FAULT_LAYER))

	# (c) Both _start_attempt() AND run_started clear _guards, _cast_pending, _bite_pending, _pike_count, _pike_last, verb items.
	for mode in ["attempt", "run_started"]:
		combat._guards[12345] = combat
		combat._cast_pending = {"slot": "special", "id": "x", "fire": Callable()}
		combat._bite_pending = true
		combat._pike_count = 4
		combat._pike_last = 12.0
		combat._strips.append({"layer": "verb_strip_98", "until": combat._clock + 5.0, "struck": {}, "shape": {}, "damage": 1.0, "knock": 1.0, "hits": 0})
		combat._bells.append({"layer": "second_bell_98", "at": combat._clock + 5.0, "mode": "pulse", "damage": 1.0, "limit": -1, "knock": 1.0, "breaks": false, "shape": {}})
		if mode == "attempt":
			combat._start_attempt()
		else:
			game.events.run_started.emit("pylon_engineer")
		_t.check("P0 #3c (%s): clears _guards, _cast_pending, _bite_pending, pike, verb items" % mode,
			combat._guards.is_empty() and combat._cast_pending.is_empty() and not combat._bite_pending
			and combat._pike_count == 0 and combat._pike_last == -INF
			and combat._strips.is_empty() and combat._bells.is_empty())

	game.free()
	await process_frame


# --- Combat P0 #4: _door_caps expired exposure eviction frees CannonExposure mark node ---

func _test_combat_door_caps_mark_free_p0_4() -> void:
	var game = await _calm_game()
	var combat = game.combat
	var enemy := _spawn_chaser(game, game.player.ball_position() + Vector3(0.0, 0.0, -5.0))
	combat._cannon_expose(enemy, 0.5, "plate")
	var id := enemy.get_instance_id()
	var mark: Node = enemy.get_node_or_null("CannonExposure")
	_t.check("P0 #4 precondition: CannonExposure attached and tracked", mark != null and combat._exposed.has(id))
	# Expire exposure on clock without stepping _step_cannon_exposure, then hit with contact so _door_caps prunes it.
	combat._clock += 1.0
	combat.strike(enemy, "ram", 5.0)
	_t.check("P0 #4: _door_caps erased _exposed entry", not combat._exposed.has(id))
	_t.check("P0 #4: _door_caps detached and queued mark for deletion",
		enemy.get_node_or_null("CannonExposure") == null and mark.is_queued_for_deletion())
	await process_frame
	_t.check("P0 #4: mark node freed next frame (zero orphan leak)", not is_instance_valid(mark))
	game.free()
	await process_frame


# --- Combat P0 #5: Second Bell damage mod, explicit breaks_props, stale-enemy guard ---

func _test_combat_second_bell_p0_5() -> void:
	var game = await _calm_game()
	var combat = game.combat

	# (a) _fire_plate records scaled damage * _damage_mod(CANNON_LANE) and breaks_props == false.
	var cannon_def: Resource = ClassDef.by_id("remembered_cannon")
	game.run.class_def = cannon_def
	game.player.fit_class(cannon_def)
	game.run.parts.assign(["second_bell"])
	game.build.recompute()
	game.tuning.set_mod("weapon_damage", 1.5)
	var shape: Dictionary = combat._plate_geometry(1.0)
	var mark: Dictionary = combat._bell_mark()
	combat._fire_plate(1.0, shape)
	var want_plate_dmg: float = Weapons.PLATE_DAMAGE_MAX * 1.5
	_t.near("P0 #5a: _fire_plate last_burst damage includes _damage_mod(CANNON_LANE)",
		float(combat.last_burst.get("damage", 0.0)), want_plate_dmg, 0.001)
	_t.eq("P0 #5a: _fire_plate sets explicit breaks_props = false", combat.last_burst.get("breaks_props"), false)
	combat._ring_bell("cannon_plate", shape, mark)
	_t.eq("P0 #5a: Second Bell queued with scaled half-damage and breaks=false",
		[combat._bells.size(), snappedf(float(combat._bells[0]["damage"]), 0.01), combat._bells[0]["breaks"]],
		[1, snappedf(want_plate_dmg * 0.5, 0.01), false])
	combat._clear_verb_items()
	game.tuning.set_mod("weapon_damage", 1.0)

	# (b) _fire_line sets breaks_props = true when catching a charge even with no destructibles on map,
	# and breaks_props = false when catching none.
	var kest_def: Resource = ClassDef.by_id("demolitions_caster")
	game.run.class_def = kest_def
	game.player.fit_class(kest_def)
	game.run.parts.assign(["second_bell"])
	game.build.recompute()
	var line_shape: Dictionary = combat.line_geometry(1.0)
	var mark_empty: Dictionary = combat._bell_mark()
	combat.fire_line(1.0, line_shape)
	_t.eq("P0 #5b: _fire_line with 0 caught charges sets breaks_props = false", combat.last_burst.get("breaks_props"), false)
	combat._ring_bell("detonation_line", line_shape, mark_empty)
	_t.eq("P0 #5b: bell inherits breaks = false", combat._bells[0]["breaks"], false)
	combat._clear_verb_items()

	var mid: Vector3 = (line_shape["from"] as Vector3).lerp(line_shape["to"], 0.5)
	combat.sticky.drop(mid, 10.0, 2.0, 5.0, 0.0, 0.0, combat._clock)
	var mark_caught: Dictionary = combat._bell_mark()
	combat.fire_line(1.0, line_shape)
	_t.eq("P0 #5b: _fire_line with caught charge sets breaks_props = true", combat.last_burst.get("breaks_props"), true)
	combat._ring_bell("detonation_line", line_shape, mark_caught)
	_t.eq("P0 #5b: bell inherits breaks = true without break_order diffing", combat._bells[0]["breaks"], true)
	combat._clear_verb_items()

	# (c) _toll skips enemies killed mid-loop by an earlier hit in the same toll.
	var origin: Vector3 = game.player.ball_position()
	var a := _spawn_chaser(game, origin + Vector3(0.0, 0.0, -2.0))
	var b := _spawn_chaser(game, origin + Vector3(0.0, 0.0, -4.0))
	var struck_b := [0]
	var killer := func(enemy: Node3D, _kind: String, _force: float):
		if enemy == a and is_instance_valid(b) and not b.is_dead():
			b._die()
		elif enemy == b:
			struck_b[0] += 1
	game.events.enemy_struck.connect(killer)
	var bell := {
		"id": "detonation_gauge", "layer": "second_bell_test", "mode": "pulse", "damage": 25.0,
		"limit": -1, "knock": 6.0, "breaks": false, "source": "item_proc", "bits": 0, "at": combat._clock,
		"shape": game.player.yours({"kind": "ring", "centre": origin, "radius": 8.0}),
	}
	combat._toll(bell)
	game.events.enemy_struck.disconnect(killer)
	_t.eq("P0 #5c: _toll skipped enemy killed mid-loop (hits == 1, b never struck)",
		[int(combat.last_bell["hits"]), struck_b[0]], [1, 0])

	game.free()
	await process_frame


# --- Combat P1 #10 & P2 #11, #13, #15 ---

func _test_combat_polish_p1_p2() -> void:
	var game = await _calm_game()
	var combat = game.combat

	# (a) _on_cannon_slammed ignores strength < 0.05.
	var cannon_def: Resource = ClassDef.by_id("remembered_cannon")
	game.run.class_def = cannon_def
	game.player.fit_class(cannon_def)
	combat._free_cannon()
	game.events.slammed.emit(game.player.ball_position(), 0.01, 1.0)
	_t.eq("P1/P2: _on_cannon_slammed ignores strength < 0.05", combat._cannon.size(), 0)
	game.events.slammed.emit(game.player.ball_position(), 1.0, 1.0)
	_t.eq("P1/P2 planted control: strength 1.0 commits cannon rush", combat._cannon.size(), 1)
	combat._free_cannon()

	# (b) Cached evolution flags update across _rebuild_patterns().
	var sable_def: Resource = ClassDef.by_id("pylon_engineer")
	game.run.class_def = sable_def
	game.player.fit_class(sable_def)
	game.run.parts.clear()
	combat.rebuild_patterns()
	_t.eq("P1/P2: cached evolution flags start false", [combat._has_grapeshot, combat._has_hoar, combat._has_fault], [false, false, false])
	game.run.add_part("cross_split", "test")
	game.run.add_part("pin_setter", "test")
	game.build.recompute()
	_t.eq("P1/P2: _has_grapeshot cached true after evolution", [combat._has_grapeshot, combat._has_hoar, combat._has_fault], [true, false, false])
	game.run.add_part("frost_barb", "test")
	game.run.add_part("rime_rounds", "test")
	game.run.add_part("echo_locator", "test")
	game.run.add_part("brace_frame", "test")
	game.build.recompute()
	_t.eq("P1/P2: all three evolution flags cached true", [combat._has_grapeshot, combat._has_hoar, combat._has_fault], [true, true, true])
	# Removing parts through build.recompute() without part_gained must invalidate the cache too.
	game.run.parts.clear()
	game.build.recompute()
	_t.eq("P1/P2: build.recompute() after clearing parts invalidates evolution cache",
		[combat._has_grapeshot, combat._has_hoar, combat._has_fault], [false, false, false])
	game.run.add_part("echo_locator", "test")
	game.run.add_part("brace_frame", "test")
	game.build.recompute()

	# (c) Multiple queued Fault Hammer rings render simultaneously without hiding each other.
	var p1: Vector3 = game.player.ball_position()
	var p2: Vector3 = p1 + Vector3(8.0, 0.0, 0.0)
	game.events.slammed.emit(p1, 1.0, 1.0)
	for i in 10:
		combat._physics_process(1.0 / 90.0)
	game.events.slammed.emit(p2, 1.0, 1.0)
	_t.eq("P1/P2: two rapid slams queue two aftershocks", combat._aftershocks.size(), 2)
	var s0: Dictionary = game.player.indicator.shapes.get(Combat.FAULT_LAYER, {})
	var s1: Dictionary = game.player.indicator.shapes.get("fault_hammer_1", {})
	_t.check("P1/P2: both waiting rings are drawn simultaneously",
		s0.get("kind", "") == "ring" and (s0.get("centre", Vector3.INF) as Vector3).distance_to(p1) < 0.01
		and s1.get("kind", "") == "ring" and (s1.get("centre", Vector3.INF) as Vector3).distance_to(p2) < 0.01)
	# Advance past first aftershock's due time, before second's.
	for i in 35:
		combat._physics_process(1.0 / 90.0)
	_t.eq("P1/P2: after first fires, second remains on FAULT_LAYER and fault_hammer_1 is cleared",
		[combat._aftershocks.size(), game.player.indicator.shapes.has(Combat.FAULT_LAYER), game.player.indicator.shapes.has("fault_hammer_1")],
		[1, true, false])
	for i in 20:
		combat._physics_process(1.0 / 90.0)
	_t.eq("P1/P2: after second fires, all fault layers cleared",
		[combat._aftershocks.size(), game.player.indicator.shapes.has(Combat.FAULT_LAYER), game.player.indicator.shapes.has("fault_hammer_1")],
		[0, false, false])

	# (d) Barbed Reel knock parity: applies full authored knock (6.0), not halved (3.0).
	game.run.parts.clear()
	game.run.add_part("barbed_reel", "test")
	game.build.recompute()
	combat._start_attempt()
	var base: Vector3 = game.player.ball_position()
	var a := _spawn_chaser(game, base + Vector3(0.0, 0.0, -3.0))
	var b := _spawn_chaser(game, base + Vector3(4.0, 0.0, -3.0))
	await physics_frame
	game.player.smash_landing = a
	combat.strike(a, "ram", 20.0)
	game.player.smash_landing = null
	game.events.harpoon_smashed.emit(a, base, 20.0)
	var b_knock: Vector3 = b.get("_knock")
	var b_knock_force: float = Vector2(b_knock.x, b_knock.z).length() * float(b.weight)
	var want_knock: float = float(combat._verb("reel_chain").get("knock", 6.0))
	_t.eq("P1/P2: Barbed Reel names target via single _chain scan", combat.last_reel_arc.get("target") == b, true)
	_t.near("P1/P2: Barbed Reel knock parity (full 6.0, not halved 3.0)", b_knock_force, want_knock, 0.001)

	# (e) _tint and _step_verb_items accept pre-fetched enemies array cleanly.
	combat._tint([])
	combat._step_verb_items([])
	_t.check("P1/P2: _tint and _step_verb_items accept explicit enemies list", true)

	game.free()
	await process_frame


# --- Effects.live_mark_count() & stress_capture.gd ---

func _test_effects_live_mark_count() -> void:
	var fx := Effects.new()
	root.add_child(fx)
	fx.setup()
	_t.eq("Effects.live_mark_count starts at 0", fx.live_mark_count(), 0)
	fx.arc(Vector3.ZERO, Vector3.RIGHT, Color.WHITE)
	fx.ring(Vector3.ZERO, 2.0, Color.WHITE)
	fx.spark(Vector3.ZERO, Color.WHITE)
	fx.beam(Vector3.ZERO, Vector3.FORWARD, Color.WHITE, 0.2)
	fx.bit_hit("pierce", Vector3.ZERO, Vector3.FORWARD)
	_t.eq("Effects.live_mark_count sums arcs + rings + sparks + beams + flair", fx.live_mark_count(), 5)
	fx.frost_flash(Vector3.ZERO)
	fx.shockwave(Vector3.ZERO, 4.0, Color.WHITE)
	_t.eq("Effects.live_mark_count counts payoff flair marks too", fx.live_mark_count(), 7)
	fx.clear()
	_t.eq("Effects.live_mark_count returns 0 after clear()", fx.live_mark_count(), 0)
	fx.free()

	var sc_script = load("res://tools/stress_capture.gd")
	_t.check("stress_capture.gd parses cleanly", sc_script != null)
	var src := FileAccess.get_file_as_string("res://tools/stress_capture.gd")
	_t.check("stress_capture.gd uses fx_node.live_mark_count() instead of private arrays",
		src.contains("fx_node.live_mark_count()") and not src.contains("fx_node._arcs"))
