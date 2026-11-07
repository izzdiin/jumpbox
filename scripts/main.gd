extends Node3D
## Builds the whole playground from code: sky, ground, rides, the player and the touch controls.
## Rainbow doors in the park lead to the jump courses. Only one place is shown at a time:
## the park, or the course you are in. Each course is built the first time you enter it.
## Run with `-- --shot=/path/to/file.png` to save a screenshot after a few seconds and quit.

const U := preload("res://scripts/util.gd")
const Rides := preload("res://scripts/rides.gd")
const PlayerScript := preload("res://scripts/player.gd")
const TouchUIScript := preload("res://scripts/touch_ui.gd")
const MenuScript := preload("res://scripts/menu.gd")
const SoundScript := preload("res://scripts/sound.gd")
const Hats := preload("res://scripts/hats.gd")
## The jump courses: their script, where they are, and the icon over their door.
const COURSES := {
	"sky": {"script": preload("res://scripts/sky_course.gd"), "pos": Vector3(0, 40, -110), "door": Vector3(22, 0, 14)},
	"lava": {"script": preload("res://scripts/lava_course.gd"), "pos": Vector3(200, 0, 0), "door": Vector3(-22, 0, 14)},
	"slide": {"script": preload("res://scripts/slide_course.gd"), "pos": Vector3(-200, 0, 0), "door": Vector3(10, 0, 25)},
	"water": {"script": preload("res://scripts/water_course.gd"), "pos": Vector3(0, 0, 200), "door": Vector3(-10, 0, 25)},
	"indoor": {"script": preload("res://scripts/indoor_course.gd"), "pos": Vector3(200, 0, 200), "door": Vector3(0, 0, 30)},
}

const SPAWN := Vector3(0, 0.1, 15)
const HALF_SIZE := 38.0
## WLAN multiplayer: one phone hosts on this port, the others join by its address.
const NET_PORT := 8899
const MAX_PEERS := 4
const SETTINGS_PATH := "user://settings.cfg"
## Finding a host without typing: hosts answer a broadcast shout on this port.
const DISCOVERY_PORT := 8900
const DISCOVER_MSG := "JUMPBOX_DISCOVER?"
const HOST_MSG_PREFIX := "JUMPBOX_HOST "
## The running race: a marked arena on the east side of the park, with a
## start and finish arch, hurdles and blocks to dodge, and gold coins to
## collect on the way. Places and coin counts are compared at the end.
const RACE_CENTER_X := 28.0
const RACE_LANE_X: Array[float] = [25.6, 27.2, 28.8, 30.4]
const RACE_START_Z := 30.0
const RACE_FINISH_Z := -32.0
const RACE_COUNTDOWN := 3.0
const RACE_TIMEOUT := 45.0
const RACE_RESULTS_TIME := 10.0
const RACE_COIN_Y := 1.0
const GOLD := Color(1.0, 0.8, 0.15)
const GOLD_LIGHT := Color(1.0, 0.9, 0.45)
## Coin spots as [x, z] pairs, in the gaps between the obstacle rows.
const RACE_COIN_SPOTS := [
	[25.6, 26.0], [28.8, 26.0], [27.2, 20.0], [30.4, 20.0],
	[25.6, 14.0], [28.8, 14.0], [30.4, 8.0], [27.2, 8.0],
	[25.6, 2.0], [28.8, 2.0], [30.4, -4.0], [27.2, -10.0],
	[25.6, -16.0], [28.8, -22.0], [30.4, -28.0], [27.2, -28.0],
]

## Hijaiyah Adventure: the 28 letters, in their usual teaching order, and
## the hiding spots around the park where the letter boards wait.
const HIJAIYAH: Array[String] = ["ا", "ب", "ت", "ث", "ج", "ح", "خ", "د", "ذ", "ر", "ز", "س", "ش", "ص", "ض", "ط", "ظ", "ع", "غ", "ف", "ق", "ك", "ل", "م", "ن", "ه", "و", "ي"]
const HIJ_SPOTS: Array[Vector3] = [Vector3(-16, 0, 8), Vector3(12, 0, 20), Vector3(-4, 0, -24), Vector3(18, 0, -8), Vector3(-20, 0, -16), Vector3(4, 0, 32), Vector3(-28, 0, 4), Vector3(20, 0, 28), Vector3(-16, 0, 30), Vector3(14, 0, -26)]

## Wudhu Challenge: where the washing place stands, and the washing order
## step by step. "part" is the marker spot on the character (which faces
## -Z), "times" how often the big button is pressed, "btn" its caption.
const WUDHU_POS := Vector3(-24, 0, 21.5)
const WUDHU_COLORS: Array[Color] = [Color(0.35, 0.7, 1.0), Color(0.75, 0.9, 1.0), Color(1, 1, 1)]
const WUDHU_STEPS := [
	{"name": "Niat dan membaca basmalah", "part": Vector3(0, 1.15, -0.35), "times": 1, "btn": "NIAT"},
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
	{"name": "Doa sesudah wudhu", "part": Vector3(0, 2.0, -0.3), "times": 1, "btn": "DOA"},
]
## Wudhu is done slowly: presses faster than this gap are not counted, and
## the washing place may not be left until the order is finished.
const WUDHU_PRESS_GAP := 0.9
const WUDHU_AREA_R := 2.4

## The mini zoo pen in the park's far corner.
const ZOO_CENTER := Vector3(-29, 0, -29)
const ZOO_HORSE_HOME := Vector3(-32.5, 0, -31.5)

const GRASS := Color(0.42, 0.78, 0.35)
const SAND := Color(0.96, 0.86, 0.6)
const WOOD := Color(0.6, 0.4, 0.22)
const WHITE := Color(0.97, 0.97, 0.97)
const RAINBOW: Array[Color] = [
	Color(0.95, 0.3, 0.3), Color(1.0, 0.6, 0.15), Color(1.0, 0.85, 0.2), Color(0.4, 0.8, 0.3),
	Color(0.25, 0.65, 0.95), Color(0.55, 0.4, 0.9), Color(0.95, 0.45, 0.75),
]

var _clouds: Array[Node3D] = []
var _sound: Node
var _player: Node
var _ui: Node
var _menu: Node
## The park content, hidden while you are on a course.
var _park: Node3D
## Courses built so far, by name.
var _courses := {}
## The course you are on, or null in the park.
var _active: Node
var _icons: Array[Node3D] = []
## WLAN session state. _puppets holds the other players, by peer id.
var _net_active := false
var _is_host := false
var _puppets := {}
## Host discovery (broadcast shout) and the running race.
var _discovery: PacketPeerUDP
var _scan_peer: PacketPeerUDP
var _scan_deadline := 0
var _scan_found := {}
var _race_state := 0  # 0 idle, 1 countdown, 2 running
var _race_timer := 0.0
var _race_total := 0
var _race_finishers: Array[int] = []
var _race_banner: Label
var _banner_timer := 0.0
var _race_results: Label
var _results_timer := 0.0
var _race_coins: Array[Dictionary] = []
var _race_obstacles: Array[Node] = []
var _race_coin_counts := {}
var _race_names := {}

## The two learning games (see start_hijaiyah and start_wudhu). One runs at
## a time, both are solo, and both share the two prompt labels.
var _game_label: Label
var _game_sub: Label
var _game_clear_timer := 0.0
var _hij_active := false
var _hij_order: Array[int] = []
var _hij_pos := 0
var _hij_tokens: Array[Dictionary] = []
var _hij_cooldown := 0.0
var _wudhu_button: Button
var _wudhu_marker: MeshInstance3D
var _wudhu_active := false
var _wudhu_step := 0
var _wudhu_presses := 0
var _wudhu_since_press := 99.0
var _wudhu_warn := 0.0

## The game prompts live on their own canvas layer under the menu, so
## opening the menu hides them all at once.
var _game_layer: CanvasLayer
## Hijaiyah played together: one shared hunt, one score per player.
var _hij_scores := {}
var _hij_names := {}

## The mini zoo: the animals, the one you are standing by, its three big
## buttons, and whether you are on the horse.
var _zoo: Array[Dictionary] = []
var _zoo_near: Dictionary = {}
var _zoo_feed_button: Button
var _zoo_play_button: Button
var _zoo_ride_button: Button
var _riding := false


