extends Control
## The menu: opened with the menu button at the top. It pauses the game and
## offers big touch buttons in two columns, so every page fits the screen
## without scrolling. Pages: the main page, Tentang (about), Karakter
## (name, gender, colours, hair, hijab and face — the look is saved on
## this phone and shared with the other players in a WLAN game) and Main
## Berdua (host or join a game on the same WiFi, find a host with the
## scan button, and start a running race). On a phone that has no
## character yet, the game opens straight on the Karakter page.

const PlayerScript := preload("res://scripts/player.gd")

const BG := Color(0.1, 0.15, 0.3, 0.6)
const CARD := Color(1, 1, 1, 0.95)
const TEXT := Color(0.2, 0.2, 0.3)
const GREEN := Color(0.35, 0.75, 0.3)
const BLUE := Color(0.3, 0.65, 0.95)
const RED := Color(0.9, 0.35, 0.3)
const PINK := Color(0.95, 0.45, 0.75)
const PURPLE := Color(0.55, 0.4, 0.9)
const ORANGE := Color(1.0, 0.6, 0.15)

signal host_pressed
signal join_pressed(ip: String)
signal leave_pressed
signal scan_pressed
signal race_pressed
signal profile_changed(profile: Dictionary)

var _main_box: VBoxContainer
var _about_box: VBoxContainer
var _char_box: VBoxContainer
var _net_box: VBoxContainer

## The character being edited (a player.gd profile_dict). Set from main.gd;
## every change goes back up through profile_changed so main can apply it to
## the player, save it, and share it with the other phones.
var _profile: Dictionary = {}

## True while the first-run character setup is showing: its Kembali button
## starts the game instead of going to the main page.
var _onboarding := false
## True while a WLAN session is running; the join controls hide then.
var _in_session := false

var _name_edit: LineEdit
var _boy_button: Button
var _girl_button: Button
var _skin_grid: GridContainer
var _shirt_grid: GridContainer
var _hair_section: VBoxContainer
var _hair_grid: GridContainer
var _hair_color_grid: GridContainer
var _face_grid: GridContainer
var _hijab_button: Button
var _hijab_color_box: VBoxContainer
var _hijab_color_grid: GridContainer

var _net_status: Label
var _join_section: VBoxContainer
var _ip_edit: LineEdit
var _scan_status: Label
var _scan_box: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var dim := ColorRect.new()
	dim.color = BG
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = CARD
	style.set_corner_radius_all(28)
	style.set_content_margin_all(24)
	card.add_theme_stylebox_override("panel", style)
	center.add_child(card)
	var pages := VBoxContainer.new()
	card.add_child(pages)

	_main_box = _page(pages)
	_label(_main_box, "Menu", 40)
	var main_grid := _grid2(_main_box)
	_button(main_grid, "Main lagi", GREEN, close, Vector2(250, 92), 32)
	_button(main_grid, "Tentang", BLUE, _show_about, Vector2(250, 92), 32)
	_button(main_grid, "Karakter", PURPLE, _show_char, Vector2(250, 92), 32)
	_button(main_grid, "Main Berdua", ORANGE, _show_net, Vector2(250, 92), 32)
	_button(main_grid, "Keluar", RED, func(): get_tree().quit(), Vector2(250, 92), 32)

	_about_box = _page(pages)
	_label(_about_box, "JumpBox", 40)
	_label(_about_box, "Versi " + str(ProjectSettings.get_setting("application/config/version", "?")), 26)
	_label(_about_box, "Main tanpa internet, gratis.", 26)
	_label(_about_box, "Dibuat oleh Yusuf\nThreads: @yusufmalikul", 30)
	_label(_about_box, "Modifikasi oleh @iz_ddin", 26)
	_label(_about_box, "Dibuat dengan Godot Engine (lisensi MIT).", 20)
	_button(_about_box, "Kembali", BLUE, _show_main, Vector2(512, 68), 30)

	_build_char_page(pages)
	_build_net_page(pages)
	_show_main()


