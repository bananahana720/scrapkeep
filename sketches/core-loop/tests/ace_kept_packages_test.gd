extends SceneTree

const T := preload("res://tests/support/t.gd")
const Ace := preload("res://src/presentation/ace_sequencer.gd")
const AceStub := preload("res://tests/support/ace_stub.gd")

# A band built for a package it read lately reuses that package's streams instead of reading every
# Ogg again (the dam's landmark tune ending at the Warden engage brought the stage pack back for
# 13 ms of the 4080's tick). Only the last KEPT_PACKAGES packages are kept, so a band older than that
# reads its files again; every band built either way is ready and plays its own playbacks.

const A := "res://assets/music_ace/anthem_brindle/manifest.json"
const OTHERS := ["res://assets/music_ace/anthem_mind/manifest.json", "res://assets/music_ace/anthem_waking/manifest.json",
	"res://assets/music_ace/anthem_champion/manifest.json", "res://assets/music_ace/anthem_gate_crane/manifest.json"]

var _t := T.new("ace_kept_packages_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	AceStub.install("ace_kept_stub")
	var first := Ace.new(A)
	_t.check("the first band reads its package", first.ready() and first.streams.size() > 0, "missing %s, %d streams" % [first.missing, first.streams.size()])
	var again := Ace.new(A)
	_t.check("a band for the package just read reuses every stream", again.ready() and _shared(first, again) == first.streams.size(),
		"%d of %d shared" % [_shared(first, again), first.streams.size()])
	var playback_a := _playback(first)
	var playback_b := _playback(again)
	_t.check("each band still plays its own playback", playback_a != null and playback_b != null and playback_a != playback_b)
	var ready := true
	for k in Ace.KEPT_PACKAGES - 1:
		ready = ready and Ace.new(OTHERS[k]).ready()
	var back := Ace.new(A)
	_t.check("with KEPT_PACKAGES - 1 other packages read since, it is still kept", ready and back.ready() and _shared(first, back) == first.streams.size(),
		"%d of %d shared" % [_shared(first, back), first.streams.size()])
	for k in Ace.KEPT_PACKAGES:
		ready = ready and Ace.new(OTHERS[k]).ready()
	var late := Ace.new(A)
	_t.check("KEPT_PACKAGES other packages later, it is read again and still ready", ready and late.ready() and _shared(first, late) == 0,
		"%d shared" % _shared(first, late))
	quit(_t.verdict())


func _shared(a, b) -> int:
	var n := 0
	for file in a.streams:
		if b.streams.get(file) == a.streams[file]:
			n += 1
	return n


func _playback(band) -> AudioStreamPlayback:
	for file in band.streams:
		return band.streams[file].instantiate_playback()
	return null
