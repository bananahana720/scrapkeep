extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Tuning := preload("res://src/movement/tuning.gd")

# Compaction (DEMO-SPEC, reconciled.json owner B): the shell is drawn from mass and
# parts, not the scrap wallet. After add_scrap(120) and a 40-scrap purchase, the chunk
# count is not lower and heft is higher. After lose_scrap(30) the chunk count drops and
# the lost chunks fly off. With mass and parts restored, the shell redraw is
# idempotent. The shell grows a step per heft class while the collider stays 1 m. A
# Warden's scrap lands in a line along the ball's heading.

var _game
var _build
var _failures := 0
var _ticks := 0
var _phase := 0
var _state := {}


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_ticks += 1
	if _ticks == 1:
		_game.ctx.calm = true
		_game.player.source = Intent.Scripted.new()
		_game.flow.press_start()
		_game.flow.choose_class(0)
		_build = _game.ctx.build
		return false
	if _ticks < 12:
		return false
	match _phase:
		0:
			_check_purchase()
			_start_theft()
		1:
			_check_theft()
			_check_idempotent()
			_check_shell()
			_check_warden_line()
			print("build_compaction_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
			_game.free()
			quit(0 if _failures == 0 else 1)
			return true
	_phase += 1
	return false


func _check_purchase() -> void:
	var run = _game.run
	run.add_scrap(120, Vector3.ZERO)
	var chunks_before: int = _build.accretion.chunk_count()
	var heft_before: float = run.heft()
	var mass_before: float = run.mass
	var spent: bool = run.spend_scrap(40)
	run.add_part("slag_rounds", "fabricator")
	_report("purchase compacts", spent and _build.accretion.chunk_count() >= chunks_before and run.heft() > heft_before
			and is_equal_approx(run.mass, mass_before) and run.scrap == 80,
		"add_scrap(120) then a 40-scrap purchase: chunks %d -> %d, heft %.3f -> %.3f, mass %.0f -> %.0f, wallet %d"
			% [chunks_before, _build.accretion.chunk_count(), heft_before, run.heft(), mass_before, run.mass, run.scrap])


func _start_theft() -> void:
	_state["chunks"] = _build.accretion.chunk_count()
	_state["taken"] = _game.run.lose_scrap(30, _game.player.ball_position() + Vector3(12.0, 2.0, 0.0), "crane")
	_state["flung"] = _build.accretion.flung_count()


func _check_theft() -> void:
	_report("theft drops chunks", _state["taken"] == 30 and _build.accretion.chunk_count() < _state["chunks"] and _state["flung"] > 0
			and _state["flung"] == _state["chunks"] - _build.accretion.chunk_count(),
		"lose_scrap(30) took %d mass: chunks %d -> %d, %d flung toward the crane"
			% [_state["taken"], _state["chunks"], _build.accretion.chunk_count(), _state["flung"]])


func _check_idempotent() -> void:
	var run = _game.run
	var first := [_build.accretion.chunk_count(), _build.accretion.piece_count(), _build.accretion.shell_class()]
	_build.recompute()
	_build.recompute()
	var again := [_build.accretion.chunk_count(), _build.accretion.piece_count(), _build.accretion.shell_class()]
	_game.flow.retry_stage()
	var restored := [_build.accretion.chunk_count(), _build.accretion.piece_count(), _build.accretion.shell_class()]
	_build.recompute()
	var restored_again := [_build.accretion.chunk_count(), _build.accretion.piece_count(), _build.accretion.shell_class()]
	_report("shell redraw is idempotent", first == again and restored == restored_again and restored == [0, 0, 1]
			and run.mass == 0.0,
		"chunks, pieces, class %s, %s after two recomputes; %s after a retry to the stage start, %s after another"
			% [first, again, restored, restored_again])


func _check_shell() -> void:
	var run = _game.run
	var small: float = _build.accretion.scale.x
	run.add_scrap(300, Vector3.ZERO)
	var big: float = _build.accretion.scale.x
	var shape: CollisionShape3D = null
	for child in _game.player.body().get_children():
		if child is CollisionShape3D:
			shape = child
	var radius: float = (shape.shape as SphereShape3D).radius
	_report("shell grows, collider stays", big > small and run.heft_class() >= 3 and is_equal_approx(radius, Tuning.RADIUS),
		"heft class %d: shell scale %.2f -> %.2f; collider radius %.2f m" % [run.heft_class(), small, big, radius])


func _check_warden_line() -> void:
	var scrap = _build.scrap
	var before: int = scrap.count()
	var at: Vector3 = _game.player.ball_position() + Vector3(0.0, 0.0, 30.0)
	_game.run.record_kill("warden", at, 12)
	var added: Array = scrap._items.slice(before)
	var far := 0.0
	for item in added:
		far = maxf(far, Vector2((item as Node3D).global_position.x - at.x, (item as Node3D).global_position.z - at.z).length())
	_report("warden scrap lines out", added.size() == 12 and far >= 15.0 and far <= 23.0,
		"a Warden worth 12 scrap dropped %d pieces reaching %.1f m along the heading" % [added.size(), far])