func _build_char_page(pages: VBoxContainer) -> void:
	_char_box = _page(pages)
	_char_box.add_theme_constant_override("separation", 10)
	_label(_char_box, "Karakter", 40)
	_label(_char_box, "Tulis namamu dan pilih gayamu!", 22)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	_char_box.add_child(cols)

	var left := _column(cols)
	_label(left, "Nama", 22)
	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size = Vector2(296, 56)
	_name_edit.add_theme_font_size_override("font_size", 30)
	_name_edit.placeholder_text = "Tulis namamu"
	_name_edit.max_length = 16
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(_name_edit)
	_name_edit.text_submitted.connect(func(_t: String): _commit_name())
	_name_edit.focus_exited.connect(_commit_name)
	var grow := _row(left)
	_boy_button = _button(grow, "Laki-laki", BLUE, func(): _set_gender("boy"), Vector2(142, 58), 24)
	_girl_button = _button(grow, "Perempuan", PINK, func(): _set_gender("girl"), Vector2(142, 58), 24)
	_label(left, "Warna Kulit", 22)
	_skin_grid = _grid(left, 6)
	_label(left, "Warna Baju", 22)
	_shirt_grid = _grid(left, 5)

	var right := _column(cols)
	_hair_section = _column(right, false)
	_label(_hair_section, "Rambut", 22)
	_hair_grid = _grid(_hair_section, 2)
	_label(_hair_section, "Warna Rambut", 22)
	_hair_color_grid = _grid(_hair_section, 6)
	_label(right, "Ekspresi Wajah", 22)
	_face_grid = _grid(right, 3)
	_hijab_button = _button(right, "Jilbab: Tidak", PURPLE, _toggle_hijab, Vector2(296, 56), 25)
	_hijab_color_box = VBoxContainer.new()
	_hijab_color_box.add_theme_constant_override("separation", 10)
	right.add_child(_hijab_color_box)
	_label(_hijab_color_box, "Warna Jilbab", 22)
	_hijab_color_grid = _grid(_hijab_color_box, 4)

	_button(_char_box, "Kembali", BLUE, func():
		_commit_name()
		if _onboarding:
			_onboarding = false
			close()
		else:
			_show_main(), Vector2(612, 72), 30)


func _build_net_page(pages: VBoxContainer) -> void:
	_net_box = _page(pages)
	_net_box.add_theme_constant_override("separation", 8)
	_label(_net_box, "Main Berdua", 36)
	_net_status = _label(_net_box, "Tidak terhubung. Main sendiri.", 22)
	_net_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_net_status.custom_minimum_size = Vector2(480, 0)
	_join_section = VBoxContainer.new()
	_join_section.add_theme_constant_override("separation", 8)
	_net_box.add_child(_join_section)
	var join_grid := _grid2(_join_section)
	_button(join_grid, "Jadi Tuan Rumah", GREEN, func(): host_pressed.emit(), Vector2(250, 68), 28)
	_button(join_grid, "Cari Tuan Rumah", BLUE, func(): scan_pressed.emit(), Vector2(250, 68), 28)
	_scan_status = _label(_join_section, "", 20)
	_scan_box = VBoxContainer.new()
	_scan_box.add_theme_constant_override("separation", 6)
	_join_section.add_child(_scan_box)
	_ip_edit = LineEdit.new()
	_ip_edit.custom_minimum_size = Vector2(512, 52)
	_ip_edit.add_theme_font_size_override("font_size", 30)
	_ip_edit.placeholder_text = "atau ketik alamat: 192.168.1.5"
	_ip_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_join_section.add_child(_ip_edit)
	_button(_join_section, "Gabung", BLUE, func(): join_pressed.emit(_ip_edit.text), Vector2(512, 64), 28)
	var play_grid := _grid2(_net_box)
	_button(play_grid, "Balap Lari", ORANGE, func():
		race_pressed.emit()
		if _in_session:
			close(), Vector2(250, 68), 28)
	_button(play_grid, "Putuskan", RED, func(): leave_pressed.emit(), Vector2(250, 68), 28)
	_button(_net_box, "Kembali", BLUE, _show_main, Vector2(512, 68), 30)


