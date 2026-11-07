extends CharacterBody3D
## The blocky kid you play as. Walks, jumps, bounces on trampolines, slides down slides and
## climbs climbing walls. It also owns the follow camera.

const U := preload("res://scripts/util.gd")
const Hats := preload("res://scripts/hats.gd")
const SETTINGS_PATH := "user://settings.cfg"

const WALK_SPEED := 6.0
const JUMP_SPEED := 8.0
const GRAVITY := 22.0
const SLIDE_ACCEL := 16.0
const SLIDE_MAX_SPEED := 13.0
const COYOTE_TIME := 0.15
const CLIMB_SPEED := 2.6
## Bodies on this physics layer (nets) stop the player but not the camera, so the camera
## can look through them. Everything else is on layer 1.
const NET_LAYER := 2
const CAM_DISTANCE := 7.0

const SKIN := Color(1.0, 0.8, 0.25)
const SHIRT := Color(0.95, 0.3, 0.3)
const PANTS := Color(0.2, 0.45, 0.9)

## Choices shown on the character page of the menu.
const SKIN_TONES: Array[Color] = [
	Color(1.0, 0.8, 0.25), Color(1.0, 0.87, 0.66), Color(0.98, 0.76, 0.52),
	Color(0.85, 0.6, 0.4), Color(0.62, 0.42, 0.28), Color(0.4, 0.27, 0.18),
]
const SHIRT_COLORS: Array[Color] = [
	Color(0.95, 0.3, 0.3), Color(1.0, 0.6, 0.15), Color(1.0, 0.85, 0.2), Color(0.4, 0.8, 0.3),
	Color(0.25, 0.65, 0.95), Color(0.55, 0.4, 0.9), Color(0.95, 0.45, 0.75),
	Color(0.97, 0.97, 0.97), Color(0.25, 0.25, 0.3),
]
const HAIR_COLORS: Array[Color] = [
	Color(0.12, 0.09, 0.07), Color(0.35, 0.2, 0.1), Color(0.9, 0.7, 0.3),
	Color(0.8, 0.3, 0.1), Color(0.25, 0.5, 0.95), Color(0.95, 0.5, 0.75),
]
const HIJAB_COLORS: Array[Color] = [
	Color(0.95, 0.5, 0.7), Color(0.6, 0.45, 0.9), Color(0.35, 0.6, 0.95), Color(0.2, 0.75, 0.7),
	Color(1.0, 0.85, 0.3), Color(0.97, 0.97, 0.97), Color(0.9, 0.35, 0.35),
]
const HAIR_STYLES := ["Botak", "Pendek", "Jabrik", "Panjang"]
const FACE_STYLES := ["Senyum", "Gembira", "Biasa", "Terkejut", "Ngantuk", "Kedip"]
## How often the owner of a player sends its place to the other phones (seconds).
const NET_SEND_EVERY := 0.05

## The touch UI (touch_ui.gd). Set by main.gd.
var ui: Node
## The sound player (sound.gd). Set by main.gd.
var sound: Node
## Where you come back after falling or pressing home. The sky course moves it to its checkpoints.
var respawn_point := Vector3.ZERO
## Falling below this height sends you back to respawn_point.
var kill_y := -10.0
## Walking speed is multiplied by this (the water park makes it slower in the pool).
var move_scale := 1.0
## The sound for falling below kill_y.
var fall_sound := "home"

var _model: Node3D
## Riding the zoo horse: the mount is a horse prop under the model and the
## model sits up on its back. Synced to the other phones through the
## profile ("mount"), so everyone sees who is riding.
const MOUNT_LIFT := 0.92
var mount := false
var _mount_root: Node3D
var _mount_legs: Array[Node3D] = []
var _mount_tail: Node3D
var _mount_phase := 0.0
var _mount_amp := 0.0
## Swimming in the park river: main sets this while you are in the water;
## the body then paddles at swim_y instead of walking on the bed.
var swim := false
var swim_y := -0.42
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _hat_root: Node3D
## The hat being worn ("" for none). Saved, so it stays on next time.
var hat := ""
var _walk_time := 0.0
var _squash := 0.0
var _air_time := 0.0
## What is right under our feet (from the shadow ray). Used to know if we are on a slide.
var _floor_obj: Object
## The swing seat we sit on, if any.
var _seat: Node3D
var _seat_cooldown := 0.0
## The seat we just got off. We only sit on it again after walking away from it.
var _last_seat: Node3D
## The swim ring we sit in, if any (water park).
var _float: Node3D
var _float_cooldown := 0.0
## True until the jump button is let go after sitting on a swing or getting into a ring,
## so holding jump does not throw you right back off.
var _wait_release := false
var _was_on_slide := false
var _kick_cooldown := 0.0
## The flat normal of the climbing wall we touch (ZERO when none). Set after each move.
var _wall_normal := Vector3.ZERO
var _last_wall_normal := Vector3.ZERO
var _climbing := false

var _cam_yaw := 0.0
var _cam_pitch := -0.3
var _cam_rig: Node3D
var _cam_pitch_node: Node3D
var _shadow: MeshInstance3D

