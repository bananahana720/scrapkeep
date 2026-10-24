extends RefCounted

# A stub ACE stem tree for cloud runs: the Oggs are gitignored, so a cloud checkout has
# manifests and no audio. install() writes the committed 2 s tone as every stem STEMS.sha256
# lists, under user://<dir>/<pack>/<file>, and points MusicRows.stem_dir at it. The tone is
# not the music; tests that need real stems still say so.

const MusicRows := preload("res://src/presentation/music_rows.gd")

const TONE := "res://tests/fixtures/ace_stub/tone.ogg"
const LIST := "res://assets/music_ace/STEMS.sha256"


static func install(dir := "ace_stem_stub") -> String:
	var root := "user://" + dir
	var tone := FileAccess.get_file_as_bytes(TONE)
	for line in FileAccess.get_file_as_string(LIST).split("\n", false):
		var rel := line.strip_edges().split("  ", false)[-1]
		var file := root.path_join(rel)
		if FileAccess.file_exists(file):
			continue
		DirAccess.make_dir_recursive_absolute(file.get_base_dir())
		var out := FileAccess.open(file, FileAccess.WRITE)
		out.store_buffer(tone)
		out.close()
	MusicRows.stem_dir = root
	return root
