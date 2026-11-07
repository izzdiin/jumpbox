class_name WudhuGame
extends Node3D
## Wudhu Challenge: stand at the washing place in the park corner and
## press the big button for every wash, in the right order. A glowing
## blue marker rides on the part of the character being washed, so the
## order is learned by doing it. The first step (niat) and the last one
## (the closing prayer) are reading steps: the Arabic text and its Latin
## spelling are shown, and the player reads them — slowly — before
## pressing "SUDAH KUBACA". Wudhu is not a race: presses faster than
## PRESS_GAP do not count, and the washing place may not be left until
## the order is finished.

const POS := Vector3(-24, 0, 21.5)
const PRESS_GAP := 0.9
const AREA_R := 2.4
const COLORS: Array[Color] = [Color(0.35, 0.7, 1.0), Color(0.75, 0.9, 1.0), Color(1, 1, 1)]
const RAINBOW: Array[Color] = [
	Color(0.95, 0.3, 0.3), Color(1.0, 0.6, 0.15), Color(1.0, 0.85, 0.2), Color(0.4, 0.8, 0.3),
	Color(0.25, 0.65, 0.95), Color(0.55, 0.4, 0.9), Color(0.95, 0.45, 0.75),
]
const WHITE := Color(0.97, 0.97, 0.97)

## "part" is the marker spot on the character (which faces -Z), "times"
## how often the big button is pressed, "btn" its caption. The two
## reading steps carry their text in "read".
const STEPS := [
	{"name": "Niat dan membaca basmalah", "part": Vector3(0, 1.15, -0.35), "times": 1, "btn": "SUDAH KUBACA",
		"read": {"intro": "Baca pelan-pelan ya:",
			"arab": "بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ\nنَوَيْتُ الْوُضُوءَ لِرَفْعِ الْحَدَثِ الْأَصْغَرِ فَرْضًا لِلَّهِ تَعَالَى",
			"latin": "Bismillaahir-rahmaanir-rahiim.\nNawaitul wudhuu-a liraf'il hadatsil asghari fardhal lillaahi ta'aalaa."}},
	{"name": "Membasuh kedua telapak tangan", "part": Vector3(0, 0.95, -0.35), "times": 3, "btn": "AIR!"},
	{"name": "Berkumur", "part": Vector3(0, 1.48, -0.36), "times": 3, "btn": "AIR!"},
	{"name": "Membasuh hidung", "part": Vector3(0, 1.58, -0.36), "times": 3, "btn": "AIR!"},
	{"name": "Membasuh wajah", "part": Vector3(0, 1.64, -0.36), "times": 3, "btn": "AIR!"},
	{"name": "Membasuh lengan kanan sampai siku", "part": Vector3(0.52, 1.15, -0.2), "times": 3, "btn": "AIR!"},
	{"name": "Membasuh lengan kiri sampai siku", "part": Vector3(-0.52, 1.15, -0.2), "times": 3, "btn": "AIR!"},
	{"name": "Mengusap kepala", "part": Vector3(0, 2.02, 0), "times": 1, "btn": "USAP"},
	{"name": "Mengusap telinga", "part": Vector3(0.3, 1.66, 0), "times": 1, "btn": "USAP"},
	{"name": "Membasuh kaki kanan sampai mata kaki", "part": Vector3(0.28, 0.3, -0.2), "times": 3, "btn": "AIR!"},
	{"name": "Membasuh kaki kiri sampai mata kaki", "part": Vector3(-0.28, 0.3, -0.2), "times": 3, "btn": "AIR!"},
	{"name": "Doa sesudah wudhu", "part": Vector3(0, 2.0, -0.3), "times": 1, "btn": "SUDAH KUBACA",
		"read": {"intro": "Baca doanya pelan-pelan ya:",
			"arab": "أَشْهَدُ أَنْ لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ\nوَأَشْهَدُ أَنَّ مُحَمَّدًا عَبْدُهُ وَرَسُولُهُ\nاللَّهُمَّ اجْعَلْنِي مِنَ التَّوَّابِينَ وَاجْعَلْنِي مِنَ الْمُتَطَهِّرِينَ",
			"latin": "Asyhadu allaa ilaaha illallaah, wahdahu laa syariika lah,\nwa asyhadu anna Muhammadan 'abduhu wa rasuuluh.\nAllaahummaj-'alnii minat-tawwaabiina\nwaj-'alnii minal-mutathahhiriin."}},
]

const U := preload("res://scripts/util.gd")

var active := false
var step := 0
var presses := 0
var since_press := 99.0
var button: Button
var marker: MeshInstance3D

var _warn := 0.0
var _host: Node
var _player: Node
var _sound: Node
var _label: Label
var _sub: Label


func setup(host: Node, player: Node, sound: Node, label: Label, sub: Label, game_layer: CanvasLayer) -> void:
	_host = host
	_player = player
	_sound = sound
	_label = label
	_sub = sub
	_build_station()
	button = Button.new()
	button.anchor_left = 0.5
	button.anchor_right = 0.5
	button.anchor_top = 1.0
	button.anchor_bottom = 1.0
	button.offset_left = -150
	button.offset_right = 150
	button.offset_top = -204
	button.offset_bottom = -96
	button.add_theme_font_size_override("font_size", 44)
	button.add_theme_color_override("font_color", Color.WHITE)
	for st in ["normal", "hover"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.25, 0.6, 0.95)
		sb.set_corner_radius_all(28)
		button.add_theme_stylebox_override(st, sb)
	var sbp := StyleBoxFlat.new()
	sbp.bg_color = Color(0.15, 0.45, 0.8)
	sbp.set_corner_radius_all(28)
	button.add_theme_stylebox_override("pressed", sbp)
	button.visible = false
	button.pressed.connect(press)
	game_layer.add_child(button)
	var sphere := SphereMesh.new()
	sphere.radius = 0.17
	sphere.height = 0.34
	sphere.radial_segments = 16
	sphere.rings = 8
	marker = MeshInstance3D.new()
	marker.mesh = sphere
	marker.material_override = U.mat(Color(0.3, 0.65, 1.0, 0.85))
	marker.visible = false
	add_child(marker)


