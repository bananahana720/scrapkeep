extends RefCounted

## Single persistence owner for the TADR-004 hello-world proof.
## Order of operations is stage, validate, commit, acknowledge.
## Every field is a placeholder. Nothing here reads browser storage and no
## field for an open question exists (Q-E05 and Q-E09 stay open).

const SCHEMA_VERSION: int = 1
const SAVE_NAME: String = "save.json"
const TEMP_PREFIX: String = "save.json.tmp-"

const STATUS_MISSING: String = "missing"
const STATUS_CORRUPT: String = "corrupt"
const STATUS_UNSUPPORTED_NEWER: String = "unsupported_newer"
const STATUS_COMMITTED: String = "committed"
const STATUS_COMMITTED_STALE_TEMP: String = "committed_stale_temp"
const STATUS_AMBIGUOUS_LIFECYCLE: String = "ambiguous_lifecycle"

var root: String
var committed: Dictionary = {}
var committed_error: Error = OK
var converged: bool = false
var acknowledged: Array[String] = []
var inject_fault_accept_newer_schema: bool = false

var _validated_temp: String = ""
var _commit_ok_transactions: Array[String] = []


## The fault flag exists only so the runner can prove it detects a missing
## newer-schema rejection; it is never set outside `--inject-fault`.
func _init(save_root: String, accept_newer_schema_fault: bool = false) -> void:
	root = save_root
	inject_fault_accept_newer_schema = accept_newer_schema_fault
	_load_committed()


func save_path() -> String:
	return root.path_join(SAVE_NAME)


func temp_path_for(transaction_id: String) -> String:
	return root.path_join(TEMP_PREFIX + transaction_id)