func _ready() -> void:
	_sound = SoundScript.new()
	add_child(_sound)
	_build_environment()
	_park = Node3D.new()
	add_child(_park)
	_build_ground()
	_build_fence()
	_build_race_arena()
	_build_wudhu_station()
	_build_hijaiyah_tokens()
	_build_zoo()
	_build_trampolines()
	_build_slide(Vector3(7, 0, -2), 2.6, RAINBOW[4])
	_build_slide(Vector3(15, 0, 0), 5.0, RAINBOW[0])
	_build_swings(Vector3(0, 0, -12))
	_build_merry_go_round(Vector3(9, 0, -18))
	_build_block_tower(Vector3(-11, 0, -20))
	_build_balls(Vector3(-1, 0, 1))
	_build_trees()
	_build_clouds()
	for course_name in COURSES:
		_build_door(course_name)
	_build_hat_stands()

	var player := PlayerScript.new()
	_player = player
	player.respawn_point = SPAWN
	player.sound = _sound
	player.position = SPAWN
	add_child(player)

	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := TouchUIScript.new()
	layer.add_child(ui)
	player.ui = ui
	ui.home_pressed.connect(_go_home)

	_ui = ui
	ui.stage_prev_pressed.connect(_skip_stage.bind(-1))
	ui.stage_next_pressed.connect(_skip_stage.bind(1))
	ui.music_pressed.connect(func():
		_sound.toggle_music()
		ui.music_on = _sound.music_on
		ui.queue_redraw())
	var menu := MenuScript.new()
	layer.add_child(menu)
	_menu = menu
	ui.menu_pressed.connect(func():
		ui.release_all()
		menu.open())

	menu.host_pressed.connect(net_host)
	menu.join_pressed.connect(net_join)
	menu.leave_pressed.connect(net_disconnect)
	menu.scan_pressed.connect(net_scan)
	menu.race_pressed.connect(_on_race_pressed)
	menu.hijaiyah_pressed.connect(start_hijaiyah)
	menu.wudhu_pressed.connect(start_wudhu)
	menu.end_game_pressed.connect(_cancel_games)
	menu.opened.connect(func():
		_game_layer.visible = false
		if _wudhu_marker:
			_wudhu_marker.visible = false)
	menu.closed.connect(func():
		_game_layer.visible = true
		if _wudhu_marker and _wudhu_active:
			_wudhu_marker.visible = true)
	menu.profile_changed.connect(_on_profile_changed)
	menu.set_profile(_player.profile_dict())
	menu.set_net_status("Tidak terhubung. Main sendiri.")
	# First run on a real device: make your character before anything else.
	if _player.player_name == "" and not OS.has_feature("editor"):
		menu.open_onboarding()
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		var last_ip := str(cfg.get_value("net", "last_ip", ""))
		if last_ip != "":
			menu.set_join_ip(last_ip)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	_race_banner = Label.new()
	_race_banner.anchor_left = 0.0
	_race_banner.anchor_right = 1.0
	_race_banner.offset_top = 84
	_race_banner.offset_bottom = 190
	_race_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_race_banner.add_theme_font_size_override("font_size", 64)
	_race_banner.add_theme_color_override("font_color", Color.WHITE)
	_race_banner.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.15))
	_race_banner.add_theme_constant_override("outline_size", 18)
	_race_banner.visible = false
	layer.add_child(_race_banner)

	_race_results = Label.new()
	_race_results.anchor_left = 0.0
	_race_results.anchor_right = 1.0
	_race_results.offset_top = 196
	_race_results.offset_bottom = 580
	_race_results.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_race_results.add_theme_font_size_override("font_size", 36)
	_race_results.add_theme_color_override("font_color", Color.WHITE)
	_race_results.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.15))
	_race_results.add_theme_constant_override("outline_size", 12)
	_race_results.visible = false
	layer.add_child(_race_results)

	# Prompts for the two learning games: one big line (the letter to find or
	# the wudhu step), a smaller progress line under it, one huge button for
	# the washing steps, and a glowing blue marker that rides on the part of
	# the character being washed. They live on their own layer under the
	# menu layer, and the layer hides while the menu is open.
	_game_layer = CanvasLayer.new()
	_game_layer.layer = 0
	add_child(_game_layer)

	_game_label = Label.new()
	_game_label.anchor_left = 0.0
	_game_label.anchor_right = 1.0
	_game_label.offset_top = 84
	_game_label.offset_bottom = 168
	_game_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_label.add_theme_font_size_override("font_size", 54)
	_game_label.add_theme_color_override("font_color", Color.WHITE)
	_game_label.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.15))
	_game_label.add_theme_constant_override("outline_size", 14)
	_game_label.visible = false
	_game_layer.add_child(_game_label)

	_game_sub = Label.new()
	_game_sub.anchor_left = 0.0
	_game_sub.anchor_right = 1.0
	_game_sub.offset_top = 168
	_game_sub.offset_bottom = 238
	_game_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_sub.add_theme_font_size_override("font_size", 28)
	_game_sub.add_theme_color_override("font_color", Color.WHITE)
	_game_sub.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.15))
	_game_sub.add_theme_constant_override("outline_size", 10)
	_game_sub.visible = false
	_game_layer.add_child(_game_sub)

	_wudhu_button = Button.new()
	_wudhu_button.anchor_left = 0.5
	_wudhu_button.anchor_right = 0.5
	_wudhu_button.anchor_top = 1.0
	_wudhu_button.anchor_bottom = 1.0
	_wudhu_button.offset_left = -150
	_wudhu_button.offset_right = 150
	_wudhu_button.offset_top = -204
	_wudhu_button.offset_bottom = -96
	_wudhu_button.add_theme_font_size_override("font_size", 44)
	_wudhu_button.add_theme_color_override("font_color", Color.WHITE)
	for st in ["normal", "hover"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.25, 0.6, 0.95)
		sb.set_corner_radius_all(28)
		_wudhu_button.add_theme_stylebox_override(st, sb)
	var sbp := StyleBoxFlat.new()
	sbp.bg_color = Color(0.15, 0.45, 0.8)
	sbp.set_corner_radius_all(28)
	_wudhu_button.add_theme_stylebox_override("pressed", sbp)
	_wudhu_button.visible = false
	_wudhu_button.pressed.connect(_on_wudhu_press)
	_game_layer.add_child(_wudhu_button)

	# The zoo buttons: feed and play side by side, ride above them. They only
	# show while you stand by an animal (or sit on the horse).
	_zoo_feed_button = _big_button("Beri Makan", Color(0.35, 0.75, 0.35), -248, -8)
	_zoo_feed_button.pressed.connect(func(): _zoo_feed(_zoo_near))
	_game_layer.add_child(_zoo_feed_button)
	_zoo_play_button = _big_button("Ajak Main", Color(0.6, 0.45, 0.9), 8, 248)
	_zoo_play_button.pressed.connect(func(): _zoo_play(_zoo_near))
	_game_layer.add_child(_zoo_play_button)
	_zoo_ride_button = _big_button("Naik Kuda", Color(1.0, 0.6, 0.15), -125, 125)
	_zoo_ride_button.offset_top = -316
	_zoo_ride_button.offset_bottom = -224
	_zoo_ride_button.pressed.connect(func():
		if _riding:
			_stop_riding()
		else:
			_start_riding())
	_game_layer.add_child(_zoo_ride_button)

	var sphere := SphereMesh.new()
	sphere.radius = 0.17
	sphere.height = 0.34
	sphere.radial_segments = 16
	sphere.rings = 8
	_wudhu_marker = MeshInstance3D.new()
	_wudhu_marker.mesh = sphere
	_wudhu_marker.material_override = U.mat(Color(0.3, 0.65, 1.0, 0.85))
	_wudhu_marker.visible = false
	add_child(_wudhu_marker)

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_take_screenshot(arg.trim_prefix("--shot="))
		elif arg == "--net-host":
			call_deferred("net_host")
		elif arg.begins_with("--net-join="):
			call_deferred("net_join", arg.trim_prefix("--net-join="))


func _enter_course(course_name: String) -> void:
	if _active:
		return
	_cancel_games()
	_stop_riding(true)
	var course: Node = _courses.get(course_name)
	if course == null:
		var info: Dictionary = COURSES[course_name]
		course = info["script"].new()
		course.position = info["pos"]
		course.player = _player
		course.sound = _sound
		course.ui = _ui
		course.go_home.connect(_go_home)
		add_child(course)
		_courses[course_name] = course
	_set_park_shown(false)
	_active = course
	course.enter()


func _skip_stage(step: int) -> void:
	if _active:
		_active.skip(step)


func _go_home() -> void:
	if _wudhu_active:
		# Wudhu is finished where it started: the home trip waits, and you
		# are simply put back at the washing place.
		_player.teleport(WUDHU_POS + Vector3(0, 0.1, 0))
		_player.look_toward(Vector3(0, 0, 1))
		return
	_cancel_games()
	if _active:
		_active.leave()
		_active = null
	_set_park_shown(true)
	_player.kill_y = -10.0
	_player.respawn_point = SPAWN
	_player.fall_sound = "home"
	_player.respawn()


## Hiding the park and taking it out of physics keeps the phone fast while on a course.
func _set_park_shown(shown: bool) -> void:
	_park.visible = shown
	_park.process_mode = Node.PROCESS_MODE_INHERIT if shown else Node.PROCESS_MODE_DISABLED


## Five hats on little stands in a half circle in front of the start. Walk up to one to wear it.
func _build_hat_stands() -> void:
	for i in Hats.NAMES.size():
		var hat_name := Hats.NAMES[i]
		var a := deg_to_rad(-60 + 30 * i)
		var pos := SPAWN + Vector3(sin(a) * 4.0, -0.1, -cos(a) * 4.0)
		U.solid_cylinder(_park, 0.55, 0.5, pos + Vector3(0, 0.25, 0), RAINBOW[i])
		var display := Node3D.new()
		display.position = pos + Vector3(0, 1.0, 0)
		display.scale = Vector3.ONE * 2.6
		_park.add_child(display)
		Hats.build(hat_name, display)
		_icons.append(display)
		var area := Area3D.new()
		area.position = pos + Vector3(0, 1.0, 0)
		var shape := SphereShape3D.new()
		shape.radius = 1.3
		var cs := CollisionShape3D.new()
		cs.shape = shape
		area.add_child(cs)
		_park.add_child(area)
		area.body_entered.connect(func(body: Node3D):
			if body == _player and _player.hat != hat_name:
				_player.set_hat(hat_name)
				if _net_active:
					_player.rpc("_receive_profile", _player.profile_dict())
				_sound.play("sit")
				U.confetti(self, pos + Vector3(0, 1.0, 0), 30, RAINBOW), CONNECT_DEFERRED)


