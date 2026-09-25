extends RefCounted

# Godot's half of protocol v1 (tools/jev-player/protocol/PROTOCOL.md). One
# instance owns one <io> directory: it writes hello, state, events, error and
# done, and reads intent and abort. Validators return a list of
# {path, message}; an empty list means valid. Paths are the ones protocol.mjs
# reports, so both sides name a fault the same way.

enum Read { ABSENT, VALID, INVALID }

const PROTOCOL := "scrapkeep-jev/1"
const EVENTS_FILE := "events.ndjson"
const GRID_SLACK := 1e-9
const MAX_THREATS := 3

const INTENTS := [
	"push_objective",
	"sweep_scrap",
	"take_cache",
	"hit_kicker",
	"stomp_target",
	"ram_target",
	"evade_hazard",
	"retreat_regen",
	"start_exit",
]
const ARMS := {
	"random": ["seeded", "forced"],
	"scripted": ["rule", "forced"],
	"jev": ["live", "cache", "forced"],
}
const ERROR_CODES := ["internal", "intent_invalid", "intent_timeout"]
const ABORT_REASONS := ["interrupted", "arm_error", "replay_miss"]
const DONE_REASONS := ["complete", "aborted"]
const SPEED_TIERS := ["walk", "cruise", "fast", "blazing"]
const ANOMALIES := ["nan", "tunnel", "out_of_bounds", "overspeed"]

# A field's kind is a name checked by _kind_error, an Array of allowed strings,
# or null for a field whose contents are checked elsewhere. "int" is exact;
# "whole" and "tenth" are the jev block's grid checks with GRID_SLACK.
const HELLO := {
	"protocol": "protocol",
	"sketch": "string",
	"scenario": "string",
	"seed": "any_int",
	"physics_mode": "string",
	"godot": "string",
	"tick_hz": "int",
	"snapshot_every": "int",
	"hold_ticks": "int",
	"intent_timeout_s": "int",
}
const STATE := {
	"protocol": "protocol",
	"seq": "int",
	"tick": "int",
	"held": "held",
	"jev": null,
	"sim": null,
}
const INTENT := {
	"protocol": "protocol",
	"seq": "int",
	"intent": "intent_id",
	"arm": ["random", "scripted", "jev"],
	"source": "string",
	"meta": null,
}
const ERROR := {
	"protocol": "protocol",
	"code": ERROR_CODES,
	"seq": "seq_or_null",
	"tick": "int",
	"message": "string",
}
const ABORT := {"protocol": "protocol", "reason": ABORT_REASONS}
const ABORT_OPTIONAL := {"message": "string"}
const DONE := {
	"protocol": "protocol",
	"reason": DONE_REASONS,
	"tick": "int",
	"snapshots": "int",
	"trace_hash": "sha",
}

const JEV_STATE := {"self": null, "stage": null, "threats": null, "objective": null}
const JEV_STATE_OPTIONAL := {"scrap": null, "buffs": null}
const SELF := {"speed_ms": "tenth", "speed_tier": "tier", "grounded": "boolean"}
const SELF_OPTIONAL := {
	"hp": "whole",
	"air_jump_available": "boolean",
	"location": "string",
	"over": "string",
}
const STAGE := {"name": "string", "time_s": "whole", "tier": "whole"}
const THREAT := {"kind": "string"}
const THREAT_OPTIONAL := {
	"distance_m": "whole",
	"damage": "whole",
	"closing": "boolean",
	"impact_in_s": "tenth",
	"arc_lands_in_s": "tenth",
	"water_rises_in_s": "tenth",
	"on_current_line": "boolean",
	"targets_current_position": "boolean",
	"telegraphing": "boolean",
	"below": "boolean",
	"effect": "string",
	"lands_on": "string",
}
const OBJECTIVE := {"kind": "string", "distance_m": "whole"}
const OBJECTIVE_OPTIONAL := {"inside_ring": "boolean", "charge_started": "boolean"}
const SCRAP := {"held": "whole"}
const OPTION := {"id": "intent_id", "why": "string"}
const OPTION_OPTIONAL := {"requires_speed_ms": "tenth"}

