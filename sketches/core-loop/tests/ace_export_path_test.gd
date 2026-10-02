extends SceneTree

const Ace := preload("res://src/presentation/ace_sequencer.gd")
const T := preload("res://tests/support/t.gd")

# Where the ACE manifest is found: the source tree path first, the music_ace/ sidecar
# beside the executable second, and neither is a not-ready band, never a crash. Driven with
# a temporary folder standing in for the executable's directory.

const REL := "spillway/manifest.json"


func _write(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{}")
	f.close()


func _remove(dir: String) -> void:
	for sub in DirAccess.get_directories_at(dir):
		_remove(dir.path_join(sub))
	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file))
	DirAccess.remove_absolute(dir)


func _initialize() -> void:
	var t := T.new("ace_export_path_test")
	var tmp := OS.get_temp_dir().path_join("ace_export_path_%d" % OS.get_process_id())
	var res_path := "res://assets/music_ace/" + REL
	var absent := "res://assets/music_ace/no_such_theme/manifest.json"

	# Neither: an empty executable folder and a manifest that is not in the source tree.
	DirAccess.make_dir_recursive_absolute(tmp)
	t.eq("neither resolves to nothing", Ace.resolve_manifest(absent, tmp), "")
	var none := Ace.new(absent, tmp)
	t.check("neither is not ready", not none.ready() and not none.missing.is_empty(), "ready=%s missing=%s" % [none.ready(), none.missing])

	# Sidecar: only the folder beside the executable holds it.
	var sidecar_manifest := tmp.path_join("music_ace").path_join(absent.trim_prefix("res://assets/music_ace/"))
	_write(sidecar_manifest)
	t.eq("sidecar found", Ace.resolve_manifest(absent, tmp), sidecar_manifest)

	# Source first: an existing source path wins over a sidecar copy of the same manifest.
	var source := tmp.path_join("source_manifest.json")
	_write(source)
	_write(tmp.path_join("music_ace").path_join(REL))
	t.eq("source first", Ace.resolve_manifest(source, tmp), source)
	if FileAccess.file_exists(ProjectSettings.globalize_path(res_path)):
		t.eq("source tree first over sidecar", Ace.resolve_manifest(res_path, tmp), ProjectSettings.globalize_path(res_path))

	_remove(tmp)
	quit(t.verdict())