## --- Character profile: picked on the menu's character page, saved, and shared
## with the other players in a WLAN game so everyone looks different.
var player_name := ""
var gender := "boy"  # "boy" or "girl"
var skin_color := SKIN
var shirt_color := SHIRT
var hair_style := 1  # index into HAIR_STYLES
var hair_color := Color(0.12, 0.09, 0.07)
var face_style := 0  # index into FACE_STYLES
var wear_hijab := false
var hijab_color := Color(0.95, 0.5, 0.7)

## --- WLAN multiplayer. peer_id is 0 while playing alone. A player with
## is_remote set is a puppet: no input, no camera, no physics of its own; the
## phone of the kid playing it sends where it is (see _receive_state).
var peer_id := 0
var is_remote := false
var _name_label: Label3D
var _net_timer := 0.0
var _net_pos := Vector3.ZERO
var _net_yaw := 0.0
var _net_speed := 0.0
var _net_state := 0
var _net_started := false


func _ready() -> void:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.7
	var cs := CollisionShape3D.new()
	cs.shape = capsule
	cs.position.y = 0.85
	add_child(cs)
	collision_mask = 1 | NET_LAYER
	floor_max_angle = deg_to_rad(50)
	floor_snap_length = 0.3
	if is_remote:
		# A puppet never bumps into anything and nothing bumps into it: the
		# owning phone just tells it where to stand.
		collision_layer = 0
		collision_mask = 0
	_build_model()
	_build_name_label()
	if not is_remote:
		_build_camera()
	_build_shadow()
	if not is_remote:
		var cfg := ConfigFile.new()
		if cfg.load(SETTINGS_PATH) == OK:
			_load_profile(cfg)
			set_hat(cfg.get_value("player", "hat", ""), false)


func set_hat(hat_name: String, save := true) -> void:
	if hat_name == hat:
		return
	hat = hat_name
	for child in _hat_root.get_children():
		child.queue_free()
	var holder := Node3D.new()
	_hat_root.add_child(holder)
	Hats.build(hat_name, holder)
	if save:
		var cfg := ConfigFile.new()
		cfg.load(SETTINGS_PATH)
		cfg.set_value("player", "hat", hat_name)
		cfg.save(SETTINGS_PATH)


## The whole look as one dictionary: saved on this phone and sent to the other
## phones in a WLAN game (Colors travel as Colors, they are a built-in type).
func profile_dict() -> Dictionary:
	return {
		"name": player_name, "gender": gender,
		"skin": skin_color, "shirt": shirt_color,
		"hair_style": hair_style, "hair_color": hair_color, "face": face_style,
		"hijab": wear_hijab, "hijab_color": hijab_color, "hat": hat,
		"mount": mount,
	}


func apply_profile(d: Dictionary, save := false) -> void:
	player_name = str(d.get("name", player_name)).left(16)
	gender = str(d.get("gender", gender))
	skin_color = d.get("skin", skin_color)
	shirt_color = d.get("shirt", shirt_color)
	hair_style = clampi(int(d.get("hair_style", hair_style)), 0, HAIR_STYLES.size() - 1)
	hair_color = d.get("hair_color", hair_color)
	face_style = clampi(int(d.get("face", face_style)), 0, FACE_STYLES.size() - 1)
	wear_hijab = bool(d.get("hijab", wear_hijab))
	hijab_color = d.get("hijab_color", hijab_color)
	refresh_appearance()
	set_hat(str(d.get("hat", hat)), false)
	if d.has("mount"):
		set_mount(bool(d["mount"]))
	if save:
		_save_profile()


## Rebuild the blocky kid with the current profile colors, hair and hijab.
func refresh_appearance() -> void:
	if _model:
		_model.queue_free()
	_legs.clear()
	_arms.clear()
	_build_model()
	_model.position.y = MOUNT_LIFT if mount else 0.0
	var worn := hat
	hat = ""
	set_hat(worn, false)
	_update_name_label()


func _save_profile() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("profile", "name", player_name)
	cfg.set_value("profile", "gender", gender)
	cfg.set_value("profile", "skin", skin_color.to_html())
	cfg.set_value("profile", "shirt", shirt_color.to_html())
	cfg.set_value("profile", "hair_style", hair_style)
	cfg.set_value("profile", "hair_color", hair_color.to_html())
	cfg.set_value("profile", "face", face_style)
	cfg.set_value("profile", "hijab", wear_hijab)
	cfg.set_value("profile", "hijab_color", hijab_color.to_html())
	cfg.save(SETTINGS_PATH)


func _load_profile(cfg: ConfigFile) -> void:
	var d := {
		"name": cfg.get_value("profile", "name", player_name),
		"gender": cfg.get_value("profile", "gender", gender),
		"skin": Color.html(cfg.get_value("profile", "skin", skin_color.to_html())),
		"shirt": Color.html(cfg.get_value("profile", "shirt", shirt_color.to_html())),
		"hair_style": cfg.get_value("profile", "hair_style", hair_style),
		"hair_color": Color.html(cfg.get_value("profile", "hair_color", hair_color.to_html())),
		"face": cfg.get_value("profile", "face", face_style),
		"hijab": cfg.get_value("profile", "hijab", wear_hijab),
		"hijab_color": Color.html(cfg.get_value("profile", "hijab_color", hijab_color.to_html())),
		"hat": hat,
	}
	apply_profile(d)