func stage(aggregate: Dictionary) -> String:
	var transaction_id: String = str(aggregate.get("transaction_id", ""))
	if transaction_id.is_empty():
		push_error("stage refused: aggregate has no transaction_id")
		return ""
	var path: String = temp_path_for(transaction_id)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("stage failed to open %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return ""
	file.store_string(serialize(aggregate))
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		push_error("stage write error on %s: %s" % [path, error_string(write_error)])
		return ""
	return path


func validate(temp_path: String) -> Error:
	converged = false
	_validated_temp = ""
	var read: Dictionary = read_envelope(temp_path)
	var read_error: Error = read["error"]
	if read_error != OK:
		return read_error
	var candidate: Dictionary = read["aggregate"]
	if committed_error != OK:
		return committed_error
	if committed.is_empty():
		_validated_temp = temp_path
		return OK
	var candidate_transaction: String = candidate["transaction_id"]
	var committed_transaction: String = committed["transaction_id"]
	if candidate_transaction == committed_transaction:
		converged = true
		_validated_temp = temp_path
		return OK
	var candidate_generation: int = candidate["generation"]
	var committed_generation: int = committed["generation"]
	if candidate_generation <= committed_generation:
		return ERR_ALREADY_EXISTS
	_validated_temp = temp_path
	return OK


func commit(temp_path: String) -> Error:
	if temp_path.is_empty() or temp_path != _validated_temp:
		return ERR_UNCONFIGURED
	_validated_temp = ""
	var read: Dictionary = read_envelope(temp_path)
	var read_error: Error = read["error"]
	if read_error != OK:
		return read_error
	var candidate: Dictionary = read["aggregate"]
	var transaction_id: String = candidate["transaction_id"]
	if converged:
		var remove_error: Error = DirAccess.remove_absolute(temp_path)
		if remove_error != OK:
			return remove_error
		_commit_ok_transactions.append(transaction_id)
		return OK
	var rename_error: Error = DirAccess.rename_absolute(temp_path, save_path())
	if rename_error != OK:
		return rename_error
	_load_committed()
	_commit_ok_transactions.append(transaction_id)
	return OK


func acknowledge(transaction_id: String) -> void:
	if not _commit_ok_transactions.has(transaction_id):
		push_error("acknowledge refused: %s has not committed" % transaction_id)
		return
	if not acknowledged.has(transaction_id):
		acknowledged.append(transaction_id)


func is_acknowledged(transaction_id: String) -> bool:
	return acknowledged.has(transaction_id)


func recover() -> Dictionary:
	var result: Dictionary = {
		"status": STATUS_MISSING,
		"aggregate": {},
		"stale": [] as Array[String],
		"playable": false,
	}
	var stale: Array[String] = result["stale"]
	if not FileAccess.file_exists(save_path()):
		stale.append_array(list_temp_names())
		return result
	var read: Dictionary = read_envelope(save_path())
	var read_error: Error = read["error"]
	if read_error == ERR_UNAVAILABLE:
		result["status"] = STATUS_UNSUPPORTED_NEWER
		stale.append_array(list_temp_names())
		return result
	if read_error != OK:
		result["status"] = STATUS_CORRUPT
		stale.append_array(list_temp_names())
		return result
	var source: Dictionary = read["aggregate"]
	result["aggregate"] = source
	result["status"] = STATUS_COMMITTED
	result["playable"] = is_playable(source)
	var source_generation: int = source["generation"]
	for temp_name: String in list_temp_names():
		stale.append(temp_name)
		var temp_read: Dictionary = read_envelope(root.path_join(temp_name))
		var temp_error: Error = temp_read["error"]
		if temp_error != OK:
			continue
		var temp_aggregate: Dictionary = temp_read["aggregate"]
		var temp_generation: int = temp_aggregate["generation"]
		if temp_generation <= source_generation:
			continue
		var resolved: Dictionary = resolve_lifecycle(temp_aggregate, source)
		var resolved_run: Dictionary = resolved["run"]
		var source_run: Dictionary = source["run"]
		if resolved_run["lifecycle"] != source_run["lifecycle"]:
			result["status"] = STATUS_AMBIGUOUS_LIFECYCLE
			result["playable"] = false
	if result["status"] == STATUS_COMMITTED and not stale.is_empty():
		result["status"] = STATUS_COMMITTED_STALE_TEMP
	return result


func resolve_lifecycle(a: Dictionary, b: Dictionary) -> Dictionary:
	var a_generation: int = a["generation"]
	var b_generation: int = b["generation"]
	var newer: Dictionary = a if a_generation >= b_generation else b
	var older: Dictionary = b if newer == a else a
	var resolved: Dictionary = newer.duplicate(true)
	var resolved_run: Dictionary = resolved["run"]
	var resolved_lifecycle: Dictionary = resolved_run["lifecycle"]
	var older_run: Dictionary = older["run"]
	var older_lifecycle: Dictionary = older_run["lifecycle"]
	var older_spent: bool = older_lifecycle["revival_spent"]
	var older_terminal: bool = older_lifecycle["terminal"]
	var newer_spent: bool = resolved_lifecycle["revival_spent"]
	var newer_terminal: bool = resolved_lifecycle["terminal"]
	resolved_lifecycle["revival_spent"] = older_spent or newer_spent
	resolved_lifecycle["terminal"] = older_terminal or newer_terminal
	resolved["playable"] = is_playable(resolved)
	return resolved


static func is_playable(aggregate: Dictionary) -> bool:
	var run: Dictionary = aggregate["run"]
	var lifecycle: Dictionary = run["lifecycle"]
	var terminal: bool = lifecycle["terminal"]
	return not terminal


func list_temp_names() -> Array[String]:
	var names: Array[String] = []
	if not DirAccess.dir_exists_absolute(root):
		return names
	for file_name: String in DirAccess.get_files_at(root):
		if file_name.begins_with(TEMP_PREFIX):
			names.append(file_name)
	names.sort()
	return names


func serialize(aggregate: Dictionary) -> String:
	return JSON.stringify(aggregate, "  ", true) + "\n"


## Reads bytes from disk, parses them and casts JSON numbers to int at the
## envelope boundary. Returns {"error": Error, "aggregate": Dictionary}.
func read_envelope(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": FileAccess.get_open_error(), "aggregate": {}}
	var text: String = file.get_as_text()
	file.close()
	return parse_envelope(text)


func parse_envelope(text: String) -> Dictionary:
	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(text)
	if parse_error != OK:
		return {"error": ERR_PARSE_ERROR, "aggregate": {}}
	var data: Variant = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return {"error": ERR_INVALID_DATA, "aggregate": {}}
	var raw: Dictionary = data
	if not _has_number(raw, "schema_version"):
		return {"error": ERR_INVALID_DATA, "aggregate": {}}
	var schema_version: int = _as_int(raw["schema_version"])
	if schema_version > SCHEMA_VERSION and not inject_fault_accept_newer_schema:
		return {"error": ERR_UNAVAILABLE, "aggregate": {}}
	if not _has_string(raw, "content_revision") or not _has_number(raw, "generation") or not _has_string(raw, "transaction_id"):
		return {"error": ERR_INVALID_DATA, "aggregate": {}}
	if typeof(raw.get("profile")) != TYPE_DICTIONARY or typeof(raw.get("run")) != TYPE_DICTIONARY:
		return {"error": ERR_INVALID_DATA, "aggregate": {}}
	var run: Dictionary = raw["run"]
	if typeof(run.get("checkpoint")) != TYPE_DICTIONARY or typeof(run.get("lifecycle")) != TYPE_DICTIONARY:
		return {"error": ERR_INVALID_DATA, "aggregate": {}}
	var checkpoint: Dictionary = run["checkpoint"]
	var lifecycle: Dictionary = run["lifecycle"]
	if not _has_string(checkpoint, "next_entrance") or not _has_bool(lifecycle, "revival_spent") or not _has_bool(lifecycle, "terminal"):
		return {"error": ERR_INVALID_DATA, "aggregate": {}}
	var profile: Dictionary = raw["profile"]
	var content_revision: String = raw["content_revision"]
	var transaction_id: String = raw["transaction_id"]
	var next_entrance: String = checkpoint["next_entrance"]
	var revival_spent: bool = lifecycle["revival_spent"]
	var terminal: bool = lifecycle["terminal"]
	var aggregate: Dictionary = {
		"schema_version": schema_version,
		"content_revision": content_revision,
		"generation": _as_int(raw["generation"]),
		"transaction_id": transaction_id,
		"profile": profile.duplicate(true),
		"run": {
			"checkpoint": {"next_entrance": next_entrance},
			"lifecycle": {"revival_spent": revival_spent, "terminal": terminal},
		},
	}
	return {"error": OK, "aggregate": aggregate}


static func _as_int(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		var as_int: int = value
		return as_int
	var as_float: float = value
	return int(as_float)


static func _has_number(source: Dictionary, key: String) -> bool:
	var value_type: int = typeof(source.get(key))
	return value_type == TYPE_INT or value_type == TYPE_FLOAT


static func _has_string(source: Dictionary, key: String) -> bool:
	return typeof(source.get(key)) == TYPE_STRING


static func _has_bool(source: Dictionary, key: String) -> bool:
	return typeof(source.get(key)) == TYPE_BOOL


## An unreadable or unsupported committed file blocks every later commit so
## the source is never overwritten (TADR-004 lines 34 and 40).
func _load_committed() -> void:
	committed = {}
	committed_error = OK
	if not FileAccess.file_exists(save_path()):
		return
	var read: Dictionary = read_envelope(save_path())
	committed_error = read["error"]
	if committed_error == OK:
		committed = read["aggregate"]
