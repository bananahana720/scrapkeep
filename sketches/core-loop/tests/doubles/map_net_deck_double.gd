extends "res://src/world/map_spillway.gd"

# Stage 1's map with a net deck declared 30 m down: the one method flow's rescue looks for.
const NET_H := -30.0


func net_deck_height() -> float:
	return NET_H
