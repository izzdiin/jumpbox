class_name Zoo
extends Node3D
## The mini zoo: a big fenced pen in the park's corner with ten animals
## that wander, graze and play on their own — horses (four), a rabbit, a
## cat, a small dinosaur, a giraffe, an elephant and a monkey — around a
## waterfall, a river, a fish pond and a mud puddle. Stand by an animal
## and its buttons appear; a horse can be ridden, with the kid SITTING on
## it while the horse's own legs do the walking. This node owns all of
## it: building, behaviour, buttons and riding. Main only wires it up.

const ZOO_X0 := -37.0
const ZOO_X1 := -13.0
const ZOO_Z0 := -37.0
const ZOO_Z1 := -21.0
const ZOO_GATE_Z := -29.0
const POND_POS := Vector3(-16.5, 0, -24.5)
const POND_R := 2.6
const MONKEY_TREE := Vector3(-24.5, 0, -35.2)

const SAND := Color(0.96, 0.86, 0.6)
const WHITE := Color(0.97, 0.97, 0.97)
const RAINBOW: Array[Color] = [
	Color(0.95, 0.3, 0.3), Color(1.0, 0.6, 0.15), Color(1.0, 0.85, 0.2), Color(0.4, 0.8, 0.3),
	Color(0.25, 0.65, 0.95), Color(0.55, 0.4, 0.9), Color(0.95, 0.45, 0.75),
]

const U := preload("res://scripts/util.gd")

var animals: Array[Dictionary] = []
var fish: Array[Dictionary] = []
var near: Dictionary = {}
var riding := false
var ridden: Dictionary = {}

var _player: Node
var _sound: Node
var _mount_changed := Callable()
var _feed_button: Button
var _play_button: Button
var _ride_button: Button


## Wire the zoo to the player, the sounds and the shared game layer,
## then build the pen and put its buttons on the layer.
func setup(player: Node, sound: Node, game_layer: CanvasLayer, mount_changed: Callable) -> void:
	_player = player
	_sound = sound
	_mount_changed = mount_changed
	build()
	_feed_button = _big_button("Beri Makan", Color(0.35, 0.75, 0.35), -248, -8)
	_feed_button.pressed.connect(func(): feed(near))
	game_layer.add_child(_feed_button)
	_play_button = _big_button("Ajak Main", Color(0.6, 0.45, 0.9), 8, 248)
	_play_button.pressed.connect(func(): play(near))
	game_layer.add_child(_play_button)
	# The ride button is smaller than the others on purpose: while you
	# ride it stays on screen the whole time.
	_ride_button = _big_button("Naik Kuda", Color(1.0, 0.6, 0.15), -100, 100)
	_ride_button.offset_top = -300
	_ride_button.offset_bottom = -238
	_ride_button.add_theme_font_size_override("font_size", 26)
	_ride_button.pressed.connect(func():
		if riding:
			stop_riding()
		else:
			start_riding())
	game_layer.add_child(_ride_button)


## Where a fisher stands for the pond, and where the bobber lands.
func pond_spot() -> Dictionary:
	return {"bank": POND_POS + Vector3(POND_R + 1.4, 0, 0.6), "water": POND_POS + Vector3(0.4, 0.1, 0)}


const HEART_COLORS: Array[Color] = [Color(0.95, 0.45, 0.75), Color(0.95, 0.3, 0.3), Color(1, 1, 1)]