func _build_name_label() -> void:
	_name_label = Label3D.new()
	_name_label.position = Vector3(0, 2.45, 0)
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.font_size = 128
	_name_label.pixel_size = 0.006
	_name_label.modulate = Color.WHITE
	_name_label.outline_size = 24
	_name_label.outline_modulate = Color(0.1, 0.1, 0.15, 0.9)
	add_child(_name_label)
	_update_name_label()


## Only the other players wear a name tag; your own would hang in the camera.
func _update_name_label() -> void:
	if _name_label == null:
		return
	_name_label.text = player_name
	_name_label.visible = is_remote and player_name != ""


func respawn(sound_name := "home") -> void:
	teleport(respawn_point)
	_sfx(sound_name)


## Throws the player straight up, like a water jet does.
func launch(up_speed: float) -> void:
	_leave_float()
	velocity.y = up_speed
	_air_time = COYOTE_TIME
	_squash = 1.0


## Turns the camera to look along `dir` (only its flat part counts).
func look_toward(dir: Vector3) -> void:
	_cam_yaw = atan2(-dir.x, -dir.z)


func teleport(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	_seat = null
	_climbing = false
	_wall_normal = Vector3.ZERO
	_model.rotation.x = 0.0
	_leave_float()
	_cam_rig.global_position = pos + Vector3.UP * 1.3


func _sfx(sound_name: String, volume_db := 0.0, pitch := 1.0) -> void:
	if sound:
		sound.play(sound_name, volume_db, pitch)


## Sit on (or climb off) the horse. The horse prop faces -Z like the model,
## so it trots along wherever the model turns.
func set_mount(on: bool) -> void:
	mount = on
	if on:
		if _mount_root == null:
			_mount_root = _build_mount_horse()
			add_child(_mount_root)
		_mount_root.visible = true
	elif _mount_root:
		_mount_root.visible = false
		_mount_root.position.y = 0.0
		for leg in _mount_legs:
			leg.rotation.x = 0.0
	if _model:
		_model.position.y = MOUNT_LIFT if on else 0.0


## The riding pose, shared by the local player and the puppets: the kid
## SITS — legs bent forward over the horse's sides, hands low on the
## reins — and the horse does the walking, legs swinging with the speed.
func _pose_riding(delta: float, speed: float) -> void:
	# Legs bend FORWARD over the horse's sides (positive rotation swings
	# the downward leg toward the facing direction, -Z).
	for i in 2:
		_legs[i].rotation.x = lerpf(_legs[i].rotation.x, 1.3, 0.3)
		_arms[i].rotation.x = lerpf(_arms[i].rotation.x, 0.55, 0.25)
	if _mount_root == null:
		return
	if _model:
		_mount_root.rotation.y = _model.rotation.y
	_mount_amp = lerpf(_mount_amp, 0.5 if speed > 0.5 else 0.0, 1.0 - exp(-8.0 * delta))
	if speed > 0.5:
		_mount_phase += delta * speed * 2.1
	for j in _mount_legs.size():
		var off := 0.0 if j == 0 or j == 3 else PI
		_mount_legs[j].rotation.x = sin(_mount_phase + off) * _mount_amp
	_mount_root.position.y = absf(sin(_mount_phase)) * 0.09 * (_mount_amp / 0.5) if _mount_amp > 0.01 else 0.0
	if _mount_tail:
		_mount_tail.rotation.y = sin(Time.get_ticks_msec() * 0.004) * 0.25


func _build_mount_horse() -> Node3D:
	var horse := Node3D.new()
	var brown := Color(0.55, 0.38, 0.22)
	var dark := Color(0.3, 0.2, 0.12)
	U.mesh_box(horse, Vector3(0.56, 0.58, 1.6), Vector3(0, 0.8, 0), brown)
	var neck := Node3D.new()
	neck.position = Vector3(0, 1.02, -0.8)
	neck.rotation.x = 0.6
	horse.add_child(neck)
	U.mesh_box(neck, Vector3(0.3, 0.62, 0.3), Vector3(0, 0.26, 0), brown)
	U.mesh_box(neck, Vector3(0.34, 0.56, 0.1), Vector3(0, 0.28, 0.14), dark)
	U.mesh_box(horse, Vector3(0.52, 0.26, 0.28), Vector3(0, 1.44, -1.12), brown)
	U.mesh_box(horse, Vector3(0.3, 0.2, 0.22), Vector3(0, 1.36, -1.3), brown.lightened(0.12))
	U.mesh_box(horse, Vector3(0.09, 0.18, 0.05), Vector3(-0.14, 1.62, -1.04), brown)
	U.mesh_box(horse, Vector3(0.09, 0.18, 0.05), Vector3(0.14, 1.62, -1.04), brown)
	_mount_legs.clear()
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var pivot := Node3D.new()
			pivot.position = Vector3(0.19 * sx, 0.55, 0.58 * sz)
			horse.add_child(pivot)
			U.mesh_cylinder(pivot, 0.06, 0.55, Vector3(0, -0.27, 0), brown.darkened(0.15))
			_mount_legs.append(pivot)
	_mount_tail = Node3D.new()
	_mount_tail.position = Vector3(0, 1.05, 0.8)
	_mount_tail.rotation.x = -0.5
	horse.add_child(_mount_tail)
	U.mesh_box(_mount_tail, Vector3(0.12, 0.55, 0.12), Vector3(0, -0.26, 0), dark)
	return horse


func _build_model() -> void:
	_model = Node3D.new()
	add_child(_model)
	for side: float in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(0.15 * side, 0.75, 0)
		_model.add_child(leg)
		U.mesh_box(leg, Vector3(0.26, 0.75, 0.3), Vector3(0, -0.375, 0), PANTS)
		_legs.append(leg)
		var arm := Node3D.new()
		arm.position = Vector3(0.43 * side, 1.32, 0)
		_model.add_child(arm)
		U.mesh_box(arm, Vector3(0.22, 0.62, 0.26), Vector3(0, -0.28, 0), skin_color)
		_arms.append(arm)
	U.mesh_box(_model, Vector3(0.62, 0.62, 0.36), Vector3(0, 1.06, 0), shirt_color)
	var head := U.mesh_box(_model, Vector3(0.5, 0.5, 0.5), Vector3(0, 1.64, 0), skin_color)
	# Face looks toward -Z, which is "forward" in Godot.
	_build_face(head)
	_build_hair(head)
	_hat_root = Node3D.new()
	_hat_root.position.y = 0.25  # top of the head
	head.add_child(_hat_root)


## The face: two eyes and a mouth as flat boxes on the -Z side of the head.
## Which boxes you get depends on the picked expression.
func _build_face(head: MeshInstance3D) -> void:
	var dark := Color(0.08, 0.06, 0.08)
	var mouth_c := Color(0.5, 0.12, 0.12)
	var z := -0.255
	match face_style:
		1:  # Gembira: happy squint eyes and a big open grin.
			U.mesh_box(head, Vector3(0.13, 0.05, 0.02), Vector3(-0.11, 0.06, z), dark)
			U.mesh_box(head, Vector3(0.13, 0.05, 0.02), Vector3(0.11, 0.06, z), dark)
			U.mesh_box(head, Vector3(0.24, 0.16, 0.02), Vector3(0, -0.12, z), mouth_c)
		2:  # Biasa: plain dots and a straight little mouth.
			U.mesh_box(head, Vector3(0.07, 0.1, 0.02), Vector3(-0.11, 0.05, z), dark)
			U.mesh_box(head, Vector3(0.07, 0.1, 0.02), Vector3(0.11, 0.05, z), dark)
			U.mesh_box(head, Vector3(0.14, 0.03, 0.02), Vector3(0, -0.11, z), mouth_c)
		3:  # Terkejut: big eyes and a small round mouth.
			U.mesh_box(head, Vector3(0.13, 0.17, 0.02), Vector3(-0.11, 0.06, z), dark)
			U.mesh_box(head, Vector3(0.13, 0.17, 0.02), Vector3(0.11, 0.06, z), dark)
			U.mesh_box(head, Vector3(0.1, 0.12, 0.02), Vector3(0, -0.13, z), mouth_c)
		4:  # Ngantuk: closed eyes and a tiny yawn.
			U.mesh_box(head, Vector3(0.13, 0.03, 0.02), Vector3(-0.11, 0.05, z), dark)
			U.mesh_box(head, Vector3(0.13, 0.03, 0.02), Vector3(0.11, 0.05, z), dark)
			U.mesh_box(head, Vector3(0.1, 0.09, 0.02), Vector3(0, -0.12, z), mouth_c)
		5:  # Kedip: one eye open, one eye winking, and a smile.
			U.mesh_box(head, Vector3(0.08, 0.12, 0.02), Vector3(-0.11, 0.05, z), dark)
			U.mesh_box(head, Vector3(0.13, 0.03, 0.02), Vector3(0.11, 0.05, z), dark)
			_smile(head, mouth_c, z)
		_:  # Senyum: the friendly default.
			U.mesh_box(head, Vector3(0.08, 0.12, 0.02), Vector3(-0.11, 0.05, z), dark)
			U.mesh_box(head, Vector3(0.08, 0.12, 0.02), Vector3(0.11, 0.05, z), dark)
			_smile(head, mouth_c, z)


## A smile from three boxes: a middle bar and two ends tipped up.
func _smile(head: MeshInstance3D, c: Color, z: float) -> void:
	U.mesh_box(head, Vector3(0.16, 0.05, 0.02), Vector3(0, -0.13, z), c)
	for side: float in [-1.0, 1.0]:
		var end := U.mesh_box(head, Vector3(0.05, 0.09, 0.02), Vector3(0.1 * side, -0.1, z), c)
		end.rotation.z = 0.5 * side


## Hair (or a hijab) as boxes on the head. The face side is -Z and stays open,
## so a hijab wraps the top, back and sides and drapes over the shoulders.
func _build_hair(head: MeshInstance3D) -> void:
	if wear_hijab:
		var c := hijab_color
		U.mesh_box(head, Vector3(0.56, 0.18, 0.56), Vector3(0, 0.24, 0), c)
		U.mesh_box(head, Vector3(0.56, 0.72, 0.14), Vector3(0, -0.08, 0.24), c)
		for side: float in [-1.0, 1.0]:
			U.mesh_box(head, Vector3(0.13, 0.58, 0.52), Vector3(0.245 * side, -0.02, 0), c)
		# The drape over the shoulders hangs from the model, not the head.
		U.mesh_box(_model, Vector3(0.74, 0.42, 0.62), Vector3(0, 1.24, 0.04), c)
		return
	var c := hair_color
	match hair_style:
		1:  # Pendek: a neat cap and a short back.
			U.mesh_box(head, Vector3(0.54, 0.14, 0.54), Vector3(0, 0.23, 0), c)
			U.mesh_box(head, Vector3(0.54, 0.3, 0.1), Vector3(0, 0.08, 0.24), c)
		2:  # Jabrik: a cap plus three spikes.
			U.mesh_box(head, Vector3(0.54, 0.12, 0.54), Vector3(0, 0.23, 0), c)
			for i in 3:
				var spike := U.mesh_box(head, Vector3(0.13, 0.26, 0.13), Vector3(-0.16 + 0.16 * i, 0.38, 0), c)
				spike.rotation.z = -0.25 + 0.25 * i
		3:  # Panjang: over the top, down the back and both sides.
			U.mesh_box(head, Vector3(0.54, 0.14, 0.54), Vector3(0, 0.23, 0), c)
			U.mesh_box(head, Vector3(0.54, 0.68, 0.12), Vector3(0, -0.06, 0.24), c)
			for side: float in [-1.0, 1.0]:
				U.mesh_box(head, Vector3(0.11, 0.52, 0.44), Vector3(0.24 * side, -0.03, 0), c)


func _build_camera() -> void:
	_cam_rig = Node3D.new()
	_cam_rig.top_level = true
	add_child(_cam_rig)
	_cam_pitch_node = Node3D.new()
	_cam_rig.add_child(_cam_pitch_node)
	var arm := SpringArm3D.new()
	arm.spring_length = CAM_DISTANCE
	arm.margin = 0.3
	arm.add_excluded_object(get_rid())
	arm.collision_mask = 1
	_cam_pitch_node.add_child(arm)
	var cam := Camera3D.new()
	cam.fov = 70
	cam.far = 200
	cam.current = true
	arm.add_child(cam)
	_cam_rig.global_position = global_position + Vector3.UP * 1.2


func _build_shadow() -> void:
	_shadow = U.mesh_cylinder(self, 0.45, 0.02, Vector3.ZERO, Color(0, 0, 0, 0.35))
	_shadow.top_level = true


func _read_move() -> Vector2:
	var v := Vector2.ZERO
	if ui:
		v = ui.move_vector
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): v.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): v.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): v.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): v.y += 1
	return v.limit_length(1.0)


