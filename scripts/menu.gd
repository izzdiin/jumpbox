extends Control
## The menu: opened with the menu button at the top. It pauses the game and has big
## buttons to go back to playing, to read about the game, and to close the app.
## More pages: Karakter (name, gender, colours, hair, hijab and face — the
## look is saved on this phone and shared with the other players in a WLAN
## game) and Main Berdua (host or join a game on the same WiFi, find a host
## with the scan button, and start a running race). Every page scrolls, so
## the buttons at the bottom can always be reached, even on short screens.

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
var _main_scroll: ScrollContainer
var _about_box: VBoxContainer
var _about_scroll: ScrollContainer
var _char_box: VBoxContainer
var _char_scroll: ScrollContainer
var _net_box: VBoxContainer
var _net_scroll: ScrollContainer

## The character being edited (a player.gd profile_dict). Set from main.gd;
## every change goes back up through profile_changed so main can apply it to
## the player, save it, and share it with the other phones.
var _profile: Dictionary = {}

var _name_edit: LineEdit
var _boy_button: Button
var _girl_button: Button
var _skin_grid: GridContainer
var _shirt_grid: GridContainer
var _hair_grid: GridContainer
var _hair_color_grid: GridContainer
var _face_grid: GridContainer
var _hijab_button: Button
var _hijab_color_box: VBoxContainer
var _hijab_color_grid: GridContainer

var _net_status: Label
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
	style.set_content_margin_all(36)
	card.add_theme_stylebox_override("panel", style)
	center.add_child(card)
	var pages := VBoxContainer.new()
	card.add_child(pages)

	_main_scroll = _scroll(pages)
	_main_box = _page(_main_scroll)
	_label(_main_box, "Menu", 48)
	_button(_main_box, "Main lagi", GREEN, close)
	_button(_main_box, "Tentang", BLUE, _show_about)
	_button(_main_box, "Keluar", RED, func(): get_tree().quit())
	_button(_main_box, "Karakter", PURPLE, _show_char)
	_button(_main_box, "Main Berdua", ORANGE, _show_net)

	_about_scroll = _scroll(pages)
	_about_box = _page(_about_scroll)
	_label(_about_box, "JumpBox", 48)
	_label(_about_box, "Versi " + str(ProjectSettings.get_setting("application/config/version", "?")), 26)
	_label(_about_box, "Main tanpa internet, gratis.", 26)
	_label(_about_box, "Dibuat oleh Yusuf\nThreads: @yusufmalikul", 30)
	_label(_about_box, "Dibuat dengan Godot Engine (lisensi MIT).", 20)
	_button(_about_box, "Kembali", BLUE, _show_main)

	_build_char_page(pages)
	_build_net_page(pages)
	_show_main()


func _build_char_page(pages: VBoxContainer) -> void:
	_char_scroll = _scroll(pages)
	_char_box = _page(_char_scroll)
	_label(_char_box, "Karakter", 40)
	_label(_char_box, "Nama", 24)
	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size = Vector2(420, 72)
	_name_edit.add_theme_font_size_override("font_size", 32)
	_name_edit.placeholder_text = "Tulis namamu"
	_name_edit.max_length = 16
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_char_box.add_child(_name_edit)
	_name_edit.text_submitted.connect(func(_t: String): _commit_name())
	_name_edit.focus_exited.connect(_commit_name)
	var grow := _row(_char_box)
	_boy_button = _button(grow, "Laki-laki", BLUE, func(): _set_gender("boy"), Vector2(204, 84), 28)
	_girl_button = _button(grow, "Perempuan", PINK, func(): _set_gender("girl"), Vector2(204, 84), 28)
	_label(_char_box, "Warna Kulit", 24)
	_skin_grid = _grid(_char_box, 6)
	_label(_char_box, "Warna Baju", 24)
	_shirt_grid = _grid(_char_box, 5)
	_label(_char_box, "Rambut", 24)
	_hair_grid = _grid(_char_box, 2)
	_label(_char_box, "Warna Rambut", 24)
	_hair_color_grid = _grid(_char_box, 6)
	_label(_char_box, "Ekspresi Wajah", 24)
	_face_grid = _grid(_char_box, 3)
	_hijab_button = _button(_char_box, "Jilbab: Tidak", PURPLE, _toggle_hijab)
	_hijab_color_box = VBoxContainer.new()
	_hijab_color_box.add_theme_constant_override("separation", 20)
	_char_box.add_child(_hijab_color_box)
	_label(_hijab_color_box, "Warna Jilbab", 24)
	_hijab_color_grid = _grid(_hijab_color_box, 4)
	_button(_char_box, "Kembali", BLUE, func():
		_commit_name()
		_show_main())


