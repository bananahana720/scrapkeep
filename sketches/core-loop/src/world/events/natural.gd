extends Node3D

const Kinds := preload("res://src/core/event_kinds.gd")
const Palette := preload("res://src/core/palette.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")

const KINDS := {
	"flood_fill": {"form": "flood_rising", "land": "flood_landed"},
	"drain": {"form": "flood_rising", "land": "flood_landed"},
	"cave_in": {"form": "cave_in_crumble", "land": "cave_in_swap"},
	"collapse": {"form": "cave_in_crumble", "land": "cave_in_swap"},
	"impact": {"form": "impact_incoming", "land": "impact_swap", "lift_mps": 8.0},
	"flash_flood": {"form": "flood_rising", "land": "flood_landed"},
	"lightning": {"form": "lightning_charge", "land": "lightning_landed", "lift_mps": 8.0},
}

var world
var active := {}


func setup(world_ref) -> void:
	world = world_ref
	name = "NaturalEvents"


func handle(action: String, row: Dictionary, ctx: Dictionary) -> void:
	if not KINDS.has(row.kind):
		return
	match action:
		"telegraph":
			active[row.id] = {"phase": "telegraph", "at": ctx.at}
		"land":
			active[row.id].phase = "land"
		"step":
			active[row.id].phase = "live"
		"end":
			active.erase(row.id)


func release() -> void:
	active.clear()
	world = null
