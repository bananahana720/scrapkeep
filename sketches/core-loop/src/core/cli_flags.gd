extends RefCounted


static func args(include_engine_args := false) -> PackedStringArray:
	if not include_engine_args:
		return OS.get_cmdline_user_args()
	var out := PackedStringArray()
	out.append_array(OS.get_cmdline_args())
	out.append_array(OS.get_cmdline_user_args())
	return out


static func has_flag(flag: String, include_engine_args := false, argv = null) -> bool:
	var list: PackedStringArray = args(include_engine_args) if argv == null else PackedStringArray(argv)
	return flag in list


static func has_prefix(prefix: String, include_engine_args := false, argv = null) -> bool:
	var list: PackedStringArray = args(include_engine_args) if argv == null else PackedStringArray(argv)
	for arg in list:
		if arg.begins_with(prefix):
			return true
	return false


static func value_of(flag: String, default_value := "", include_engine_args := false, argv = null) -> String:
	var prefix := _prefix(flag)
	var out := default_value
	var list: PackedStringArray = args(include_engine_args) if argv == null else PackedStringArray(argv)
	for arg in list:
		if arg.begins_with(prefix):
			out = arg.trim_prefix(prefix)
	return out


static func values_of(flag: String, include_engine_args := false, argv = null) -> PackedStringArray:
	var prefix := _prefix(flag)
	var out := PackedStringArray()
	var list: PackedStringArray = args(include_engine_args) if argv == null else PackedStringArray(argv)
	for arg in list:
		if arg.begins_with(prefix):
			out.append(arg.trim_prefix(prefix))
	return out


static func _prefix(flag: String) -> String:
	return flag if flag.ends_with("=") else flag + "="