func _build_door(course_name: String) -> void:
	var pos: Vector3 = COURSES[course_name]["door"]
	# The doors stand away from the rides, facing the start, with a sand path leading to each.
	var to_start := Vector3(SPAWN.x - pos.x, 0, SPAWN.z - pos.z)
	var door := U.portal(_park, pos, Basis.looking_at(to_start, Vector3.UP), RAINBOW)
	var path := U.mesh_box(_park, Vector3(2.4, 0.02, to_start.length()), pos + to_start * 0.5 + Vector3.UP * 0.012, SAND)
	path.rotation.y = atan2(to_start.x, to_start.z)
	door.body_entered.connect(func(body: Node3D):
		if body == _player:
			_enter_course(course_name), CONNECT_DEFERRED)
	var icon := Node3D.new()
	icon.position = pos + Vector3(0, 4.3, 0)
	_park.add_child(icon)
	_icons.append(icon)
	if course_name == "water":
		# A water drop.
		var drop := U.mesh_box(icon, Vector3(0.7, 0.7, 0.35), Vector3(0, -0.1, 0), Color(0.3, 0.65, 1.0))
		drop.rotation.z = PI * 0.25
		U.mesh_box(icon, Vector3(0.3, 0.45, 0.35), Vector3(0, 0.45, 0), Color(0.3, 0.65, 1.0))
		U.mesh_box(icon, Vector3(0.12, 0.2, 0.37), Vector3(-0.15, -0.05, 0), Color(0.8, 0.92, 1.0))
	elif course_name == "indoor":
		# A little climbing wall with colorful holds.
		U.mesh_box(icon, Vector3(1.0, 1.3, 0.15), Vector3.ZERO, RAINBOW[4])
		for k in 6:
			U.mesh_box(icon, Vector3(0.2, 0.15, 0.3), Vector3(-0.25 + (k % 2) * 0.5, -0.45 + k * 0.18, 0), RAINBOW[k])
	elif course_name == "slide":
		# A little spiral slide around a white pole.
		U.mesh_box(icon, Vector3(0.14, 1.4, 0.14), Vector3.ZERO, WHITE)
		for k in 10:
			var a := k * 0.7
			var step := U.mesh_box(icon, Vector3(0.32, 0.08, 0.2), Vector3(cos(a) * 0.32, 0.6 - k * 0.13, sin(a) * 0.32), RAINBOW[k % RAINBOW.size()])
			step.rotation.y = -a
	elif course_name == "sky":
		# A cloud.
		U.mesh_box(icon, Vector3(1.6, 0.6, 0.5), Vector3(0, 0, 0), WHITE)
		U.mesh_box(icon, Vector3(0.8, 0.6, 0.5), Vector3(-0.35, 0.4, 0), WHITE)
		U.mesh_box(icon, Vector3(0.7, 0.5, 0.5), Vector3(0.35, 0.3, 0), WHITE)
	else:
		# A flame: red outside, orange, then yellow inside.
		var flame := [[Color(0.95, 0.2, 0.1), 1.0, 0.0], [Color(1.0, 0.55, 0.1), 0.7, 0.06], [Color(1.0, 0.9, 0.3), 0.4, 0.12]]
		for f in flame:
			var b := U.mesh_box(icon, Vector3(f[1], f[1], 0.3 + f[2] * 2), Vector3(0, -0.15 + f[2], 0), f[0])
			b.rotation.z = PI * 0.25
			U.mesh_box(icon, Vector3(f[1] * 0.45, f[1] * 0.8, 0.3 + f[2] * 2), Vector3(0, 0.55 + f[2] * 0.5, 0), f[0])


func _process(delta: float) -> void:
	_poll_discovery()
	_poll_scan()
	_race_process(delta)
	_games_process(delta)
	_zoo_process(delta)
	for icon in _icons:
		icon.rotation.y += delta * 1.2
		icon.position.y += sin(Time.get_ticks_msec() * 0.003) * delta * 0.3
	for c in _clouds:
		c.position.x += delta * 0.6
		if c.position.x > 60:
			c.position.x = -60


func _take_screenshot(path: String) -> void:
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()


func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.3, 0.58, 0.98)
	sky_mat.sky_horizon_color = Color(0.72, 0.87, 1.0)
	sky_mat.ground_horizon_color = Color(0.72, 0.87, 1.0)
	sky_mat.ground_bottom_color = Color(0.85, 0.9, 1.0)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.0
	add_child(sun)


func _build_ground() -> void:
	U.block(_park, Vector3(HALF_SIZE * 2 + 4, 1, HALF_SIZE * 2 + 4), Vector3(0, -0.5, 0), GRASS)
	# Sand patches under the play areas (looks only, no collision).
	U.mesh_box(_park, Vector3(16, 0.02, 14), Vector3(-10, 0.01, -2), SAND)
	U.mesh_box(_park, Vector3(14, 0.02, 22), Vector3(11, 0.01, -1), SAND)
	U.mesh_box(_park, Vector3(10, 0.02, 7), Vector3(0, 0.01, -12), SAND)
	# A bright start circle.
	U.mesh_cylinder(_park, 1.5, 0.03, Vector3(SPAWN.x, 0.015, SPAWN.z), Color(1, 1, 1, 0.6))


func _build_fence() -> void:
	var h := HALF_SIZE
	for side: float in [-1.0, 1.0]:
		# Tall invisible walls so nobody leaves the park, even from the big trampoline.
		var wall_x := StaticBody3D.new()
		_park.add_child(wall_x)
		U.add_box_shape(wall_x, Vector3(1, 60, h * 2 + 2), Vector3(h * side, 30, 0))
		var wall_z := StaticBody3D.new()
		_park.add_child(wall_z)
		U.add_box_shape(wall_z, Vector3(h * 2 + 2, 60, 1), Vector3(0, 30, h * side))
		# The fence you can see.
		for y: float in [0.45, 0.95]:
			U.mesh_box(_park, Vector3(0.15, 0.15, h * 2), Vector3(h * side, y, 0), WHITE)
			U.mesh_box(_park, Vector3(h * 2, 0.15, 0.15), Vector3(0, y, h * side), WHITE)
		var post := -h
		while post <= h:
			U.mesh_box(_park, Vector3(0.25, 1.3, 0.25), Vector3(h * side, 0.65, post), WHITE)
			U.mesh_box(_park, Vector3(0.25, 1.3, 0.25), Vector3(post, 0.65, h * side), WHITE)
			post += 3.0


## --- The race arena -----------------------------------------------------------
## A permanent running track on the east side of the park: a start arch and a
## finish arch, lane lines, hurdles, blocks and cones to dodge, and gold coins
## that only show up while a race is on.

func _build_race_arena() -> void:
	# The track surface and its edges.
	U.mesh_box(_park, Vector3(8.4, 0.04, 70.0), Vector3(RACE_CENTER_X, 0.02, -1.0), Color(0.83, 0.86, 0.9))
	for side: float in [-1.0, 1.0]:
		U.mesh_box(_park, Vector3(0.35, 0.05, 70.0), Vector3(RACE_CENTER_X + side * 4.2, 0.025, -1.0), WHITE)
	# Lane lines between the four lanes.
	for bx in [24.8, 26.4, 28.0, 29.6, 31.2]:
		U.mesh_box(_park, Vector3(0.08, 0.045, 62.0), Vector3(bx, 0.022, -1.0), Color(1, 1, 1, 0.55))
	_build_race_line(RACE_START_Z)
	_build_race_line(RACE_FINISH_Z)
	_build_race_arch(RACE_START_Z, RAINBOW[3], "START")
	_build_race_arch(RACE_FINISH_Z, RAINBOW[0], "FINISH")
	# Obstacle rows. Every row leaves a way through: a free lane or a low
	# hurdle you can jump.
	_race_hurdle(RACE_LANE_X[0], 23.0)
	_race_hurdle(RACE_LANE_X[2], 23.0)
	_race_block(RACE_LANE_X[1], 17.0)
	_race_hurdle(RACE_LANE_X[3], 17.0)
	_race_cone(RACE_LANE_X[0], 11.0)
	_race_hurdle(RACE_LANE_X[2], 11.0)
	_race_cone(RACE_LANE_X[3], 11.0)
	_race_hurdle(RACE_LANE_X[0], 5.0)
	_race_block(RACE_LANE_X[2], 5.0)
	_race_hurdle(RACE_LANE_X[1], -1.0)
	_race_hurdle(RACE_LANE_X[3], -1.0)
	_race_block(RACE_LANE_X[0], -7.0)
	_race_cone(RACE_LANE_X[2], -7.0)
	_race_hurdle(RACE_LANE_X[0], -13.0)
	_race_hurdle(RACE_LANE_X[1], -13.0)
	_race_hurdle(RACE_LANE_X[2], -13.0)
	_race_hurdle(RACE_LANE_X[1], -19.0)
	_race_block(RACE_LANE_X[3], -19.0)
	_race_cone(RACE_LANE_X[1], -25.0)
	_race_cone(RACE_LANE_X[2], -25.0)
	_race_hurdle(RACE_LANE_X[3], -25.0)
	# The coins, hidden until a race starts.
	for spot in RACE_COIN_SPOTS:
		_build_race_coin(Vector3(float(spot[0]), RACE_COIN_Y, float(spot[1])))


## A chequered start/finish line across the track.
func _build_race_line(z: float) -> void:
	for i in 8:
		var c := Color(0.12, 0.12, 0.14) if i % 2 == 0 else WHITE
		U.mesh_box(_park, Vector3(0.8, 0.045, 0.9), Vector3(24.8 + 0.4 + i * 0.8, 0.023, z), c)


