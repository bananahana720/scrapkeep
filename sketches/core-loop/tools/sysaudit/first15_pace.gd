extends "res://tools/bot_run.gd"

# Systems audit pass E (docs/systems-audit/first-15/): the pace of a world 1 run, one row a game
# second, so a chart can show how hard each minute is beside what it teaches. Wraps bot_run and reads
# only; the run is bot_run's. One seed per process (bot_run forks children that run bot_run.gd
# itself, so a second seed would not be logged):
#
#   godot --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/sysaudit/first15_pace.gd \
#     -- --out=<abs dir> --policy=random --seeds=<n> --table=park --until=2
#
# Writes <out>/pace-<seed>.ndjson on one clock, the run's in-play seconds (run.run_time):
#   a "second" row each game second: stage, hp, hp_max, enemies (live "enemy" group nodes), hits and
#     damage taken that second, kills that second;
#   a "lesson" row the first time each lesson shows: a key prompt or first-meet tip (prompt_shown,
#     "prompt:<verb>") or an objective row ("objective:<id>", the HUD's objective_reading), the same
#     ids tools/first_timer.gd counts.

var _hooked: Object = null
var _pace: FileAccess = null
var _next_t := 1.0
var _hits := 0
var _damage := 0.0
var _kills := 0
var _lessons := {}


func _physics_process(delta: float) -> bool:
	var over := super(delta)
	if _game != null and _game != _hooked and _game.events != null:
		_hooked = _game
		_pace = FileAccess.open(_out.path_join("pace-%d.ndjson" % _seeds[_index]), FileAccess.WRITE)
		_game.events.player_hit.connect(_on_hit)
		_game.events.enemy_killed.connect(_on_kill)
		_game.events.prompt_shown.connect(func(verb: String): _lesson("prompt:" + verb))
	if _pace != null and _game != null and _game == _hooked and _game.run != null and _game.hud != null \
			and _game.flow.in_play():
		var id: String = _game.hud.objective_reading()["id"]
		if id != "":
			_lesson("objective:" + id)
	if _pace != null and _game != null and _game == _hooked and _game.run != null and _game.run.run_time >= _next_t:
		_next_t += 1.0
		_pace.store_line(JSON.stringify({"kind": "second", "t": snappedf(_game.run.run_time, 0.1), "stage": _game.run.stage,
			"hp": snappedf(_game.run.hp, 0.1), "hp_max": snappedf(_game.run.max_hp, 0.1),
			"enemies": _game.get_tree().get_nodes_in_group("enemy").size(), "hits": _hits,
			"damage": snappedf(_damage, 0.1), "kills": _kills}))
		_hits = 0
		_damage = 0.0
		_kills = 0
	# bot_run frees the game and returns false at a run's normal end, so close once the game is gone.
	if _pace != null and (over or _game == null):
		_pace.close()
		_pace = null
	return over


func _lesson(id: String) -> void:
	if _pace == null or _lessons.has(id) or _game == null or _game.run == null:
		return
	_lessons[id] = true
	_pace.store_line(JSON.stringify({"kind": "lesson", "t": snappedf(_game.run.run_time, 0.1), "stage": _game.run.stage, "id": id}))


func _on_hit(amount: float, _source: String) -> void:
	_hits += 1
	_damage += amount


func _on_kill(_kind: String, _at: Vector3, _scrap: int) -> void:
	_kills += 1
