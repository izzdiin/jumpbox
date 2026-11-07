class_name River
extends Node3D
## The park river: a long, wide and deep channel running down the west
## side of the park, from the north fence to just above the mini zoo.
## It is deep enough to swim in (main asks this node where the water is
## and puts the player into swim mode), with stone banks, three wooden
## decks to fish from, and ramps at the decks and the south end so
## swimmers can climb out again. The ground slab in main leaves a gap
## exactly where this channel runs.

const CH_X0 := -35.2
const CH_X1 := -30.8
const CH_Z0 := -19.5
const CH_Z1 := 38.0
const BED_Y := -1.05
const WATER_Y := -0.5
const SWIM_Y := -0.42
const DECK_Z: Array[float] = [24.0, 2.0, -16.0]

const U := preload("res://scripts/util.gd")
const STONE := Color(0.55, 0.55, 0.6)
const WOOD := Color(0.6, 0.4, 0.22)


func build() -> void:
	var cx := (CH_X0 + CH_X1) / 2.0
	var cz := (CH_Z0 + CH_Z1) / 2.0
	var len_z := CH_Z1 - CH_Z0
	# The bed and the water itself.
	U.block(self, Vector3(CH_X1 - CH_X0, 0.3, len_z), Vector3(cx, BED_Y - 0.15, cz), Color(0.76, 0.68, 0.5))
	U.mesh_box(self, Vector3(CH_X1 - CH_X0 - 0.3, 0.5, len_z), Vector3(cx, WATER_Y - 0.25, cz), Color(0.3, 0.62, 0.95, 0.8))
	U.mesh_box(self, Vector3(1.6, 0.52, len_z), Vector3(cx - 0.5, WATER_Y - 0.25, cz), Color(0.45, 0.72, 0.97, 0.55))
	# Stone linings along both banks, hiding the cut faces of the ground.
	for sx in [CH_X0 + 0.12, CH_X1 - 0.12]:
		U.mesh_box(self, Vector3(0.24, 1.16, len_z), Vector3(sx, -0.5, cz), STONE)
	# The north end: rocks and a little fall where the river comes from.
	U.mesh_box(self, Vector3(1.6, 1.1, 1.2), Vector3(cx - 0.9, 0.4, CH_Z1 - 0.5), STONE.darkened(0.1))
	U.mesh_box(self, Vector3(1.3, 1.7, 1.0), Vector3(cx + 0.7, 0.7, CH_Z1 - 0.45), STONE.darkened(0.2))
	U.mesh_box(self, Vector3(0.12, 1.6, 1.1), Vector3(cx - 0.15, 0.6, CH_Z1 - 0.55), Color(0.78, 0.9, 1.0, 0.75))
	# Rocks where the river ends above the zoo.
	U.mesh_box(self, Vector3(1.1, 0.6, 0.8), Vector3(cx - 1.0, -0.75, CH_Z0 + 0.3), STONE)
	U.mesh_box(self, Vector3(0.8, 0.45, 0.7), Vector3(cx + 1.1, -0.82, CH_Z0 + 0.25), STONE.darkened(0.12))
	# The exit ramps: at the south end and beside every deck, the bed
	# rises in a walkable slope back to the bank. Their centres all sit
	# at y = -0.47, so the low end meets the bed and the high end the bank.
	_add_ramp(Vector3(cx, -0.47, CH_Z0 + 0.9), Vector3(CH_X1 - CH_X0 - 0.4, 0.25, 2.6), Vector3(deg_to_rad(24.0), 0, 0))
	for dz in DECK_Z:
		_add_ramp(Vector3(CH_X1 - 0.75, -0.47, dz), Vector3(2.6, 0.25, 1.7), Vector3(0, 0, deg_to_rad(24.0)))
	# The wooden fishing decks on the east bank.
	for dz in DECK_Z:
		U.block(self, Vector3(1.7, 0.1, 2.3), Vector3(CH_X1 + 0.6, 0.05, dz), WOOD)
		U.mesh_box(self, Vector3(0.09, 0.5, 0.09), Vector3(CH_X1 + 1.35, 0.25, dz - 1.05), WOOD.darkened(0.2))
		U.mesh_box(self, Vector3(0.09, 0.5, 0.09), Vector3(CH_X1 + 1.35, 0.25, dz + 1.05), WOOD.darkened(0.2))


func _add_ramp(center: Vector3, size: Vector3, rot: Vector3) -> void:
	var holder := Node3D.new()
	holder.position = center
	holder.rotation = rot
	add_child(holder)
	U.block(holder, size, Vector3(0, 0, 0), Color(0.76, 0.68, 0.5))


func in_channel(pos: Vector3) -> bool:
	return pos.x > CH_X0 and pos.x < CH_X1 and pos.z > CH_Z0 and pos.z < CH_Z1


## The upper part of every ramp: while a swimmer is over one, swim mode
## lets go so physics can walk them up the slope and out.
func ramp_at(pos: Vector3) -> bool:
	if pos.z < CH_Z0 + 1.6 and pos.z > CH_Z0 - 0.2 and in_channel(pos):
		return true
	if pos.x > CH_X1 - 1.5 and pos.x < CH_X1 + 0.1:
		for dz in DECK_Z:
			if absf(pos.z - dz) < 1.15:
				return true
	return false


## One fishing spot per deck: where to stand, where the bobber lands.
func fishing_spots() -> Array:
	var out: Array = []
	for dz in DECK_Z:
		out.append({"bank": Vector3(CH_X1 + 0.6, 0, dz), "water": Vector3((CH_X0 + CH_X1) / 2.0, WATER_Y + 0.06, dz)})
	return out