func _build_net_page(pages: VBoxContainer) -> void:
	_net_scroll = _scroll(pages)
	_net_box = _page(_net_scroll)
	_label(_net_box, "Main Berdua", 40)
	_net_status = _label(_net_box, "Tidak terhubung. Main sendiri.", 24)
	_net_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_net_status.custom_minimum_size = Vector2(400, 0)
	_button(_net_box, "Balap Lari", ORANGE, func():
		race_pressed.emit()
		close())
	_button(_net_box, "Jadi Tuan Rumah", GREEN, func(): host_pressed.emit())
	_button(_net_box, "Cari Tuan Rumah", BLUE, func(): scan_pressed.emit())
	_scan_status = _label(_net_box, "", 22)
	_scan_box = VBoxContainer.new()
	_scan_box.add_theme_constant_override("separation", 12)
	_net_box.add_child(_scan_box)
	_label(_net_box, "atau ketik alamat tuan rumah:", 24)
	_ip_edit = LineEdit.new()
	_ip_edit.custom_minimum_size = Vector2(420, 72)
	_ip_edit.add_theme_font_size_override("font_size", 32)
	_ip_edit.placeholder_text = "192.168.1.5"
	_ip_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_net_box.add_child(_ip_edit)
	_button(_net_box, "Gabung", BLUE, func(): join_pressed.emit(_ip_edit.text))
	_button(_net_box, "Putuskan", RED, func(): leave_pressed.emit())
	_button(_net_box, "Kembali", BLUE, _show_main)


func open() -> void:
	_show_main()
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
		_button(_scan_box, "Gabung ke %s (%s)" % [str(found[ip]), ip], GREEN, _on_scan_pick.bind(ip))


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
		Vector2(204, 72), 26, func(i: int): _pick("hair_style", i))
	_fill_swatches(_hair_color_grid, PlayerScript.HAIR_COLORS,
		_nearest(PlayerScript.HAIR_COLORS, _profile.get("hair_color", Color(0.12, 0.09, 0.07))),
		func(i: int): _pick("hair_color", PlayerScript.HAIR_COLORS[i]))
	_fill_choices(_face_grid, PlayerScript.FACE_STYLES, int(_profile.get("face", 0)),
		Vector2(136, 72), 24, func(i: int): _pick("face", i))
	_fill_swatches(_hijab_color_grid, PlayerScript.HIJAB_COLORS,
		_nearest(PlayerScript.HIJAB_COLORS, _profile.get("hijab_color", Color(0.95, 0.5, 0.7))),
		func(i: int): _pick("hijab_color", PlayerScript.HIJAB_COLORS[i]))
	var hijab := bool(_profile.get("hijab", false))
	_hijab_button.text = "Jilbab: Dipakai ✓" if hijab else "Jilbab: Tidak"
	_hijab_color_box.visible = hijab


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
		b.custom_minimum_size = Vector2(56, 56)
		for state in ["normal", "hover", "pressed", "focus"]:
			var s := StyleBoxFlat.new()
			s.bg_color = colors[i]
			s.set_corner_radius_all(16)
			if i == current:
				s.set_border_width_all(5)
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
	_show_only(_main_scroll, _main_box)


func _show_about() -> void:
	_show_only(_about_scroll, _about_box)


func _show_char() -> void:
	_show_only(_char_scroll, _char_box)


func _show_net() -> void:
	_show_only(_net_scroll, _net_box)


## Only one page shows at a time. The tests look at the boxes, the layout
## looks at the scroll containers, so both get the same answer.
func _show_only(scroll: ScrollContainer, box: VBoxContainer) -> void:
	for s in [_main_scroll, _about_scroll, _char_scroll, _net_scroll]:
		s.visible = s == scroll
	for b in [_main_box, _about_box, _char_box, _net_box]:
		b.visible = b == box


## A page-sized scroll area: tall pages stay reachable on short screens.
func _scroll(parent: Node) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.custom_minimum_size = Vector2(500, 540)
	parent.add_child(s)
	return s


func _page(parent: Node) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	return box


func _row(parent: Node) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 12)
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(r)
	return r


func _grid(parent: Node, columns: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = columns
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
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