# Each event kind's fields beyond {tick, kind}.
const EVENTS := {
	"trace": {"pos": "vec3", "vel": "vec3", "tier": "tier", "grounded": "boolean"},
	"intent": {"seq": "int", "intent": "intent_id"},
	"tier": {"from": "tier", "to": "tier"},
	"takeoff": {},
	"landing": {},
	"knock": {"strength": "number"},
	"stuck_begin": {},
	"stuck_end": {},
	"anomaly": {"what": ANOMALIES},
}

var dir: String
var _events: FileAccess
var _events_final := false
var _event_count := 0
var _event_order := {"last": -1, "trace_tick": null}
var _last_written := ""


func _init(io_dir: String) -> void:
	dir = ProjectSettings.globalize_path(io_dir)


# --- writing -----------------------------------------------------------------


func write_hello(fields: Dictionary) -> Array:
	var message := _message(fields)
	return _write_json("hello.json", message, validate_hello(message))


func write_state(fields: Dictionary) -> Array:
	var message := _message(fields)
	var errors := validate_state(message)
	var name := "state.json" if not errors.is_empty() else "state-%06d.json" % int(message.seq)
	return _write_json(name, message, errors)


# Appends one line to events.ndjson.tmp. The event's key order is its byte
# order, and trace_hash covers those bytes.
func append_event(event: Dictionary) -> Array:
	if _events_final or _last_written != "":
		return [_err(EVENTS_FILE, "is already renamed into place")]
	var order := _event_order.duplicate()
	var errors := []
	_check_event(errors, "events[%d]" % _event_count, event, order)
	if not errors.is_empty():
		return _prefixed(EVENTS_FILE, errors)
	var line = stringify(event)
	if line == null:
		return [_err(EVENTS_FILE, "holds a value JSON cannot carry")]
	if _events == null:
		_events = FileAccess.open(_path(EVENTS_FILE + ".tmp"), FileAccess.WRITE)
		if _events == null:
			return [_err(EVENTS_FILE, "cannot open: %s" % error_string(FileAccess.get_open_error()))]
	_events.store_string(line + "\n")
	_events.flush()
	_event_order = order
	_event_count += 1
	return []


func write_done(reason: String, tick: int, snapshots: int) -> Array:
	var errors := _finish_events()
	if not errors.is_empty():
		return errors
	var message := {
		"protocol": PROTOCOL,
		"reason": reason,
		"tick": tick,
		"snapshots": snapshots,
		"trace_hash": FileAccess.get_sha256(_path(EVENTS_FILE)),
	}
	return _write_json("done.json", message, validate_done(message), true)


# `seq` is the snapshot concerned, or null.
func write_error(code: String, seq: Variant, tick: int, text: String) -> Array:
	var errors := _finish_events()
	if not errors.is_empty():
		return errors
	var message := {"protocol": PROTOCOL, "code": code, "seq": seq, "tick": tick, "message": text}
	return _write_json("error.json", message, validate_error(message), true)


func _message(fields: Dictionary) -> Dictionary:
	var message := {"protocol": PROTOCOL}
	message.merge(fields)
	return message


func _write_json(name: String, message: Dictionary, errors: Array, last := false) -> Array:
	if _last_written != "":
		return [_err(name, "cannot follow %s, which is the last file" % _last_written)]
	if not errors.is_empty():
		return _prefixed(name, errors)
	var text = stringify(message)
	if text == null:
		return [_err(name, "holds a value JSON cannot carry")]
	var failure := _write_atomic(name, text + "\n")
	if failure != OK:
		return [_err(name, "cannot write: %s" % error_string(failure))]
	if last:
		_last_written = name
	return []


# events.ndjson.tmp becomes events.ndjson, empty if nothing was appended, before
# done.json or error.json is written.
func _finish_events() -> Array:
	if _last_written != "":
		return [_err(_last_written, "is already written; it is the last file")]
	if _events_final:
		return []
	var temporary := _path(EVENTS_FILE + ".tmp")
	if _events != null:
		_events.close()
		_events = null
	else:
		var empty := FileAccess.open(temporary, FileAccess.WRITE)
		if empty == null:
			return [_err(EVENTS_FILE, "cannot open: %s" % error_string(FileAccess.get_open_error()))]
		empty.close()
	var failure := DirAccess.rename_absolute(temporary, _path(EVENTS_FILE))
	if failure != OK:
		return [_err(EVENTS_FILE, "cannot rename: %s" % error_string(failure))]
	_events_final = true
	return []