func open() -> void:
	_show_main()
	visible = true
	get_tree().paused = true


## First run: land on the character page so the kid makes their character
## before anything else. Kembali there starts the game.
func open_onboarding() -> void:
	_onboarding = true
	_show_char()
	visible = true
	get_tree().paused = true


func close() -> void:
	visible = false
	get_tree().paused = false


## Called from main.gd with the player's current look.
func set_profile(d: Dictionary) -> void:
	_profile = d.duplicate()
	if _name_edit:
		_name_edit.text = str(_profile.get("name", ""))
	_refresh_char()


## Called from main.gd when the WLAN session state changes.
func set_net_status(text: String) -> void:
	if _net_status:
		_net_status.text = text


## While connected, the host/scan/typing controls hide: the page then only
## offers the race, disconnecting, and going back.
func set_in_session(active: bool) -> void:
	_in_session = active
	if _join_section:
		_join_section.visible = not active


func set_join_ip(ip: String) -> void:
	if _ip_edit:
		_ip_edit.text = ip


## Called from main.gd while a host scan runs and when it finds someone.
func set_scan_status(text: String) -> void:
	if _scan_status:
		_scan_status.text = text


## The hosts a scan found, as {ip: name}. Each becomes a join button.
func set_scan_results(found: Dictionary) -> void:
	if _scan_box == null:
		return
	for child in _scan_box.get_children():
		_scan_box.remove_child(child)
		child.queue_free()
	for ip in found:
		_button(_scan_box, "Gabung ke %s (%s)" % [str(found[ip]), ip], GREEN, _on_scan_pick.bind(ip), Vector2(512, 46), 22)


func _on_scan_pick(ip: String) -> void:
	join_pressed.emit(ip)


func _emit_profile() -> void:
	profile_changed.emit(_profile.duplicate())


func _pick(key: String, value: Variant) -> void:
	_profile[key] = value
	_emit_profile()
	_refresh_char()


func _set_gender(g: String) -> void:
	if str(_profile.get("gender", "boy")) == g:
		return
	_profile["gender"] = g
	# A fresh start for the hair: short for boys, long for girls. It can
	# still be changed right below.
	_profile["hair_style"] = 1 if g == "boy" else 3
	_emit_profile()
	_refresh_char()


func _toggle_hijab() -> void:
	_profile["hijab"] = not bool(_profile.get("hijab", false))
	_emit_profile()
	_refresh_char()


func _commit_name() -> void:
	if _profile.is_empty() or _name_edit == null:
		return
	var n := _name_edit.text.strip_edges()
	if n != str(_profile.get("name", "")):
		_profile["name"] = n
		_emit_profile()


func _refresh_char() -> void:
	if _profile.is_empty() or _skin_grid == null:
		return
	var gender := str(_profile.get("gender", "boy"))
	_boy_button.text = ("✓ " if gender == "boy" else "") + "Laki-laki"
	_girl_button.text = ("✓ " if gender == "girl" else "") + "Perempuan"
	_fill_swatches(_skin_grid, PlayerScript.SKIN_TONES,
		_nearest(PlayerScript.SKIN_TONES, _profile.get("skin", PlayerScript.SKIN)),
		func(i: int): _pick("skin", PlayerScript.SKIN_TONES[i]))
	_fill_swatches(_shirt_grid, PlayerScript.SHIRT_COLORS,
		_nearest(PlayerScript.SHIRT_COLORS, _profile.get("shirt", PlayerScript.SHIRT)),
		func(i: int): _pick("shirt", PlayerScript.SHIRT_COLORS[i]))
	_fill_choices(_hair_grid, PlayerScript.HAIR_STYLES, int(_profile.get("hair_style", 1)),
		Vector2(142, 50), 22, func(i: int): _pick("hair_style", i))
	_fill_swatches(_hair_color_grid, PlayerScript.HAIR_COLORS,
		_nearest(PlayerScript.HAIR_COLORS, _profile.get("hair_color", Color(0.12, 0.09, 0.07))),
		func(i: int): _pick("hair_color", PlayerScript.HAIR_COLORS[i]))
	_fill_choices(_face_grid, PlayerScript.FACE_STYLES, int(_profile.get("face", 0)),
		Vector2(93, 50), 19, func(i: int): _pick("face", i))
	_fill_swatches(_hijab_color_grid, PlayerScript.HIJAB_COLORS,
		_nearest(PlayerScript.HIJAB_COLORS, _profile.get("hijab_color", Color(0.95, 0.5, 0.7))),
		func(i: int): _pick("hijab_color", PlayerScript.HIJAB_COLORS[i]))
	var hijab := bool(_profile.get("hijab", false))
	_hijab_button.text = "Jilbab: Dipakai ✓" if hijab else "Jilbab: Tidak"
	_hijab_color_box.visible = hijab
	# A hijab covers the hair, so the hair pickers hide while it is worn.
	_hair_section.visible = not hijab