func _read_jump() -> bool:
	return (ui != null and ui.jump_down) or Input.is_key_pressed(KEY_SPACE)


func _physics_process(delta: float) -> void:
	if is_remote:
		return  # Puppets are placed by _update_puppet, not by physics.
	_seat_cooldown -= delta
	_kick_cooldown -= delta
	_float_cooldown -= delta
	_find_seat()
	if _seat:
		_ride_seat()
		return
	if _float:
		_ride_float()
		return
	if swim:
		# Paddle around at water height; the ramps and banks are left to
		# normal physics once main turns swim off over them.
		var sinput := _read_move()
		var swish := Vector3(sinput.x, 0, sinput.y).rotated(Vector3.UP, _cam_yaw)
		var sflat := Vector3(velocity.x, 0, velocity.z)
		sflat = sflat.move_toward(swish * WALK_SPEED * 0.55 * move_scale, 26.0 * delta)
		velocity.x = sflat.x
		velocity.z = sflat.z
		velocity.y = 0.0
		move_and_slide()
		global_position.y = lerpf(global_position.y, swim_y, 1.0 - exp(-6.0 * delta))
		_update_shadow()
		return
	var input := _read_move()
	var wish := Vector3(input.x, 0, input.y).rotated(Vector3.UP, _cam_yaw)
	var on_floor := is_on_floor()
	var on_slide := on_floor and _floor_obj != null and _floor_obj.has_meta("slide")
	if on_slide and not _was_on_slide:
		_sfx("slide", -2.0)
	_was_on_slide = on_slide

	_air_time = 0.0 if on_floor else _air_time + delta
	if _climb(wish):
		move_and_slide()
		_after_move()
		_update_shadow()
		return
	if not on_floor:
		velocity.y -= GRAVITY * delta

	if on_slide:
		var n := get_floor_normal()
		var downhill := (Vector3.DOWN - n * n.dot(Vector3.DOWN)).normalized()
		velocity += downhill * SLIDE_ACCEL * delta + wish * 3.0 * delta
		velocity = velocity.limit_length(SLIDE_MAX_SPEED)
	else:
		var flat := Vector3(velocity.x, 0, velocity.z)
		var accel := 40.0 if on_floor else 14.0
		if on_floor and wish == Vector3.ZERO:
			accel = 18.0
		flat = flat.move_toward(wish * WALK_SPEED * move_scale, accel * delta)
		velocity.x = flat.x
		velocity.z = flat.z

	# Holding the jump button keeps jumping. Easy for small hands.
	if _read_jump() and _air_time < COYOTE_TIME and velocity.y <= 0.5:
		velocity.y = JUMP_SPEED
		_air_time = COYOTE_TIME
		_sfx("jump", -4.0)

	var fall_speed := -velocity.y
	move_and_slide()
	var bounced := _after_move()
	if not bounced and not on_floor and is_on_floor() and fall_speed > 6.0:
		_sfx("land", -6.0)
	_update_shadow()

	if global_position.y < kill_y:
		respawn(fall_sound)


