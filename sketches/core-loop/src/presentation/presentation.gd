extends Node

# Writer C's module: how every committed fact looks and sounds. It reads GameEvents
# and event_kinds.gd and nothing else (TADR-008), and uses the camera and ball hooks
# in CONTRACTS.md for juice. This stub does nothing; C replaces this folder wholesale.

var ctx


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	name = "Presentation"