## A little washing place: basin, tap and water.
func _build_station() -> void:
	var base := Vector3(-22.9, 0, 20.1)
	U.block(self, Vector3(0.5, 0.75, 0.5), base + Vector3(0, 0.375, 0), WHITE)
	U.solid_cylinder(self, 0.85, 0.25, base + Vector3(0, 0.85, 0), RAINBOW[4])
	U.mesh_cylinder(self, 0.72, 0.06, base + Vector3(0, 0.99, 0), Color(0.35, 0.7, 1.0))
	U.mesh_box(self, Vector3(0.12, 1.7, 0.12), base + Vector3(0, 0.85, -0.45), Color(0.6, 0.65, 0.7))
	U.mesh_box(self, Vector3(0.12, 0.12, 0.55), base + Vector3(0, 1.68, -0.22), Color(0.6, 0.65, 0.7))
	U.mesh_box(self, Vector3(0.12, 0.3, 0.12), base + Vector3(0, 1.52, 0.02), Color(0.6, 0.65, 0.7))
	U.mesh_box(self, Vector3(2.2, 0.06, 1.6), POS + Vector3(0, 0.03, 0), Color(0.55, 0.8, 0.95))


func begin() -> void:
	active = true
	step = 0
	presses = 0
	since_press = PRESS_GAP
	_warn = 0.0
	_player.teleport(POS + Vector3(0, 0.1, 0))
	_player.look_toward(Vector3(0, 0, 1))
	_player._model.rotation.y = 0.0
	button.visible = true
	marker.visible = true
	_host.set_game_running("Wudhu Challenge")
	_show_step()


func cancel() -> void:
	active = false
	if button:
		button.visible = false
	if marker:
		marker.visible = false
	if _sub:
		_sub.offset_bottom = 238


func sub_text() -> String:
	if presses > 0:
		var st: Dictionary = STEPS[step]
		return "Langkah %d dari %d — lagi %d kali" % [step + 1, STEPS.size(), int(st["times"]) - presses]
	return "Langkah %d dari %d" % [step + 1, STEPS.size()]


func _show_step() -> void:
	var st: Dictionary = STEPS[step]
	_label.text = "Wudhu: " + str(st["name"])
	if st.has("read"):
		var read: Dictionary = st["read"]
		_sub.text = str(read["intro"]) + "\n" + str(read["arab"]) + "\n" + str(read["latin"])
		_sub.offset_bottom = 380
	else:
		_sub.text = sub_text()
		_sub.offset_bottom = 238
	_label.visible = true
	_sub.visible = true
	button.text = str(st["btn"])
	if str(st["btn"]) == "SUDAH KUBACA":
		button.add_theme_font_size_override("font_size", 30)
	else:
		button.add_theme_font_size_override("font_size", 44)


func press() -> void:
	if not active:
		return
	if since_press < PRESS_GAP:
		# Wudhu is not a race: a too-fast press is not counted, and the
		# warning stays until it fades on its own.
		_sub.text = "Pelan-pelan ya — jangan wudhu cepat-cepat."
		_sub.offset_bottom = 238
		_sound.play("sit", -4.0)
		_warn = 1.6
		return
	since_press = 0.0
	var st: Dictionary = STEPS[step]
	presses += 1
	var part_pos: Vector3 = _player.global_position + st["part"]
	if st["btn"] == "AIR!":
		_sound.play("splash", -4.0)
		U.confetti(self, part_pos, 14, COLORS)
	else:
		_sound.play("checkpoint", -4.0)
		U.confetti(self, part_pos, 10, RAINBOW)
	if presses >= int(st["times"]):
		step += 1
		presses = 0
		if step >= STEPS.size():
			active = false
			button.visible = false
			marker.visible = false
			_sub.offset_bottom = 238
			_label.text = "Wudhu selesai! Hebat!"
			_sub.text = "Kamu sudah belajar urutan wudhu."
			_label.visible = true
			_sub.visible = true
			_sound.play("fanfare")
			U.confetti(self, _player.global_position + Vector3(0, 1.8, 0), 50, RAINBOW)
			_host.show_prompts_for(6.0)
			_host.set_game_running("")
			_host.game_completed("wudhu")
		else:
			_sound.play("checkpoint", -2.0)
			_show_step()
	else:
		_sub.text = sub_text()


func _process(delta: float) -> void:
	since_press += delta
	if _warn > 0.0:
		_warn -= delta
		if _warn <= 0.0 and active:
			_show_step()
	if not active or not is_visible_in_tree():
		return
	# The washing place may not be left until the order is finished:
	# stepping too far simply puts you back at its edge.
	var flat := Vector2(_player.global_position.x - POS.x, _player.global_position.z - POS.z)
	if flat.length() > AREA_R:
		var clamped := flat.normalized() * AREA_R
		_player.global_position.x = POS.x + clamped.x
		_player.global_position.z = POS.z + clamped.y
	if marker:
		var st: Dictionary = STEPS[step]
		marker.global_position = _player.global_position + st["part"]
		marker.scale = Vector3.ONE * (1.0 + 0.22 * sin(Time.get_ticks_msec() * 0.008))
