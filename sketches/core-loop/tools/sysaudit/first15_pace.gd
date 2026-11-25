extends "res://tools/bot_run.gd"


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
