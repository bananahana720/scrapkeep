extends Node

const Audio := preload("res://src/presentation/audio.gd")
const Juice := preload("res://src/presentation/juice.gd")
const Vfx := preload("res://src/presentation/vfx.gd")

# Writer C's module: how every committed fact looks, feels and sounds. It reads the
# GameEvents bus, the event_kinds table and the spine's camera and ball hooks, and
# never decides an outcome (TADR-008).
#
#   audio.gd       the director: which cue, now or on the beat; the mixer and keys
#   music_engine   the band: 172 BPM drum-and-bass in D Dorian, layered by pressure
#   sfx_bank       one synthesized sound per event_kinds sound id
#   synth          the instrument rack both of them play
#   harmony        tempo, key and scales, the one musical source
#   juice          squash and stretch, camera punches and kicks, hit-stop, the pylon
#   vfx            trails, speed lines, flashes, rings and sparkles

var ctx
var audio
var juice
var vfx


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	name = "Presentation"
	audio = Audio.new()
	add_child(audio)
	audio.setup(ctx)
	juice = Juice.new()
	add_child(juice)
	juice.setup(ctx)
	vfx = Vfx.new()
	add_child(vfx)
	vfx.setup(ctx)
