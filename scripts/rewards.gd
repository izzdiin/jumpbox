class_name Rewards
extends RefCounted
## The star reward system: finishing a mini game earns stars. The total
## and the per-game counts live in a small file on the device, so they
## survive closing the game. Everything here is static — any screen can
## ask for the total, and any game can award its stars through main.

const PATH := "user://rewards.cfg"

static var _stars := -1  # -1: not loaded from disk yet
static var _counts := {}


static func _ensure_loaded() -> void:
	if _stars >= 0:
		return
	_stars = 0
	_counts = {}
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		_stars = int(cfg.get_value("rewards", "stars", 0))
		var saved: Dictionary = cfg.get_value("rewards", "counts", {})
		for k in saved:
			_counts[k] = int(saved[k])


static func total_stars() -> int:
	_ensure_loaded()
	return _stars


static func count_for(kind: String) -> int:
	_ensure_loaded()
	return int(_counts.get(kind, 0))


## Add stars for finishing something; returns the new total.
static func award(kind: String, stars: int) -> int:
	_ensure_loaded()
	_stars += stars
	_counts[kind] = int(_counts.get(kind, 0)) + 1
	var cfg := ConfigFile.new()
	cfg.set_value("rewards", "stars", _stars)
	cfg.set_value("rewards", "counts", _counts)
	cfg.save(PATH)
	return _stars
