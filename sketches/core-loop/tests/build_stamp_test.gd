extends SceneTree

const BuildStamp := preload("res://src/core/build_stamp.gd")
const SettingsPages := preload("res://src/ui/settings_pages.gd")
const Game := preload("res://src/game.gd")

# The build stamp (build_stamp.gd): BUILD.txt as sketch:export writes it, the checkout fallback in
# each shape git keeps HEAD (detached, loose ref, packed ref, worktree), what the player reads, the
# boot log line, and the settings page carrying it under Back.

const SHA := "8180ec6c0f3a4b5d6e7f8091a2b3c4d5e6f70812"
const OTHER := "24ebf5e8aa11bb22cc33dd44ee55ff6600778899"
const BUILD_TXT := "commit: %s\ndirty: %s\nbuilt: 20261108T190700\ngodot: 4.7.2.stable\nstems: 12 from /x/music_ace\nboss smoke brindle PASS\nwin proof: not run (pass --win-proof)\n"

var _t := preload("res://tests/support/t.gd").new("build_stamp_test")
var _dir := "user://build-stamp-test-%d" % OS.get_process_id()
var _game


func _initialize() -> void:
	_exports()
	_checkouts()
	_words()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _put(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _exports() -> void:
	var exe := _dir.path_join("export")
	_put(exe.path_join("BUILD.txt"), BUILD_TXT % [SHA, "false"])
	var clean := BuildStamp.read_from(exe, "")
	_t.eq("export stamp", clean, {"commit": SHA, "dirty": false, "built": "20261108T190700", "source": "export"})
	_t.eq("export label", BuildStamp.label(clean), "Build 8180ec6 · 8 Nov 2026")
	_t.eq("export line", BuildStamp.line(clean), "SCRAPKEEP_BUILD commit=%s dirty=false built=20261108T190700 source=export" % SHA)
	_put(exe.path_join("BUILD.txt"), BUILD_TXT % [SHA, "true"])
	_t.eq("dirty label", BuildStamp.label(BuildStamp.read_from(exe, "")), "Build 8180ec6-dirty · 8 Nov 2026")
	# A macOS .app: the executable in Contents/MacOS, the stamp in Contents/Resources.
	var app := _dir.path_join("Scrapkeep.app/Contents")
	_put(app.path_join("Resources/BUILD.txt"), BUILD_TXT % [OTHER, "false"])
	DirAccess.make_dir_recursive_absolute(app.path_join("MacOS"))
	_t.eq("mac app stamp", BuildStamp.read_from(app.path_join("MacOS"), ""),
		{"commit": OTHER, "dirty": false, "built": "20261108T190700", "source": "export"})
	_put(app.path_join("MacOS/BUILD.txt"), BUILD_TXT % [SHA, "false"])
	_t.eq("beside the executable wins", BuildStamp.read_from(app.path_join("MacOS"), "")["commit"], SHA)
	var none := BuildStamp.read_from(_dir.path_join("nowhere"), "")
	_t.eq("no stamp", none, {"commit": "", "dirty": false, "built": "", "source": "none"})
	_t.eq("no stamp label", BuildStamp.label(none), "Build unknown")
	_t.eq("no stamp line", BuildStamp.line(none), "SCRAPKEEP_BUILD commit=unknown dirty=false built=unknown source=none")
	_t.eq("a bad date drops out", BuildStamp.label({"commit": SHA, "source": "export", "built": "soon"}), "Build 8180ec6")


func _checkouts() -> void:
	var detached := _dir.path_join("detached")
	_put(detached.path_join(".git/HEAD"), SHA + "\n")
	_t.eq("detached HEAD", BuildStamp.checkout_commit(detached), SHA)
	var loose := _dir.path_join("loose")
	_put(loose.path_join(".git/HEAD"), "ref: refs/heads/stage/alpha-w33\n")
	_put(loose.path_join(".git/refs/heads/stage/alpha-w33"), SHA + "\n")
	_t.eq("loose ref", BuildStamp.checkout_commit(loose), SHA)
	var packed := _dir.path_join("packed")
	_put(packed.path_join(".git/HEAD"), "ref: refs/heads/main\n")
	_put(packed.path_join(".git/packed-refs"), "# pack-refs with: peeled fully-peeled sorted\n%s refs/heads/main-old\n%s refs/heads/main\n" % [OTHER, SHA])
	_t.eq("packed ref", BuildStamp.checkout_commit(packed), SHA)
	# A worktree: .git is a file naming its folder under the main repo, which holds the refs.
	var tree := _dir.path_join("tree")
	var main_git := ProjectSettings.globalize_path(loose.path_join(".git"))
	_put(tree.path_join(".git"), "gitdir: %s\n" % main_git.path_join("worktrees/tree"))
	_put(loose.path_join(".git/worktrees/tree/HEAD"), "ref: refs/heads/unit\n")
	_put(loose.path_join(".git/worktrees/tree/commondir"), "../..\n")
	_put(loose.path_join(".git/refs/heads/unit"), OTHER + "\n")
	_t.eq("worktree", BuildStamp.checkout_commit(tree), OTHER)
	_t.eq("no repo", BuildStamp.checkout_commit(_dir.path_join("nowhere")), "")
	# The sketch sits two folders under the repo root.
	var stamp := BuildStamp.read_from(_dir.path_join("nowhere"), loose.path_join("sketches/core-loop"))
	_t.eq("checkout stamp", stamp, {"commit": SHA, "dirty": false, "built": "", "source": "checkout"})
	_t.eq("checkout label", BuildStamp.label(stamp), "Dev build 8180ec6")


func _words() -> void:
	var live := BuildStamp.read()
	var commit: String = live["commit"]
	_t.check("this run's stamp", live["source"] in ["checkout", "none"] and (commit == "" or (commit.length() == 40 and commit.is_valid_hex_number())),
		BuildStamp.line())


func _process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	var page := SettingsPages.new()
	root.add_child(page)
	page.setup(_game)
	_t.check("settings page shows the stamp", page.stamp.text == BuildStamp.label() and page.stamp.get_index() == page.back.get_index() + 1
			and page.stamp.is_visible_in_tree(), "\"%s\" under Back" % page.stamp.text)
	page.queue_free()
	_clear(_dir)
	quit(_t.verdict())
	return false


func _clear(path: String) -> void:
	for sub in DirAccess.get_directories_at(path):
		_clear(path.path_join(sub))
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
