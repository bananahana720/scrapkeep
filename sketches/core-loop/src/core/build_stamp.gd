extends RefCounted


const FILE := "BUILD.txt"
const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

static var _stamp := {}


static func read() -> Dictionary:
	if _stamp.is_empty():
		_stamp = read_from(OS.get_executable_path().get_base_dir(),
			ProjectSettings.globalize_path("res://") if OS.has_feature("editor") else "")
	return _stamp


# macOS codesign refuses data files in Contents/MacOS, so exported .app bundles place BUILD.txt in Contents/Resources.
static func read_from(exe_dir: String, project_dir: String) -> Dictionary:
	var rows := parse(_text(exe_dir.path_join(FILE)))
	if rows.is_empty() and project_dir == "" and exe_dir.simplify_path().ends_with(".app/Contents/MacOS"):
		rows = parse(_text(exe_dir.path_join("../Resources").simplify_path().path_join(FILE)))
	if rows.get("commit", "") != "":
		return {"commit": rows["commit"], "dirty": rows.get("dirty", "false") == "true",
			"built": rows.get("built", ""), "source": "export"}
	var commit := checkout_commit(project_dir.path_join("../..").simplify_path()) if project_dir != "" else ""
	return {"commit": commit, "dirty": false, "built": "", "source": "checkout" if commit != "" else "none"}


static func parse(text: String) -> Dictionary:
	var rows := {}
	for line in text.split("\n", false):
		var cut := line.find(": ")
		if cut > 0:
			rows[line.substr(0, cut)] = line.substr(cut + 2).strip_edges()
	return rows


static func checkout_commit(repo: String) -> String:
	var git := repo.path_join(".git")
	if FileAccess.file_exists(git):
		git = _under(repo, _text(git).trim_prefix("gitdir: "))
	var head := _text(git.path_join("HEAD"))
	if not head.begins_with("ref: "):
		return head if head.is_valid_hex_number() else ""
	var ref := head.trim_prefix("ref: ")
	var common := _text(git.path_join("commondir"))
	var shared := git if common == "" else _under(git, common)
	var loose := _text(shared.path_join(ref))
	if loose.is_valid_hex_number():
		return loose
	for line in _text(shared.path_join("packed-refs")).split("\n", false):
		if line.ends_with(" " + ref):
			return line.get_slice(" ", 0)
	return ""


static func _text(path: String) -> String:
	return FileAccess.get_file_as_string(path).strip_edges() if FileAccess.file_exists(path) else ""


static func _under(base: String, path: String) -> String:
	return path if path.is_absolute_path() else base.path_join(path).simplify_path()


static func label(stamp := read()) -> String:
	var commit: String = stamp.get("commit", "")
	if commit == "":
		return "Build unknown"
	var short := commit.left(7) + ("-dirty" if stamp.get("dirty", false) else "")
	if stamp.get("source", "") != "export":
		return "Dev build %s" % short
	var day := built_day(stamp.get("built", ""))
	return "Build %s" % short if day == "" else "Build %s · %s" % [short, day]


static func built_day(built: String) -> String:
	if built.length() < 8 or not built.left(8).is_valid_int():
		return ""
	var month := int(built.substr(4, 2))
	if month < 1 or month > 12:
		return ""
	return "%d %s %s" % [int(built.substr(6, 2)), MONTHS[month - 1], built.left(4)]


static func line(stamp := read()) -> String:
	var commit: String = stamp.get("commit", "")
	var built: String = stamp.get("built", "")
	return "SCRAPKEEP_BUILD commit=%s dirty=%s built=%s source=%s" % [
		commit if commit != "" else "unknown", stamp.get("dirty", false),
		built if built != "" else "unknown", stamp.get("source", "none")]