## Push the joystick toward a climbing wall (or hold jump) to climb up. Let go and you hang
## on; push away and you drop off. At the top edge you get a little hop onto the floor.
## Returns true while climbing.
func _climb(wish: Vector3) -> bool:
	if _wall_normal == Vector3.ZERO:
		if _climbing:
			_climbing = false
			# We just went past the top edge: hop over it.
			if velocity.y > 0.0:
				velocity = Vector3.UP * 4.0 - _last_wall_normal * 3.0
				_air_time = COYOTE_TIME
		return false
	var into := wish.dot(-_wall_normal)
	var up := into > 0.3 or _read_jump()
	if into < -0.3 or (is_on_floor() and not up):
		_climbing = false
		return false
	if not _climbing:
		_sfx("sit", -6.0)
	_climbing = true
	_last_wall_normal = _wall_normal
	var sideways := wish + _wall_normal * into
	# Lean into the wall a little, so we keep touching it.
	velocity = Vector3.UP * (CLIMB_SPEED if up else 0.0) + sideways * 2.0 - _wall_normal
	_air_time = COYOTE_TIME
	return true


## Walk into a swing seat (or land on it) to sit down. No need to jump right on top.
func _find_seat() -> void:
	if _seat or _float or _seat_cooldown > 0.0:
		return
	if _last_seat and is_instance_valid(_last_seat):
		if _flat_distance(_last_seat.global_position) < 1.8:
			return
		_last_seat = null
	for seat: Node3D in get_tree().get_nodes_in_group("seats"):
		if not seat.is_visible_in_tree():
			continue
		var dy := global_position.y - seat.global_position.y
		if _flat_distance(seat.global_position) < 1.2 and dy > -1.2 and dy < 1.0:
			_seat = seat
			_wait_release = _read_jump()
			_sfx("sit")
			return


