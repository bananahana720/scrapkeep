extends RefCounted

# Times every handler connected to the named GameEvents signals (bot_run --entry-profile=1).
# Each connection is replaced, in its original order and with its flags, by a wrapper that
# calls it and records its main-thread ms. Handlers connected after time_signals() are not timed.
# Rows: {"signal", "args", "f", "total_ms", "handlers": [[label, ms], ...]} sorted slowest first; signals under MIN_MS in a frame are dropped.

const MIN_MS := 5.0

var rows: Array[Dictionary] = []
var frame := 0
var _pending := {}


var _events: Object
var _names: Array = []
# A connection does not keep its object alive.
var _wrappers: Array = []


# Call again (flush does) to time handlers connected since; the timed ones are kept as they are.
func time_signals(events: Object, names: Array) -> void:
	_events = events
	_names = names
	for signal_name: String in names:
		var connections: Array = events.get_signal_connection_list(signal_name).filter(func(c): return not (c.callable.get_object() is Timed))
		for c in connections:
			events.disconnect(signal_name, c.callable)
		for c in connections:
			var callable: Callable = c.callable
			var label := _label(callable)
			var count: int = events.get_signal_list().filter(func(s): return s.name == signal_name)[0].args.size()
			# One object per handler: Godot treats one method bound to different arguments as one callable.
			var timed := Timed.new(self, signal_name, callable, label)
			_wrappers.append(timed)
			var arities := [timed.zero, timed.one, timed.two, timed.three, timed.four, timed.five]
			events.connect(signal_name, arities[count], c.flags)


class Timed:
	extends RefCounted
	var timer
	var signal_name: String
	var callable: Callable
	var label: String

	func _init(owner, name: String, target: Callable, text: String) -> void:
		timer = owner
		signal_name = name
		callable = target
		label = text

	func zero() -> void:
		timer._timed([], signal_name, callable, label)

	func one(a) -> void:
		timer._timed([a], signal_name, callable, label)

	func two(a, b) -> void:
		timer._timed([a, b], signal_name, callable, label)

	func three(a, b, c) -> void:
		timer._timed([a, b, c], signal_name, callable, label)

	func four(a, b, c, d) -> void:
		timer._timed([a, b, c, d], signal_name, callable, label)

	func five(a, b, c, d, e) -> void:
		timer._timed([a, b, c, d, e], signal_name, callable, label)


func _timed(args: Array, signal_name: String, callable: Callable, label: String) -> void:
	var started := Time.get_ticks_usec()
	callable.callv(args)
	var ms := (Time.get_ticks_usec() - started) / 1000.0
	var key := "%s:%d" % [signal_name, frame]
	if not _pending.has(key):
		_pending[key] = {"signal": signal_name, "args": str(args), "f": frame, "total_ms": 0.0, "handlers": []}
	_pending[key].total_ms += ms
	_pending[key].handlers.append([label, snappedf(ms, 0.01)])


# Moves the finished signals into rows; call once a frame.
func flush() -> void:
	for key in _pending:
		var row: Dictionary = _pending[key]
		row.handlers.sort_custom(func(x, y): return x[1] > y[1])
		row.total_ms = snappedf(row.total_ms, 0.01)
		if row.total_ms >= MIN_MS:
			rows.append(row)
	_pending.clear()
	if is_instance_valid(_events):
		time_signals(_events, _names)


static func _label(callable: Callable) -> String:
	var target := callable.get_object()
	var where := ""
	if target != null:
		var script = target.get_script()
		where = script.resource_path.get_file() if script != null else target.get_class()
	return "%s.%s" % [where, callable.get_method()]