## Two posts and a beam over the track, with a floating word on top.
func _build_race_arch(z: float, color: Color, word: String) -> void:
	for side: float in [-1.0, 1.0]:
		U.block(_park, Vector3(0.4, 3.4, 0.4), Vector3(RACE_CENTER_X + side * 3.9, 1.7, z), color)
	U.mesh_box(_park, Vector3(8.2, 0.55, 0.45), Vector3(RACE_CENTER_X, 3.55, z), color)
	var label := Label3D.new()
	label.text = word
	label.font_size = 128
	label.pixel_size = 0.008
	label.modulate = WHITE
	label.outline_size = 24
	label.outline_modulate = Color(0.1, 0.1, 0.15)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(RACE_CENTER_X, 4.5, z)
	_park.add_child(label)


## A low bar you jump over.
func _race_hurdle(x: float, z: float) -> void:
	var body := U.block(_park, Vector3(1.5, 0.55, 0.35), Vector3(x, 0.275, z), RAINBOW[1])
	U.mesh_box(body, Vector3(1.5, 0.14, 0.37), Vector3(0, 0.12, 0), WHITE)
	_race_obstacles.append(body)


## A tall block you run around.
func _race_block(x: float, z: float) -> void:
	_race_obstacles.append(U.block(_park, Vector3(1.4, 1.05, 0.7), Vector3(x, 0.525, z), RAINBOW[5]))


## A traffic cone you dodge.
func _race_cone(x: float, z: float) -> void:
	var body := U.solid_cylinder(_park, 0.42, 0.85, Vector3(x, 0.425, z), RAINBOW[0])
	U.mesh_cylinder(body, 0.43, 0.14, Vector3(0, 0.05, 0), WHITE)
	_race_obstacles.append(body)


## One gold coin: a spinning disc, so it can bob and turn while the race
## runs. Hidden until a race starts.
func _build_race_coin(pos: Vector3) -> void:
	var coin := Node3D.new()
	coin.position = pos
	coin.visible = false
	_park.add_child(coin)
	var disc := U.mesh_cylinder(coin, 0.42, 0.1, Vector3.ZERO, GOLD)
	disc.rotation.x = PI * 0.5
	var face := U.mesh_cylinder(coin, 0.26, 0.12, Vector3.ZERO, GOLD_LIGHT)
	face.rotation.x = PI * 0.5
	_race_coins.append({"node": coin, "pos": pos, "taken": false})


func _build_trampoline(pos: Vector3, radius: float, power: float, color: Color) -> void:
	U.solid_cylinder(_park, radius, 0.6, pos + Vector3(0, 0.3, 0), color)
	var pad := U.solid_cylinder(_park, radius - 0.3, 0.1, pos + Vector3(0, 0.62, 0), Color(0.15, 0.15, 0.2))
	pad.set_meta("bounce", power)


func _build_trampolines() -> void:
	_build_trampoline(Vector3(-7, 0, -4), 2.0, 12.0, RAINBOW[1])
	_build_trampoline(Vector3(-12, 0, 1), 2.0, 12.0, RAINBOW[3])
	_build_trampoline(Vector3(-6, 0, 2.5), 1.6, 10.0, RAINBOW[6])
	# The super trampoline sends you really high.
	_build_trampoline(Vector3(-14, 0, -7), 3.0, 19.0, RAINBOW[5])


## A slide with stairs on the +Z side, a platform on top and the slide going down toward -Z.
func _build_slide(origin: Vector3, height: float, color: Color) -> void:
	var root := Node3D.new()
	root.position = origin
	_park.add_child(root)
	var half := 1.2
	var width := 2.0

	U.block(root, Vector3(2.4, 0.3, 2.4), Vector3(0, height - 0.15, 0), WOOD)
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			U.block(root, Vector3(0.25, height, 0.25), Vector3(x * 1.05, height * 0.5, z * 1.05), WHITE)
		# Side rails on the platform.
		U.block(root, Vector3(0.16, 0.8, 2.4), Vector3(x * 1.2, height + 0.4, 0), color)

	# Stairs: a gentle ramp with steps drawn on top.
	var stairs_len := height / tan(deg_to_rad(33))
	var bottom := Vector3(0, 0, half + stairs_len)
	var top := Vector3(0, height, half)
	U.ramp(root, bottom, top, width, WOOD)
	U.ramp_walls(root, bottom, top, width, WHITE, 0.9)
	var steps := int(height / 0.35)
	for i in steps:
		var t := (i + 0.5) / steps
		var p := bottom.lerp(top, t)
		U.mesh_box(root, Vector3(width, 0.12, stairs_len / steps * 0.6), p + Vector3(0, 0.02, 0), Color(0.75, 0.55, 0.32))

	# The slide itself.
	var slide_len := height / tan(deg_to_rad(30))
	var s_top := Vector3(0, height, -half)
	var s_bottom := Vector3(0, 0.02, -half - slide_len)
	var slide := U.ramp(root, s_top, s_bottom, width, color)
	slide.set_meta("slide", true)
	U.ramp_walls(root, s_top, s_bottom, width, color, 0.7)


func _build_swings(origin: Vector3) -> void:
	var bar_h := 3.4
	for x: float in [-3.0, 3.0]:
		for z: float in [-0.8, 0.8]:
			U.block(_park, Vector3(0.25, bar_h, 0.25), origin + Vector3(x, bar_h * 0.5, z), RAINBOW[0])
	U.block(_park, Vector3(6.4, 0.25, 0.25), origin + Vector3(0, bar_h, 0), RAINBOW[0])
	var colors := [RAINBOW[2], RAINBOW[4]]
	for i in 2:
		var seat := Rides.SwingSeat.new()
		seat.pivot = origin + Vector3(-1.4 + 2.8 * i, bar_h - 0.1, 0)
		seat.rope_length = bar_h - 0.7
		seat.phase = PI * 0.5 * i
		seat.set_meta("seat", true)
		U.mesh_box(seat, Vector3(1.3, 0.15, 0.7), Vector3.ZERO, colors[i])
		U.add_box_shape(seat, Vector3(1.3, 0.15, 0.7))
		for side: float in [-1.0, 1.0]:
			U.mesh_box(seat, Vector3(0.06, seat.rope_length, 0.06), Vector3(0.6 * side, seat.rope_length * 0.5, 0), Color(0.3, 0.3, 0.3))
		_park.add_child(seat)


func _build_merry_go_round(pos: Vector3) -> void:
	U.solid_cylinder(_park, 0.6, 0.3, pos + Vector3(0, 0.15, 0), Color(0.4, 0.4, 0.45))
	var spinner := Rides.Spinner.new()
	spinner.position = pos + Vector3(0, 0.45, 0)
	_park.add_child(spinner)
	var radius := 3.2
	U.mesh_cylinder(spinner, radius, 0.3, Vector3.ZERO, WHITE)
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 0.3
	var cs := CollisionShape3D.new()
	cs.shape = shape
	spinner.add_child(cs)
	for i in 6:
		var a := TAU * i / 6.0
		var dir := Vector3(cos(a), 0, sin(a))
		var stripe := U.mesh_box(spinner, Vector3(0.7, 0.02, radius), dir * radius * 0.5 + Vector3(0, 0.16, 0), RAINBOW[i])
		stripe.rotation.y = -a + PI * 0.5
		# Handle bars to hold on to.
		U.mesh_box(spinner, Vector3(0.12, 1.0, 0.12), dir * (radius - 0.5) + Vector3(0, 0.65, 0), RAINBOW[i])
	U.mesh_cylinder(spinner, 0.5, 1.2, Vector3(0, 0.75, 0), RAINBOW[2])
	var pole := CylinderShape3D.new()
	pole.radius = 0.5
	pole.height = 1.2
	var pole_cs := CollisionShape3D.new()
	pole_cs.shape = pole
	pole_cs.position.y = 0.75
	spinner.add_child(pole_cs)


## Rainbow blocks that climb in a spiral around a tall tower with a flag on top.
func _build_block_tower(center: Vector3) -> void:
	var steps := 9
	var step_h := 0.7
	var top_h := step_h * steps
	U.block(_park, Vector3(2.6, top_h, 2.6), center + Vector3(0, top_h * 0.5, 0), WHITE)
	for i in steps:
		var h := step_h * (i + 1)
		var a := TAU * i / 8.5
		var p := center + Vector3(cos(a) * 2.5, h * 0.5, sin(a) * 2.5)
		var b := U.block(_park, Vector3(1.4, h, 1.4), p, RAINBOW[i % RAINBOW.size()])
		b.rotation.y = -a
	U.mesh_box(_park, Vector3(0.1, 2.0, 0.1), center + Vector3(0, top_h + 1.0, 0), Color(0.3, 0.3, 0.3))
	U.mesh_box(_park, Vector3(0.9, 0.55, 0.05), center + Vector3(0.45, top_h + 1.7, 0), RAINBOW[0])
	# Reaching the top plays a fanfare.
	var goal := Area3D.new()
	goal.position = center + Vector3(0, top_h + 0.8, 0)
	U.add_box_shape(goal, Vector3(2.6, 1.6, 2.6))
	_park.add_child(goal)
	goal.body_entered.connect(func(body: Node3D):
		if body is CharacterBody3D:
			_sound.play("fanfare"))


