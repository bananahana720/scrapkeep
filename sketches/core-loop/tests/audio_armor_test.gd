extends SceneTree

const Harmony := preload("res://src/presentation/harmony.gd")
const Synth := preload("res://src/presentation/synth.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const Audio := preload("res://src/presentation/audio.gd")
const Rows := preload("res://src/presentation/rows.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const RunState := preload("res://src/core/run_state.gd")
const ScrapField := preload("res://src/build/scrap_field.gd")

# The armour cues (durability prototype, DESIGN-NOTES "Armour sounds"): a hit the scrap
# absorbs sounds as plates shedding and not as hurt, a hit that reaches the hull is hurt,
# a recovered spill cluster chimes higher through a quick run, and with the flag off the
# cues for a scripted hit sequence are the base game's. Cue decisions are read from
# audio.cue_log, so this is the director's choice, not a listening test.

class FakeBuild:
	extends RefCounted
	var scrap

class FakeCtx:
	extends RefCounted
	var events: Node
	var run
	var build

var _failures := 0
var _nodes: Array = []


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


# A director on a real run state and a real scrap field, baked, with an empty cue log.
func _rig(armor: bool) -> Dictionary:
	var events := GameEvents.new()
	var run := RunState.new(events)
	run.begin(load("res://src/core/class_def.gd").new())
	run.armor_mode = armor
	var field := ScrapField.new()
	field.setup()
	root.add_child(field)
	var build := FakeBuild.new()
	build.scrap = field
	var ctx := FakeCtx.new()
	ctx.events = events
	ctx.run = run
	ctx.build = build
	var audio := Audio.new()
	audio.setup(ctx)
	audio.bake_now()
	audio.cue_log.clear()
	_nodes.append_array([events, field, audio])
	return {"run": run, "audio": audio, "field": field, "events": events}


# What one action played: [kind, sound] per cue. The per-sound gap runs on real time, so
# it is cleared first to keep a scripted sequence deterministic.
func _played(audio, action: Callable) -> Array:
	audio._last_start.clear()
	audio.cue_log.clear()
	action.call()
	var out := []
	for cue in audio.cue_log:
		if cue[2] == "now":
			out.append([cue[0], cue[1]])
	return out


# The scrap field reads global positions, so the checks run once the tree is live.
func _process(_delta: float) -> bool:
	_bank()
	_shed_and_hurt()
	_reclaim()
	_deflect()
	_flag_off()
	for node in _nodes:
		node.free()
	print("audio_armor_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
	return true


func _bank() -> void:
	var bad := []
	for id in ["armor_shed_small", "armor_shed", "armor_shed_big", "armor_reclaim", "armor_deflect"]:
		var buf := SfxBank.samples(id)
		var peak := 0.0
		for s in buf:
			peak = maxf(peak, absf(s))
		var seconds := buf.size() / float(SfxBank.RATE)
		if not SfxBank.has_recipe(id) or peak < 0.1 or peak > 0.95 or seconds < 0.1 or seconds > 0.6:
			bad.append("%s peak %.2f %.2fs" % [id, peak, seconds])
	_check("bank", bad.is_empty(), "5 armour recipes bake non-silent under 0.95 peak and 0.6 s; failing %s" % [bad])
	var shed := EventKinds.LOOT_ROWS["armor_hit"]
	var reclaim := EventKinds.LOOT_ROWS["armor_reclaim"]
	var hurt := EventKinds.row("player_hit")
	_check("one source", Rows.sound("armor_hit") == "armor_shed" and Rows.sound("armor_reclaim") == "armor_reclaim"
			and shed["sound"] != hurt["sound"] and shed["color"] != hurt["color"]
			and reclaim["color"] == EventKinds.color("scrap_collected") and Audio.KEYED_SOUNDS.has("armor_reclaim"),
		"rows resolve to their own ids; the shed is not the hurt cue in sound or colour; the reclaim shares scrap's colour and follows the live key")


func _shed_and_hurt() -> void:
	# Armour only: 100 scrap, a 5 HP hit takes 50 scrap and nothing from the hull.
	var rig := _rig(true)
	var run: RunState = rig["run"]
	run.grant_start_mass(100.0)
	var soft := _played(rig["audio"], func(): run.damage(5.0, "t"))
	var hurts := soft.filter(func(c): return c[1] == "hurt")
	var sheds := soft.filter(func(c): return String(c[1]).begins_with("armor_shed"))
	_check("absorbed hit sheds plates", sheds.size() == 1 and hurts.is_empty() and is_equal_approx(run.hp, run.max_hp),
		"a 5 HP hit on 100 scrap played %s, hull untouched at %.0f" % [soft, run.hp])
	# Reaching the hull: 20 scrap left, a 12 HP hit takes it all and 10 HP of hull.
	run.mass = 20.0
	var hard := _played(rig["audio"], func(): run.damage(12.0, "t"))
	_check("hull hit is hurt", hard.size() == 2 and String(hard[0][1]).begins_with("armor_shed") and hard[1][1] == "hurt" and run.metrics["hull_damage"] > 0.0,
		"a 12 HP hit on 20 scrap played %s (plates first, then hurt), hull damage %.0f" % [hard, run.metrics["hull_damage"]])
	# No scrap left: the hull takes the whole hit, so it is hurt and there is nothing to shed.
	var bare := _played(rig["audio"], func(): run.damage(6.0, "t"))
	_check("bare hull is hurt", bare == [["player_hit", "hurt"]], "a 6 HP hit on no scrap played %s" % [bare])
	# A new run on the same director: hull_damage restarts below the old total, and its first
	# hull hit must still be heard.
	var old_total: float = run.metrics["hull_damage"]
	run.begin(load("res://src/core/class_def.gd").new())
	run.armor_mode = true
	run.mass = 0.0
	var second := _played(rig["audio"], func(): run.damage(2.0, "t"))
	_check("second run hurt", second == [["player_hit", "hurt"]] and run.metrics["hull_damage"] < old_total,
		"after a run that took %.0f hull damage, a 2 HP bare hit in the next run played %s" % [old_total, second])
	# A new run started through the bus, as flow does: its first hull hit equal to the
	# previous run's total must still sound.
	var before_total: float = run.metrics["hull_damage"]
	run.begin(load("res://src/core/class_def.gd").new())
	run.armor_mode = true
	run.mass = 0.0
	rig["events"].run_started.emit("sable")
	var equal := _played(rig["audio"], func(): run.damage(before_total, "t"))
	_check("new run, equal hit, hurt", equal == [["player_hit", "hurt"]],
		"after run_started, a %.0f HP bare hit equal to the last run's hull total played %s" % [before_total, equal])
	# Size follows the scrap removed: a bigger clatter is a bigger sound, lower and louder.
	var sizes := []
	var pitches := []
	for removed in [30.0, 100.0, 200.0]:
		rig["audio"]._last_start.clear()
		rig["audio"].cue_log.clear()
		rig["audio"]._on_armor_hit(removed, 0, "t")
		var cue: Array = rig["audio"].cue_log[0]
		sizes.append(cue[1])
		pitches.append(float(cue[4]))
	_check("size follows scrap", sizes == ["armor_shed_small", "armor_shed", "armor_shed_big"] and pitches[0] > pitches[1] and pitches[1] > pitches[2],
		"30, 100 and 200 scrap removed play %s at pitches %s" % [sizes, pitches])


func _reclaim() -> void:
	var rig := _rig(true)
	var field: ScrapField = rig["field"]
	var audio = rig["audio"]
	field.drop_recovery(null, Vector3.ZERO, Vector3.FORWARD, 60, 4, RandomNumberGenerator.new())
	var items: Array = field._items.duplicate()
	audio.cue_log.clear()
	for item in items:
		field.step(item.global_position, 0.0, 0.016)
	var chimes: Array = audio.cue_log.filter(func(c): return c[1] == "armor_reclaim" and c[2] == "now")
	var rising := chimes.size() >= 3
	for i in range(1, chimes.size()):
		rising = rising and float(chimes[i][4]) > float(chimes[i - 1][4])
	var pitches := chimes.map(func(c): return snappedf(float(c[4]), 0.001))
	_check("reclaim chime climbs", rising and field.recovery_count() == 0,
		"4 recovered clusters played %d chimes at pitches %s; the spill is gone" % [chimes.size(), pitches])
	# A pause longer than the window starts the run over.
	audio.reclaim_streak.last_ms -= 5000
	field.drop_recovery(null, Vector3.ZERO, Vector3.FORWARD, 20, 1, RandomNumberGenerator.new())
	audio.cue_log.clear()
	field.step(field._items[0].global_position, 0.0, 0.016)
	var restart: Array = audio.cue_log.filter(func(c): return c[1] == "armor_reclaim")
	_check("reclaim run restarts", restart.size() == 1 and is_equal_approx(float(restart[0][4]), 1.0), "after a pause the next chime plays at %s" % [restart.map(func(c): return c[4])])
	# Recovery is silent to the pickup chain: it is no scrap_collected.
	_check("no pickup cue", audio.cue_log.filter(func(c): return c[0] == "scrap_collected").is_empty(), "recovering a cluster played no scrap_tick")


# A hit turned aside entirely (mitigation 100 percent here: no scrap removed, no hull
# damage) plays the soft deflect tick and neither shed nor hurt; a shed and a hull hit
# stay as they were.
func _deflect() -> void:
	var rig := _rig(true)
	var run: RunState = rig["run"]
	run.grant_start_mass(100.0)
	run.mitigation = 1.0
	var aside := _played(rig["audio"], func(): run.damage(5.0, "t"))
	_check("deflected hit ticks", aside == [["armor_deflect", "armor_deflect"]] and is_equal_approx(run.hp, run.max_hp) and is_equal_approx(run.mass, 100.0),
		"a fully mitigated 5 HP hit played %s, scrap %.0f, hull %.0f" % [aside, run.mass, run.hp])
	# A deflect item (the run's own hook) turns aside a hit the same way.
	run.mitigation = 0.0
	run.deflect_hook = func(_source: String) -> bool: return true
	var hooked := _played(rig["audio"], func(): run.damage(9.0, "t"))
	_check("deflect item ticks", hooked == [["armor_deflect", "armor_deflect"]], "a deflect-hook hit played %s" % [hooked])
	run.deflect_hook = Callable()
	# The next hit is not read as deflected because of the last one: it sheds.
	var shed := _played(rig["audio"], func(): run.damage(5.0, "t"))
	_check("shed unchanged", shed.size() == 1 and String(shed[0][1]).begins_with("armor_shed"), "the next 5 HP hit played %s" % [shed])
	run.mass = 20.0
	var hull := _played(rig["audio"], func(): run.damage(12.0, "t"))
	_check("hull hit unchanged", hull.size() == 2 and String(hull[0][1]).begins_with("armor_shed") and hull[1][1] == "hurt",
		"a 12 HP hit on 20 scrap played %s" % [hull])
	var buf := SfxBank.samples("armor_deflect")
	var seconds := buf.size() / float(SfxBank.RATE)
	var row := EventKinds.LOOT_ROWS["armor_deflect"]
	_check("tick is its own", seconds < 0.15 and seconds >= 0.1 and row["sound"] == "armor_deflect" and row["sound"] != "hurt"
			and not String(row["sound"]).begins_with("armor_shed") and row["sound"] != "armor_reclaim" and SfxBank.trim_db("armor_deflect") <= -9.0,
		"deflect is %.2f s at trim %.0f dB, its own sound id" % [seconds, SfxBank.trim_db("armor_deflect")])


# Flag off, a scripted hit sequence plays the base game's cues: one hurt per hit, nothing
# armour, and no chime because no cluster ever exists. Each cue matches the base by name,
# pitch and volume: hurt at the bank trim plus the row's priority level plus the hit's
# own size, at pitch 1, computed here from the bank and the row and not from audio.gd.
func _flag_off() -> void:
	var rig := _rig(false)
	var run: RunState = rig["run"]
	var signature := []
	var amounts := [3.0, 12.0, 40.0, 8.0]
	var expected := []
	for amount in amounts:
		var cues := _played_full(rig["audio"], func(): run.damage(amount, "t"))
		signature.append(cues)
		var db: float = snappedf(SfxBank.trim_db("hurt") + Audio.PRIORITY_DB[Rows.priority("player_hit")] + clampf(amount / 10.0, 0.0, 1.0) * 4.0 - 4.0, 0.0001)
		expected.append([["player_hit", "hurt", 1.0, db]])
	_check("flag off is the base", signature == expected and rig["field"].recovery_count() == 0,
		"4 scripted hits played [kind, sound, pitch, dB] %s against base %s" % [signature, expected])
	print("off_signature: %s" % [signature])


# Like _played, with each cue's pitch and volume.
func _played_full(audio, action: Callable) -> Array:
	audio._last_start.clear()
	audio.cue_log.clear()
	action.call()
	var out := []
	for cue in audio.cue_log:
		if cue[2] == "now":
			out.append([cue[0], cue[1], snappedf(float(cue[4]), 0.0001), snappedf(float(cue[5]), 0.0001)])
	return out
