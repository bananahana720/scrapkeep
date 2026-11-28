extends SceneTree

const Game := preload("res://src/game.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const Augments := preload("res://src/movement/augments.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")

# Knockback by weapon class (v3 W11), through combat's real hit on real chasers: at the
# same damage a gun nudges, a bomb or blast throws and a ram pushes about as hard, all
# read from the weapon and ability rows. Then the feedback kicks: a shot, a throw, a
# blast beside the ball, a ram, a rebound, a dodge and a hit taken move the camera and
# the shell only; the ball's velocity is exactly what it was.

const DAMAGE := 12.0

var _game
var _failures := 0
var _frame := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _process(_delta: float) -> bool:
	if _game == null or _game.flow == null:
		return false
	_frame += 1
	if _frame == 1:
		_knockback()
		_game.player._rigid.set_velocity_now(Vector3(3.0, 0.0, -17.0))
		return false
	if _frame < 6:
		return false
	_kicks()
	print("combat_knockback_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


func _knockback() -> void:
	_game.ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(0)
	var combat = _game.combat
	var impact: Dictionary = EventKinds.IMPACT
	var shoves := {
		"rapid_laser": impact["runner"]["knock"],
		"arc_caster": impact["arc"]["knock"],
		"pylon_turret": impact["turret"]["knock"],
		"sticky_charge": impact["sticky"]["knock"],
		"discharge": impact["burst"]["knock"],
		"detonation_line": impact["line"]["knock"],
		"overdrive": impact["overdrive"]["knock"],
		"ram": impact["ram"]["knock"],
	}
	var kinds := {"rapid_laser": "runner", "arc_caster": "arc", "pylon_turret": "turret", "sticky_charge": "sticky", "discharge": "turret",
		"detonation_line": "line", "overdrive": "runner", "ram": "ram"}
	var sources := {"discharge": "burst", "overdrive": "overdrive"}
	var moved := {}
	var keys := {}
	var current := [""]
	var note := func(_enemy: Node3D, _kind: String, _force: float) -> void:
		keys[current[0]] = String(combat.last_impact.get("key", ""))
	_game.events.enemy_struck.connect(note)
	var i := 0
	for id in shoves:
		var at: Vector3 = _game.player.ball_position() + Vector3(40.0 + 8.0 * i, 0.0, 40.0)
		var enemy: Node3D = combat.spawn_enemy("chaser", _game.ctx.terrain.drop_point(at.x, at.z, 1.0))
		enemy.hp = 1000.0
		current[0] = id
		combat.deal_hit(enemy, kinds[id], DAMAGE, Vector3.RIGHT, shoves[id], "", "", sources.get(id, ""))
		moved[id] = enemy._knocked_speed()
		i += 1
	_game.events.enemy_struck.disconnect(note)
	_check("the impact key rides its own hit", keys.get("overdrive", "?") == "overdrive" and keys.get("discharge", "?") == "burst"
			and keys.get("rapid_laser", "?") == "" and keys.get("ram", "?") == "" and combat.last_impact.is_empty(),
		"while enemy_struck is out combat names the row: overdrive '%s', discharge '%s', laser '%s', ram '%s'; after the hit the record is empty (%s)"
			% [keys.get("overdrive", "?"), keys.get("discharge", "?"), keys.get("rapid_laser", "?"), keys.get("ram", "?"), combat.last_impact.is_empty()])
	var pinned := Weapons.BASE[Weapons.RAPID_LASER]["knock"] == 3.0 and Weapons.BASE[Weapons.STICKY_CHARGE]["knock"] == 26.0 \
		and Weapons.OVERDRIVE_KNOCK == 34.0 and Weapons.BURST_KNOCK == 24.0 and Weapons.LINE_KNOCK == 28.0 \
		and Weapons.BASE[Weapons.ARC_CASTER]["knock"] == 5.0 and Weapons.BASE[Weapons.PYLON_TURRET]["knock"] == 6.0
	_check("knock sizes held", pinned and moved["sticky_charge"] > Weapons.PIN_MIN_SPEED,
		"laser 3, arc 5, turret 6, sticky 26, burst 24, line 28, overdrive 34 as before the table; a sticky hit moves %.1f m/s against the pin floor %.0f"
			% [moved["sticky_charge"], Weapons.PIN_MIN_SPEED])
	var guns := maxf(moved["rapid_laser"], maxf(moved["arc_caster"], moved["pylon_turret"]))
	var blasts := minf(moved["sticky_charge"], minf(moved["discharge"], minf(moved["detonation_line"], moved["overdrive"])))
	var listed := PackedStringArray()
	for id in moved:
		listed.append("%s %.1f" % [id, moved[id]])
	_check("guns nudge, bombs throw", guns * 3.0 <= blasts and moved["ram"] > guns * 3.0,
		"at %.0f damage the shove in m/s: %s" % [DAMAGE, ", ".join(listed)])


func _kicks() -> void:
	var combat = _game.combat
	var ball = _game.player
	var before: Vector3 = ball._rigid.linear_velocity
	var state_before: Vector3 = ball.state.velocity
	var events = _game.events
	var here: Vector3 = ball.ball_position()
	var foe: Node3D = combat.spawn_enemy("chaser", here + Vector3(0.0, 0.0, -3.0))
	events.shot_fired.emit("rapid_laser", here, here + Vector3(0.0, 0.0, -20.0))
	events.shot_fired.emit("sticky_charge", here, here + Vector3(0.0, 0.0, -12.0))
	events.sticky_detonated.emit(here + Vector3(1.5, 0.0, 0.0), false)
	events.enemy_struck.emit(foe, "ram", 20.0)
	events.enemy_rebounded.emit(foe, 12.0)
	events.near_miss.emit("threat_lane", here)
	events.player_hit.emit(8.0, "chaser")
	_game.presentation.juice.flush()
	var after: Vector3 = ball._rigid.linear_velocity
	var juice = _game.presentation.juice
	var kicked: bool = juice.hook_log.has(["kick", "shot_fired"]) and juice.hook_log.has(["kick", "sticky_detonated"]) \
		and juice.hook_log.has(["kick", "enemy_struck"]) and juice.hook_log.has(["kick", "enemy_rebounded"])
	_check("kicks leave the ball alone", after == before and ball.state.velocity == state_before and kicked and before.length() > 5.0,
		"after a shot, a throw, a blast 1.5 m away, a ram, a rebound, a dodge and a hit taken (camera kicks fired %s), the ball's velocity %s is %s"
			% [kicked, after, "unchanged" if after == before else "changed from %s" % before])


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
