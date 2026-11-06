extends SceneTree
## Tapping the menu button opens the menu and pauses the game; "Main lagi" closes it.
## Run: godot --headless --path . -s tests/menu_test.gd

var _fails := 0

func _check(ok: bool, what: String) -> void:
	if not ok: _fails += 1
	print("%s: %s" % [what, "OK" if ok else "FAIL"])

## Buttons live in grids now, so tests find them by their text.
func _find_button(node: Node, text: String) -> Button:
	for child in node.get_children():
		if child is Button and child.text == text:
			return child
		var found := _find_button(child, text)
		if found != null:
			return found
	return null

func _initialize():
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var ui = main._ui
	var menu = main._menu
	var e := InputEventScreenTouch.new()
	e.position = ui._menu_center()
	e.pressed = true
	ui._input(e)
	_check(menu.visible and paused, "menu button opens the menu and pauses")
	_find_button(menu._main_box, "Tentang").pressed.emit()
	_check(menu._about_box.visible and not menu._main_box.visible, "about page shows")
	_find_button(menu._about_box, "Kembali").pressed.emit()
	_check(menu._main_box.visible, "back to the menu")
	_find_button(menu._main_box, "Main lagi").pressed.emit()
	_check(not menu.visible and not paused, "play again closes the menu")
	print("RESULT: %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
	quit(0 if _fails == 0 else 1)