## The closest entry in a colour palette (saved colours come back from
## settings.cfg slightly rounded, so an exact match is not guaranteed).
func _nearest(colors: Array, c: Color) -> int:
	var best := 0
	var best_d := 1e9
	for i in colors.size():
		var o: Color = colors[i]
		var d := (o.r - c.r) * (o.r - c.r) + (o.g - c.g) * (o.g - c.g) + (o.b - c.b) * (o.b - c.b)
		if d < best_d:
			best_d = d
			best = i
	return best


func _fill_swatches(grid: GridContainer, colors: Array, current: int, on_pick: Callable) -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	for i in colors.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(40, 40)
		for state in ["normal", "hover", "pressed", "focus"]:
			var s := StyleBoxFlat.new()
			s.bg_color = colors[i]
			s.set_corner_radius_all(12)
			if i == current:
				s.set_border_width_all(4)
				s.border_color = Color(0.15, 0.15, 0.2)
			b.add_theme_stylebox_override(state, s)
		b.pressed.connect(on_pick.bind(i))
		grid.add_child(b)


func _fill_choices(grid: GridContainer, names: Array, current: int, min_size: Vector2, font_size: int, on_pick: Callable) -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	for i in names.size():
		var label := ("✓ " if i == current else "") + str(names[i])
		_button(grid, label, BLUE if i == current else Color(0.55, 0.6, 0.7), on_pick.bind(i), min_size, font_size)


func _show_main() -> void:
	_show_only(_main_box)


func _show_about() -> void:
	_show_only(_about_box)


func _show_char() -> void:
	_show_only(_char_box)


func _show_net() -> void:
	_show_only(_net_box)


func _show_only(box: VBoxContainer) -> void:
	for b in [_main_box, _about_box, _char_box, _net_box]:
		b.visible = b == box


func _page(parent: Node) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	return box


## One side of the character page.
func _column(parent: Node, expand := true) -> VBoxContainer:
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", 10)
	if expand:
		c.custom_minimum_size = Vector2(296, 0)
	parent.add_child(c)
	return c


func _row(parent: Node) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 12)
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(r)
	return r


## A two-column grid for the big menu buttons.
func _grid2(parent: Node) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 12)
	g.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(g)
	return g


func _grid(parent: Node, columns: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = columns
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	g.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(g)
	return g


func _label(parent: Node, text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", TEXT)
	parent.add_child(l)
	return l


func _button(parent: Node, text: String, color: Color, action: Callable, min_size := Vector2(420, 96), font_size := 36) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	for state in ["normal", "hover", "pressed", "focus"]:
		var s := StyleBoxFlat.new()
		s.bg_color = color.darkened(0.15) if state == "pressed" else color
		s.set_corner_radius_all(24 if min_size.y < 96.0 else 48)
		b.add_theme_stylebox_override(state, s)
	b.pressed.connect(action)
	parent.add_child(b)
	return b
