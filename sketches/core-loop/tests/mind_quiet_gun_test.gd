extends "res://tests/cannon_ultimate_test.gd"
# 2026-10-12 (PC-CANNON): the answer must follow a non-zero live music key.
# 2026-10-12 (PC-CANNON): answer trim derives from mind_adapted's bank sound and priority.
# 2026-10-12 (PC-CANNON): stepping the quote clock also expires its wall-clock admission gap.
# 2026-10-11 (PC-CANNON): real Mind death, fallback, arena cleanup, notes and settle-once grants.
const EXPECTED_QUIET_CHECKS := 50
const Mind := preload("res://src/boss/mind.gd")
const QuietGun := preload("res://src/presentation/quiet_gun.gd")
const Palette := preload("res://src/core/palette.gd")
const Cosmetics := preload("res://src/core/cosmetics.gd")
const Achievements := preload("res://src/core/achievements.gd")
const Profile := preload("res://src/core/profile.gd")
const Progress := preload("res://src/core/progress.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const Rows := preload("res://src/presentation/rows.gd")


func _expected_checks() -> int:
	return EXPECTED_QUIET_CHECKS


func _safe(node: Node) -> bool:
	if node is CollisionObject3D or node is CollisionShape3D or node is Light3D:
		return false
	if node is MeshInstance3D and node.material_override != null:
		return false
	return node.get_children().all(func(child): return _safe(child))


func _cases() -> void:
	_t = T.new("mind_quiet_gun_test")
	await _reset()
	_game.run.class_def = ClassDef.by_id("pylon_engineer")
	var mind := Mind.new()
	root.add_child(mind)
	mind.setup(_game.ctx)
	mind.set_physics_process(false)
	mind.pad = StaticBody3D.new()
	mind.add_child(mind.pad)
	mind.pad.global_position = HOME
	mind.state = mind.FIGHT
	var housing_path := QuietGun.housing_path
	QuietGun.housing_path = "res://tests/no_quiet_gun_housing.glb"
	var gun = QuietGun.attach(mind)
	QuietGun.housing_path = housing_path
	gun.set_physics_process(false)
	_t.check("quiet gun is visual only", _safe(gun))
	_t.eq("fallback housing wears Old Verdigris", gun.barrel.get_node("BarrelHousing").mesh.material.albedo_color, Palette.VERDIGRIS)
	gun.step(0.0)
	_t.eq("gun waits for the intro", gun.lit, 0)
	mind.clock = 3.0
	for phase in range(1, 5):
		mind.phase = phase
		gun.step(0.0)
		_t.eq("one band per phase %d" % phase, gun.lit, phase)
		_t.eq("one family note per phase %d" % phase, gun.notes.back(), Harmony.motif_notes("cannon")[phase - 1])
	gun.step(0.0)
	_t.eq("same phase never repeats a note", gun.notes.size(), 4)
	_t.eq("bands use friendly ancient green", gun.bands[0].mesh.surface_get_material(0).albedo_color, Palette.ANCIENT)
	_t.check("green differs from hazard and brass", gun.bands[0].mesh.surface_get_material(0).albedo_color not in [Palette.HAZARD, Palette.BRASS])
	var discovered: Array = []
	_game.events.synergy_discovered.connect(func(id: String, _category: String, _first: bool): discovered.append(id))
	mind._on_warden_died(HOME, 0)
	gun.step(0.0)
	_t.check("the fall releases the gun", gun.fallen)
	_t.eq("the fall plays its whole motif", gun.notes.back(), [59, 64, 67, 74])
	gun.step(0.1)
	gun.step(0.1)
	_t.eq("the fall motif sounds once", gun.notes.size(), 5)
	gun.step(0.6)
	_t.check("the bore plug pops out", not gun.plug.visible)
	_t.eq("non-Cannon Mind fall discovers the quiet gun", discovered.count("mind_quiet_gun"), 1)
	_t.eq("non-Cannon never discovers Old Tune", discovered.count("cannon_old_tune"), 0)
	_game.run.class_def = ClassDef.by_id("remembered_cannon")
	mind.state = mind.FIGHT
	mind._on_warden_died(HOME, 0)
	mind._on_warden_died(HOME, 0)
	_t.eq("quiet gun discovery remains once", discovered.count("mind_quiet_gun"), 1)
	_t.eq("Cannon Mind fall discovers Old Tune once", discovered.count("cannon_old_tune"), 1)
	var empty = QuietGun.make("remembered_cannon")
	_t.eq("Cannon pilot has no quiet barrel", empty.bands.size(), 0)
	_t.check("empty cradle stays", empty.has_node("EmptyCradle") and not empty.has_node("Barrel"))
	empty.free()

	var audio = _game.presentation.audio
	audio.set_process(false)
	audio._cannon_queue.clear()
	audio.cannon_log.clear()
	audio._motif = "cannon"
	audio.bake_now()
	audio.engine.key = 3
	_game.events.mind_adapted.emit("slam", "ab_cannon_smash")
	var due: float = audio._cannon_queue.back()["due"]
	var wait: float = SfxBank.stream("mind_cannon").get_length() / Harmony.ratio(audio.live_key()) + float(audio.engine.beat_len()) / Harmony.RATE
	_t.near("answer follows the whole quote plus one beat", due - audio.clock, wait)
	audio.clock = due - 0.001
	audio._step_cannon_cues()
	_t.eq("answer never interrupts the quote", audio.cannon_log.size(), 0)
	audio.clock = due
	audio._last_start.erase("mind_cannon")
	audio._step_cannon_cues()
	_t.eq("one answer after the quote", audio.cannon_log.size(), 1)
	_t.eq("the answer is the right motif", audio.cannon_log.back()["notes"], [59, 64, 67, 74])
	var answer_sound := Rows.sound("mind_adapted", {"motif": "cannon"})
	_t.near("answer trim", audio.cannon_log.back()["db"], SfxBank.trim_db(answer_sound) + audio.PRIORITY_DB[Rows.priority("mind_adapted")])
	_t.near("Cannon answer follows the live key", audio.cue_log.back()[4], Harmony.ratio(3))
	_t.check("answer dresses the Mind adaptation fact", audio.cue_log.back()[0] == "mind_adapted" and audio.cue_log.back()[1] == answer_sound and audio.cue_log.back()[2] == "now", str(audio.cue_log.back()))
	var cues: Dictionary = audio.get_script().get_script_constant_map().get("CANNON_CUES", {})
	_t.check("Cannon cue table has no absolute db rows", not cues.is_empty() and cues.values().all(func(row): return not row.has("db")), str(cues))
	var cue_count: int = audio.cue_log_total
	audio.sound_ready = false
	audio.cannon_line(1)
	_t.check("Cannon uses shared admission while the bank is cold", audio.cue_log_total == cue_count + 1 and audio.cue_log.back()[2] == "skip")
	audio.sound_ready = true
	audio._cannon_threat_at = audio.clock
	var beat_delay: float = float(audio.engine.next_beat() - audio.engine.clock) / Harmony.RATE
	_t.check("a fresh warning moves the quiet note one beat", audio._cannon_beat_delay() >= beat_delay + float(audio.engine.beat_len()) / Harmony.RATE - 0.0001)

	var pilots: Array = ClassDef.all().map(func(def): return def.id)
	_t.eq("Cannon cosmetics validate", Cosmetics.validate(Cosmetics.ROWS, pilots), [])
	_t.eq("Cannon grants validate", Achievements.validate(Achievements.ROWS, Achievements.bus_signals(), pilots, Cosmetics.ids()), [])
	var path := "user://cannon-grants-%d.json" % OS.get_process_id()
	var profile := Profile.new(path)
	_t.check("fresh grant profile", profile.load_profile())
	var progress := Progress.new()
	progress.rows = {}
	for id in ["ach_cannon_recital", "ach_cannon_time_on_target", "ach_cannon_old_tune"]:
		progress.rows[id] = Achievements.ROWS[id]
	root.add_child(progress)
	var grant_events := preload("res://src/core/game_events.gd").new()
	var grant_run := preload("res://src/core/run_state.gd").new()
	progress.setup(grant_events, grant_run, profile)
	var earned: Array = []
	grant_events.achievement_earned.connect(func(id: String): earned.append(id))
	for id in progress.rows:
		var row: Dictionary = progress.rows[id]
		grant_events.synergy_discovered.emit(row["where"]["synergy_id"], "enemy", false)
		grant_events.synergy_discovered.emit(row["where"]["synergy_id"], "enemy", false)
		_t.check(id + " earned", profile.earned(id))
		_t.check(id + " grants its cosmetic", profile.has_cosmetic(row["reward"]["cosmetic"]))
		_t.eq(id + " announces once", earned.count(id), 1)
	var reload := Profile.new(path)
	_t.check("grant profile reloads", reload.load_profile())
	_t.check("all three grants persist", progress.rows.keys().all(func(id): return reload.earned(id) and reload.has_cosmetic(progress.rows[id]["reward"]["cosmetic"])))
	progress.free()
	grant_events.free()
	mind.pad = null
	gun._physics_process(0.0)
	_t.check("quiet gun leaves with the arena", gun.is_queued_for_deletion())