func _flat_distance(p: Vector3) -> float:
	return Vector2(global_position.x - p.x, global_position.z - p.z).length()


## Sit still on the swing seat and move with it. Jump to get off.
func _ride_seat() -> void:
	# The hips (top of the legs, 0.75 above the feet) rest on top of the seat.
	global_position = _seat.global_position + _seat.global_basis.y * (0.075 - 0.75)
	velocity = Vector3.ZERO
	_update_shadow()
	if not _read_jump():
		_wait_release = false
	elif not _wait_release:
		var forward := _seat.global_basis.z * -1.0
		velocity = Vector3.UP * JUMP_SPEED + forward * 3.0
		# Start from the front of the seat, clear of it.
		global_position = _seat.global_position + Vector3.UP * 0.2 + forward * 0.7
		_last_seat = _seat
		_seat = null
		_seat_cooldown = 0.5
		_air_time = COYOTE_TIME
		_model.rotation.x = 0.0
		_sfx("jump", -4.0)


## Sit in the swim ring. The joystick paddles it around; jump to get out.
func _ride_float() -> void:
	var input := _read_move()
	_float.paddle(Vector3(input.x, 0, input.y).rotated(Vector3.UP, _cam_yaw))
	# Sit low, so the legs are in the water and the body pokes out of the ring.
	global_position = _float.global_position + Vector3.DOWN * 0.7
	velocity = Vector3.ZERO
	_update_shadow()
	if not _read_jump():
		_wait_release = false
	elif not _wait_release:
		var forward := _float.global_basis.z * -1.0
		_float.push_off(forward)
		_leave_float()
		# Start from the front edge, so you land in the water and not back in the ring.
		global_position += Vector3.UP * 1.1 + forward * 1.0
		velocity = Vector3.UP * JUMP_SPEED + forward * 4.0
		_air_time = COYOTE_TIME
		_sfx("jump", -4.0)


