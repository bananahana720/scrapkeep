extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")

# The vault: a static plated cache. It never moves and never attacks (no player_hit in
# HOLD seconds with the ball parked beside it and rammed into it), its plating is the
# next stage's Warden plating (StageDefs: 80 on stage 1, 140 on stage 2) and combat's
# VAULT_TOP_SCALE (1.2) times its own Warden's on stage 3 (168). Hits land in full only
# when punch reaches the plating (probed just under and just over it at heft 1, against
# the live plating, since each probe's shred lowers it for the next), and breaking it
# publishes enemy_killed with kind "vault".

const HOLD := 10.0
const SCALE := 3.0

var _game
var _combat
var _source := Intent.Scripted.new()
var _failures := 0
var _phase := "setup"
var _sim := 0.0
var _vault: Node3D
var _home := Vector3.ZERO
var _drift := 0.0
var _hits := 0
var _kills: Array = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(check: String, ok: bool, detail: String) -> void:
	print("[%s] %s -> %s" % [check, detail, "PASS" if ok else "FAIL"])
	if not ok:
		_failures += 1


func _physics_process(delta: float) -> bool:
	if _game.flow == null:
		return false
	match _phase:
		"setup":
			_setup()
		"hold":
			_sim += delta
			_drift = maxf(_drift, _vault.global_position.distance_to(_home))
			if _sim >= HOLD:
				Engine.time_scale = 1.0
				_report("static", _drift < 0.001 and _hits == 0,
					"over %.0f s with the ball parked against it: moved %.4f m, player_hit %d" % [HOLD, _drift, _hits])
				_plating_rule()
				_plating_by_stage()
				return _finish()
	return false


func _setup() -> void:
	_combat = _game.ctx.spawner
	var ctx = _game.ctx
	ctx.calm = true
	ctx._hit_stop = Callable()
	_game.player.source = _source
	_game.events.player_hit.connect(func(_a: float, _s: String): _hits += 1)
	_game.events.enemy_killed.connect(func(kind: String, _at: Vector3, _scrap: int): _kills.append(kind))
	_game.flow.press_start()
	_game.flow.choose_class(1)
	_game.run.set_max_hp(99999.0)
	_combat.heft_override = 1.0
	var spawn: Vector3 = ctx.terrain.spawn_point(1)
	var heading: Vector3 = ctx.terrain.entry_heading(1)
	var at: Vector3 = spawn + heading * 20.0
	_vault = ctx.spawner.spawn_enemy("vault", at)
	_home = _vault.global_position
	# Park the ball just short of it, rolling into it, and ram it once.
	var ball: Vector3 = _vault.global_position - heading * 3.2
	ball.y = ctx.terrain.height(ball.x, ball.z) + 1.05
	_game.player.reset_to(ball, heading * 6.0)
	_game.player.body().global_position = ball
	_combat.strike(_vault, "ram", 6.0)
	Engine.time_scale = SCALE
	_phase = "hold"


func _plating_rule() -> void:
	var plating: float = _combat.plating_of(_vault)
	var checks := []
	# [kind, force offset from the live threshold, expect full]
	# Forces just under and just over the plating at heft 1: runner punch is its force,
	# ram (14 + 1.3 v) and stomp (30 + 1.1 v).
	for row in [["runner", -10.0, false], ["runner", 0.0, true], ["ram", -5.0, false], ["ram", 1.0, true],
			["stomp", -5.0, false], ["stomp", 1.0, true]]:
		var live: float = _combat.plating_of(_vault)
		var at: float = {"runner": live, "ram": (live - 14.0) / 1.3, "stomp": (live - 30.0) / 1.1}[row[0]]
		var force: float = at + row[1]
		var before: float = _vault.hp
		var deflections: int = _combat.deflections
		var punch: float = _combat.punch_of(row[0], force)
		_combat.strike(_vault, row[0], force)
		var dealt: float = before - _vault.hp
		var full: bool = _combat.deflections == deflections
		var expected: float = punch if row[2] else punch * 0.2
		checks.append("%s %.0f against %.1f: punch %.1f -> %.1f %s" % [row[0], force, live, punch, dealt, "full" if full else "chip"])
		if full != row[2] or not is_equal_approx(dealt, expected):
			_failures += 1
			print("[plating_rule] %s %.0f dealt %.2f, expected %.2f -> FAIL" % [row[0], force, dealt, expected])
	_report("plating_rule", plating == StageDefs.of(2)["warden_plating"], "stage 1 vault plating %.0f; %s" % [plating, "; ".join(checks)])
	while not _vault.is_dead():
		_combat.strike(_vault, "runner", 400.0)
	_report("kill", _kills == ["vault"], "breaking it published enemy_killed %s" % [_kills])


func _plating_by_stage() -> void:
	var seen := []
	for stage in [2, 3]:
		_game.flow.enter_stage(stage, Vector3.ZERO, false)
		var ctx = _game.ctx
		var at: Vector3 = ctx.terrain.spawn_point(stage) + ctx.terrain.entry_heading(stage) * 20.0
		var vault: Node3D = ctx.spawner.spawn_enemy("vault", at)
		seen.append([_combat.plating_of(vault), vault.max_hp])
	var want_2: float = StageDefs.of(3)["warden_plating"]
	var want_3: float = roundf(_combat.VAULT_TOP_SCALE * StageDefs.of(3)["warden_plating"])
	_report("by_stage", seen == [[want_2, 800.0], [want_3, 1200.0]] and want_3 > StageDefs.of(3)["warden_plating"],
		"stage 2 vault plating %.0f / hp %.0f, stage 3 plating %.0f / hp %.0f (needs %.0f/800 and %.0f/1200, above Warden III's %.0f)"
			% [seen[0][0], seen[0][1], seen[1][0], seen[1][1], want_2, want_3, StageDefs.of(3)["warden_plating"]])


func _finish() -> bool:
	Engine.time_scale = 1.0
	var ok := _failures == 0
	print("combat_vault_test: %s" % ("PASS" if ok else "FAIL"))
	_game.free()
	quit(0 if ok else 1)
	return true
