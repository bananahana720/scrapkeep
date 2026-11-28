extends SceneTree

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Roster := preload("res://src/combat/roster.gd")
const CombatCodex := preload("res://src/combat/codex_entries.gd")
const CodexWorld := preload("res://src/world/codex_world.gd")
const BossCodex := preload("res://src/boss/codex_entries.gd")
const WindupRows := preload("res://src/presentation/windup_rows.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const Synth := preload("res://src/presentation/synth.gd")
const Registry := preload("res://tests/support/content_registry.gd")

const WARNINGS := {
	"burrower": "warn_burrow", "drill_crew": "warn_bore", "lamp_swarm": "warn_lure",
	"line_cutter": "warn_cut", "anchor_crew": "warn_winch", "kite_drone": "warn_dive",
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var t := T.new("audio_row_coverage_test")
	_check_rows(t)
	await _check_windups(t)
	quit(t.verdict())


func _check_rows(t) -> void:
	var measures := {}
	for kind in WARNINGS:
		var id: String = WARNINGS[kind]
		t.eq("windup sound " + kind, WindupRows.ROWS.get(kind, {}).get("sound", ""), id)
		t.check("recipe " + id, SfxBank.has_recipe(id))
		var wav := SfxBank.stream(id)
		var peak := Synth.wav_peak(wav)
		var seconds := wav.data.size() / 2.0 / wav.mix_rate
		t.check("peak " + id, peak >= 0.1, "peak %.4f" % peak)
		t.eq("16-bit " + id, wav.format, AudioStreamWAV.FORMAT_16_BITS)
		t.check("length " + id, seconds > 0.02 and seconds < 0.6, "%.6f s" % seconds)
		var samples := SfxBank.samples(id)
		t.check("not fallback blip " + id, samples.size() != int(0.12 * SfxBank.RATE), "%d samples" % samples.size())
		measures[id] = {"size": samples.size(), "peak": peak}
		var roster := Roster.row(kind)
		var rows := CombatCodex.ENTRIES.filter(func(row): return row.id == roster.get("mechanic", ""))
		if t.eq("codex row " + kind, rows.size(), 1):
			t.eq("roster text " + kind, rows[0].text, roster["line"])
			t.check("codex fields " + kind, not rows[0].name.is_empty() and not rows[0].hint.is_empty() and not rows[0].clue.is_empty())
	var ids: Array = measures.keys()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a: Dictionary = measures[ids[i]]
			var b: Dictionary = measures[ids[j]]
			t.check("distinct %s / %s" % [ids[i], ids[j]], a.size != b.size or a.peak != b.peak)
	var seen := {}
	for row in CombatCodex.ENTRIES + CodexWorld.ENTRIES + BossCodex.all():
		t.check("unique codex id " + row.id, not seen.has(row.id))
		seen[row.id] = true
	for table in ["windup_rows.ROWS", "combat.codex_entries.ENTRIES"]:
		var rows = WindupRows.ROWS if table == "windup_rows.ROWS" else CombatCodex.ENTRIES
		t.eq("golden digest " + table, Registry.digest(rows), Registry.GOLDEN_HASHES[table])


func _check_windups(t) -> void:
	var game := Game.new()
	game.test_mode = true
	game.table = "slice"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.ctx.calm = true
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(0)
	game.player.set_frozen(true)
	await physics_frame
	for enemy in get_nodes_in_group("enemy"):
		enemy.free()
	for kind in WARNINGS:
		if not Roster.built(kind):
			print("SKIP windup %s: enemy script does not exist yet" % kind)
			continue
		var enemy = game.combat.spawn_enemy(kind, game.ctx.terrain.drop_point(-70.0, -70.0, 2.0))
		if not t.check("spawn " + kind, enemy != null and enemy.kind == kind):
			continue
		enemy.set_physics_process(false)
		game.presentation.audio.cue_log.clear()
		# World crews use Counter's real warning entry, which commits and publishes aim.
		if t.check("windup entry " + kind, enemy.has_method("_warn")):
			enemy._warn(Vector3.FORWARD)
			var heard := false
			for cue in game.presentation.audio.cue_log:
				heard = heard or cue[1] == WARNINGS[kind]
			t.check("row drives sound " + kind, heard, WARNINGS[kind])
		enemy.free()
	game.free()
