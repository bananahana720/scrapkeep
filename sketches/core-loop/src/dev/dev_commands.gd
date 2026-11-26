extends RefCounted

signal said(line: String, tone: String)

const HISTORY_CAP := 64

var _rows := {}
var _order: Array[String] = []
var history: Array[String] = []


func add(name: String, usage: String, help: String, run: Callable) -> void:
	assert(not _rows.has(name), "dev command declared twice: %s" % name)
	_rows[name] = {"usage": usage, "help": help, "run": run}
	_order.append(name)


func has(name: String) -> bool:
	return _rows.has(name)


func names() -> Array[String]:
	return _order.duplicate()


func usage(name: String) -> String:
	return "%s %s" % [name, _rows[name].usage] if _rows.has(name) else ""


func help(name: String) -> String:
	return String(_rows[name].help) if _rows.has(name) else ""


func complete(text: String) -> Array[String]:
	var head := text.strip_edges(true, false)
	var matches: Array[String] = []
	for name in _order:
		if name.begins_with(head):
			matches.append(name)
	return matches


func run(line: String, remember := true) -> Array[String]:
	var replies: Array[String] = []
	var trimmed := line.strip_edges()
	if trimmed.is_empty():
		return replies
	if remember and (history.is_empty() or history[-1] != trimmed):
		history.append(trimmed)
		if history.size() > HISTORY_CAP:
			history.pop_front()
	for part in trimmed.split(";", false):
		replies.append(run_one(part))
	return replies


func run_one(text: String) -> String:
	var words := text.strip_edges().split(" ", false)
	if words.is_empty():
		return ""
	var name := words[0].to_lower()
	if not _rows.has(name):
		var near := complete(name)
		var reply := "!no command '%s'%s" % [name, (", try: " + ", ".join(near.slice(0, 4))) if not near.is_empty() else ""]
		said.emit(reply, "warn")
		return reply
	var args: Array[String] = []
	for i in range(1, words.size()):
		args.append(words[i])
	var result = _rows[name].run.call(args)
	var reply := String(result) if result != null else ""
	if not reply.is_empty():
		said.emit(reply, "warn" if reply.begins_with("!") else "ok")
	return reply


static func number(args: Array[String], index: int, fallback: float) -> float:
	if index >= args.size() or not args[index].is_valid_float():
		return fallback
	return args[index].to_float()


static func whole(args: Array[String], index: int, fallback: int) -> int:
	if index >= args.size() or not args[index].is_valid_int():
		return fallback
	return args[index].to_int()


static func word(args: Array[String], index: int, fallback := "") -> String:
	return args[index] if index < args.size() else fallback


static func flag(args: Array[String], index: int, current: bool) -> bool:
	var value := word(args, index, "").to_lower()
	if value in ["on", "1", "true", "yes"]:
		return true
	if value in ["off", "0", "false", "no"]:
		return false
	return not current
