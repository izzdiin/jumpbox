class_name HijaiyahGame
extends Node3D
## Hijaiyah Adventure: a letter is shown at the top of the screen; four
## letter boards hide around the park and walking into the matching one
## finds it. All 28 letters come by, in a shuffled order. Played together
## over the WLAN session the hunt is shared: one shuffled order for every
## phone, identical boards everywhere, and a score per player.

const HIJAIYAH: Array[String] = ["ا", "ب", "ت", "ث", "ج", "ح", "خ", "د", "ذ", "ر", "ز", "س", "ش", "ص", "ض", "ط", "ظ", "ع", "غ", "ف", "ق", "ك", "ل", "م", "ن", "ه", "و", "ي"]
const HIJ_SPOTS: Array[Vector3] = [Vector3(-16, 0, 8), Vector3(12, 0, 20), Vector3(-4, 0, -24), Vector3(18, 0, -8), Vector3(-20, 0, -16), Vector3(4, 0, 32), Vector3(-28, 0, 4), Vector3(20, 0, 28), Vector3(-16, 0, 30), Vector3(14, 0, -26)]

const U := preload("res://scripts/util.gd")
const WOOD := Color(0.6, 0.4, 0.22)
const WHITE := Color(0.97, 0.97, 0.97)
const RAINBOW: Array[Color] = [
	Color(0.95, 0.3, 0.3), Color(1.0, 0.6, 0.15), Color(1.0, 0.85, 0.2), Color(0.4, 0.8, 0.3),
	Color(0.25, 0.65, 0.95), Color(0.55, 0.4, 0.9), Color(0.95, 0.45, 0.75),
]

var active := false
var order: Array[int] = []
var pos := 0
var tokens: Array[Dictionary] = []
var scores := {}
var names := {}

var _cooldown := 0.0
var _host: Node
var _player: Node
var _sound: Node
var _label: Label
var _sub: Label


func setup(host: Node, player: Node, sound: Node, label: Label, sub: Label) -> void:
	_host = host
	_player = player
	_sound = sound
	_label = label
	_sub = sub
	# Four letter boards on posts, reused for every round of the hunt.
	for i in 4:
		var root := Node3D.new()
		root.visible = false
		add_child(root)
		U.mesh_cylinder(root, 0.09, 1.0, Vector3(0, 0.5, 0), WOOD)
		U.mesh_box(root, Vector3(1.15, 1.15, 0.1), Vector3(0, 1.6, 0), RAINBOW[i % RAINBOW.size()])
		var lab := Label3D.new()
		lab.font_size = 160
		lab.pixel_size = 0.0062
		lab.modulate = WHITE
		lab.outline_size = 20
		lab.outline_modulate = Color(0.1, 0.1, 0.15)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		# The billboarded text plane passes through the board itself, so
		# without this the board's front face hides the letter.
		lab.no_depth_test = true
		lab.position = Vector3(0, 1.6, 0)
		root.add_child(lab)
		tokens.append({"root": root, "label": lab, "letter": "", "armed": true})


## The starter shuffles the 28 letters and shares the order, so every
## phone hunts the same target with the same boards.
func begin() -> void:
	var shuffled: Array[int] = []
	for i in HIJAIYAH.size():
		shuffled.append(i)
	shuffled.shuffle()
	if _host.net_active():
		rpc("_begin_rpc", shuffled)
	else:
		_begin_rpc(shuffled)


func cancel() -> void:
	active = false
	for tok in tokens:
		tok["root"].visible = false
	scores.clear()
	names.clear()


@rpc("any_peer", "reliable", "call_local")
func _begin_rpc(shared_order: Array) -> void:
	_host.prepare_for_game()
	order.clear()
	for v in shared_order:
		order.append(int(v))
	scores.clear()
	names.clear()
	for id in _host.race_ids():
		scores[id] = 0
		names[id] = _host.name_for_id(id)
	pos = 0
	_cooldown = 0.0
	active = true
	_host.set_game_running("Hijaiyah Adventure")
	_round()


func hud_text() -> String:
	var line := "Ditemukan: %d dari %d" % [pos, HIJAIYAH.size()]
	if scores.size() > 1:
		var parts: Array[String] = []
		for id in scores:
			var nm := "Kamu" if id == _host.my_id() else str(names.get(id, "Pemain"))
			parts.append("%s: %d" % [nm, int(scores[id])])
		line += "\n" + " • ".join(parts)
	return line


func _round() -> void:
	if pos >= HIJAIYAH.size():
		active = false
		for tok in tokens:
			tok["root"].visible = false
		_label.text = "Hebat! Semua huruf hijaiyah ditemukan!"
		_sub.text = "Kamu sudah mengenal 28 huruf hijaiyah."
		if scores.size() > 1:
			_sub.text = hud_text().replace("Ditemukan:", "Skor akhir — ditemukan:")
		_label.visible = true
		_sub.visible = true
		_sound.play("fanfare")
		_host.show_prompts_for(6.0)
		_host.set_game_running("")
		_host.game_completed("hijaiyah")
		return
	var target: String = HIJAIYAH[order[pos]]
	var letters: Array[String] = [target]
	var k := 1
	while letters.size() < tokens.size():
		var cand: String = HIJAIYAH[order[(pos + k) % HIJAIYAH.size()]]
		if not letters.has(cand):
			letters.append(cand)
		k += 1
	var start := (pos * 3) % HIJ_SPOTS.size()
	for j in tokens.size():
		var tok := tokens[j]
		# The arrangement turns with the round number instead of shuffling,
		# so every phone in a group game shows the same boards.
		var letter: String = letters[(j + pos) % letters.size()]
		tok["letter"] = letter
		# Boards arm once the player is a few steps away, so the board you
		# just found cannot fire again while you still stand on its spot.
		tok["armed"] = false
		tok["label"].text = letter
		tok["root"].position = HIJ_SPOTS[(start + j * 3) % HIJ_SPOTS.size()]
		tok["root"].visible = true
	_label.text = "Cari huruf: " + target
	_sub.text = hud_text()
	_label.visible = true
	_sub.visible = true


## A find counts for the finder only, and the hunt moves on for everyone.
## The round number rides along so a late or double call cannot count twice.
@rpc("any_peer", "reliable", "call_local")
func found_rpc(round_pos: int) -> void:
	if not active or round_pos != pos:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = _host.my_id()
	if not scores.has(sender):
		scores[sender] = 0
		names[sender] = _host.name_for_id(sender)
	scores[sender] = int(scores[sender]) + 1
	var target: String = HIJAIYAH[order[pos]]
	for tok in tokens:
		if tok["letter"] == target:
			U.confetti(self, tok["root"].position + Vector3(0, 1.6, 0), 30, RAINBOW)
			break
	_sound.play("checkpoint")
	pos += 1
	_cooldown = 0.6
	_round()


func _process(delta: float) -> void:
	if not active or not is_visible_in_tree():
		return
	_cooldown -= delta
	var target: String = HIJAIYAH[order[pos]]
	for tok in tokens:
		var root: Node3D = tok["root"]
		if not root.visible:
			continue
		var flat := Vector2(_player.global_position.x - root.position.x,
			_player.global_position.z - root.position.z).length()
		if flat > 2.2:
			tok["armed"] = true
		elif flat < 1.25 and tok["armed"] and _cooldown <= 0.0:
			tok["armed"] = false
			if tok["letter"] == target:
				if _host.net_active():
					rpc("found_rpc", pos)
				else:
					found_rpc(pos)
			else:
				_sound.play("boing", -4.0)
				_sub.text = "Bukan yang ini. Cari huruf: " + target
				_cooldown = 0.8
