extends SceneTree
## The WLAN and character pieces that can be checked without a network:
## changing the look in the menu reaches the player and is saved on the phone,
## a fresh player reads the saved look back, and a puppet (the other kid in a
## WLAN game) can be spawned, dressed, moved by hand and removed again.
## The live host/join check needs two phones on the same WiFi.
## Run: godot --headless --path . -s tests/net_test.gd

var _fails := 0

func _check(ok: bool, what: String) -> void:
	if not ok: _fails += 1
	print("%s: %s" % [what, "OK" if ok else "FAIL"])

func _initialize():
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var player = main._player
	var menu = main._menu

	# The character page of the menu drives the player's look.
	menu._name_edit.text = "Sari"
	menu._commit_name()
	_check(player.player_name == "Sari", "name from the menu reaches the player")
	menu._set_gender("boy")
	menu._set_gender("girl")
	_check(player.gender == "girl" and player.hair_style == 3, "girl starts with long hair")
	menu._pick("face", 3)
	_check(player.face_style == 3, "face picked in the menu")
	menu._pick("hijab", true)
	_check(player.wear_hijab, "hijab picked in the menu")
	_check(player.profile_dict().has("face"), "profile carries the face")

	# The live preview on the character page wears the same look at once.
	_check(menu._preview_player != null, "character page has a preview")
	_check(menu._preview_player.face_style == 3 and menu._preview_player.wear_hijab,
		"preview follows face and hijab picks")
	_check(menu._preview_player.shirt_color == player.shirt_color, "preview wears the same shirt")

	# A new player reads the same look back from the phone's settings file.
	var fresh = load("res://scripts/player.gd").new()
	root.add_child(fresh)
	await process_frame
	_check(fresh.player_name == "Sari" and fresh.face_style == 3 and fresh.wear_hijab,
		"the look is saved on the phone and read back")
	fresh.queue_free()

	# A puppet: no physics of its own, dressed by its owner, moved by hand here.
	main._spawn_puppet(42)
	_check(main._puppets.has(42), "puppet spawns")
	var puppet = main._puppets[42]
	_check(puppet.is_remote and puppet.name == "Player42", "puppet is a remote player")
	_check(puppet.collision_layer == 0 and puppet.collision_mask == 0, "puppet bumps into nothing")
	puppet.apply_profile({"name": "PuppetKid", "gender": "girl", "hijab": true, "face": 5,
		"shirt": Color(0.4, 0.8, 0.3)})
	_check(puppet._name_label.visible and puppet._name_label.text == "PuppetKid",
		"puppet wears its name over its head")
	puppet._net_started = true
	puppet._net_pos = puppet.global_position + Vector3(4, 0, 0)
	await create_timer(0.6).timeout
	_check(puppet.global_position.distance_to(puppet._net_pos) < 0.5,
		"puppet walks to where its owner is")
	main._despawn_puppet(42)
	_check(not main._puppets.has(42), "puppet leaves with its owner")

	# The arena is built: lanes of obstacles and a set of coins per race.
	_check(main._race_obstacles.size() >= 12, "race arena has obstacles")
	_check(main._race_coins.size() == 16, "race arena has coins")

	# A solo practice race: the countdown holds you, then you run to the line.
	main._race_start()
	_check(main._race_state == 1 and player.move_scale == 0.0, "race countdown holds the player")
	_check(player.global_position.x == main.RACE_LANE_X[0] and player.global_position.z == main.RACE_START_Z,
		"race lines you up in a start lane")
	_check(main._race_coins[0]["node"].visible, "coins appear for the race")
	await create_timer(3.4).timeout
	_check(main._race_state == 2 and player.move_scale == 1.0, "race starts after the countdown")
	# Step onto the first coin: it is collected and counted.
	var spot: Vector3 = main._race_coins[0]["pos"]
	player.teleport(Vector3(spot.x, 0.1, spot.z))
	await create_timer(0.3).timeout
	_check(main._race_coins[0]["taken"] and not main._race_coins[0]["node"].visible, "coin is collected")
	_check(int(main._race_coin_counts.get(0, 0)) == 1, "coin count is kept")
	player.teleport(Vector3(main.RACE_CENTER_X, 0.1, main.RACE_FINISH_Z - 1.0))
	await create_timer(0.3).timeout
	_check(main._race_finishers.size() == 1 and main._race_state == 0, "crossing the line ends the race")
	# The results board compares places and coins.
	_check(main._race_results.visible and main._race_results.text.contains("HASIL BALAP LARI"),
		"results board shows after the race")
	_check(main._race_results.text.contains("Sari") and main._race_results.text.contains("1 koin"),
		"results compare the coin counts")

	# Hijaiyah Adventure: the shown letter waits on a board in the park, and
	# only the matching board counts.
	main.start_hijaiyah()
	_check(main._hij_active and main._hij_order.size() == 28, "hijaiyah adventure covers 28 letters")
	var letters_before: Array = []
	for tok in main._hij_tokens:
		letters_before.append(tok["letter"])
	main._hij_begin(main._hij_order)
	var same_boards := true
	for j in main._hij_tokens.size():
		if main._hij_tokens[j]["letter"] != letters_before[j]:
			same_boards = false
	_check(same_boards and main._hij_pos == 0, "shared order makes the same boards")
	var target_letter: String = main.HIJAIYAH[main._hij_order[main._hij_pos]]
	var target_root: Node3D = null
	var wrong_root: Node3D = null
	for tok in main._hij_tokens:
		if tok["letter"] == target_letter:
			target_root = tok["root"]
		else:
			wrong_root = tok["root"]
	_check(target_root != null and target_root.visible, "target letter board hides in the park")
	player.teleport(wrong_root.position + Vector3(0, 0.1, 0))
	await create_timer(0.3).timeout
	_check(main._hij_pos == 0, "wrong letter does not count")
	player.teleport(target_root.position + Vector3(0, 0.1, 0))
	await create_timer(0.3).timeout
	_check(main._hij_pos == 1, "finding the letter counts")
	main._hij_found_rpc(1)
	_check(main._hij_pos == 2 and int(main._hij_scores.get(0, 0)) == 2, "a reported find scores and moves on")
	main._hij_found_rpc(1)
	_check(main._hij_pos == 2, "a stale find cannot count twice")
	main._cancel_games()
	_check(not main._hij_active, "hijaiyah adventure stops")

	# Wudhu Challenge: slow presses walk the whole washing order; a fast
	# press is warned and not counted, and the place cannot be left.
	main.start_wudhu()
	_check(main._wudhu_active and main._wudhu_step == 0, "wudhu challenge starts at niat")
	_check(main._wudhu_button.visible and main._wudhu_marker.visible, "wudhu button and marker show")
	main._on_wudhu_press()
	_check(main._wudhu_step == 1, "niat counts")
	main._on_wudhu_press()
	_check(main._wudhu_step == 1 and main._wudhu_presses == 0
		and main._game_sub.text.contains("cepat-cepat"), "a too-fast press is warned, not counted")
	player.teleport(main.WUDHU_POS + Vector3(9, 0.1, 0))
	await create_timer(0.25).timeout
	_check(Vector2(player.global_position.x - main.WUDHU_POS.x,
		player.global_position.z - main.WUDHU_POS.z).length() <= 2.7,
		"the washing place cannot be left mid-wudhu")
	var counted := 1
	while main._wudhu_active and counted < 40:
		main._wudhu_since_press = 99.0
		main._on_wudhu_press()
		counted += 1
	_check(counted == 28 and not main._wudhu_active, "wudhu order completes in 28 slow presses")
	_check(main._game_label.text.contains("Wudhu selesai"), "wudhu finish is celebrated")

	# The mini zoo: four animals to feed and play with, and a horse to ride.
	_check(main._zoo.size() == 4, "zoo has four animals")
	var horse := main._horse_animal()
	player.teleport(horse["root"].position + Vector3(1.5, 0.1, 0))
	await create_timer(0.25).timeout
	_check(main._zoo_near.get("kind") == "kuda", "standing by the horse offers its buttons")
	main._zoo_feed(main._zoo_near)
	_check(float(main._zoo_near["feed_t"]) > 0.0 and main._zoo_near["food"].visible, "feeding shows the food")
	main._zoo_play(main._zoo_near)
	_check(float(main._zoo_near["play_t"]) > 0.0, "playing starts the trick")
	main._start_riding()
	_check(main._riding and player.mount and not horse["root"].visible, "riding hides the pen horse and mounts up")
	main._stop_riding()
	_check(not main._riding and not player.mount and horse["root"].visible, "climbing off brings the horse back")
	print("RESULT: %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
	quit(0 if _fails == 0 else 1)
