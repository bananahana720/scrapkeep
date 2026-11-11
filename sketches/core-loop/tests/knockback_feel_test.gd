extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Augments := preload("res://src/movement/augments.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const CombatRules := preload("res://src/combat/combat.gd")

# Knockback feel (KNOCKBACK-FEEL, 2026-10-17). Drives the real ball into real chasers,
# prints one JSON line per case prefixed "KNOCKLAB " (and appends them to the ndjson file
# KNOCKLAB_OUT names, when set) for before/after tables, then holds the targets:
#   speed   a blazing ram throws at least 1.8x as hard as a cruise bump (heft I)
#   growth  the same ram at heft IV (a grown depth-4 build) flies 1.9x to 2.6x as far as at
#           heft I, and heft V no more than 3x (Andrew's
#           "Clearly mightier", 16:36Z 17 Oct: late-run knockback about 2x the first fight)
#   cap     speed past Contact.SOFT_CAP_SPEED adds no throw; no ram passes KNOCK_CEILING
#   bowling a ram at fast speed or more into a six-pin rack topples all six and lands at
#           least 3 pins at every heft (the hulk: a killed body bowls on)
#   roll-up at heft V the rack is wiped: a grown ball's pins kill what they scatter, so
#           bowling never knocks fodder clear of the Katamari roll-up (hive clear rule)
#   keystone a haul from 10 m at heft V throws the chaser at least 1.9x as far as at heft I
#   posture a hulk never pins a Warden, so stagger timing is untouched
#   impact  hit-stop and shake follow the throw: a blazing heft V ram stops 15 ms longer and
#           shakes harder than a cruise bump, inside the 60 ms and 0.5 caps
#   damage  the ram's and the slam's strike force do not change with the new throw
# The cases:
#   ram:   one chaser, ball speed x heft; the knock speed, how far it flies in 1.2 s,
#          the hit-stop juice asked for and whether the hit killed it.
#   rack:  five chasers racked 1-2-2 like bowling pins; how many topple, pins, kills
#          and the mean scatter.
#   haul:  the keystone, for real: bite a chaser from HAUL_FROM m away and haul in; the
#          closing speed, the landed chaser's throw and a chaser 4 m behind it.
#   smash: the harpoon haul's landing (the shockwave the smash lands) at a closing
#          speed x heft over a ring of six chasers 2 to 7 m out.
# Chasers take hp 1000 in the ram and smash cases so the knock is measured, not the
# kill; the rack runs at real chaser health so the Katamari pass shows.
# Evidence limit: placed starts on one flat stretch of the Spillway, chasers on calm; not a
# player's run and not feel.

const SPEEDS := [8.0, 16.0, 27.0, 45.0, 60.0]
const HEFTS := [1.0, 2.2, 4.6]
const SMASH_SPEEDS := [12.0, 30.0, 48.0]
const FLY_SECONDS := 1.2
const HAUL_FROM := [10.0, 25.0]

var _game
var _base := Vector3.ZERO
var _stops: Array = []
var _source := Intent.Scripted.new()
var _closing := -1.0
var _rows: Array = []
var _failures := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _sim(seconds: float) -> void:
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		await physics_frame


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await _sim(0.6)
	var juice = _game.presentation.juice
	juice.hit_stop_sink = func(seconds: float) -> void: _stops.append(seconds * 1000.0)
	_game.run.set_max_hp(99999.0)
	# Kills here would roll grey panel drops (IL-01), and a Ram Bumper scales the punch: no drops.
	_game.build.dropper.scale = 0.0
	_game.events.harpoon_smashed.connect(func(_e: Node3D, _at: Vector3, speed: float): _closing = speed)
	_base = _game.ctx.terrain.spawn_point(1) + Vector3(20.0, 0.0, 40.0)
	for heft in HEFTS + [3.2]:
		for speed in SPEEDS:
			await _ram_case(speed, heft)
	for heft in HEFTS:
		for speed in [16.0, 27.0, 45.0]:
			await _rack_case(speed, heft)
	for heft in HEFTS:
		for from in HAUL_FROM:
			await _haul_case(from, heft)
	for heft in HEFTS:
		for speed in SMASH_SPEEDS:
			await _smash_case(speed, heft)
	await _posture_case()
	_damage_case()
	_judge()
	_write_rows()
	print("knockback_feel_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _row(case: String, match: Dictionary) -> Dictionary:
	for row in _rows:
		if row["case"] != case:
			continue
		var ok := true
		for key in match:
			if not is_equal_approx(float(row.get(key, -1.0)), float(match[key])):
				ok = false
		if ok:
			return row
	return {}


func _judge() -> void:
	var cruise := _row("ram", {"speed": 8.0, "heft": 1.0})
	var blazing := _row("ram", {"speed": 27.0, "heft": 1.0})
	_check("speed", float(blazing["knock"]) >= 1.8 * float(cruise["knock"]),
		"heft I: a cruise bump throws %.1f m/s (%.1f m), a blazing ram %.1f m/s (%.1f m)"
			% [cruise["knock"], cruise["fly_m"], blazing["knock"], blazing["fly_m"]])
	var small := _row("ram", {"speed": 16.0, "heft": 1.0})
	var grown := _row("ram", {"speed": 16.0, "heft": 3.2})
	var top_heft := _row("ram", {"speed": 16.0, "heft": 4.6})
	var ratio := float(grown["fly_m"]) / maxf(0.1, float(small["fly_m"]))
	var top_ratio := float(top_heft["fly_m"]) / maxf(0.1, float(small["fly_m"]))
	_check("growth", ratio >= 1.9 and ratio <= 2.6 and top_ratio <= 3.0,
		"a fast ram flies %.1f m at heft I, %.1f m at heft IV (%.2fx, the power read's grown build) and %.1f m at heft V (%.2fx)"
			% [small["fly_m"], grown["fly_m"], ratio, top_heft["fly_m"], top_ratio])
	var bump := _row("ram", {"speed": 8.0, "heft": 1.0})
	var mid := _row("ram", {"speed": 8.0, "heft": 2.2})
	var huge := _row("ram", {"speed": 27.0, "heft": 4.6})
	_check("impact", float(huge["stop_ms"]) >= float(bump["stop_ms"]) + 15.0 and float(huge["shake"]) > float(bump["shake"])
			and float(huge["stop_ms"]) > float(mid["stop_ms"]) and float(huge["stop_ms"]) <= 60.0 and float(huge["shake"]) <= 0.5,
		"hit-stop and shake follow the throw: cruise heft I %.0f ms / %.2f, cruise heft II %.0f ms / %.2f, blazing heft V %.0f ms / %.2f (caps 60 ms, 0.5)"
			% [bump["stop_ms"], bump["shake"], mid["stop_ms"], mid["shake"], huge["stop_ms"], huge["shake"]])
	var top := 0.0
	for row in _rows:
		if row["case"] == "ram":
			top = maxf(top, float(row["knock"]))
	# Read by name, so this file still runs (and fails) on a build without the ceiling.
	var contact: GDScript = load("res://src/movement/contact.gd")
	var ceiling := float(contact.get_script_constant_map().get("KNOCK_CEILING", 0.0))
	var at60 := float(contact.call("ram_knock", Augments.RAM_KNOCK, 60.0, 2.2)) if ceiling > 0.0 else -1.0
	var at95 := float(contact.call("ram_knock", Augments.RAM_KNOCK, 95.0, 2.2)) if ceiling > 0.0 else -2.0
	_check("cap", ceiling > 0.0 and is_equal_approx(at60, at95) and top <= ceiling + 0.5,
		"a ram at 60 and 95 m/s throws %.1f and %.1f m/s; the hardest measured ram %.1f m/s against the ceiling %.0f"
			% [at60, at95, top, ceiling])
	var racks := PackedStringArray()
	var bowled := true
	for row in _rows:
		if row["case"] == "rack":
			racks.append("%.0f m/s heft %.1f: %d toppled, %d pins" % [row["speed"], row["heft"], row["toppled"], row["pins"]])
			bowled = bowled and int(row["toppled"]) == 6 and int(row["pins"]) >= 3
	_check("bowling", bowled, "; ".join(racks))
	var rolled := true
	for speed in [16.0, 27.0, 45.0]:
		rolled = rolled and int(_row("rack", {"speed": speed, "heft": 4.6}).get("kills", 0)) == 6
	_check("roll-up", rolled, "at heft V every rack is wiped within %.1f s: the strike's pins kill what they scatter" % FLY_SECONDS)
	var light := _row("haul", {"from": 10.0, "heft": 1.0})
	var heavy := _row("haul", {"from": 10.0, "heft": 4.6})
	_check("keystone", float(heavy["fly_m"]) >= 1.9 * float(light["fly_m"]),
		"a haul from 10 m throws the chaser %.1f m at heft I and %.1f m at heft V" % [light["fly_m"], heavy["fly_m"]])


# A hulk aimed straight through a Warden passes it by and still pins the chaser beyond.
func _posture_case() -> void:
	_clear()
	await physics_frame
	var combat = _game.combat
	if not combat.has_method("bowl_hulk"):
		_check("posture", false, "combat has no bowl_hulk: killed bodies do not bowl")
		return
	# This case's half-metre gaps were set with chasers at their own run speed. At the dam's 9 m/s (wave 37 unit
	# D2) the chaser beside the Warden has run 0.9 m by the time the hulk arrives and the Warden's posture moves
	# 0.1, so the case spawns its chasers at the old speed: it measures the hulk, not the chase.
	ChallengeDials.set_overrides({"mobs.chaser_speed_by_stage": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]})
	var warden: Node3D = combat.spawn_enemy("warden", _drop(_base.x + 3.0, _base.z))
	var beyond := _spawn(_drop(_base.x + 3.0, _base.z + 0.5), 1000.0)
	var dead := _spawn(_drop(_base.x, _base.z), 1000.0)
	await _sim(0.1)
	var posture0: float = warden.posture()
	combat.bowl_hulk(dead, Vector3.RIGHT, 30.0)
	await _sim(0.4)
	var posture1: float = warden.posture()
	# Control: the same pin, laid on the Warden directly, does move its posture, so an
	# unchanged posture above means the hulk passed it by.
	combat._pin(warden, Vector3.RIGHT, 30.0, 4.6)
	var posture2: float = warden.posture()
	_check("posture", is_equal_approx(posture1, posture0) and not is_equal_approx(posture2, posture1) and beyond.knocks > 0,
		"a 30 m/s hulk through a Warden: posture %.1f -> %.1f (a direct pin moves it to %.1f); the chaser beside it took %d pins"
			% [posture0, posture1, posture2, beyond.knocks])
	ChallengeDials.set_overrides({})
	warden.queue_free()


# The throw changed; the damage did not. The ram's punch is the old row and the slam's
# strike carries SLAM_KNOCK x strength x falloff whatever the heft.
func _damage_case() -> void:
	var combat = _game.combat
	combat.heft_override = 3.2
	var punch: float = combat.punch_of("ram", 20.0)
	var want: float = (CombatRules.STRIKE_DAMAGE["ram"][0] + 20.0 * CombatRules.STRIKE_DAMAGE["ram"][1]) * 3.2
	_check("damage", is_equal_approx(punch, want) and Augments.RAM_KNOCK == 24.0 and Augments.SLAM_KNOCK == 26.0,
		"a 20 m/s ram at heft 3.2 punches %.1f (row says %.1f); RAM_KNOCK %.0f, SLAM_KNOCK %.0f as before" % [punch, want, Augments.RAM_KNOCK, Augments.SLAM_KNOCK])


func _write_rows() -> void:
	var out := OS.get_environment("KNOCKLAB_OUT")
	if out == "":
		return
	var file := FileAccess.open(out, FileAccess.READ_WRITE if FileAccess.file_exists(out) else FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	for row in _rows:
		file.store_line(JSON.stringify(row))
	file.close()


func _set_heft(heft: float) -> void:
	_game.combat.heft_override = heft
	_game.player.heft_of = func() -> float: return heft


func _clear() -> void:
	for enemy in _game.get_tree().get_nodes_in_group("enemy"):
		enemy.queue_free()
	_game.combat.enemies.clear() if _game.combat.get("enemies") is Array else null
	_stops.clear()
	_game.presentation.juice.reset_stops()


func _drop(x: float, z: float) -> Vector3:
	return _game.ctx.terrain.drop_point(x, z, 1.6)


func _spawn(at: Vector3, hp: float) -> Node3D:
	var enemy: Node3D = _game.combat.spawn_enemy("chaser", at)
	if hp > 0.0:
		enemy.hp = hp
		enemy.max_hp = hp
	return enemy


# Rolls the ball along +x into whatever stands 7 m ahead, holding the speed until the
# first contact lands (or 1 s passes), then lets the ball run on.
func _roll_in(speed: float, watch: Array) -> void:
	var start: Vector3 = _drop(_base.x - 7.0, _base.z) + Vector3.UP * 0.2
	_game.player.reset_to(start, Vector3(speed, 0.0, 0.0))
	for i in 60:
		_game.player._rigid.set_velocity_now(Vector3(speed, _game.player._rigid.linear_velocity.y, 0.0))
		await physics_frame
		if watch.any(func(e): return not is_instance_valid(e) or e.knocks > 0 or e.is_dead()):
			return


func _ram_case(speed: float, heft: float) -> void:
	_clear()
	await physics_frame
	_set_heft(heft)
	var enemy := _spawn(_drop(_base.x, _base.z), 1000.0)
	enemy.live = func(): return false
	await _sim(0.1)
	var origin: Vector3 = enemy.global_position
	var hp0: float = enemy.hp
	await _roll_in(speed, [enemy])
	var knock: float = enemy._knocked_speed() if is_instance_valid(enemy) else 0.0
	var peak := knock
	for i in roundi(FLY_SECONDS * Engine.physics_ticks_per_second):
		await physics_frame
		if is_instance_valid(enemy):
			peak = maxf(peak, enemy._knocked_speed())
	var moved := 0.0
	if is_instance_valid(enemy):
		var d: Vector3 = enemy.global_position - origin
		moved = Vector2(d.x, d.z).length()
	_emit({"case": "ram", "speed": speed, "heft": heft, "knock": snappedf(peak, 0.1),
		"fly_m": snappedf(moved, 0.1), "dealt": snappedf(hp0 - (enemy.hp if is_instance_valid(enemy) else 0.0), 0.1),
		"stop_ms": snappedf(_stops.max() if not _stops.is_empty() else 0.0, 0.1), "shake": snappedf(_shake_for(peak), 0.01)})


func _rack_case(speed: float, heft: float) -> void:
	_clear()
	await physics_frame
	_set_heft(heft)
	var rack: Array = []
	var spots := [Vector2(0, 0), Vector2(2.6, -1.6), Vector2(2.6, 1.6), Vector2(5.2, -3.2), Vector2(5.2, 0.0), Vector2(5.2, 3.2)]
	var origins: Array = []
	for s in spots:
		var e := _spawn(_drop(_base.x + s.x, _base.z + s.y), 0.0)
		rack.append(e)
	await _sim(0.1)
	for e in rack:
		origins.append(e.global_position)
	var pins0: int = _game.combat.pins
	await _roll_in(speed, [rack[0]])
	var dead := {}
	for i in roundi(FLY_SECONDS * Engine.physics_ticks_per_second):
		await physics_frame
		for j in rack.size():
			if not is_instance_valid(rack[j]) or rack[j].is_dead():
				dead[j] = true
	var toppled := 0
	var scatter := 0.0
	var moved_n := 0
	for j in rack.size():
		var e = rack[j]
		var gone: bool = dead.has(j)
		var knocked: bool = is_instance_valid(e) and e.knocks > 0
		if gone or knocked:
			toppled += 1
		if knocked and not gone:
			var d: Vector3 = e.global_position - origins[j]
			scatter += Vector2(d.x, d.z).length()
			moved_n += 1
	_emit({"case": "rack", "speed": speed, "heft": heft, "toppled": toppled, "kills": dead.size(),
		"pins": _game.combat.pins - pins0, "scatter_m": snappedf(scatter / maxf(1.0, moved_n), 0.1)})


func _haul_case(from: float, heft: float) -> void:
	_clear()
	await physics_frame
	_set_heft(heft)
	var at: Vector3 = _drop(_base.x, _base.z)
	var target := _spawn(at, 1000.0)
	var behind := _spawn(_drop(_base.x + 4.0, _base.z), 1000.0)
	for e in [target, behind]:
		e.live = func(): return false
	await _sim(0.1)
	var origin: Vector3 = target.global_position
	var behind_origin: Vector3 = behind.global_position
	_closing = -1.0
	_game.player.reset_to(origin + Vector3(-from, 6.0, 0.0))
	_game.player.grapple_to(origin, Vector3.UP, target)
	_source.hold = {"harpoon_held": true}
	await _sim(0.02)
	_source.hold = {"harpoon_held": true, "brake_held": true}
	for tick in roundi(2.0 * Engine.physics_ticks_per_second):
		await physics_frame
		if _closing >= 0.0:
			break
	_source.hold = {}
	var peak := 0.0
	for t in roundi(FLY_SECONDS * Engine.physics_ticks_per_second):
		await physics_frame
		peak = maxf(peak, target._knocked_speed())
	var d: Vector3 = target.global_position - origin
	var b: Vector3 = behind.global_position - behind_origin
	_emit({"case": "haul", "from": from, "heft": heft, "closing": snappedf(_closing, 0.1), "knock": snappedf(peak, 0.1),
		"fly_m": snappedf(Vector2(d.x, d.z).length(), 0.1), "behind_m": snappedf(Vector2(b.x, b.z).length(), 0.1),
		"stop_ms": snappedf(_stops.max() if not _stops.is_empty() else 0.0, 0.1)})


func _smash_case(closing: float, heft: float) -> void:
	_clear()
	await physics_frame
	_set_heft(heft)
	var centre: Vector3 = _drop(_base.x, _base.z)
	_game.player.reset_to(centre + Vector3.UP * 0.4, Vector3.ZERO)
	var ring: Array = []
	var origins: Array = []
	for i in 6:
		var angle := TAU * float(i) / 6.0
		var reach := 2.0 + float(i)
		ring.append(_spawn(_drop(centre.x + cos(angle) * reach, centre.z + sin(angle) * reach), 1000.0))
	for e in ring:
		e.live = func(): return false
	await _sim(0.1)
	for e in ring:
		origins.append(e.global_position)
	_game.player._on_slammed(_game.player.ball_position(), closing, 1.0)
	var peaks := []
	peaks.resize(ring.size())
	peaks.fill(0.0)
	for t in roundi(FLY_SECONDS * Engine.physics_ticks_per_second):
		await physics_frame
		for j in ring.size():
			if is_instance_valid(ring[j]):
				peaks[j] = maxf(peaks[j], ring[j]._knocked_speed())
	var fly := []
	for j in ring.size():
		var d: Vector3 = ring[j].global_position - origins[j] if is_instance_valid(ring[j]) else Vector3.ZERO
		fly.append(snappedf(Vector2(d.x, d.z).length(), 0.1))
	_emit({"case": "smash", "speed": closing, "heft": heft, "knock_near": snappedf(peaks[0], 0.1),
		"fly_near_m": fly[0], "fly_far_m": fly[5], "reached": peaks.filter(func(p): return p > 1.0).size(),
		"stop_ms": snappedf(_stops.max() if not _stops.is_empty() else 0.0, 0.1)})


# The shake juice asks for at this throw. Read from juice's own rows: the live camera also
# shakes for landings and drops in the same window, so its amplitude cannot isolate the hit.
func _shake_for(throw: float) -> float:
	var juice: GDScript = load("res://src/presentation/juice.gd")
	if not juice.get_script_constant_map().has("THROW_SHAKE"):
		return 0.3
	var row: Array = juice.get_script_constant_map()["THROW_SHAKE"]
	return lerpf(row[0], row[1], float(juice.call("throw_share", throw)))


func _emit(row: Dictionary) -> void:
	_rows.append(row)
	print("KNOCKLAB " + JSON.stringify(row))
