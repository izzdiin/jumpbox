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
	print("RESULT: %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
	quit(0 if _fails == 0 else 1)