func _build_balls(center: Vector3) -> void:
	var bouncy := PhysicsMaterial.new()
	bouncy.bounce = 0.6
	bouncy.friction = 0.6
	for i in 7:
		var ball := RigidBody3D.new()
		ball.mass = 0.4
		ball.physics_material_override = bouncy
		ball.linear_damp = 0.3
		ball.angular_damp = 0.5
		var a := TAU * i / 7.0
		ball.position = center + Vector3(cos(a) * 2.5, 0.7 + i * 0.2, sin(a) * 2.5)
		var shape := SphereShape3D.new()
		shape.radius = 0.6
		var cs := CollisionShape3D.new()
		cs.shape = shape
		ball.add_child(cs)
		var mesh := SphereMesh.new()
		mesh.radius = 0.6
		mesh.height = 1.2
		mesh.radial_segments = 16
		mesh.rings = 8
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = U.mat(RAINBOW[i])
		ball.add_child(mi)
		_park.add_child(ball)


func _build_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var placed := 0
	while placed < 26:
		var p := Vector3(rng.randf_range(-34, 34), 0, rng.randf_range(-34, 34))
		# Keep the race arena corridor clear.
		if absf(p.x - RACE_CENTER_X) < 5.5 and p.z > -37.0 and p.z < 35.0:
			continue
		# And the zoo pen.
		if p.x > -37.5 and p.x < -20.5 and p.z > -36.5 and p.z < -21.5:
			continue
		# Keep trees near the edges, away from the rides.
		if absf(p.x) < 25 and absf(p.z) < 26:
			continue
		# And away from the doors.
		if COURSES.values().any(func(c): return Vector2(p.x - c["door"].x, p.z - c["door"].z).length() < 5.0):
			continue
		var trunk_h := rng.randf_range(1.6, 2.6)
		U.block(_park, Vector3(0.6, trunk_h, 0.6), p + Vector3(0, trunk_h * 0.5, 0), WOOD)
		var green := Color(0.2, rng.randf_range(0.5, 0.7), 0.25)
		U.mesh_box(_park, Vector3(2.6, 1.6, 2.6), p + Vector3(0, trunk_h + 0.7, 0), green)
		U.mesh_box(_park, Vector3(1.7, 1.1, 1.7), p + Vector3(0, trunk_h + 1.9, 0), green.lightened(0.15))
		placed += 1


func _build_clouds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 7:
		var cloud := Node3D.new()
		cloud.position = Vector3(rng.randf_range(-60, 60), rng.randf_range(22, 30), rng.randf_range(-50, 30))
		_park.add_child(cloud)
		for j in 3:
			U.mesh_box(cloud, Vector3(rng.randf_range(4, 7), 1.6, rng.randf_range(3, 4)), Vector3(j * 2.5 - 2.5, rng.randf_range(0, 0.8), 0), WHITE)
		_clouds.append(cloud)


## --- WLAN multiplayer -------------------------------------------------------
## One phone hosts the game, the others join by its WLAN address. Only the
## players are shared: every phone still runs its own park and courses, so a
## friend shows up as a puppet that mirrors what its owner does (player.gd).

func net_host() -> void:
	if _net_active:
		return
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(NET_PORT, MAX_PEERS - 1) != OK:
		_menu.set_net_status("Gagal membuat sesi. Coba lagi.")
		return
	multiplayer.multiplayer_peer = peer
	_net_active = true
	_is_host = true
	_player.peer_id = 1
	_player.name = "Player1"
	print("NET: hosting on port ", NET_PORT)
	_update_net_status()
	# Answer discovery shouts, so other phones can find this host by scanning.
	_discovery = PacketPeerUDP.new()
	_discovery.set_broadcast_enabled(true)
	if _discovery.bind(DISCOVERY_PORT) != OK:
		_discovery = null


func net_join(ip: String) -> void:
	if _net_active:
		return
	ip = ip.strip_edges()
	if ip == "":
		_menu.set_net_status("Isi dulu alamat IP tuan rumah.")
		return
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(ip, NET_PORT) != OK:
		_menu.set_net_status("Alamat IP tidak valid.")
		return
	multiplayer.multiplayer_peer = peer
	_net_active = true
	_is_host = false
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("net", "last_ip", ip)
	cfg.save(SETTINGS_PATH)
	_menu.set_net_status("Menghubungkan ke " + ip + " ...")
	print("NET: joining ", ip)


## --- The mini zoo -------------------------------------------------------------
## A fenced pen with a horse, a rabbit, a cat and a small dinosaur. Stand
## by one and its buttons appear: feed it, play with it. The horse can be
## ridden — it trots along under you, a little faster than running, also in
## a race — and the other phones see the horse through your profile.

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


func _build_zoo() -> void:
	U.mesh_box(_park, Vector3(13.6, 0.04, 11.6), ZOO_CENTER + Vector3(0, 0.02, 0), SAND)
	var post_col := Color(0.85, 0.7, 0.45)
	var x0 := -36.0
	var x1 := -22.0
	var z0 := -35.0
	var z1 := -23.0
	var posts: Array[Vector3] = []
	var px := x0
	while px <= x1:
		posts.append(Vector3(px, 0, z0))
		posts.append(Vector3(px, 0, z1))
		px += 2.0
	var pz := z0 + 2.0
	while pz < z1:
		posts.append(Vector3(x0, 0, pz))
		if pz < -30.6 or pz > -27.4:
			posts.append(Vector3(x1, 0, pz))
		pz += 2.0
	for p in posts:
		U.block(_park, Vector3(0.12, 1.0, 0.12), p + Vector3(0, 0.5, 0), post_col)
	for y in [0.45, 0.85]:
		U.block(_park, Vector3(x1 - x0, 0.07, 0.07), Vector3((x0 + x1) / 2, y, z0), post_col)
		U.block(_park, Vector3(x1 - x0, 0.07, 0.07), Vector3((x0 + x1) / 2, y, z1), post_col)
		U.block(_park, Vector3(0.07, 0.07, z1 - z0), Vector3(x0, y, (z0 + z1) / 2), post_col)
		U.block(_park, Vector3(0.07, 0.07, 4.4), Vector3(x1, y, -32.8), post_col)
		U.block(_park, Vector3(0.07, 0.07, 4.4), Vector3(x1, y, -25.2), post_col)
	# A hay pile and a water trough to make it a home.
	U.mesh_box(_park, Vector3(1.4, 0.5, 1.0), Vector3(-34.6, 0.25, -33.6), Color(1.0, 0.85, 0.2))
	U.mesh_box(_park, Vector3(1.6, 0.35, 0.7), Vector3(-23.6, 0.18, -24.2), Color(0.35, 0.7, 1.0))
	_zoo.append(_zoo_horse(ZOO_HORSE_HOME, -0.6))
	_zoo.append(_zoo_rabbit(Vector3(-26, 0, -25.8), 2.6))
	_zoo.append(_zoo_cat(Vector3(-33, 0, -25.2), 0.7))
	_zoo.append(_zoo_dino(Vector3(-26.5, 0, -32.2), -2.2))


func _zoo_entry(root: Node3D, kind: String, yaw: float) -> Dictionary:
	root.rotation.y = yaw
	_park.add_child(root)
	return {"root": root, "kind": kind, "tail": null, "head": null, "food": null,
		"phase": randf() * 6.0, "play_t": 0.0, "feed_t": 0.0, "home_yaw": yaw}


func _zoo_horse(pos: Vector3, yaw: float) -> Dictionary:
	var root := Node3D.new()
	root.position = pos
	var brown := Color(0.55, 0.38, 0.22)
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
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			U.mesh_cylinder(root, 0.07, 0.72, Vector3(0.55 * sx, 0.36, 0.18 * sz), brown.darkened(0.15))
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
	e["food"] = food
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
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			U.mesh_cylinder(root, 0.09, 0.36, Vector3(0.38 * sx, 0.18, 0.17 * sz), skin.darkened(0.12))
	var food := Node3D.new()
	food.position = Vector3(1.2, 0.05, 0)
	root.add_child(food)
	U.mesh_box(food, Vector3(0.36, 0.04, 0.26), Vector3(0, 0, 0), Color(0.45, 0.85, 0.4))
	food.visible = false
	_zoo_sign(root, "Dino", 2.0)
	var e := _zoo_entry(root, "dino", yaw)
	e["head"] = head
	e["food"] = food
	return e