func _write_atomic(name: String, text: String) -> Error:
	var temporary := _path(name + ".tmp")
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.flush()
	file.close()
	return DirAccess.rename_absolute(temporary, _path(name))


func _path(name: String) -> String:
	return dir.path_join(name)


# --- reading -----------------------------------------------------------------


# Reads intent-<seq>.json and judges it against the state it answers.
# Returns {status: Read, message, errors}; ABSENT until Node renames it in.
func read_intent(seq: int, state: Dictionary) -> Dictionary:
	var name := "intent-%06d.json" % seq
	var read := _read_json(name)
	if read.status == Read.VALID:
		_judge(read, name, validate_intent(read.message, state))
	return read


func read_abort() -> Dictionary:
	var read := _read_json("abort.json")
	if read.status == Read.VALID:
		_judge(read, "abort.json", validate_abort(read.message))
	return read


func _read_json(name: String) -> Dictionary:
	var path := _path(name)
	if not FileAccess.file_exists(path):
		return {"status": Read.ABSENT, "message": null, "errors": []}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {"status": Read.INVALID, "message": null, "errors": [_err(name + ":(root)", "is not JSON")]}
	return {"status": Read.VALID, "message": json.data, "errors": []}


func _judge(read: Dictionary, name: String, errors: Array) -> void:
	if not errors.is_empty():
		read.status = Read.INVALID
		read.errors = _prefixed(name, errors)


# --- validators ----------------------------------------------------------------


static func validate_hello(message: Variant) -> Array:
	var errors := []
	var ok := _shape(errors, "", message, HELLO)
	if ok and errors.is_empty():
		for key in ["tick_hz", "snapshot_every", "intent_timeout_s"]:
			if message[key] == 0:
				errors.append(_err(key, "must be > 0"))
		if message.hold_ticks >= message.snapshot_every:
			errors.append(_err("hold_ticks", "must be below snapshot_every, or the next snapshot lands before the intent applies"))
	return errors


static func validate_state(message: Variant) -> Array:
	var errors := []
	if not _shape(errors, "", message, STATE):
		return errors
	if message.has("jev"):
		_check_jev(errors, message.jev)
	if message.has("sim"):
		if message.sim is Dictionary:
			for key in ["pos", "vel"]:
				var text := _kind_error("vec3", message.sim.get(key))
				if text != "":
					errors.append(_err("sim." + key, text))
		else:
			errors.append(_err("sim", "must be an object"))
	return errors


# `state`, when it has a jev block, is the state-NNNNNN.json this intent
# answers; without one only the message itself is checked.
static func validate_intent(message: Variant, state: Variant = null) -> Array:
	var errors := []
	if not _shape(errors, "", message, INTENT):
		return errors
	var arm = message.get("arm")
	var source = message.get("source")
	if _is_str(arm) and ARMS.has(String(arm)) and not ARMS[String(arm)].has(source):
		errors.append(_err("source", "must be one of %s for the %s arm" % [", ".join(ARMS[String(arm)]), arm]))
	var meta = message.get("meta")
	if meta is not Dictionary:
		errors.append(_err("meta", "must be an object"))
	elif _same(arm, "jev"):
		var text := _kind_error("sha", meta.get("questions_sha"))
		if text != "":
			errors.append(_err("meta.questions_sha", "is required for the jev arm and " + text))
	if state is Dictionary and state.get("jev") is Dictionary:
		if not _same(message.get("seq"), state.get("seq")):
			errors.append(_err("seq", "must match the state's seq %s" % str(state.get("seq"))))
		var offered := offered_options(state.jev)
		var floor_hold := _same(arm, "jev") and not _same(source, "forced")
		var chosen = message.get("intent")
		if not (_is_str(chosen) and offered.has(String(chosen))) and not (floor_hold and _same(chosen, "push_objective")):
			errors.append(_err("intent", "must be one of the offered options " + ", ".join(offered)))
		if offered.size() == 1 and not _same(source, "forced"):
			errors.append(_err("source", "must be forced when a single option is offered"))
		elif offered.size() > 1 and _same(source, "forced"):
			errors.append(_err("source", "cannot be forced with %d options offered" % offered.size()))
	return errors


