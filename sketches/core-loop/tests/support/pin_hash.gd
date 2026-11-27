extends RefCounted

const STEP := 0.001
const POS_DRIFT := 7.6e-6
const UNIT_DRIFT := 6e-8
const MARGIN_MIN := 10.0
const TOLERANCE := 0.5 + MARGIN_MIN * POS_DRIFT / STEP
const ALLOW_RECORD_FLAG := "--allow-pin-record"
const ALLOW_RECORD_ENV := "SCRAPKEEP_ALLOW_PIN_RECORD"


static func can_record(cmdline_args: PackedStringArray = OS.get_cmdline_user_args(), env_allow := OS.get_environment(ALLOW_RECORD_ENV)) -> bool:
	if env_allow == "1":
		return true
	for arg in cmdline_args:
		if arg == ALLOW_RECORD_FLAG:
			return true
	return false


static func check(path: String, value: Variant, allow_record := false) -> String:
	var floats := _floats(value, [])
	var shape := hash(var_to_bytes(_shape(value)))
	if OS.get_environment("PIN_RECORD") == "1":
		if not allow_record and not can_record():
			return "PIN_RECORD=1 is set without %s or %s=1; refusing to overwrite %s in an ordinary test run" % [ALLOW_RECORD_FLAG, ALLOW_RECORD_ENV, path]
		var out := FileAccess.open_compressed(path, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
		out.store_var([shape, PackedInt32Array(floats.map(func(x: float) -> int: return int(roundf(x / STEP))))])
		out.close()
		print("pin_hash: recorded %d floats to %s" % [floats.size(), path])
		return ""
	var file := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if file == null:
		return "no pin at %s: record it with PIN_RECORD=1 %s=1" % [path, ALLOW_RECORD_ENV]
	var stored: Array = file.get_var()
	if stored[0] != shape:
		return "the ints, strings or nesting changed"
	var want: PackedInt32Array = stored[1]
	if floats.size() != want.size():
		return "%d floats, pinned %d" % [floats.size(), want.size()]
	for k in floats.size():
		if is_nan(floats[k]) or absf(floats[k] / STEP - want[k]) > TOLERANCE:
			return "float %d is %.4f, pinned %.4f" % [k, floats[k], want[k] * STEP]
	return ""


static func margin(value: Variant) -> float:
	var kinds := []
	var xs := _floats(value, kinds)
	var best := INF
	for k in xs.size():
		var q: float = xs[k] / STEP
		var distance := absf(q - floorf(q) - 0.5) * STEP
		best = minf(best, distance / (UNIT_DRIFT if kinds[k] else POS_DRIFT))
	return best


static func _floats(value: Variant, kinds: Array) -> Array:
	var out := []
	_collect(value, out, kinds, false)
	return out


static func _collect(value: Variant, out: Array, kinds: Array, unit: bool) -> void:
	match typeof(value):
		TYPE_FLOAT:
			out.append(value)
			kinds.append(unit)
		TYPE_VECTOR2:
			_collect([value.x, value.y], out, kinds, unit)
		TYPE_VECTOR3:
			_collect([value.x, value.y, value.z], out, kinds, unit)
		TYPE_VECTOR4, TYPE_QUATERNION:
			_collect([value.x, value.y, value.z, value.w], out, kinds, unit or value is Quaternion)
		TYPE_BASIS:
			_collect([value.x, value.y, value.z], out, kinds, true)
		TYPE_TRANSFORM3D:
			_collect(value.basis, out, kinds, true)
			_collect(value.origin, out, kinds, false)
		TYPE_AABB:
			_collect([value.position, value.size], out, kinds, false)
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY:
			var start := out.size()
			out.append_array(Array(value))
			kinds.resize(out.size())
			for k in range(start, out.size()):
				kinds[k] = unit
		TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_ARRAY:
			for item in value:
				_collect(item, out, kinds, unit)
		TYPE_DICTIONARY:
			for key in value:
				_collect(value[key], out, kinds, unit)


static func _shape(value: Variant) -> Variant:
	match typeof(value):
		TYPE_ARRAY:
			return value.map(_shape)
		TYPE_DICTIONARY:
			var out := {}
			for key in value:
				out[key] = _shape(value[key])
			return out
		TYPE_FLOAT, TYPE_VECTOR2, TYPE_VECTOR3, TYPE_VECTOR4, TYPE_QUATERNION, TYPE_BASIS, TYPE_TRANSFORM3D, TYPE_AABB, \
				TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY:
			return "f%d" % _floats(value, []).size()
	return value