func _leave_float() -> void:
	if _float == null:
		return
	if is_instance_valid(_float):
		_float.ridden = false
	_float = null
	_float_cooldown = 0.8


## Handles what we touched. Returns true if we bounced on a trampoline.
func _after_move() -> bool:
	var bounced := false
	_wall_normal = Vector3.ZERO
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var obj := c.get_collider()
		if obj == null:
			continue
		var n := c.get_normal()
		if absf(n.y) < 0.5 and obj.has_meta("climb"):
			_wall_normal = Vector3(n.x, 0, n.z).normalized()
		if n.y > 0.6 and obj.has_meta("float") and _float_cooldown <= 0.0 and _float == null:
			_float = obj
			_float.ridden = true
			_wait_release = _read_jump()
			_sfx("splash", -8.0)
		if n.y > 0.6:
			if obj.has_meta("bounce"):
				var power: float = obj.get_meta("bounce")
				if _read_jump():
					power *= 1.15
				velocity.y = power
				_squash = 1.0
				_air_time = COYOTE_TIME
				if not bounced:
					_sfx("boing", 0.0, 1.25 - power * 0.025)  # bigger bounce, deeper boing
				bounced = true
		if obj is RigidBody3D:
			var push := -n
			push.y = 0.3
			obj.apply_central_impulse(push * 1.2)
			if _kick_cooldown <= 0.0:
				_sfx("kick", -3.0)
				_kick_cooldown = 0.3
	return bounced


func _process(delta: float) -> void:
	if is_remote:
		_update_puppet(delta)
		return
	_update_camera(delta)
	_update_model(delta)
	if peer_id != 0:
		_net_timer -= delta
		if _net_timer <= 0.0:
			_net_timer = NET_SEND_EVERY
			rpc("_receive_state", global_position, _model.rotation.y,
				Vector3(velocity.x, 0, velocity.z).length(), _state_code())


## What the body is doing, as a small number the puppets can pose with:
## 0 walking/standing, 1 on a swing, 2 in a swim ring, 3 climbing, 4 in the
## air, 5 on a slide.
func _state_code() -> int:
	if swim:
		return 6
	if _seat:
		return 1
	if _float:
		return 2
	if _climbing:
		return 3
	if _was_on_slide:
		return 5
	if not is_on_floor():
		return 4
	return 0


## Sent by the phone that owns this player, about 20 times a second.
@rpc("any_peer", "unreliable")
func _receive_state(pos: Vector3, yaw: float, speed: float, state: int) -> void:
	if not is_remote or multiplayer.get_remote_sender_id() != peer_id:
		return
	if not _net_started:
		_net_started = true
		global_position = pos
	_net_pos = pos
	_net_yaw = yaw
	_net_speed = speed
	_net_state = state


## Sent by the owning phone when a game starts and when the look changes.
@rpc("any_peer", "reliable")
func _receive_profile(d: Dictionary) -> void:
	if not is_remote or multiplayer.get_remote_sender_id() != peer_id:
		return
	apply_profile(d)
	print("NET: profile from peer ", peer_id, ": name=", player_name, " gender=", gender, " hat=", hat)


## Move and pose a puppet toward the last place its owner sent.
func _update_puppet(delta: float) -> void:
	if _net_started:
		if global_position.distance_to(_net_pos) > 6.0:
			global_position = _net_pos  # teleported (fell and respawned): snap
		else:
			global_position = global_position.lerp(_net_pos, 1.0 - exp(-14.0 * delta))
		_model.rotation.y = lerp_angle(_model.rotation.y, _net_yaw, 1.0 - exp(-14.0 * delta))
	if mount:
		_pose_riding(delta, _net_speed)
		_update_shadow()
		return
	var leg_swing := 0.0
	var arm_angle := 0.0
	match _net_state:
		6:  # swimming in the river: sweeping arms, kicking legs
			_walk_time += delta * 5.0
			leg_swing = sin(_walk_time) * 0.4
			arm_angle = 1.1 + sin(_walk_time) * 0.45
		1:  # on a swing: legs forward, hands on the ropes
			leg_swing = -1.4
			arm_angle = -2.9
		2:  # in a swim ring
			leg_swing = -1.3
			arm_angle = -0.9
		3, 4, 5:  # climbing, flying or sliding: arms up
			arm_angle = -2.6
			leg_swing = 0.35 if _net_state == 4 else 0.0
		_:
			if _net_speed > 0.5:
				_walk_time += delta * _net_speed * 1.8
				leg_swing = sin(_walk_time) * 0.7
	for i in 2:
		var s := 1.0 if i == 0 else -1.0
		_legs[i].rotation.x = lerpf(_legs[i].rotation.x, leg_swing * s, 0.3)
		var arm_target := arm_angle if arm_angle != 0.0 else -leg_swing * s
		_arms[i].rotation.x = lerpf(_arms[i].rotation.x, arm_target, 0.25)
	_update_shadow()


