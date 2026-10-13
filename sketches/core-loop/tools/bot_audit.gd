extends RefCounted

var file: FileAccess
var driver
var objects := {}

func setup(bus: Node, bot, path: String) -> void:
	driver = bot
	file = FileAccess.open(path, FileAccess.WRITE)
	for entry in bus.get_script().get_script_signal_list():
		bus.connect(entry.name, Callable(self, "_event%d" % entry.args.size()).bind(entry.name))

func _write(name: String, args: Array) -> void:
	file.store_line(JSON.stringify({"tick": driver.ticks, "event": name, "args": _stable(args)}, "", true, true))

func _stable(value):
	if value is Vector3:
		return [value.x, value.y, value.z]
	if value is Vector2:
		return [value.x, value.y]
	if value is Array or value is PackedStringArray:
		var list := []
		for item in value:
			list.append(_stable(item))
		return list
	if value is Dictionary:
		var row := {}
		for key in value:
			row[str(key)] = _stable(value[key])
		return row
	if value is Object:
		var id: int = value.get_instance_id()
		if not objects.has(id):
			objects[id] = objects.size() + 1
		var script = value.get_script()
		var row := {"object": objects[id], "script": script.resource_path if script != null else value.get_class()}
		if value is Node3D and value.is_inside_tree():
			row.position = _stable(value.global_position)
		return row
	return value


func _event0(label: String) -> void:
	_write(label, [])


func _event1(a, label: String) -> void:
	_write(label, [a])


func _event2(a, b, label: String) -> void:
	_write(label, [a, b])


func _event3(a, b, c, label: String) -> void:
	_write(label, [a, b, c])


func _event4(a, b, c, d, label: String) -> void:
	_write(label, [a, b, c, d])


func _event5(a, b, c, d, e, label: String) -> void:
	_write(label, [a, b, c, d, e])


func _event6(a, b, c, d, e, f, label: String) -> void:
	_write(label, [a, b, c, d, e, f])


func _event7(a, b, c, d, e, f, g, label: String) -> void:
	_write(label, [a, b, c, d, e, f, g])