static func validate_error(message: Variant) -> Array:
	var errors := []
	_shape(errors, "", message, ERROR)
	return errors


static func validate_abort(message: Variant) -> Array:
	var errors := []
	_shape(errors, "", message, ABORT, ABORT_OPTIONAL)
	return errors


static func validate_done(message: Variant) -> Array:
	var errors := []
	_shape(errors, "", message, DONE)
	return errors


static func validate_events(text: String) -> Array:
	var errors := []
	if text == "":
		return errors
	if not text.ends_with("\n"):
		errors.append(_err("events", "must end with a newline"))
	var order := {"last": -1, "trace_tick": null}
	var lines := text.trim_suffix("\n").split("\n")
	for i in lines.size():
		var at := "events[%d]" % i
		var json := JSON.new()
		if json.parse(lines[i]) != OK:
			errors.append(_err(at, "is not one JSON value"))
			continue
		_check_event(errors, at, json.data, order)
	return errors


# The ids an arm may choose from: the options that pass decide.mjs's
# precondition gate, or push_objective alone when the gate removes everything.
static func offered_options(jev: Dictionary) -> Array:
	var kept := []
	var options = jev.get("options")
	if options is Array:
		for option in options:
			if option is Dictionary and _passes_gate(jev.get("state"), option):
				kept.append(option.get("id"))
	return kept if not kept.is_empty() else ["push_objective"]


# decide.mjs PRECONDITION: physics the engine cannot execute, not judgement.
static func _passes_gate(state: Variant, option: Dictionary) -> bool:
	var me = state.get("self") if state is Dictionary else null
	if me is not Dictionary:
		me = {}
	match option.get("id"):
		"stomp_target":
			return _same(me.get("grounded"), true) or _same(me.get("air_jump_available"), true)
		"ram_target":
			return _same(me.get("speed_tier"), "fast") or _same(me.get("speed_tier"), "blazing")
		"hit_kicker":
			if not option.has("requires_speed_ms"):
				return true
			var speed = me.get("speed_ms")
			var needed = option.requires_speed_ms
			return _is_num(speed) and _is_num(needed) and speed >= needed
		"start_exit":
			var objective = state.get("objective") if state is Dictionary else null
			return objective is not Dictionary or not _same(objective.get("inside_ring"), false)
	return true


static func _check_jev(errors: Array, jev: Variant) -> void:
	if not _shape(errors, "jev", jev, {"state": null, "options": null}):
		return
	var state = jev.get("state")
	if _shape(errors, "jev.state", state, JEV_STATE, JEV_STATE_OPTIONAL):
		_shape(errors, "jev.state.self", state.get("self"), SELF, SELF_OPTIONAL)
		_shape(errors, "jev.state.stage", state.get("stage"), STAGE)
		if _list(errors, "jev.state.threats", state.get("threats"), 0, MAX_THREATS):
			for i in state.threats.size():
				_shape(errors, "jev.state.threats[%d]" % i, state.threats[i], THREAT, THREAT_OPTIONAL)
		_shape(errors, "jev.state.objective", state.get("objective"), OBJECTIVE, OBJECTIVE_OPTIONAL)
		if state.has("scrap"):
			_shape(errors, "jev.state.scrap", state.scrap, SCRAP)
		if state.has("buffs") and _list(errors, "jev.state.buffs", state.buffs):
			for i in state.buffs.size():
				var text := _kind_error("string", state.buffs[i])
				if text != "":
					errors.append(_err("jev.state.buffs[%d]" % i, text))
	var options = jev.get("options")
	if _list(errors, "jev.options", options, 1):
		# Keyed like a JavaScript Set of option?.id: a missing id counts as one
		# value, and an array or object id never repeats.
		var seen := {}
		for i in options.size():
			var option = options[i]
			_shape(errors, "jev.options[%d]" % i, option, OPTION, OPTION_OPTIONAL)
			var id = option.get("id") if option is Dictionary and option.has("id") else null
			var key = "undefined" if option is not Dictionary or not option.has("id") else null
			if key == null and id is not Array and id is not Dictionary:
				key = stringify(id)
			if key != null:
				if seen.has(key):
					errors.append(_err("jev.options[%d].id" % i, "is offered twice"))
				seen[key] = true


