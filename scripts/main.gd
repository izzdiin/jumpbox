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

## The shared game prompts: one big line and a smaller one under it,
## plus the reward toast. They live on their own canvas layer under the
## menu, so opening the menu hides them all at once.
var _game_label: Label
var _game_sub: Label
var _game_clear_timer := 0.0
var _game_layer: CanvasLayer

## The park's big pieces, each in its own script since the great split:
## the zoo, the river and the three mini games. Main builds and wires
## them, coordinates which game runs, and owns the shared prompt labels.
var zoo: Zoo
var river: River
var hijaiyah: HijaiyahGame
var wudhu: WudhuGame
var fishing: FishingGame
var _running_game := ""
var _reward_label: Label
var _reward_timer := 0.0


func _ready() -> void:
	_sound = SoundScript.new()
	add_child(_sound)
	_build_environment()
	_park = Node3D.new()
	add_child(_park)
	_build_ground()
	_build_fence()
	_build_race_arena()
	river = River.new()
	river.name = "River"
	_park.add_child(river)
	river.build()
	zoo = Zoo.new()
	zoo.name = "Zoo"
	_park.add_child(zoo)
	hijaiyah = HijaiyahGame.new()
	hijaiyah.name = "HijaiyahGame"
	_park.add_child(hijaiyah)
	wudhu = WudhuGame.new()
	wudhu.name = "WudhuGame"
	_park.add_child(wudhu)
	fishing = FishingGame.new()
	fishing.name = "FishingGame"
	_park.add_child(fishing)
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
		if wudhu:
			wudhu.marker.visible = false)
	menu.closed.connect(func():
		_game_layer.visible = true
		if wudhu and wudhu.active:
			wudhu.marker.visible = true)
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

	# The reward toast: stars rain briefly at the top of the screen.
	_reward_label = Label.new()
	_reward_label.anchor_left = 0.0
	_reward_label.anchor_right = 1.0
	_reward_label.offset_top = 252
	_reward_label.offset_bottom = 322
	_reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward_label.add_theme_font_size_override("font_size", 38)
	_reward_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	_reward_label.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.15))
	_reward_label.add_theme_constant_override("outline_size", 12)
	_reward_label.visible = false
	_game_layer.add_child(_reward_label)

	# Wire the modules now that the player, the sounds and the shared
	# prompt labels all exist.
	zoo.setup(_player, _sound, _game_layer, _on_mount_changed)
	hijaiyah.setup(self, _player, _sound, _game_label, _game_sub)
	wudhu.setup(self, _player, _sound, _game_label, _game_sub, _game_layer)
	var spots: Array = [zoo.pond_spot()]
	spots.append_array(river.fishing_spots())
	fishing.setup(self, _player, _sound, _game_label, _game_sub, _game_layer, spots)

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
	zoo.stop_riding(true)
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
	if wudhu.active:
		# Wudhu is finished where it started: the home trip waits, and you
		# are simply put back at the washing place.
		_player.teleport(WudhuGame.POS + Vector3(0, 0.1, 0))
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
	if _game_clear_timer > 0.0:
		_game_clear_timer -= delta
		if _game_clear_timer <= 0.0 and _running_game == "":
			_game_label.visible = false
			_game_sub.visible = false
	if _reward_timer > 0.0:
		_reward_timer -= delta
		if _reward_timer <= 0.0:
			_reward_label.visible = false
	_update_swim()
	if zoo and zoo.riding and _race_state != 1:
		_player.move_scale = 1.3
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
	# In pieces, so the river channel (see river.gd) stays open along the
	# west side, north of the mini zoo.
	U.block(_park, Vector3(70.8, 1, HALF_SIZE * 2 + 4), Vector3(4.6, -0.5, 0), GRASS)
	U.block(_park, Vector3(4.8, 1, HALF_SIZE * 2 + 4), Vector3(-37.6, -0.5, 0), GRASS)
	U.block(_park, Vector3(4.4, 1, 20.5), Vector3(-33, -0.5, -29.75), GRASS)
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
		if p.x > Zoo.ZOO_X0 - 0.5 and p.x < Zoo.ZOO_X1 + 0.5 and p.z > Zoo.ZOO_Z0 - 0.5 and p.z < Zoo.ZOO_Z1 + 0.5:
			continue
		# And the river channel.
		if p.x > -36.2 and p.x < -29.8 and p.z > -20.5:
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


## --- The mini games: coordination, rewards and swimming ---------------
## Each game lives in its own script (HijaiyahGame, WudhuGame,
## FishingGame, Zoo). Main keeps the shared prompt labels, decides which
## game may run, hands out the star rewards, and watches the river.

## Stop every game and hide their signs.
func _cancel_games() -> void:
	hijaiyah.cancel()
	wudhu.cancel()
	fishing.cancel()
	if _game_label:
		_game_label.visible = false
	if _game_sub:
		_game_sub.visible = false
	_game_clear_timer = 0.0
	set_game_running("")


func set_game_running(game_name: String) -> void:
	_running_game = game_name
	if _menu:
		_menu.set_game_running(game_name)


func running_game() -> String:
	return _running_game


func zoo_riding() -> bool:
	return zoo and zoo.riding


## A game is about to start (also on the other phones, via the hijaiyah
## RPC): leave any course, stop the race, stop whatever else was running.
func prepare_for_game() -> void:
	if _active:
		_go_home()
	_stop_race()
	_cancel_games()


func net_active() -> bool:
	return _net_active


func race_ids() -> Array:
	return _race_ids()


func name_for_id(id: int) -> String:
	return _name_for_id(id)


func my_id() -> int:
	return _my_id()


## Keep a finished game's message on screen a little while.
func show_prompts_for(seconds: float) -> void:
	_game_clear_timer = seconds


## Stars for finishing a game, celebrated with the toast.
func game_completed(kind: String) -> void:
	var total := Rewards.award(kind, 5)
	_show_reward("⭐ +5 Bintang! Total bintangmu: %d" % total)


func fish_caught(_fish_name: String, size_cm: int) -> void:
	var stars := 2 if size_cm >= 28 else 1
	var total := Rewards.award("mancing", stars)
	_show_reward("⭐ +%d Bintang! Total bintangmu: %d" % [stars, total])


func _show_reward(text: String) -> void:
	_reward_label.text = text
	_reward_label.visible = true
	_reward_timer = 3.0


func start_hijaiyah() -> void:
	if wudhu.active or fishing.active:
		return
	prepare_for_game()
	hijaiyah.begin()


func start_wudhu() -> void:
	if hijaiyah.active or fishing.active:
		return
	prepare_for_game()
	wudhu.begin()


func _on_wudhu_press() -> void:
	wudhu.press()


func _on_mount_changed() -> void:
	if not zoo.riding:
		_player.move_scale = 0.0 if _race_state == 1 else 1.0
	_on_profile_changed(_player.profile_dict())


## The river is deep in its channel: stepping in puts you into swim
## mode, and the ramps (or leaving the channel) take you out of it.
func _update_swim() -> void:
	if _player == null:
		return
	if _active:
		_player.swim = false
		return
	var want: bool = river.in_channel(_player.global_position) \
		and not river.ramp_at(_player.global_position) \
		and _player.global_position.y < -0.02 \
		and not zoo.riding
	if want and not _player.swim:
		_player.swim = true
		_player.swim_y = River.SWIM_Y
		_sound.play("splash", -3.0)
	elif not want and _player.swim:
		_player.swim = false


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
	if hijaiyah.active or wudhu.active or fishing.active:
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