func _update_camera(delta: float) -> void:
	if ui:
		var look: Vector2 = ui.consume_look()
		_cam_yaw -= look.x * 0.008
		_cam_pitch = clampf(_cam_pitch - look.y * 0.006, -1.2, 0.25)
	# While sliding fast, turn the camera to look where we go, so spirals are not confusing.
	var on_slide := is_on_floor() and _floor_obj != null and _floor_obj.has_meta("slide")
	var flat := Vector3(velocity.x, 0, velocity.z)
	if on_slide and flat.length() > 3.0:
		_cam_yaw = lerp_angle(_cam_yaw, atan2(-flat.x, -flat.z), 1.0 - exp(-4.0 * delta))
	if Input.is_key_pressed(KEY_Q): _cam_yaw += 2.0 * delta
	if Input.is_key_pressed(KEY_E): _cam_yaw -= 2.0 * delta
	var target := global_position + Vector3.UP * 1.3
	_cam_rig.global_position = _cam_rig.global_position.lerp(target, 1.0 - exp(-10.0 * delta))
	_cam_rig.rotation = Vector3(0, _cam_yaw, 0)
	_cam_pitch_node.rotation.x = _cam_pitch


func _update_model(delta: float) -> void:
	var flat := Vector3(velocity.x, 0, velocity.z)
	var speed := flat.length()
	if speed > 0.5:
		var target_yaw := atan2(-flat.x, -flat.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, 1.0 - exp(-12.0 * delta))

	var leg_swing := 0.0
	var arm_angle := 0.0
	var on_slide := _floor_obj != null and _floor_obj.has_meta("slide")
	if _seat:
		_model.rotation.y = _seat.global_rotation.y
		_model.rotation.x = _seat.global_rotation.x  # swing back and forth with the seat
		arm_angle = -2.9  # hold the ropes
		leg_swing = -1.4  # legs forward, like sitting
		for i in 2:
			_legs[i].rotation.x = lerpf(_legs[i].rotation.x, leg_swing, 0.3)
			_arms[i].rotation.x = lerpf(_arms[i].rotation.x, arm_angle, 0.3)
		return
	if _float:
		_model.rotation.y = _float.global_rotation.y
		for i in 2:
			_legs[i].rotation.x = lerpf(_legs[i].rotation.x, -1.3, 0.3)  # legs forward, in the water
			_arms[i].rotation.x = lerpf(_arms[i].rotation.x, -0.9, 0.3)  # arms on the ring
		return
	if _climbing:
		# Face the wall and reach up, one hand after the other.
		_model.rotation.y = atan2(_last_wall_normal.x, _last_wall_normal.z)
		_walk_time += delta * absf(velocity.y) * 2.5
		for i in 2:
			var s := 1.0 if i == 0 else -1.0
			_arms[i].rotation.x = lerpf(_arms[i].rotation.x, -2.6 + sin(_walk_time) * 0.5 * s, 0.3)
			_legs[i].rotation.x = lerpf(_legs[i].rotation.x, -0.4 - sin(_walk_time) * 0.4 * s, 0.3)
		return
	if swim:
		_walk_time += delta * (3.0 + speed * 0.7)
		_model.rotation.x = lerpf(_model.rotation.x, 0.16, 0.2)
		for i in 2:
			var s := 1.0 if i == 0 else -1.0
			_arms[i].rotation.x = lerpf(_arms[i].rotation.x, 1.15 + sin(_walk_time * 2.0) * 0.5 * s, 0.3)
			_legs[i].rotation.x = lerpf(_legs[i].rotation.x, sin(_walk_time * 2.0 + (0.0 if i == 0 else PI)) * 0.4, 0.3)
		return
	if mount:
		_pose_riding(delta, speed)
		return
	if on_slide or not is_on_floor():
		arm_angle = -2.6  # arms up: wheee!
		leg_swing = 0.0 if on_slide else 0.35
	elif speed > 0.5:
		_walk_time += delta * speed * 1.8
		leg_swing = sin(_walk_time) * 0.7
	_model.rotation.x = lerpf(_model.rotation.x, 0.0, 0.25)
	for i in 2:
		var s := 1.0 if i == 0 else -1.0
		_legs[i].rotation.x = lerpf(_legs[i].rotation.x, leg_swing * s, 0.3)
		var arm_target := arm_angle if arm_angle != 0.0 else -leg_swing * s
		_arms[i].rotation.x = lerpf(_arms[i].rotation.x, arm_target, 0.25)

	_squash = move_toward(_squash, 0.0, delta * 4.0)
	var q := sin(_squash * PI) * 0.3
	_model.scale = Vector3(1.0 + q, 1.0 - q, 1.0 + q)


func _update_shadow() -> void:
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.5, global_position + Vector3.DOWN * 40)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	_shadow.visible = not hit.is_empty()
	_floor_obj = null
	if not hit.is_empty():
		if hit["position"].distance_to(global_position) < 0.3:
			_floor_obj = hit["collider"]
		_shadow.global_position = hit["position"] + Vector3.UP * 0.02