# `order` carries the last tick and the latest trace tick between lines: ticks
# never decrease, and at an equal tick the intent line precedes the trace line.
static func _check_event(errors: Array, at: String, event: Variant, order: Dictionary) -> void:
	var kind = event.get("kind") if event is Dictionary else null
	if not (_is_str(kind) and EVENTS.has(String(kind))):
		errors.append(_err(at + ".kind", "must be one of " + ", ".join(EVENTS.keys())))
		return
	var fields := {"tick": "int", "kind": null}
	fields.merge(EVENTS[String(kind)])
	_shape(errors, at, event, fields)
	var tick = event.get("tick")
	if not _is_int(tick):
		return
	if tick < order.last:
		errors.append(_err(at + ".tick", "goes back from %d" % order.last))
	if kind == "intent" and order.trace_tick != null and tick == order.trace_tick:
		errors.append(_err(at, "an intent line must come before the trace line at the same tick"))
	if kind == "trace":
		order.trace_tick = tick
	order.last = maxi(order.last, int(tick))


# Checks `value` against a closed shape: every required key present, no key
# outside required and optional, and each field's kind.
static func _shape(errors: Array, at: String, value: Variant, required: Dictionary, optional := {}) -> bool:
	if value is not Dictionary:
		errors.append(_err(at if at != "" else "(root)", "must be an object"))
		return false
	for key in required:
		if not value.has(key):
			errors.append(_err(_join(at, key), "is required"))
	for key in value:
		var path := _join(at, str(key))
		var kind
		if required.has(key):
			kind = required[key]
		elif optional.has(key):
			kind = optional[key]
		else:
			errors.append(_err(path, "is not a protocol v1 field"))
			continue
		if kind != null:
			var text := _kind_error(kind, value[key])
			if text != "":
				errors.append(_err(path, text))
	return true


static func _list(errors: Array, at: String, value: Variant, least := 0, most := -1) -> bool:
	if value is not Array:
		errors.append(_err(at, "must be an array"))
		return false
	if value.size() < least or (most >= 0 and value.size() > most):
		var bound := "at least %d" % least if most < 0 else "%d to %d" % [least, most]
		errors.append(_err(at, "must hold %s entries" % bound))
		return false
	return true


# "" when `value` is of `kind`, else the message protocol.mjs gives.
static func _kind_error(kind: Variant, value: Variant) -> String:
	if kind is Array:
		return "" if _is_str(value) and kind.has(String(value)) else "must be one of " + ", ".join(kind)
	match kind:
		"string":
			return "" if _is_str(value) and value != "" else "must be a non-empty string"
		"boolean":
			return "" if value is bool else "must be a boolean"
		"int":
			return "" if _is_int(value) and value >= 0 else "must be a whole number >= 0"
		"whole":
			return "" if _on_grid(value, 1.0) and value >= 0 else "must be a whole number >= 0"
		"any_int":
			return "" if _is_int(value) else "must be a whole number"
		"tenth":
			return "" if _on_grid(value, 0.1) and value >= 0 else "must be >= 0 in steps of 0.1"
		"number":
			return "" if _is_num(value) and is_finite(value) else "must be a finite number"
		"sha":
			return "" if _is_sha(value) else "must be 64 lowercase hex characters"
		"vec3":
			var ok: bool = value is Array and value.size() == 3
			if ok:
				for part in value:
					ok = ok and _is_num(part) and is_finite(part)
			return "" if ok else "must be three finite numbers"
		"protocol":
			return "" if _same(value, PROTOCOL) else "must be \"%s\"" % PROTOCOL
		"tier":
			return "" if _is_str(value) and SPEED_TIERS.has(String(value)) else "must be one of " + ", ".join(SPEED_TIERS)
		"intent_id":
			return "" if _is_str(value) and INTENTS.has(String(value)) else "must be an intent id from decide.mjs"
		"held":
			return "" if value == null or (_is_str(value) and INTENTS.has(String(value))) else "must be null or an intent id from decide.mjs"
		"seq_or_null":
			return "" if value == null or (_is_int(value) and value >= 0) else "must be a whole number >= 0"
	push_error("jev_io: unknown field kind %s" % str(kind))
	return "has an unknown kind"


static func _is_str(value: Variant) -> bool:
	return value is String or value is StringName


