extends "res://tools/bot_run.gd"


const SAMPLE_TICKS := 9

var _tally := {}
var _cost := {}


func _physics_process(delta: float) -> bool:
	var out := super._physics_process(delta)
	if _game != null and _game.run != null and _ticks % SAMPLE_TICKS == 0:
		var sum := 0
		for enemy in get_nodes_in_group("enemy"):
			if enemy is Node3D and (enemy as Node3D).is_visible_in_tree():
				sum += _surfaces(enemy)
		if sum > 0:
			var stage := int(_game.run.stage)
			if not _tally.has(stage):
				_tally[stage] = []
			_tally[stage].append(sum)
	if _game != null and _game.run != null and _settings.get("whole", "0") == "1" and _ticks % (SAMPLE_TICKS * 5) == 0:
		_whole(int(_game.run.stage))
	return out


var _worst := {}


func _whole(stage: int) -> void:
	var by := {}
	var total := 0
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		var geo := node as GeometryInstance3D
		if not geo.is_visible_in_tree():
			continue
		var mesh: Mesh = null
		if geo is MeshInstance3D:
			mesh = (geo as MeshInstance3D).mesh
		elif geo is MultiMeshInstance3D and (geo as MultiMeshInstance3D).multimesh != null:
			mesh = (geo as MultiMeshInstance3D).multimesh.mesh
		var n := 1 if mesh == null else mesh.get_surface_count()
		var owner_node: Node = geo
		while owner_node != null and owner_node.get_script() == null:
			owner_node = owner_node.get_parent()
		var key := "none" if owner_node == null else String((owner_node.get_script() as Script).resource_path.get_file())
		by[key] = int(by.get(key, 0)) + n
		total += n
	if total > int(_worst.get(stage, {}).get("total", 0)):
		_worst[stage] = {"total": total, "by": by}


func _surfaces(enemy: Node) -> int:
	var id := enemy.get_instance_id()
	if _cost.has(id):
		return _cost[id]
	var n := 0
	for node in enemy.find_children("*", "GeometryInstance3D", true, false):
		var geo := node as GeometryInstance3D
		if not geo.is_visible_in_tree():
			continue
		var mesh: Mesh = null
		if geo is MeshInstance3D:
			mesh = (geo as MeshInstance3D).mesh
		elif geo is MultiMeshInstance3D and (geo as MultiMeshInstance3D).multimesh != null:
			mesh = (geo as MultiMeshInstance3D).multimesh.mesh
		if mesh == null:
			continue
		var passes := 1 if geo.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF else 2
		n += mesh.get_surface_count() * passes
	_cost[id] = n
	return n


func _finish() -> void:
	for stage in _tally:
		var s: Array = _tally[stage]
		s.sort()
		print("enemy_draw_tally: ", JSON.stringify({"stage": stage, "samples": s.size(), "p50": s[s.size() / 2],
			"p99": s[mini(s.size() - 1, int(s.size() * 0.99))], "max": s[-1]}))
	for stage in _worst:
		var by: Dictionary = _worst[stage]["by"]
		var keys := by.keys()
		keys.sort_custom(func(a, b): return by[a] > by[b])
		var top := {}
		for k in keys.slice(0, 25):
			top[k] = by[k]
		print("enemy_draw_tally_whole: ", JSON.stringify({"stage": stage, "total": _worst[stage]["total"], "top": top}))
	super._finish()
