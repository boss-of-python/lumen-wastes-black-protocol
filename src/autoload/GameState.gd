# GameState.gd
extends Node

const SAVE_SLOTS: int = 3
const SAVE_VERSION: int = 1
const CODEX_PATH: String = "user://codex_30_endings.json"
const SLOT_PATH_FMT: String = "user://save_slot_%d.json"

var current_slot: int = -1
var _slots: Array[Dictionary] = []

signal save_written(slot: int)
signal load_completed(slot: int)
signal codex_updated(unlocked_count: int)

func _ready() -> void:
	_load_slots_cache()
	setup_input_actions()

func setup_input_actions() -> void:
	_add_key_action("move_left", KEY_LEFT)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_RIGHT)
	_add_key_action("move_right", KEY_D)
	_add_key_action("move_up", KEY_UP)
	_add_key_action("move_down", KEY_DOWN)
	_add_key_action("jump", KEY_SPACE)
	_add_key_action("dash", KEY_SHIFT)
	_add_key_action("shoot", KEY_W)
	_add_mouse_button_action("shoot", MOUSE_BUTTON_LEFT)
	_add_key_action("reload", KEY_R)
	_add_key_action("swap_weapon", KEY_Q)
	_add_key_action("spell_stasis", KEY_1)
	_add_key_action("spell_mirage", KEY_2)
	_add_key_action("spell_swarm", KEY_3)
	_add_key_action("spell_aegis", KEY_4)
	_add_key_action("bash", KEY_H)
	_add_key_action("grapple", KEY_J)
	_add_key_action("melee", KEY_K)
	_add_key_action("interact", KEY_E)
	_add_key_action("medkit", KEY_M)
	_add_key_action("nvg_toggle", KEY_N)
	_add_key_action("focus", KEY_F)
	_add_key_action("vehicle_boost", KEY_B)
	_add_key_action("ui_cancel", KEY_ESCAPE)
	# Aim directions via arrow keys for twin-stick-style control.
	_add_key_action("aim_left", KEY_LEFT)
	_add_key_action("aim_right", KEY_RIGHT)
	_add_key_action("aim_up", KEY_UP)
	_add_key_action("aim_down", KEY_DOWN)

func _add_key_action(action_name: String, keycode: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action_name, event)

func _add_mouse_button_action(action_name: String, button_index: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	InputMap.action_add_event(action_name, event)

# ---------------------------------------------------------------------------
# Slot cache
# ---------------------------------------------------------------------------
func _slot_path(slot: int) -> String:
	return SLOT_PATH_FMT % slot

func _load_slots_cache() -> void:
	_slots.clear()
	for i in SAVE_SLOTS:
		_slots.append(_read_slot_file(i))

func _read_slot_file(slot: int) -> Dictionary:
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		return _blank_slot(slot)
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return _blank_slot(slot)
	var data: Variant = f.get_var()
	var err := f.get_error()
	f.close()
	if err != OK or typeof(data) != TYPE_DICTIONARY:
		return _blank_slot(slot)
	if int(data.get("version", 0)) != SAVE_VERSION:
		return _blank_slot(slot)
	return data

func _blank_slot(slot: int) -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"slot": slot,
		"name": "Slot %d" % (slot + 1),
		"created_seconds": 0,
		"playtime_seconds": 0,
		"biome_index": 0,
		"player_hp": 100,
		"player_max_hp": 100,
		"narrative_flags": {},
		"codex_unlocked": [],
		"gunsmith_unlocks": ["m4_x_pulse", "m870_breacher", "mp7_ghost", "tactical_pistol"],
		"equipped_shard": "",
		"armor_set": "wraith_operative",
	}

func _write_slot_file(slot: int, data: Dictionary) -> Error:
	var path := _slot_path(slot)
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		var d := DirAccess.open("user://")
		if d == null:
			return ERR_CANT_OPEN
		var mk_err := d.make_dir_recursive(dir.trim_prefix("user://"))
		if mk_err != OK:
			return mk_err
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ERR_CANT_OPEN
	f.store_var(data)
	var err := f.get_error()
	f.close()
	return err

func get_slot(slot: int) -> Dictionary:
	if slot < 0 or slot >= SAVE_SLOTS:
		return _blank_slot(0)
	return _slots[slot]

func is_slot_empty(slot: int) -> bool:
	if slot < 0 or slot >= SAVE_SLOTS:
		return true
	return int(_slots[slot].get("created_seconds", 0)) == 0

func save_to_slot(slot: int, name: String = "", state: Dictionary = {}) -> Error:
	if slot < 0 or slot >= SAVE_SLOTS:
		return ERR_INVALID_PARAMETER
	var data := _slots[slot].duplicate(true)
	data["version"] = SAVE_VERSION
	data["slot"] = slot
	if name != "":
		data["name"] = name
	data["created_seconds"] = int(Time.get_ticks_msec() / 1000)
	data.merge(state)
	var err := _write_slot_file(slot, data)
	if err == OK:
		_slots[slot] = data
		current_slot = slot
		save_written.emit(slot)
	return err

func load_from_slot(slot: int) -> Dictionary:
	if slot < 0 or slot >= SAVE_SLOTS:
		return _blank_slot(0)
	_slots[slot] = _read_slot_file(slot)
	current_slot = slot
	load_completed.emit(slot)
	return _slots[slot]

func delete_slot(slot: int) -> Error:
	if slot < 0 or slot >= SAVE_SLOTS:
		return ERR_INVALID_PARAMETER
	if FileAccess.file_exists(_slot_path(slot)):
		var f := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
		if f == null:
			return ERR_CANT_OPEN
		f.close()
	_slots[slot] = _blank_slot(slot)
	return OK

func unlock_ending(ending_id: int) -> bool:
	var codex := load_codex()
	var unlocked: Array = codex["unlocked_ids"]
	if ending_id in unlocked:
		return false
	unlocked.append(ending_id)
	unlocked.sort()
	codex["unlocked_ids"] = unlocked
	codex["last_unlocked"] = ending_id
	var f := FileAccess.open(CODEX_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_var(codex)
	f.close()
	codex_updated.emit(unlocked.size())
	return true

func load_codex() -> Dictionary:
	if not FileAccess.file_exists(CODEX_PATH):
		return {"unlocked_ids": [], "last_unlocked": -1}
	var f := FileAccess.open(CODEX_PATH, FileAccess.READ)
	if f == null:
		return {"unlocked_ids": [], "last_unlocked": -1}
	var data: Variant = f.get_var()
	var err := f.get_error()
	f.close()
	if err != OK or typeof(data) != TYPE_DICTIONARY:
		return {"unlocked_ids": [], "last_unlocked": -1}
	if not data.has("unlocked_ids"):
		data["unlocked_ids"] = []
	if not data.has("last_unlocked"):
		data["last_unlocked"] = -1
	return data

func get_unlocked_count() -> int:
	return load_codex()["unlocked_ids"].size()

func is_ending_unlocked(ending_id: int) -> bool:
	return ending_id in load_codex()["unlocked_ids"]

func merge_flags(flags: Dictionary) -> void:
	if current_slot < 0 or current_slot >= SAVE_SLOTS:
		return
	var data := _slots[current_slot]
	var existing: Dictionary = data.get("narrative_flags", {})
	for key in flags:
		existing[key] = flags[key]
	data["narrative_flags"] = existing
	_write_slot_file(current_slot, data)