static func _is_num(value: Variant) -> bool:
	return value is int or value is float


# Godot's JSON parser returns every number as a float, so a whole number is
# judged by value.
static func _is_int(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floorf(value))


static func _on_grid(value: Variant, step: float) -> bool:
	if not _is_num(value) or not is_finite(value):
		return false
	var steps: float = value / step
	return absf(steps - roundf(steps)) < GRID_SLACK


static func _is_sha(value: Variant) -> bool:
	if not _is_str(value) or String(value).length() != 64:
		return false
	for c in String(value):
		if not "0123456789abcdef".contains(c):
			return false
	return true


# Equal type family and value, like JavaScript's ===; a number never equals a
# string or a boolean.
static func _same(a: Variant, b: Variant) -> bool:
	if _is_num(a) and _is_num(b):
		return a == b
	if _is_str(a) and _is_str(b):
		return String(a) == String(b)
	return typeof(a) == typeof(b) and a == b


static func _join(at: String, key: String) -> String:
	return key if at == "" else at + "." + key


static func _err(path: String, message: String) -> Dictionary:
	return {"path": path, "message": message}


static func _prefixed(name: String, errors: Array) -> Array:
	var out := []
	for error in errors:
		out.append(_err(name + ":" + error.path, error.message))
	return out


# --- JSON text -----------------------------------------------------------------


# JavaScript's JSON.stringify layout for JSON values: no whitespace, keys in
# insertion order, no ".0" on whole numbers. null when `value` holds something
# JSON cannot carry.
static func stringify(value: Variant) -> Variant:
	match typeof(value):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if value else "false"
		TYPE_INT:
			return str(value)
		TYPE_FLOAT:
			return _number(value)
		TYPE_STRING, TYPE_STRING_NAME:
			return _quote(String(value))
		TYPE_ARRAY:
			var parts := PackedStringArray()
			for item in value:
				var text = stringify(item)
				if text == null:
					return null
				parts.append(text)
			return "[" + ",".join(parts) + "]"
		TYPE_DICTIONARY:
			var parts := PackedStringArray()
			for key in value:
				var text = stringify(value[key])
				if text == null:
					return null
				parts.append(_quote(str(key)) + ":" + text)
			return "{" + ",".join(parts) + "}"
	return null


# ECMAScript Number::toString's layout over String.num_scientific's digits:
# plain decimals from 1e-6 up to 1e21, exponent form outside. Those digits
# always parse back to the same double, but for about 1 value in 2000 Godot
# prints a 17th digit where JavaScript stops at 16.
static func _number(value: float) -> String:
	if is_nan(value) or is_inf(value):
		return "null"
	if value == 0.0:
		return "0"
	var text := String.num_scientific(absf(value))
	var exponent := 0
	var e := text.find("e")
	if e >= 0:
		exponent = text.substr(e + 1).trim_prefix("+").to_int()
		text = text.substr(0, e)
	var point := text.find(".")
	var digits := text.replace(".", "")
	var n := (point if point >= 0 else text.length()) + exponent
	while digits.length() > 1 and digits.begins_with("0"):
		digits = digits.substr(1)
		n -= 1
	while digits.length() > 1 and digits.ends_with("0"):
		digits = digits.left(-1)
	var k := digits.length()
	var sign := "-" if value < 0.0 else ""
	if k <= n and n <= 21:
		return sign + digits + "0".repeat(n - k)
	if 0 < n and n <= 21:
		return sign + digits.left(n) + "." + digits.substr(n)
	if -6 < n and n <= 0:
		return sign + "0." + "0".repeat(-n) + digits
	var mantissa := digits if k == 1 else digits.left(1) + "." + digits.substr(1)
	return sign + mantissa + "e" + ("+" if n - 1 >= 0 else "-") + str(absi(n - 1))


static func _quote(text: String) -> String:
	var out := "\""
	for c in text:
		var code := c.unicode_at(0)
		match code:
			0x22:
				out += "\\\""
			0x5c:
				out += "\\\\"
			0x08:
				out += "\\b"
			0x0c:
				out += "\\f"
			0x0a:
				out += "\\n"
			0x0d:
				out += "\\r"
			0x09:
				out += "\\t"
			_:
				out += "\\u%04x" % code if code < 0x20 else c
	return out + "\""