func _zoo_process(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	for a in _zoo:
		var root: Node3D = a["root"]
		var phase: float = a["phase"]
		match a["kind"]:
			"kelinci":
				root.position.y = pow(maxf(sin(t * 2.4 + phase), 0.0), 6.0) * 0.3
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
		if float(a["feed_t"]) > 0.0:
			a["feed_t"] = float(a["feed_t"]) - delta
			if a["kind"] != "kelinci":
				root.position.y = absf(sin(t * 14.0)) * 0.05
			if float(a["feed_t"]) <= 0.0 and a["food"]:
				a["food"].visible = false
		if float(a["play_t"]) > 0.0:
			a["play_t"] = float(a["play_t"]) - delta
			var prog := 1.0 - maxf(float(a["play_t"]), 0.0) / 1.2
			match a["kind"]:
				"kelinci":
					root.position.y += absf(sin(prog * PI * 3.0)) * 0.45
				"kucing":
					root.rotation.y += delta * 7.0
				"kuda":
					root.rotation.z = -0.4 * sin(prog * PI)
				"dino":
					if a["head"]:
						a["head"].rotation.z = -0.35 * sin(prog * PI)
			if float(a["play_t"]) <= 0.0:
				root.rotation.z = 0.0
				root.rotation.y = float(a["home_yaw"])
				if a["head"]:
					a["head"].rotation.z = 0.0
	# Who are you standing by? Their buttons follow.
	_zoo_near = {}
	if not _riding:
		var best := 2.1
		for a in _zoo:
			var root: Node3D = a["root"]
			var d := Vector2(_player.global_position.x - root.position.x,
				_player.global_position.z - root.position.z).length()
			if d < best:
				best = d
				_zoo_near = a
	if _zoo_feed_button:
		_zoo_feed_button.visible = not _zoo_near.is_empty()
		_zoo_play_button.visible = not _zoo_near.is_empty()
		_zoo_ride_button.visible = _riding or (not _zoo_near.is_empty() and _zoo_near["kind"] == "kuda")
		_zoo_ride_button.text = "Turun" if _riding else "Naik Kuda"
	if _riding and _race_state != 1:
		_player.move_scale = 1.3


func _zoo_feed(a: Dictionary) -> void:
	if a.is_empty():
		return
	if a["food"]:
		a["food"].visible = true
	a["feed_t"] = 1.4
	_sound.play("checkpoint", -3.0)
	U.confetti(self, a["root"].position + Vector3(0, 1.2, 0), 16, HEART_COLORS)


func _zoo_play(a: Dictionary) -> void:
	if a.is_empty():
		return
	a["play_t"] = 1.2
	_sound.play("boing", -3.0)
	U.confetti(self, a["root"].position + Vector3(0, 1.2, 0), 12, RAINBOW)


func _horse_animal() -> Dictionary:
	for a in _zoo:
		if a["kind"] == "kuda":
			return a
	return {}


func _start_riding() -> void:
	if _zoo_near.is_empty() or _zoo_near["kind"] != "kuda":
		return
	_riding = true
	_player.set_mount(true)
	_horse_animal()["root"].visible = false
	_on_profile_changed(_player.profile_dict())


func _stop_riding(to_pen := false) -> void:
	if not _riding:
		return
	_riding = false
	_player.set_mount(false)
	var horse := _horse_animal()
	if not horse.is_empty():
		if to_pen:
			horse["root"].position = ZOO_HORSE_HOME
		else:
			horse["root"].position = Vector3(_player.global_position.x, 0, _player.global_position.z)
		horse["root"].visible = true
	_player.move_scale = 0.0 if _race_state == 1 else 1.0
	_on_profile_changed(_player.profile_dict())


## --- The learning games: Hijaiyah Adventure and Wudhu Challenge ---

## Stop both games and hide their signs.
func _cancel_games() -> void:
	_hij_active = false
	for tok in _hij_tokens:
		tok["root"].visible = false
	_wudhu_active = false
	if _wudhu_button:
		_wudhu_button.visible = false
	if _wudhu_marker:
		_wudhu_marker.visible = false
	if _game_label:
		_game_label.visible = false
	if _game_sub:
		_game_sub.visible = false
	_game_clear_timer = 0.0
	_hij_scores.clear()
	if _menu:
		_menu.set_game_running("")


func _games_process(delta: float) -> void:
	if _game_clear_timer > 0.0:
		_game_clear_timer -= delta
		if _game_clear_timer <= 0.0 and not _hij_active and not _wudhu_active:
			_game_label.visible = false
			_game_sub.visible = false
	if _hij_active:
		_hij_cooldown -= delta
		var target: String = HIJAIYAH[_hij_order[_hij_pos]]
		for tok in _hij_tokens:
			var root: Node3D = tok["root"]
			if not root.visible:
				continue
			var flat := Vector2(_player.global_position.x - root.position.x,
				_player.global_position.z - root.position.z).length()
			if flat > 2.2:
				tok["armed"] = true
			elif flat < 1.25 and tok["armed"] and _hij_cooldown <= 0.0:
				tok["armed"] = false
				if tok["letter"] == target:
					if _net_active:
						rpc("_hij_found_rpc", _hij_pos)
					else:
						_hij_found_rpc(_hij_pos)
				else:
					_sound.play("boing", -4.0)
					_game_sub.text = "Bukan yang ini. Cari huruf: " + target
					_hij_cooldown = 0.8
	_wudhu_since_press += delta
	if _wudhu_warn > 0.0:
		_wudhu_warn -= delta
		if _wudhu_warn <= 0.0 and _wudhu_active:
			_game_sub.text = _wudhu_sub_text()
	if _wudhu_active:
		# The washing place may not be left until the order is finished:
		# stepping too far simply puts you back at its edge.
		var flat := Vector2(_player.global_position.x - WUDHU_POS.x,
			_player.global_position.z - WUDHU_POS.z)
		if flat.length() > WUDHU_AREA_R:
			var clamped := flat.normalized() * WUDHU_AREA_R
			_player.global_position.x = WUDHU_POS.x + clamped.x
			_player.global_position.z = WUDHU_POS.z + clamped.y
	if _wudhu_active and _wudhu_marker:
		var step: Dictionary = WUDHU_STEPS[_wudhu_step]
		_wudhu_marker.global_position = _player.global_position + step["part"]
		_wudhu_marker.scale = Vector3.ONE * (1.0 + 0.22 * sin(Time.get_ticks_msec() * 0.008))


## Four letter boards on posts, reused for every round of the hunt.
func _build_hijaiyah_tokens() -> void:
	for i in 4:
		var root := Node3D.new()
		root.visible = false
		_park.add_child(root)
		U.mesh_cylinder(root, 0.09, 1.0, Vector3(0, 0.5, 0), WOOD)
		U.mesh_box(root, Vector3(1.15, 1.15, 0.1), Vector3(0, 1.6, 0), RAINBOW[i % RAINBOW.size()])
		var label := Label3D.new()
		label.font_size = 160
		label.pixel_size = 0.0062
		label.modulate = WHITE
		label.outline_size = 20
		label.outline_modulate = Color(0.1, 0.1, 0.15)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		# The billboarded text plane passes through the board itself, so
		# without this the board's front face hides the letter.
		label.no_depth_test = true
		label.position = Vector3(0, 1.6, 0)
		root.add_child(label)
		_hij_tokens.append({"root": root, "label": label, "letter": "", "armed": true})


## Hijaiyah Adventure: a letter is shown at the top; four letter boards hide
## around the park and walking into the matching one finds it. All 28
## letters come by, in a shuffled order.
func start_hijaiyah() -> void:
	if _wudhu_active:
		return
	if _active:
		_go_home()
	_stop_race()
	_cancel_games()
	var order: Array[int] = []
	for i in HIJAIYAH.size():
		order.append(i)
	order.shuffle()
	if _net_active:
		rpc("_hij_begin", order)
	else:
		_hij_begin(order)


## The hunt begins on every phone with the same shuffled letter order, so
## the boards and the target match everywhere; each player's finds are
## counted on the shared score line.
@rpc("any_peer", "reliable", "call_local")
func _hij_begin(order: Array) -> void:
	_stop_race()
	_cancel_games()
	_hij_order.clear()
	for v in order:
		_hij_order.append(int(v))
	_hij_scores.clear()
	_hij_names.clear()
	for id in _race_ids():
		_hij_scores[id] = 0
		_hij_names[id] = _name_for_id(id)
	_hij_pos = 0
	_hij_cooldown = 0.0
	_hij_active = true
	_menu.set_game_running("Hijaiyah Adventure")
	_hij_round()


func _hij_hud_text() -> String:
	var line := "Ditemukan: %d dari %d" % [_hij_pos, HIJAIYAH.size()]
	if _hij_scores.size() > 1:
		var parts: Array[String] = []
		for id in _hij_scores:
			var nm := "Kamu" if id == _my_id() else str(_hij_names.get(id, "Pemain"))
			parts.append("%s: %d" % [nm, int(_hij_scores[id])])
		line += "\n" + " • ".join(parts)
	return line


func _hij_round() -> void:
	if _hij_pos >= HIJAIYAH.size():
		_hij_active = false
		for tok in _hij_tokens:
			tok["root"].visible = false
		_game_label.text = "Hebat! Semua huruf hijaiyah ditemukan!"
		_game_sub.text = "Kamu sudah mengenal 28 huruf hijaiyah."
		if _hij_scores.size() > 1:
			_game_sub.text = _hij_hud_text().replace("Ditemukan:", "Skor akhir — ditemukan:")
		_game_label.visible = true
		_game_sub.visible = true
		_sound.play("fanfare")
		_game_clear_timer = 6.0
		_menu.set_game_running("")
		return
	var target: String = HIJAIYAH[_hij_order[_hij_pos]]
	var letters: Array[String] = [target]
	var k := 1
	while letters.size() < _hij_tokens.size():
		var cand: String = HIJAIYAH[_hij_order[(_hij_pos + k) % HIJAIYAH.size()]]
		if not letters.has(cand):
			letters.append(cand)
		k += 1
	var start := (_hij_pos * 3) % HIJ_SPOTS.size()
	for j in _hij_tokens.size():
		var tok := _hij_tokens[j]
		# The arrangement turns with the round number instead of shuffling,
		# so every phone in a group game shows the same boards.
		var letter: String = letters[(j + _hij_pos) % letters.size()]
		tok["letter"] = letter
		# Boards arm once the player is a few steps away, so the board you
		# just found cannot fire again while you still stand on its spot.
		tok["armed"] = false
		tok["label"].text = letter
		tok["root"].position = HIJ_SPOTS[(start + j * 3) % HIJ_SPOTS.size()]
		tok["root"].visible = true
	_game_label.text = "Cari huruf: " + target
	_game_sub.text = _hij_hud_text()
	_game_label.visible = true
	_game_sub.visible = true


## A find counts for the finder only, and the hunt moves on for everyone.
## The round number rides along so a late or double call cannot count twice.
@rpc("any_peer", "reliable", "call_local")
func _hij_found_rpc(round_pos: int) -> void:
	if not _hij_active or round_pos != _hij_pos:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = _my_id()
	if not _hij_scores.has(sender):
		_hij_scores[sender] = 0
		_hij_names[sender] = _name_for_id(sender)
	_hij_scores[sender] = int(_hij_scores[sender]) + 1
	var target: String = HIJAIYAH[_hij_order[_hij_pos]]
	for tok in _hij_tokens:
		if tok["letter"] == target:
			U.confetti(self, tok["root"].position + Vector3(0, 1.6, 0), 30, RAINBOW)
			break
	_sound.play("checkpoint")
	_hij_pos += 1
	_hij_cooldown = 0.6
	_hij_round()


## A little washing place in the park corner: basin, tap and water.
func _build_wudhu_station() -> void:
	var base := Vector3(-22.9, 0, 20.1)
	U.block(_park, Vector3(0.5, 0.75, 0.5), base + Vector3(0, 0.375, 0), WHITE)
	U.solid_cylinder(_park, 0.85, 0.25, base + Vector3(0, 0.85, 0), RAINBOW[4])
	U.mesh_cylinder(_park, 0.72, 0.06, base + Vector3(0, 0.99, 0), Color(0.35, 0.7, 1.0))
	U.mesh_box(_park, Vector3(0.12, 1.7, 0.12), base + Vector3(0, 0.85, -0.45), Color(0.6, 0.65, 0.7))
	U.mesh_box(_park, Vector3(0.12, 0.12, 0.55), base + Vector3(0, 1.68, -0.22), Color(0.6, 0.65, 0.7))
	U.mesh_box(_park, Vector3(0.12, 0.3, 0.12), base + Vector3(0, 1.52, 0.02), Color(0.6, 0.65, 0.7))
	U.mesh_box(_park, Vector3(2.2, 0.06, 1.6), WUDHU_POS + Vector3(0, 0.03, 0), Color(0.55, 0.8, 0.95))


## Wudhu Challenge: stand at the washing place, face the camera, and press
## the big button for every wash. The blue marker shows which part is next,
## so the order is learned by doing it.
func start_wudhu() -> void:
	if _hij_active:
		return
	if _active:
		_go_home()
	_stop_race()
	_cancel_games()
	_wudhu_active = true
	_wudhu_step = 0
	_wudhu_presses = 0
	_wudhu_since_press = WUDHU_PRESS_GAP
	_wudhu_warn = 0.0
	_player.teleport(WUDHU_POS + Vector3(0, 0.1, 0))
	_player.look_toward(Vector3(0, 0, 1))
	_player._model.rotation.y = 0.0
	_wudhu_button.visible = true
	_wudhu_marker.visible = true
	_menu.set_game_running("Wudhu Challenge")
	_wudhu_show_step()


func _wudhu_sub_text() -> String:
	if _wudhu_presses > 0:
		var step: Dictionary = WUDHU_STEPS[_wudhu_step]
		return "Langkah %d dari %d — lagi %d kali" % [
			_wudhu_step + 1, WUDHU_STEPS.size(), int(step["times"]) - _wudhu_presses]
	return "Langkah %d dari %d" % [_wudhu_step + 1, WUDHU_STEPS.size()]


func _wudhu_show_step() -> void:
	var step: Dictionary = WUDHU_STEPS[_wudhu_step]
	_game_label.text = "Wudhu: " + str(step["name"])
	_game_sub.text = _wudhu_sub_text()
	_game_label.visible = true
	_game_sub.visible = true
	_wudhu_button.text = str(step["btn"])


func _on_wudhu_press() -> void:
	if not _wudhu_active:
		return
	if _wudhu_since_press < WUDHU_PRESS_GAP:
		# Wudhu is not a race: a too-fast press is not counted, and the
		# warning stays until it fades on its own.
		_game_sub.text = "Pelan-pelan ya — jangan wudhu cepat-cepat."
		_sound.play("sit", -4.0)
		_wudhu_warn = 1.6
		return
	_wudhu_since_press = 0.0
	var step: Dictionary = WUDHU_STEPS[_wudhu_step]
	_wudhu_presses += 1
	var part_pos: Vector3 = _player.global_position + step["part"]
	if step["btn"] == "AIR!":
		_sound.play("splash", -4.0)
		U.confetti(self, part_pos, 14, WUDHU_COLORS)
	else:
		_sound.play("checkpoint", -4.0)
		U.confetti(self, part_pos, 10, RAINBOW)
	if _wudhu_presses >= int(step["times"]):
		_wudhu_step += 1
		_wudhu_presses = 0
		if _wudhu_step >= WUDHU_STEPS.size():
			_wudhu_active = false
			_wudhu_button.visible = false
			_wudhu_marker.visible = false
			_game_label.text = "Wudhu selesai! Hebat!"
			_game_sub.text = "Kamu sudah belajar urutan wudhu."
			_game_label.visible = true
			_game_sub.visible = true
			_sound.play("fanfare")
			U.confetti(self, _player.global_position + Vector3(0, 1.8, 0), 50, RAINBOW)
			_game_clear_timer = 6.0
			_menu.set_game_running("")
		else:
			_sound.play("checkpoint", -2.0)
			_wudhu_show_step()
	else:
		_game_sub.text = _wudhu_sub_text()


func net_disconnect() -> void:
	_end_session("Kamu main sendiri sekarang.")


## Stop any running race and put its signs away.
func _stop_race() -> void:
	if _race_state != 0:
		_race_state = 0
		_player.move_scale = 1.0
		_race_banner.visible = false
	if _race_results:
		_race_results.visible = false
	_results_timer = 0.0
	for c in _race_coins:
		c["node"].visible = false


func _end_session(message: String) -> void:
	_stop_scan()
	if _discovery:
		_discovery.close()
		_discovery = null
	_stop_race()
	_cancel_games()
	for id in _puppets:
		_puppets[id].queue_free()
	_puppets.clear()
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	_net_active = false
	_is_host = false
	_player.peer_id = 0
	_menu.set_in_session(false)
	_menu.set_net_status(message)
	print("NET: session ended (", message, ")")


func _on_peer_connected(id: int) -> void:
	print("NET: peer connected ", id)
	if not _net_active:
		return
	_spawn_puppet(id)
	_send_profile_to(id)
	_update_net_status()
	# The other phone may not have this puppet yet when the first profile
	# arrives, so send it once more a moment later.
	get_tree().create_timer(0.6).timeout.connect(func():
		if _net_active and _puppets.has(id):
			_send_profile_to(id))


func _on_peer_disconnected(id: int) -> void:
	print("NET: peer left ", id)
	_despawn_puppet(id)
	if _net_active:
		_update_net_status()


func _on_connected_to_server() -> void:
	_player.peer_id = multiplayer.get_unique_id()
	_player.name = "Player" + str(_player.peer_id)
	print("NET: connected as peer ", _player.peer_id)
	_update_net_status()


func _on_connection_failed() -> void:
	_end_session("Tidak bisa terhubung. Cek WiFi dan alamat IP-nya.")


func _on_server_disconnected() -> void:
	_end_session("Tuan rumah keluar. Sesi berakhir.")


func _on_profile_changed(d: Dictionary) -> void:
	_player.apply_profile(d, true)
	if _net_active:
		_player.rpc("_receive_profile", _player.profile_dict())


func _send_profile_to(id: int) -> void:
	_player.rpc_id(id, "_receive_profile", _player.profile_dict())


func _spawn_puppet(id: int) -> void:
	if _puppets.has(id) or id == multiplayer.get_unique_id():
		return
	var puppet := PlayerScript.new()
	puppet.is_remote = true
	puppet.peer_id = id
	puppet.name = "Player" + str(id)
	puppet.respawn_point = SPAWN
	puppet.position = SPAWN
	add_child(puppet)
	_puppets[id] = puppet
	print("NET: puppet for peer ", id, " spawned")


func _despawn_puppet(id: int) -> void:
	if _puppets.has(id):
		_puppets[id].queue_free()
		_puppets.erase(id)


func _update_net_status() -> void:
	_menu.set_in_session(_net_active)
	if not _net_active:
		return
	var count := _puppets.size() + 1
	if _is_host:
		_menu.set_net_status("Tuan rumah aktif. Pemain: %d dari %d.\nAlamat HP ini: %s\nDi HP lain buka menu Main Berdua, isi alamat itu, lalu Gabung." % [count, MAX_PEERS, _local_ip_text()])
	else:
		_menu.set_net_status("Terhubung ke tuan rumah. Pemain: %d. Selamat main bareng!" % count)


func _local_ip_text() -> String:
	var found: Array[String] = []
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("172."):
			found.append(ip)
	if found.is_empty():
		return "(tidak ketemu, cek WiFi)"
	return ", ".join(found)


## --- Finding a host by scanning ---------------------------------------------
## The host answers a broadcast shout with its name; the searching phone
## lists every answer as a one-tap join button. Typing the address by hand
## stays as the fallback when a network swallows broadcasts.

func net_scan() -> void:
	if _net_active:
		_menu.set_scan_status("Sudah terhubung. Putuskan dulu untuk mencari.")
		return
	_stop_scan()
	_scan_found.clear()
	_menu.set_scan_results({})
	_scan_peer = PacketPeerUDP.new()
	_scan_peer.set_broadcast_enabled(true)
	if _scan_peer.bind(0) != OK:
		_scan_peer = null
		_menu.set_scan_status("Tidak bisa mencari di jaringan ini.")
		return
	_scan_peer.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	_scan_peer.put_packet(DISCOVER_MSG.to_utf8_buffer())
	# Some routers drop the global broadcast but pass the subnet one.
	for ip in IP.get_local_addresses():
		var parts := ip.split(".")
		if parts.size() == 4:
			_scan_peer.set_dest_address(parts[0] + "." + parts[1] + "." + parts[2] + ".255", DISCOVERY_PORT)
			_scan_peer.put_packet(DISCOVER_MSG.to_utf8_buffer())
	_scan_deadline = Time.get_ticks_msec() + 2500
	_menu.set_scan_status("Mencari tuan rumah...")
	print("NET: scanning for hosts")


func _stop_scan() -> void:
	if _scan_peer:
		_scan_peer.close()
		_scan_peer = null


func _poll_scan() -> void:
	if _scan_peer == null:
		return
	var changed := false
	while _scan_peer.get_available_packet_count() > 0:
		var msg := _scan_peer.get_packet().get_string_from_utf8()
		if msg.begins_with(HOST_MSG_PREFIX):
			var ip := _scan_peer.get_packet_ip()
			if not _scan_found.has(ip):
				_scan_found[ip] = msg.trim_prefix(HOST_MSG_PREFIX)
				changed = true
				print("NET: scan found host ", ip)
	if changed:
		_menu.set_scan_results(_scan_found)
		_menu.set_scan_status("Ketemu! Ketuk nama untuk langsung gabung.")
	if Time.get_ticks_msec() > _scan_deadline:
		_stop_scan()
		if _scan_found.is_empty():
			_menu.set_scan_status("Tidak ditemukan. Coba ketik alamatnya di bawah.")


func _poll_discovery() -> void:
	if _discovery == null:
		return
	while _discovery.get_available_packet_count() > 0:
		var msg := _discovery.get_packet().get_string_from_utf8()
		if msg == DISCOVER_MSG:
			var nm: String = _player.player_name if _player.player_name != "" else "Tuan Rumah"
			_discovery.set_dest_address(_discovery.get_packet_ip(), _discovery.get_packet_port())
			_discovery.put_packet((HOST_MSG_PREFIX + nm).to_utf8_buffer())


## --- The running race ---------------------------------------------------------
## Anyone in the game can start it for everyone: all players are lined up in
## the arena lanes, counted down, and race from the start arch to the finish
## arch, jumping hurdles and collecting coins on the way. Places and coin
## counts are shared as they happen, and compared on the results board when
## the race ends.

func _on_race_pressed() -> void:
	if not _net_active:
		_menu.set_net_status("Balap lari perlu teman: jadi tuan rumah atau gabung dulu.")
		return
	if _hij_active or _wudhu_active:
		_menu.set_net_status("Sudahi dulu mini game yang sedang berjalan (menu Mini Game).")
		return
	rpc("_race_start")


@rpc("any_peer", "reliable", "call_local")
func _race_start() -> void:
	if _race_state != 0:
		return
	_cancel_games()
	if _active:
		_go_home()
	var ids := _race_ids()
	_race_total = ids.size()
	_race_finishers.clear()
	_race_coin_counts.clear()
	_race_names.clear()
	for id in ids:
		_race_coin_counts[id] = 0
		_race_names[id] = _name_for_id(id)
	for c in _race_coins:
		c["taken"] = false
		c["node"].visible = true
	_race_results.visible = false
	_results_timer = 0.0
	var slot := ids.find(_my_id())
	var x: float = RACE_LANE_X[clampi(slot, 0, RACE_LANE_X.size() - 1)]
	_player.teleport(Vector3(x, 0.1, RACE_START_Z))
	_player.look_toward(Vector3(0, 0, -1))
	_player.move_scale = 0.0
	_race_state = 1
	_race_timer = RACE_COUNTDOWN
	_show_banner("Balap Lari mulai dalam 3...")
	print("NET: race started, ", _race_total, " runners")


@rpc("any_peer", "reliable", "call_local")
func _race_finish(coins: int) -> void:
	var id := multiplayer.get_remote_sender_id()
	if id == 0:
		id = multiplayer.get_unique_id()
	_apply_coin(id, coins)
	_apply_finish(id)


## A runner tells everyone how many coins they hold now, so the end-of-race
## comparison can include them.
@rpc("any_peer", "reliable", "call_local")
func _race_coin(total: int) -> void:
	var id := multiplayer.get_remote_sender_id()
	if id == 0:
		id = multiplayer.get_unique_id()
	_apply_coin(id, total)


func _apply_coin(id: int, total: int) -> void:
	if _race_state == 0:
		return
	_race_coin_counts[id] = total
	if not _race_names.has(id):
		_race_names[id] = _name_for_id(id)


## Pick up the coins the local runner touches.
func _collect_coins() -> void:
	var my := _my_id()
	for c in _race_coins:
		if c["taken"]:
			continue
		var p: Vector3 = c["pos"]
		var flat := Vector2(_player.global_position.x - p.x, _player.global_position.z - p.z).length()
		if flat < 1.0 and absf(_player.global_position.y + 1.0 - RACE_COIN_Y) < 1.6:
			c["taken"] = true
			c["node"].visible = false
			_sound.play("checkpoint", -6.0)
			var total := int(_race_coin_counts.get(my, 0)) + 1
			if _net_active:
				rpc("_race_coin", total)
			else:
				_apply_coin(my, total)


func _race_process(delta: float) -> void:
	if _results_timer > 0.0:
		_results_timer -= delta
		if _results_timer <= 0.0 and _race_results:
			_race_results.visible = false
	# Coins spin and bob while they are on show.
	if _race_state != 0:
		var t := Time.get_ticks_msec() * 0.001
		for i in _race_coins.size():
			var c := _race_coins[i]
			if not c["taken"]:
				c["node"].rotation.y = t * 3.0 + float(i) * 0.7
				c["node"].position.y = RACE_COIN_Y + sin(t * 2.2 + float(i)) * 0.12
	if _banner_timer > 0.0:
		_banner_timer -= delta
		if _banner_timer <= 0.0 and _race_state != 1:
			_race_banner.visible = false
	if _race_state == 1:
		_race_timer -= delta
		if _race_timer > 0.0:
			_show_banner("Balap Lari mulai dalam %d..." % maxi(int(ceil(_race_timer)), 1))
		else:
			_race_state = 2
			_race_timer = RACE_TIMEOUT
			_player.move_scale = 1.0
			_show_banner("LARI!")
			_banner_timer = 1.0
	elif _race_state == 2:
		_race_timer -= delta
		_collect_coins()
		var my := _my_id()
		if not _race_finishers.has(my) and _player.global_position.z <= RACE_FINISH_Z:
			if _net_active:
				rpc("_race_finish", int(_race_coin_counts.get(my, 0)))
			else:
				_apply_finish(my)
		if _race_state == 2 and _race_timer <= 0.0:
			_end_race()


func _apply_finish(id: int) -> void:
	if _race_state != 2 or _race_finishers.has(id):
		return
	_race_finishers.append(id)
	var place := _race_finishers.size()
	if place == 1:
		U.confetti(self, Vector3(0, 1.5, RACE_FINISH_Z), 40, RAINBOW)
	if id == _my_id():
		_show_banner("Kamu finish ke-%d!" % place)
		_banner_timer = 3.0
	elif place == 1:
		_show_banner("%s menang!" % _name_for_id(id))
		_banner_timer = 3.0
	print("NET: race finish #", place, " = ", _name_for_id(id))
	if _race_finishers.size() >= _race_total:
		_end_race()


func _end_race() -> void:
	_race_state = 0
	_player.move_scale = 1.0
	_race_banner.visible = false
	for c in _race_coins:
		c["node"].visible = false
	if not _race_finishers.is_empty():
		_sound.play("fanfare")
	_race_results.text = _race_results_text()
	_race_results.visible = true
	_results_timer = RACE_RESULTS_TIME


## The comparison shown when a race ends: places first, then everyone who
## did not finish, with the coin counts side by side and the coin champion
## named at the bottom.
func _race_results_text() -> String:
	var lines: Array[String] = ["HASIL BALAP LARI"]
	var place := 0
	for id in _race_finishers:
		place += 1
		lines.append("%d. %s — %d koin" % [place, _race_name(id), int(_race_coin_counts.get(id, 0))])
	var rest: Array[int] = []
	for key in _race_coin_counts:
		if not _race_finishers.has(int(key)):
			rest.append(int(key))
	rest.sort_custom(func(a: int, b: int):
		return int(_race_coin_counts.get(a, 0)) > int(_race_coin_counts.get(b, 0)))
	for id in rest:
		lines.append("%s — %d koin (belum finish)" % [_race_name(id), int(_race_coin_counts.get(id, 0))])
	var best := 0
	var champs: Array[String] = []
	for key in _race_coin_counts:
		var n := int(_race_coin_counts[key])
		if n > best:
			best = n
			champs = [_race_name(int(key))]
		elif n == best and n > 0:
			champs.append(_race_name(int(key)))
	if best > 0:
		lines.append("Koin terbanyak: %s (%d)" % [", ".join(champs), best])
	return "\n".join(lines)


func _race_name(id: int) -> String:
	if _race_names.has(id):
		var nm: String = _race_names[id]
		if nm != "":
			return nm
	return _name_for_id(id)


func _my_id() -> int:
	return multiplayer.get_unique_id() if _net_active else 0


func _race_ids() -> Array[int]:
	var ids: Array[int] = []
	ids.append(_my_id())
	for id in _puppets:
		ids.append(int(id))
	ids.sort()
	return ids


func _name_for_id(id: int) -> String:
	var nm := ""
	if id == _my_id():
		nm = _player.player_name
	elif _puppets.has(id):
		nm = _puppets[id].player_name
	return nm if nm != "" else "Pemain %d" % id


func _show_banner(text: String) -> void:
	_race_banner.text = text
	_race_banner.visible = true
