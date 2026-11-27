extends SceneTree

const PinHash := preload("res://tests/support/pin_hash.gd")
const T := preload("res://tests/support/t.gd")


func _initialize() -> void:
	var t := T.new("pin_hash_guard_test")
	var dir := OS.get_user_data_dir().path_join("pin-hash-guard-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(dir)
	var pin_path := dir.path_join("sample.pin")
	var prev_record := OS.get_environment("PIN_RECORD")
	var prev_allow := OS.get_environment(PinHash.ALLOW_RECORD_ENV)

	OS.set_environment("PIN_RECORD", "1")
	OS.unset_environment(PinHash.ALLOW_RECORD_ENV)
	t.check("can_record is false without flag or env", not PinHash.can_record(PackedStringArray(), ""))
	t.check("can_record accepts --allow-pin-record flag", PinHash.can_record(PackedStringArray([PinHash.ALLOW_RECORD_FLAG]), ""))
	t.check("can_record accepts SCRAPKEEP_ALLOW_PIN_RECORD=1", PinHash.can_record(PackedStringArray(), "1"))

	var refused := PinHash.check(pin_path, [1.25, 2.5])
	t.check("leftover PIN_RECORD=1 without allow flag fails loudly", refused.contains("refusing to overwrite"), refused)
	t.check("refused record writes no pin file", not FileAccess.file_exists(pin_path))

	OS.set_environment(PinHash.ALLOW_RECORD_ENV, "1")
	var recorded := PinHash.check(pin_path, [1.25, 2.5])
	t.eq("authorized PIN_RECORD=1 records cleanly", recorded, "")
	t.check("pin file exists after authorized record", FileAccess.file_exists(pin_path))

	OS.unset_environment(PinHash.ALLOW_RECORD_ENV)
	var refused_overwrite := PinHash.check(pin_path, [9.99, 8.88])
	t.check("leftover PIN_RECORD=1 refuses to overwrite existing pin", refused_overwrite.contains("refusing to overwrite"), refused_overwrite)

	OS.unset_environment("PIN_RECORD")
	t.eq("existing pin still matches original values after refused overwrite", PinHash.check(pin_path, [1.25, 2.5]), "")
	t.check("changed value fails comparison against intact pin", PinHash.check(pin_path, [9.99, 8.88]) != "")

	if prev_record.is_empty():
		OS.unset_environment("PIN_RECORD")
	else:
		OS.set_environment("PIN_RECORD", prev_record)
	if prev_allow.is_empty():
		OS.unset_environment(PinHash.ALLOW_RECORD_ENV)
	else:
		OS.set_environment(PinHash.ALLOW_RECORD_ENV, prev_allow)
	if FileAccess.file_exists(pin_path):
		DirAccess.remove_absolute(pin_path)
	DirAccess.remove_absolute(dir)
	quit(t.verdict())
