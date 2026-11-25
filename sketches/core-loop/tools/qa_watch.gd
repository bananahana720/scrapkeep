extends "res://src/core/play_watch.gd"


const DETAIL_M := 15.0
const TOLD := ["fell", "wedged"]
const TOLD_PREFIX := "play-watch: "

var _driver
var _file: FileAccess


func setup(game, driver, path: String) -> void:
	_driver = driver
	_file = FileAccess.open(path, FileAccess.WRITE)
	watch(game, _write)


func _write(row: Dictionary) -> void:
	_file.store_line(JSON.stringify(row))
	_file.flush()
	if String(row.get("kind", "")) in TOLD:
		print(TOLD_PREFIX + JSON.stringify(row))


func _who() -> Dictionary:
	return {"goal": String(_driver.get("_goal")) if _driver != null else ""}


func _detail(ball: Vector3) -> Dictionary:
	var out := super(ball)
	var boss = _driver._boss() if _game.flow.state_name() == "boss" and _driver.has_method("_boss") else null
	if boss != null and boss.has_method("pickups_left"):
		var near := []
		for p in boss.pickups_left():
			if ball.distance_to(p["at"]) < DETAIL_M:
				near.append({"at": _v(p["at"]), "source": p["source"], "d": snappedf(ball.distance_to(p["at"]), 0.1)})
		out["pickups"] = near
	return out
