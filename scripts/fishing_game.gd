class_name FishingGame
extends Node3D
## Mancing — the fishing mini game. Fishing spots wait at the zoo pond
## and on the river decks: stand on one and the Mancing button appears.
## Tap it to cast, wait for the bobber to dip and shout TARIK!, then tap
## fast to land the fish. Every catch earns stars through main's reward
## toast. No losing and no hurry anywhere except the bite moment.

const U := preload("res://scripts/util.gd")
const RAINBOW: Array[Color] = [
	Color(0.95, 0.3, 0.3), Color(1.0, 0.6, 0.15), Color(1.0, 0.85, 0.2), Color(0.4, 0.8, 0.3),
	Color(0.25, 0.65, 0.95), Color(0.55, 0.4, 0.9), Color(0.95, 0.45, 0.75),
]
## name, weight, smallest cm, biggest cm
const FISH := [
	["Ikan Mas", 0.30, 12.0, 35.0],
	["Ikan Nila", 0.30, 10.0, 30.0],
	["Ikan Lele", 0.20, 15.0, 40.0],
	["Ikan Cupang", 0.10, 5.0, 9.0],
	["Ikan Koi", 0.10, 15.0, 38.0],
]

var active := false  # a cast is out (waiting, biting or celebrating)

var _state := 0  # 0 idle, 1 waiting for a bite, 2 bite!, 3 result pause
var _timer := 0.0
var _spots: Array = []
var _spot: Dictionary = {}
var _bobber: Node3D
var _bobber_y := 0.0
var _button: Button
var _host: Node
var _player: Node
var _sound: Node
var _label: Label
var _sub: Label


func setup(host: Node, player: Node, sound: Node, label: Label, sub: Label, game_layer: CanvasLayer, spots: Array) -> void:
	_host = host
	_player = player
	_sound = sound
	_label = label
	_sub = sub
	_spots = spots
	_bobber = Node3D.new()
	_bobber.visible = false
	add_child(_bobber)
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.09
	sm.height = 0.18
	sm.radial_segments = 12
	sm.rings = 6
	ball.mesh = sm
	ball.material_override = U.mat(Color(0.95, 0.3, 0.3))
	_bobber.add_child(ball)
	var tip := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.015
	cm.bottom_radius = 0.015
	cm.height = 0.16
	tip.mesh = cm
	tip.material_override = U.mat(Color(1, 1, 1))
	tip.position = Vector3(0, 0.12, 0)
	_bobber.add_child(tip)
	_button = Button.new()
	_button.text = "Mancing"
	_button.anchor_left = 0.5
	_button.anchor_right = 0.5
	_button.anchor_top = 1.0
	_button.anchor_bottom = 1.0
	_button.offset_left = -140
	_button.offset_right = 140
	_button.offset_top = -204
	_button.offset_bottom = -96
	_button.add_theme_font_size_override("font_size", 36)
	_button.add_theme_color_override("font_color", Color.WHITE)
	for st in ["normal", "hover"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.1, 0.55, 0.6)
		sb.set_corner_radius_all(28)
		_button.add_theme_stylebox_override(st, sb)
	var sbp := StyleBoxFlat.new()
	sbp.bg_color = Color(0.08, 0.42, 0.47)
	sbp.set_corner_radius_all(28)
	_button.add_theme_stylebox_override("pressed", sbp)
	_button.visible = false
	_button.pressed.connect(_on_press)
	game_layer.add_child(_button)


func cancel() -> void:
	_state = 0
	active = false
	_spot = {}
	if _bobber:
		_bobber.visible = false
	if _button:
		_button.text = "Mancing"
		_button.visible = false


func _roll_fish() -> Array:
	var roll := randf()
	var acc := 0.0
	for f in FISH:
		acc += float(f[1])
		if roll <= acc:
			return [str(f[0]), int(round(randf_range(float(f[2]), float(f[3]))))]
	var last: Array = FISH[FISH.size() - 1]
	return [str(last[0]), int(round(randf_range(float(last[2]), float(last[3]))))]


func _on_press() -> void:
	if _state == 0:
		_cast()
	elif _state == 2:
		_catch()


func _cast() -> void:
	if _spot.is_empty():
		return
	_state = 1
	active = true
	_timer = randf_range(2.5, 6.0)
	_bobber.position = _spot["water"]
	_bobber_y = float(_spot["water"].y)
	_bobber.visible = true
	_button.text = "Tunggu..."
	_label.text = "Mancing..."
	_sub.text = "Tunggu sampai pelampungnya bergerak ya."
	_label.visible = true
	_sub.visible = true
	_sound.play("splash", -6.0)
	_host.set_game_running("Mancing")


func _catch() -> void:
	var got := _roll_fish()
	_state = 3
	_timer = 2.4
	_bobber.visible = false
	_button.text = "Mancing"
	_label.text = "Dapat %s!" % got[0]
	_sub.text = "Besarnya %d cm. Hebat!" % got[1]
	_label.visible = true
	_sub.visible = true
	_sound.play("fanfare", -4.0)
	U.confetti(self, _player.global_position + Vector3(0, 1.6, 0), 24, RAINBOW)
	_host.fish_caught(str(got[0]), int(got[1]))


func _finish_pause() -> void:
	_state = 0
	active = false
	_host.set_game_running("")
	_host.show_prompts_for(2.5)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		if _button and _state == 0:
			_button.visible = false
		return
	# The button waits at a free fishing spot while no other game runs.
	if _state == 0:
		_spot = {}
		if _host.running_game() == "" and not _host.zoo_riding() and not _player.swim:
			for s in _spots:
				var bank: Vector3 = s["bank"]
				if Vector2(_player.global_position.x - bank.x, _player.global_position.z - bank.z).length() < 2.2:
					_spot = s
					break
		_button.visible = not _spot.is_empty()
		return
	_button.visible = true
	if _state == 1:
		_bobber.position.y = _bobber_y + sin(Time.get_ticks_msec() * 0.004) * 0.03
		_timer -= delta
		if _timer <= 0.0:
			_state = 2
			_timer = 1.4
			_bobber.position.y = _bobber_y - 0.16
			_button.text = "TARIK!"
			_sub.text = "Ikannya makan! Cepat tarik!"
			_sound.play("splash", -2.0)
	elif _state == 2:
		_timer -= delta
		if _timer <= 0.0:
			_state = 3
			_timer = 1.8
			_bobber.visible = false
			_button.text = "Mancing"
			_label.text = "Yah, ikannya lepas..."
			_sub.text = "Tidak apa-apa, coba lagi ya."
			_label.visible = true
			_sub.visible = true
			_sound.play("boing", -4.0)
	elif _state == 3:
		_timer -= delta
		if _timer <= 0.0:
			_finish_pause()