func _big_button(text: String, color: Color, left: float, right: float) -> Button:
	var b := Button.new()
	b.text = text
	b.anchor_left = 0.5
	b.anchor_right = 0.5
	b.anchor_top = 1.0
	b.anchor_bottom = 1.0
	b.offset_left = left
	b.offset_right = right
	b.offset_top = -204
	b.offset_bottom = -96
	b.add_theme_font_size_override("font_size", 32)
	b.add_theme_color_override("font_color", Color.WHITE)
	for st in ["normal", "hover"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = color
		sb.set_corner_radius_all(28)
		b.add_theme_stylebox_override(st, sb)
	var sbp := StyleBoxFlat.new()
	sbp.bg_color = color.darkened(0.25)
	sbp.set_corner_radius_all(28)
	b.add_theme_stylebox_override("pressed", sbp)
	b.visible = false
	return b


func _zoo_sphere(parent: Node3D, r: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 18
	s.rings = 9
	m.mesh = s
	m.material_override = U.mat(color)
	m.position = pos
	parent.add_child(m)
	return m


func _zoo_sign(root: Node3D, text: String, y: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 96
	label.pixel_size = 0.005
	label.modulate = WHITE
	label.outline_size = 16
	label.outline_modulate = Color(0.1, 0.1, 0.15)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, y, 0)
	root.add_child(label)


## Four leg pivots at the hips, so the legs can swing while walking.
## Returns [legs, phase offsets] with diagonal pairs in step.
func _zoo_legs(root: Node3D, hip_y: float, len_: float, r: float, fx: float, bx: float, sz: float, color: Color) -> Array:
	var legs: Array[Node3D] = []
	var offs: Array[float] = []
	var spots := [Vector3(fx, hip_y, -sz), Vector3(fx, hip_y, sz), Vector3(bx, hip_y, -sz), Vector3(bx, hip_y, sz)]
	var off_list := [0.0, PI, PI, 0.0]
	for i in 4:
		var pivot := Node3D.new()
		pivot.position = spots[i]
		root.add_child(pivot)
		U.mesh_cylinder(pivot, r, len_, Vector3(0, -len_ / 2.0, 0), color)
		legs.append(pivot)
		offs.append(off_list[i])
	return [legs, offs]


func build() -> void:
	U.mesh_box(self, Vector3(23.6, 0.04, 15.6), Vector3(-25, 0.02, -29), SAND)
	var post_col := Color(0.85, 0.7, 0.45)
	var posts: Array[Vector3] = []
	var px := ZOO_X0
	while px <= ZOO_X1:
		posts.append(Vector3(px, 0, ZOO_Z0))
		posts.append(Vector3(px, 0, ZOO_Z1))
		px += 2.0
	var pz := ZOO_Z0 + 2.0
	while pz < ZOO_Z1:
		posts.append(Vector3(ZOO_X0, 0, pz))
		if pz < ZOO_GATE_Z - 1.6 or pz > ZOO_GATE_Z + 1.6:
			posts.append(Vector3(ZOO_X1, 0, pz))
		pz += 2.0
	for p in posts:
		U.block(self, Vector3(0.12, 1.0, 0.12), p + Vector3(0, 0.5, 0), post_col)
	var cx := (ZOO_X0 + ZOO_X1) / 2.0
	var cz := (ZOO_Z0 + ZOO_Z1) / 2.0
	for y in [0.45, 0.85]:
		U.block(self, Vector3(ZOO_X1 - ZOO_X0, 0.07, 0.07), Vector3(cx, y, ZOO_Z0), post_col)
		U.block(self, Vector3(ZOO_X1 - ZOO_X0, 0.07, 0.07), Vector3(cx, y, ZOO_Z1), post_col)
		U.block(self, Vector3(0.07, 0.07, ZOO_Z1 - ZOO_Z0), Vector3(ZOO_X0, y, cz), post_col)
		var seg_a := (ZOO_GATE_Z - 1.6) - ZOO_Z0
		var seg_b := ZOO_Z1 - (ZOO_GATE_Z + 1.6)
		U.block(self, Vector3(0.07, 0.07, seg_a), Vector3(ZOO_X1, y, ZOO_Z0 + seg_a / 2.0), post_col)
		U.block(self, Vector3(0.07, 0.07, seg_b), Vector3(ZOO_X1, y, ZOO_Z1 - seg_b / 2.0), post_col)
	# A hay pile and a water trough to make it a home.
	U.mesh_box(self, Vector3(1.4, 0.5, 1.0), Vector3(-35.4, 0.25, -22.6), Color(1.0, 0.85, 0.2))
	U.mesh_box(self, Vector3(1.6, 0.35, 0.7), Vector3(-20.2, 0.18, -22.2), Color(0.35, 0.7, 1.0))
	_build_zoo_scenery()
	animals.append(_zoo_horse(Vector3(-33, 0, -24.5), -0.6, Color(0.55, 0.38, 0.22)))
	animals.append(_zoo_horse(Vector3(-28, 0, -35.6), 0.9, Color(0.3, 0.22, 0.16)))
	animals.append(_zoo_horse(Vector3(-17.5, 0, -35.4), 2.4, Color(0.75, 0.55, 0.35)))
	animals.append(_zoo_horse(Vector3(-22, 0, -22.4), -2.8, Color(0.88, 0.85, 0.8)))
	animals.append(_zoo_rabbit(Vector3(-25, 0, -24), 2.6))
	animals.append(_zoo_cat(Vector3(-35.5, 0, -22.8), 0.7))
	animals.append(_zoo_dino(Vector3(-30.5, 0, -29.5), -2.2))
	animals.append(_zoo_giraffe(Vector3(-15.2, 0, -34.6), -0.9))
	animals.append(_zoo_elephant(Vector3(-19.5, 0, -30.5), 0.4))
	animals.append(_zoo_monkey(0.6))


## Waterfall and river, the fish pond, the mud puddle, rocks and trees.
func _build_zoo_scenery() -> void:
	var rock := Color(0.55, 0.55, 0.6)
	var water := Color(0.3, 0.62, 0.95)
	# The waterfall: a rock stack in the south-west corner, a sheet of
	# water falling into the river.
	U.mesh_box(self, Vector3(1.8, 1.2, 2.8), Vector3(-36.2, 0.6, -34.6), rock)
	U.mesh_box(self, Vector3(1.5, 1.0, 2.2), Vector3(-36.4, 1.6, -34.6), rock.darkened(0.1))
	U.mesh_box(self, Vector3(1.2, 0.9, 1.6), Vector3(-36.5, 2.4, -34.6), rock.darkened(0.2))
	U.mesh_box(self, Vector3(0.14, 2.5, 1.15), Vector3(-35.5, 1.35, -34.6), Color(0.78, 0.9, 1.0, 0.75))
	U.solid_cylinder(self, 0.75, 0.05, Vector3(-35.0, 0.05, -34.6), Color(0.9, 0.97, 1.0))
	# The river: flat blue segments flowing east, then bending to the pond.
	_zoo_flat(Vector3(9.5, 0.05, 1.7), Vector3(-30.2, 0.03, -34.6), water, 0.0)
	_zoo_flat(Vector3(6.0, 0.05, 1.7), Vector3(-23.6, 0.03, -33.2), water, 0.45)
	_zoo_flat(Vector3(5.6, 0.05, 1.7), Vector3(-19.9, 0.03, -29.9), water, 0.95)
	_zoo_flat(Vector3(4.6, 0.05, 1.7), Vector3(-17.6, 0.03, -26.6), water, 1.25)
	# The fish pond, ringed with rocks, with five fish circling inside.
	U.solid_cylinder(self, POND_R + 0.25, 0.05, POND_POS + Vector3(0, 0.02, 0), water.darkened(0.15))
	U.solid_cylinder(self, POND_R - 0.35, 0.06, POND_POS + Vector3(0, 0.04, 0), water.lightened(0.1))
	for i in 9:
		var ang := i * TAU / 9.0 + 0.2
		var rp := POND_POS + Vector3(cos(ang) * (POND_R + 0.45), 0, sin(ang) * (POND_R + 0.45))
		U.mesh_box(self, Vector3(0.55, 0.4, 0.45), rp + Vector3(0, 0.2, 0), rock)
	var fish_cols := [Color(1.0, 0.55, 0.15), Color(0.95, 0.3, 0.25), Color(1, 1, 1), Color(1.0, 0.8, 0.2), Color(0.95, 0.45, 0.75)]
	for i in 5:
		var f := Node3D.new()
		self.add_child(f)
		U.mesh_box(f, Vector3(0.26, 0.09, 0.07), Vector3(0, 0, 0), fish_cols[i])
		U.mesh_box(f, Vector3(0.1, 0.14, 0.02), Vector3(-0.17, 0, 0), fish_cols[i].darkened(0.15))
		fish.append({"node": f, "ang": randf() * TAU, "rad": randf_range(0.9, 1.9),
			"spd": randf_range(0.45, 0.85) * (1.0 if i % 2 == 0 else -1.0), "phase": randf() * 6.0})
	# The mud puddle the elephant loves.
	U.solid_cylinder(self, 1.9, 0.05, Vector3(-22.2, 0.03, -27.2), Color(0.45, 0.33, 0.2))
	U.solid_cylinder(self, 1.2, 0.06, Vector3(-22.2, 0.04, -27.2), Color(0.38, 0.27, 0.16))
	# Rocks to climb on and look at.
	U.block(self, Vector3(1.3, 0.8, 1.0), Vector3(-14.2, 0.4, -22.2), rock)
	U.block(self, Vector3(0.9, 0.55, 0.8), Vector3(-31.5, 0.28, -21.9), rock.darkened(0.08))
	U.mesh_box(self, Vector3(0.8, 0.5, 0.7), Vector3(-26.5, 0.25, -36.3), rock)
	U.mesh_box(self, Vector3(0.6, 0.35, 0.55), Vector3(-36.3, 0.18, -28.5), rock.darkened(0.12))
	U.mesh_box(self, Vector3(0.7, 0.45, 0.6), Vector3(-15.6, 0.23, -30.8), rock)
	# Shade trees inside the pen — one of them is the monkey's, with a
	# horizontal branch to sit on.
	_zoo_tree(Vector3(-35.2, 0, -22.4), 1.0)
	_zoo_tree(Vector3(-14.6, 0, -36.2), 1.15)
	_zoo_tree(MONKEY_TREE, 1.0)
	var branch := Node3D.new()
	branch.position = MONKEY_TREE + Vector3(0.75, 1.52, 0)
	branch.rotation.z = PI / 2.0
	self.add_child(branch)
	U.mesh_cylinder(branch, 0.09, 1.9, Vector3(0, 0, 0), Color(0.45, 0.32, 0.18))
	# Grass tufts to graze on.
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 16:
		var gp := Vector3(rng.randf_range(ZOO_X0 + 1.2, ZOO_X1 - 1.2), 0, rng.randf_range(ZOO_Z0 + 1.2, ZOO_Z1 - 1.2))
		if Vector2(gp.x - POND_POS.x, gp.z - POND_POS.z).length() < POND_R + 0.8:
			continue
		U.mesh_box(self, Vector3(0.3, 0.22, 0.3), gp + Vector3(0, 0.11, 0), Color(0.4, 0.8, 0.35))


func _zoo_flat(size: Vector3, pos: Vector3, color: Color, yaw: float) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = yaw
	self.add_child(holder)
	U.mesh_box(holder, size, Vector3(0, 0, 0), color)
	U.mesh_box(holder, Vector3(size.x * 0.55, 0.055, size.z * 0.45), Vector3(0, 0.004, 0), color.lightened(0.25))


func _zoo_tree(pos: Vector3, s: float) -> void:
	U.mesh_cylinder(self, 0.16 * s, 1.7 * s, pos + Vector3(0, 0.85 * s, 0), Color(0.45, 0.32, 0.18))
	U.mesh_box(self, Vector3(1.9, 1.1, 1.9) * s, pos + Vector3(0, 2.1 * s, 0), Color(0.3, 0.65, 0.3))
	U.mesh_box(self, Vector3(1.3, 0.8, 1.3) * s, pos + Vector3(0.3, 2.8 * s, 0.2), Color(0.36, 0.72, 0.32))


func _zoo_entry(root: Node3D, kind: String, yaw: float) -> Dictionary:
	root.rotation.y = yaw
	self.add_child(root)
	return {"root": root, "kind": kind, "tail": null, "head": null, "neck": null, "food": null,
		"phase": randf() * 6.0, "play_t": 0.0, "feed_t": 0.0, "home_yaw": yaw, "home": root.position,
		"legs": [], "leg_off": [], "state": "idle", "state_t": randf_range(1.0, 4.0),
		"target": root.position, "path": [], "speed": 0.9, "walk_phase": 0.0, "idle_t": 0.0,
		"graze_dir": 0.0, "graze_amp": 0.38, "head_base": 0.0, "ridden": false, "perch": Vector3.ZERO}



func _zoo_horse(pos: Vector3, yaw: float, brown: Color) -> Dictionary:
	var root := Node3D.new()
	root.position = pos
	var dark := Color(0.3, 0.2, 0.12)
	U.mesh_box(root, Vector3(1.5, 0.62, 0.55), Vector3(0, 1.02, 0), brown)
	var neck := Node3D.new()
	neck.position = Vector3(0.72, 1.24, 0)
	neck.rotation.z = -0.55
	root.add_child(neck)
	U.mesh_box(neck, Vector3(0.3, 0.66, 0.3), Vector3(0, 0.28, 0), brown)
	U.mesh_box(neck, Vector3(0.1, 0.6, 0.34), Vector3(-0.14, 0.28, 0), dark)
	var head := Node3D.new()
	head.position = Vector3(1.02, 1.66, 0)
	root.add_child(head)
	U.mesh_box(head, Vector3(0.56, 0.28, 0.28), Vector3(0, 0, 0), brown)
	U.mesh_box(head, Vector3(0.24, 0.2, 0.22), Vector3(0.36, -0.05, 0), brown.lightened(0.12))
	U.mesh_box(head, Vector3(0.08, 0.16, 0.05), Vector3(-0.16, 0.2, -0.1), brown)
	U.mesh_box(head, Vector3(0.08, 0.16, 0.05), Vector3(-0.16, 0.2, 0.1), brown)
	var lp := _zoo_legs(root, 0.72, 0.72, 0.07, 0.55, -0.55, 0.18, brown.darkened(0.15))
	var tail := Node3D.new()
	tail.position = Vector3(-0.76, 1.24, 0)
	root.add_child(tail)
	U.mesh_box(tail, Vector3(0.12, 0.6, 0.12), Vector3(0, -0.28, 0), dark)
	var food := _zoo_sphere(root, 0.11, Vector3(1.5, 0.11, 0), Color(0.9, 0.2, 0.2))
	food.visible = false
	_zoo_sign(root, "Kuda", 2.35)
	var e := _zoo_entry(root, "kuda", yaw)
	e["tail"] = tail
	e["head"] = head
	e["neck"] = neck
	e["head_base"] = -0.55
	e["graze_dir"] = -1.0
	e["food"] = food
	e["legs"] = lp[0]
	e["leg_off"] = lp[1]
	e["speed"] = 1.15
	return e


func _zoo_rabbit(pos: Vector3, yaw: float) -> Dictionary:
	var root := Node3D.new()
	root.position = pos
	var fur := Color(0.92, 0.92, 0.95)
	var body := _zoo_sphere(root, 0.3, Vector3(0, 0.3, 0), fur)
	body.scale = Vector3(1.15, 0.9, 0.9)
	_zoo_sphere(root, 0.2, Vector3(0.3, 0.52, 0), fur)
	_zoo_sphere(root, 0.09, Vector3(-0.36, 0.38, 0), Color(1, 1, 1))
	for sz in [-1.0, 1.0]:
		var ear := Node3D.new()
		ear.position = Vector3(0.26, 0.68, 0.08 * sz)
		ear.rotation.z = -0.15
		root.add_child(ear)
		U.mesh_box(ear, Vector3(0.07, 0.36, 0.03), Vector3(0, 0.18, 0), fur)
	var food := Node3D.new()
	food.position = Vector3(0.6, 0.1, 0)
	food.rotation.z = -1.2
	root.add_child(food)
	var cone := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.07
	cm.height = 0.28
	cone.mesh = cm
	cone.material_override = U.mat(Color(1.0, 0.55, 0.15))
	food.add_child(cone)
	U.mesh_box(food, Vector3(0.05, 0.14, 0.05), Vector3(0, 0.2, 0), Color(0.35, 0.75, 0.35))
	food.visible = false
	_zoo_sign(root, "Kelinci", 1.45)
	var e := _zoo_entry(root, "kelinci", yaw)
	e["food"] = food
	e["speed"] = 1.7
	return e


func _zoo_cat(pos: Vector3, yaw: float) -> Dictionary:
	var root := Node3D.new()
	root.position = pos
	var fur := Color(0.95, 0.6, 0.2)
	U.mesh_box(root, Vector3(0.55, 0.3, 0.28), Vector3(0, 0.34, 0), fur)
	U.mesh_box(root, Vector3(0.3, 0.28, 0.28), Vector3(0.36, 0.5, 0), fur)
	for sz in [-1.0, 1.0]:
		U.mesh_box(root, Vector3(0.09, 0.15, 0.04), Vector3(0.32, 0.7, 0.08 * sz), fur)
		U.mesh_cylinder(root, 0.045, 0.22, Vector3(0.2, 0.11, 0.09 * sz), fur.darkened(0.1))
		U.mesh_cylinder(root, 0.045, 0.22, Vector3(-0.2, 0.11, 0.09 * sz), fur.darkened(0.1))
	var tail := Node3D.new()
	tail.position = Vector3(-0.3, 0.42, 0)
	root.add_child(tail)
	var tail_mesh := U.mesh_box(tail, Vector3(0.42, 0.06, 0.06), Vector3(-0.18, 0.1, 0), fur)
	tail_mesh.rotation.z = 0.5
	var food := Node3D.new()
	food.position = Vector3(0.62, 0.08, 0)
	root.add_child(food)
	U.mesh_box(food, Vector3(0.3, 0.09, 0.13), Vector3(0, 0, 0), Color(0.6, 0.75, 0.85))
	U.mesh_box(food, Vector3(0.12, 0.16, 0.02), Vector3(-0.2, 0, 0), Color(0.6, 0.75, 0.85))
	food.visible = false
	_zoo_sign(root, "Kucing", 1.25)
	var e := _zoo_entry(root, "kucing", yaw)
	e["tail"] = tail
	e["food"] = food
	e["speed"] = 0.95
	return e


func _zoo_dino(pos: Vector3, yaw: float) -> Dictionary:
	var root := Node3D.new()
	root.position = pos
	var skin := Color(0.35, 0.7, 0.35)
	U.mesh_box(root, Vector3(1.15, 0.62, 0.52), Vector3(0, 0.66, 0), skin)
	for i in 3:
		var plate := U.mesh_box(root, Vector3(0.1, 0.2, 0.3), Vector3(-0.3 + i * 0.3, 1.06, 0), skin.darkened(0.25))
		plate.rotation.z = 0.3
	var neck := Node3D.new()
	neck.position = Vector3(0.55, 0.92, 0)
	neck.rotation.z = -0.5
	root.add_child(neck)
	U.mesh_box(neck, Vector3(0.26, 0.55, 0.26), Vector3(0, 0.24, 0), skin)
	var head := Node3D.new()
	head.position = Vector3(0.88, 1.34, 0)
	root.add_child(head)
	U.mesh_box(head, Vector3(0.44, 0.24, 0.26), Vector3(0, 0, 0), skin)
	U.mesh_box(head, Vector3(0.2, 0.16, 0.2), Vector3(0.28, -0.04, 0), skin.lightened(0.12))
	var tail_mesh := U.mesh_box(root, Vector3(0.85, 0.16, 0.16), Vector3(-0.95, 0.6, 0), skin.darkened(0.1))
	tail_mesh.rotation.z = 0.25
	var lp := _zoo_legs(root, 0.36, 0.36, 0.09, 0.38, -0.38, 0.17, skin.darkened(0.12))
	var food := Node3D.new()
	food.position = Vector3(1.2, 0.05, 0)
	root.add_child(food)
	U.mesh_box(food, Vector3(0.36, 0.04, 0.26), Vector3(0, 0, 0), Color(0.45, 0.85, 0.4))
	food.visible = false
	_zoo_sign(root, "Dino", 2.0)
	var e := _zoo_entry(root, "dino", yaw)
	e["head"] = head
	e["neck"] = neck
	e["head_base"] = -0.5
	e["graze_dir"] = -1.0
	e["food"] = food
	e["legs"] = lp[0]
	e["leg_off"] = lp[1]
	e["speed"] = 0.7
	return e


func _zoo_giraffe(pos: Vector3, yaw: float) -> Dictionary:
	var root := Node3D.new()
	root.position = pos
	var tan_c := Color(0.87, 0.66, 0.35)
	var spot := Color(0.6, 0.4, 0.2)
	var lp := _zoo_legs(root, 1.5, 1.5, 0.06, 0.55, -0.55, 0.2, tan_c.darkened(0.1))
	U.mesh_box(root, Vector3(1.5, 0.62, 0.55), Vector3(0, 1.82, 0), tan_c)
	for sx in [-1.0, 1.0]:
		for i in 3:
			U.mesh_box(root, Vector3(0.26, 0.2, 0.03), Vector3(-0.45 + i * 0.45, 1.7 + 0.14 * sx, 0.29 * sx), spot)
	var neck := Node3D.new()
	neck.position = Vector3(0.68, 2.02, 0)
	neck.rotation.z = 1.02
	root.add_child(neck)
	U.mesh_box(neck, Vector3(1.45, 0.24, 0.24), Vector3(0.68, 0, 0), tan_c)
	var head := Node3D.new()
	head.position = Vector3(1.42, 0, 0)
	neck.add_child(head)
	U.mesh_box(head, Vector3(0.4, 0.24, 0.24), Vector3(0, 0, 0), tan_c)
	U.mesh_box(head, Vector3(0.2, 0.17, 0.18), Vector3(0.28, -0.03, 0), tan_c.lightened(0.12))
	for sz in [-1.0, 1.0]:
		U.mesh_cylinder(head, 0.025, 0.16, Vector3(-0.05, 0.18, 0.08 * sz), spot)
		_zoo_sphere(head, 0.045, Vector3(-0.05, 0.27, 0.08 * sz), spot)
	var tail := Node3D.new()
	tail.position = Vector3(-0.76, 2.05, 0)
	root.add_child(tail)
	U.mesh_box(tail, Vector3(0.07, 0.7, 0.07), Vector3(0, -0.33, 0), tan_c.darkened(0.2))
	var food := Node3D.new()
	food.position = Vector3(1.8, 2.75, 0)
	root.add_child(food)
	U.mesh_box(food, Vector3(0.3, 0.16, 0.3), Vector3(0, 0, 0), Color(0.4, 0.8, 0.35))
	U.mesh_box(food, Vector3(0.22, 0.14, 0.22), Vector3(0.12, 0.1, 0.08), Color(0.35, 0.72, 0.3))
	food.visible = false
	_zoo_sign(root, "Jerapah", 3.95)
	var e := _zoo_entry(root, "jerapah", yaw)
	e["tail"] = tail
	e["neck"] = neck
	e["head_base"] = 1.02
	e["graze_dir"] = 1.0
	e["graze_amp"] = 0.22
	e["food"] = food
	e["legs"] = lp[0]
	e["leg_off"] = lp[1]
	e["speed"] = 0.8
	return e


func _zoo_elephant(pos: Vector3, yaw: float) -> Dictionary:
	var root := Node3D.new()
	root.position = pos
	var grey := Color(0.62, 0.64, 0.68)
	var lp := _zoo_legs(root, 0.78, 0.78, 0.13, 0.72, -0.72, 0.3, grey.darkened(0.08))
	U.mesh_box(root, Vector3(2.0, 1.1, 1.0), Vector3(0, 1.32, 0), grey)
	var head := Node3D.new()
	head.position = Vector3(0.98, 1.5, 0)
	root.add_child(head)
	U.mesh_box(head, Vector3(0.6, 0.6, 0.6), Vector3(0.18, 0.02, 0), grey)
	for sz in [-1.0, 1.0]:
		var ear := U.mesh_box(head, Vector3(0.5, 0.62, 0.06), Vector3(-0.08, 0.05, 0.4 * sz), grey.lightened(0.06))
		ear.rotation.y = -0.3 * sz
		var tusk := U.mesh_cylinder(head, 0.03, 0.3, Vector3(0.42, -0.18, 0.16 * sz), Color(0.95, 0.93, 0.85))
		tusk.rotation.z = 2.7
	U.mesh_box(head, Vector3(0.15, 0.45, 0.15), Vector3(0.5, -0.3, 0), grey)
	U.mesh_box(head, Vector3(0.12, 0.4, 0.12), Vector3(0.55, -0.66, 0), grey)
	U.mesh_box(head, Vector3(0.09, 0.32, 0.09), Vector3(0.5, -0.96, 0), grey.darkened(0.05))
	var tail := Node3D.new()
	tail.position = Vector3(-1.02, 1.62, 0)
	root.add_child(tail)
	U.mesh_box(tail, Vector3(0.07, 0.6, 0.07), Vector3(0, -0.28, 0), grey.darkened(0.15))
	var food := _zoo_sphere(root, 0.17, Vector3(1.75, 0.17, 0), Color(0.3, 0.6, 0.25))
	food.visible = false
	_zoo_sign(root, "Gajah", 2.95)
	var e := _zoo_entry(root, "gajah", yaw)
	e["tail"] = tail
	e["neck"] = head
	e["head_base"] = 0.0
	e["graze_dir"] = -1.0
	e["graze_amp"] = 0.3
	e["food"] = food
	e["legs"] = lp[0]
	e["leg_off"] = lp[1]
	e["speed"] = 0.7
	return e


func _zoo_monkey(yaw: float) -> Dictionary:
	var root := Node3D.new()
	var perch := MONKEY_TREE + Vector3(1.15, 1.62, 0)
	root.position = perch
	var fur := Color(0.5, 0.35, 0.2)
	var cream := Color(0.9, 0.78, 0.6)
	_zoo_sphere(root, 0.21, Vector3(0, 0.28, 0), fur).scale = Vector3(1, 1.1, 0.95)
	_zoo_sphere(root, 0.15, Vector3(0.17, 0.56, 0), fur)
	_zoo_sphere(root, 0.1, Vector3(0.27, 0.53, 0), cream).scale = Vector3(0.7, 0.9, 1)
	for sz in [-1.0, 1.0]:
		_zoo_sphere(root, 0.05, Vector3(0.13, 0.58, 0.15 * sz), fur)
		var arm := U.mesh_cylinder(root, 0.035, 0.34, Vector3(0.05, 0.28, 0.24 * sz), fur.darkened(0.08))
		arm.rotation.x = 0.4 * sz
		U.mesh_cylinder(root, 0.04, 0.2, Vector3(-0.02, 0.08, 0.1 * sz), fur.darkened(0.08))
	var tail := Node3D.new()
	tail.position = Vector3(-0.2, 0.34, 0)
	root.add_child(tail)
	var t1 := U.mesh_box(tail, Vector3(0.05, 0.28, 0.05), Vector3(-0.08, 0.12, 0), fur)
	t1.rotation.z = 0.5
	var t2 := U.mesh_box(tail, Vector3(0.05, 0.24, 0.05), Vector3(-0.22, 0.3, 0), fur)
	t2.rotation.z = 1.1
	var food := Node3D.new()
	food.position = Vector3(0.5, 0.07, 0)
	root.add_child(food)
	var banana := U.mesh_box(food, Vector3(0.17, 0.05, 0.05), Vector3(0, 0, 0), Color(1.0, 0.85, 0.25))
	banana.rotation.z = 0.35
	food.visible = false
	_zoo_sign(root, "Monyet", 1.35)
	var e := _zoo_entry(root, "monyet", yaw)
	e["tail"] = tail
	e["food"] = food
	e["perch"] = perch
	e["home"] = perch
	e["speed"] = 2.3
	return e



func _zoo_random_spot() -> Vector3:
	for tries in 8:
		var p := Vector3(randf_range(ZOO_X0 + 1.6, ZOO_X1 - 1.6), 0, randf_range(ZOO_Z0 + 1.6, ZOO_Z1 - 1.6))
		if Vector2(p.x - POND_POS.x, p.z - POND_POS.z).length() > POND_R + 1.0:
			return p
	return Vector3(-25, 0, -29)


## Pick where an idle animal goes next: a wander spot, the monkey's
## branch, or the way home through the gate after being ridden outside.
func _zoo_next_move(a: Dictionary) -> void:
	var root: Node3D = a["root"]
	var pos := root.position
	var outside := pos.x < ZOO_X0 - 0.5 or pos.x > ZOO_X1 + 0.5 or pos.z < ZOO_Z0 - 0.5 or pos.z > ZOO_Z1 + 0.5
	if outside:
		a["path"] = [Vector3(ZOO_X1 + 1.6, 0, ZOO_GATE_Z), Vector3(ZOO_X1 - 2.4, 0, ZOO_GATE_Z), _zoo_random_spot()]
	elif a["kind"] == "monyet":
		if pos.y > 0.5:
			if randf() < 0.5:
				a["state_t"] = randf_range(2.5, 6.0)
				return
			a["path"] = [Vector3(MONKEY_TREE.x + randf_range(-1.5, 2.2), 0, MONKEY_TREE.z + randf_range(-1.4, 1.6))]
		elif randf() < 0.5:
			a["path"] = [a["perch"]]
		else:
			a["path"] = [Vector3(MONKEY_TREE.x + randf_range(-2.5, 3.0), 0, MONKEY_TREE.z + randf_range(-1.4, 1.6))]
	else:
		a["path"] = [_zoo_random_spot()]
	if not a["path"].is_empty():
		a["target"] = a["path"][0]
		a["state"] = "walk"


func _zoo_idle_pose(a: Dictionary) -> void:
	var t := Time.get_ticks_msec() * 0.001
	var phase: float = a["phase"]
	var root: Node3D = a["root"]
	match a["kind"]:
		"kelinci":
			root.position.y = pow(maxf(sin(t * 2.4 + phase), 0.0), 6.0) * 0.12
		"kuda":
			if a["tail"]:
				a["tail"].rotation.x = sin(t * 2.2 + phase) * 0.35
			if a["head"]:
				a["head"].rotation.z = sin(t * 0.9 + phase) * 0.07
		"kucing":
			if a["tail"]:
				a["tail"].rotation.y = sin(t * 3.0 + phase) * 0.4
		"dino":
			if a["head"]:
				a["head"].rotation.y = sin(t * 0.7 + phase) * 0.25
		"jerapah", "gajah":
			if a["tail"]:
				a["tail"].rotation.x = sin(t * 1.8 + phase) * 0.3
		"monyet":
			if a["tail"]:
				a["tail"].rotation.y = sin(t * 2.6 + phase) * 0.35
			if root.position.y > 0.5:
				root.rotation.z = sin(t * 1.3 + phase) * 0.05
	if float(a["graze_dir"]) != 0.0 and a["neck"]:
		var g := pow(maxf(sin(float(a["idle_t"]) * 0.55 + phase), 0.0), 3.0)
		a["neck"].rotation.z = float(a["head_base"]) + float(a["graze_dir"]) * float(a["graze_amp"]) * g


func _zoo_wander(a: Dictionary, delta: float) -> void:
	var root: Node3D = a["root"]
	a["idle_t"] = float(a["idle_t"]) + delta
	if a["state"] == "idle":
		a["state_t"] = float(a["state_t"]) - delta
		_zoo_idle_pose(a)
		if float(a["state_t"]) <= 0.0:
			_zoo_next_move(a)
		return
	root.rotation.z = lerpf(root.rotation.z, 0.0, 0.2)
	var to: Vector3 = a["target"] - root.position
	var dist := to.length()
	if dist < 0.35:
		root.position.y = float(a["target"].y)
		a["path"].remove_at(0)
		if a["path"].is_empty():
			a["state"] = "idle"
			a["state_t"] = randf_range(2.0, 6.0)
			a["idle_t"] = 0.0
			for leg in a["legs"]:
				leg.rotation.z = 0.0
		else:
			a["target"] = a["path"][0]
		return
	var spd := float(a["speed"])
	if a["kind"] == "kuda" and dist > 7.0:
		spd *= 2.1
	if a["kind"] == "kucing" and dist > 5.0:
		spd *= 1.9
	var dir := to / dist
	root.position += dir * spd * delta
	if Vector2(dir.x, dir.z).length() > 0.05:
		root.rotation.y = lerp_angle(root.rotation.y, atan2(-dir.z, dir.x), 1.0 - exp(-8.0 * delta))
	a["walk_phase"] = float(a["walk_phase"]) + delta * spd * 3.4
	var ph: float = a["walk_phase"]
	for j in a["legs"].size():
		a["legs"][j].rotation.z = sin(ph + float(a["leg_off"][j])) * 0.5
	match a["kind"]:
		"kelinci":
			root.position.y = absf(sin(ph * 1.4)) * 0.16
		"monyet":
			pass
		_:
			if not a["legs"].is_empty():
				root.position.y = absf(sin(ph)) * 0.03


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		if not near.is_empty():
			near = {}
			_feed_button.visible = false
			_play_button.visible = false
			_ride_button.visible = riding
		return
	var t := Time.get_ticks_msec() * 0.001
	for a in animals:
		var root: Node3D = a["root"]
		var busy := false
		if float(a["feed_t"]) > 0.0:
			busy = true
			a["feed_t"] = float(a["feed_t"]) - delta
			if a["kind"] != "kelinci":
				var base_y := float(a["perch"].y) if a["kind"] == "monyet" and root.position.y > 0.5 else 0.0
				root.position.y = base_y + absf(sin(t * 14.0)) * 0.04
			if float(a["feed_t"]) <= 0.0 and a["food"]:
				a["food"].visible = false
		if float(a["play_t"]) > 0.0:
			busy = true
			a["play_t"] = float(a["play_t"]) - delta
			var prog := 1.0 - maxf(float(a["play_t"]), 0.0) / 1.2
			match a["kind"]:
				"kelinci":
					root.position.y += absf(sin(prog * PI * 3.0)) * 0.45
				"kucing", "monyet":
					root.rotation.y += delta * 7.0
				"kuda":
					root.rotation.z = -0.4 * sin(prog * PI)
				"dino":
					if a["head"]:
						a["head"].rotation.z = -0.35 * sin(prog * PI)
				"jerapah":
					if a["neck"]:
						a["neck"].rotation.z = float(a["head_base"]) + sin(prog * PI) * 0.3
				"gajah":
					root.rotation.z = -0.1 * sin(prog * PI)
					if a["neck"]:
						a["neck"].rotation.z = -0.25 * sin(prog * PI)
			if float(a["play_t"]) <= 0.0:
				root.rotation.z = 0.0
				root.rotation.y = float(a["home_yaw"])
				if a["head"]:
					a["head"].rotation.z = 0.0
				if a["neck"]:
					a["neck"].rotation.z = float(a["head_base"])
		if not busy and not a["ridden"]:
			_zoo_wander(a, delta)
	for f in fish:
		f["ang"] = float(f["ang"]) + float(f["spd"]) * delta
		var node: Node3D = f["node"]
		var np := POND_POS + Vector3(cos(float(f["ang"])) * float(f["rad"]), 0.14 + sin(t * 3.0 + float(f["phase"])) * 0.02, sin(float(f["ang"])) * float(f["rad"]))
		var fdir := np - node.position
		node.position = np
		if fdir.length() > 0.0005:
			node.rotation.y = atan2(-fdir.z, fdir.x)
	# Who are you standing by? Their buttons follow (with a little
	# hysteresis, so they do not flicker while an animal strolls off).
	if riding:
		near = {}
	else:
		if not near.is_empty():
			var nr: Node3D = near["root"]
			var nd := Vector2(_player.global_position.x - nr.position.x, _player.global_position.z - nr.position.z).length()
			if nd > 2.7 or not nr.visible:
				near = {}
		if near.is_empty():
			var best := 2.1
			for a in animals:
				if a["ridden"]:
					continue
				var aroot: Node3D = a["root"]
				var d := Vector2(_player.global_position.x - aroot.position.x, _player.global_position.z - aroot.position.z).length()
				if d < best:
					best = d
					near = a
	if _feed_button:
		_feed_button.visible = not near.is_empty()
		_play_button.visible = not near.is_empty()
		_ride_button.visible = riding or (not near.is_empty() and near["kind"] == "kuda")
		_ride_button.text = "Turun" if riding else "Naik Kuda"


func feed(a: Dictionary) -> void:
	if a.is_empty():
		return
	if a["food"]:
		a["food"].visible = true
	a["feed_t"] = 1.4
	_sound.play("checkpoint", -3.0)
	U.confetti(self, a["root"].position + Vector3(0, 1.2, 0), 16, HEART_COLORS)


func play(a: Dictionary) -> void:
	if a.is_empty():
		return
	a["play_t"] = 1.2
	_sound.play("boing", -3.0)
	U.confetti(self, a["root"].position + Vector3(0, 1.2, 0), 12, RAINBOW)


func horse_animal() -> Dictionary:
	for a in animals:
		if a["kind"] == "kuda":
			return a
	return {}


func start_riding() -> void:
	if near.is_empty() or near["kind"] != "kuda":
		return
	riding = true
	ridden = near
	ridden["ridden"] = true
	ridden["root"].visible = false
	_player.set_mount(true)
	_mount_changed.call()


func stop_riding(to_pen := false) -> void:
	if not riding:
		return
	riding = false
	_player.set_mount(false)
	if not ridden.is_empty():
		var root: Node3D = ridden["root"]
		if to_pen:
			root.position = ridden["home"]
		else:
			root.position = Vector3(_player.global_position.x, 0, _player.global_position.z)
		root.visible = true
		ridden["ridden"] = false
		ridden["state"] = "idle"
		ridden["state_t"] = 1.5
		ridden["path"] = []
		ridden = {}
	_mount_changed.call()


