extends SceneTree

const T := preload("res://tests/support/t.gd")
const Ace := preload("res://src/presentation/ace_sequencer.gd")
const AceStub := preload("res://tests/support/ace_stub.gd")

# A band built for a package it read lately reuses that package's streams instead of reading every
# Ogg again (the dam's landmark tune ending at the Warden engage brought the stage pack back for
# 13 ms of the 4080's tick). Only the last KEPT_PACKAGES packages are kept, so a band older than that
# reads its files again. A band from kept streams is the band a fresh read builds: the same files
# per clip and stem, the same loops. The package is stage 1's own (Ace.MANIFEST), on stub stems.

var _t := T.new("ace_kept_packages_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	AceStub.install("ace_kept_stub")
	var others := _other_packages(Ace.KEPT_PACKAGES)
	var first := Ace.new(Ace.MANIFEST)
	_t.check("the stage pack reads", first.ready() and first.streams.size() > 0, "missing %s, %d streams" % [first.missing, first.streams.size()])
	var again := Ace.new(Ace.MANIFEST)
	_t.check("a band for the package just read reuses every stream", again.ready() and _shared(first, again) == first.streams.size(),
		"%d of %d shared" % [_shared(first, again), first.streams.size()])
	var ready := others.size() == Ace.KEPT_PACKAGES
	for k in Ace.KEPT_PACKAGES - 1:
		ready = ready and Ace.new(others[k]).ready()
	var back := Ace.new(Ace.MANIFEST)
	_t.check("with KEPT_PACKAGES - 1 other packages read since, it is still kept", ready and back.ready() and _shared(first, back) == first.streams.size(),
		"%d of %d shared, %d others" % [_shared(first, back), first.streams.size(), others.size()])
	for k in Ace.KEPT_PACKAGES:
		ready = ready and Ace.new(others[k]).ready()
	var fresh := Ace.new(Ace.MANIFEST)
	_t.check("KEPT_PACKAGES other packages later, it is read again", ready and fresh.ready() and _shared(first, fresh) == 0,
		"%d shared" % _shared(first, fresh))
	_t.check("a band from kept streams is the band a fresh read builds", _same_band(back, fresh), "%d clips" % fresh.clips.size())
	quit(_t.verdict())


func _other_packages(count: int) -> Array:
	var out := []
	var root := "res://assets/music_ace"
	for dir in DirAccess.get_directories_at(root):
		var path := root.path_join(dir).path_join("manifest.json")
		if path != Ace.MANIFEST and FileAccess.file_exists(path) and out.size() < count:
			out.append(path)
	return out


func _shared(a, b) -> int:
	var n := 0
	for file in a.streams:
		if b.streams.get(file) == a.streams[file]:
			n += 1
	return n


func _same_band(kept, fresh) -> bool:
	if kept.streams.keys() != fresh.streams.keys() or kept.clips.keys() != fresh.clips.keys():
		return false
	for id in fresh.clips:
		if kept.clips[id].get("paths") != fresh.clips[id].get("paths"):
			return false
	for file in fresh.streams:
		var a: AudioStreamOggVorbis = kept.streams[file]
		var b: AudioStreamOggVorbis = fresh.streams[file]
		if a.loop != b.loop or a.loop_offset != b.loop_offset:
			return false
	return true
