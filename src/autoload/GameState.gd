# GameState.gd
# Local offline save manager: 3 save slots + global 30-Ending Codex.
# 100% offline — all data persists to user:// with no network access.
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
	if not  FileAccess.file_exists(path):
		return _blank_slot(slot)
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return _blank_slot(slot)
	var data: Variant
	var err := f.get_var(data)
	f.close()
	if err != OK or typeof(data) != TYPE_DICTIONARY:
		return _blank_slot(slot)
	if data.get("version", 0) as int != SAVE_VERSION:
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
	if not Directory.exists(dir):
		var d := DirAccess.open(dir)
		if d == null:
			return ERR_CANNOT_OPEN
		d.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ERR_CANNOT_OPEN
	var err := f.store_var(data)
	f.close()
	return err

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------
func get_slot(slot: int) -> Dictionary:
	if slot < 0 or slot >= SAVE_SLOTS:
		return _blank_slot(0)
	return _slots[slot]

func is_slot_empty(slot: int) -> bool:
	if slot < 0 or slot >= SAVE_SLOTS:
		return true
	return _slots[slot].get("created_seconds", 0) as int == 0

func save_to_slot(slot: int, name: String = "", state: Dictionary = {}) -> Error:
	if slot < 0 or slot >= SAVE_SLOTS:
		return ERR_INVALID_PARAMETER
	var data := _slots[slot].duplicate(true)
	data["version"] = SAVE_VERSION
	data["slot"] = slot
	if name != "":
		data["name"] = name
	data["created_seconds"] = Time.get_ticks_msec() // 1000
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
			return ERR_CANNOT_OPEN
		f.close()
		# Truncate via a fresh empty write, then mark slot blank.
		var blank := _blank_slot(slot)
		_write_slot_file(slot, blank)
	_slots[slot] = _blank_slot(slot)
	return OK

# ---------------------------------------------------------------------------
# Ending Codex (global, persists across all slots)
# ---------------------------------------------------------------------------
func unlock_ending(ending_id: int) -> bool:
	var codex := load_codex()
	var unlocked: Array = codex["unlocked_ids"]
	if ending_id in unlocked:
		return false
	unlocked.append(ending_id)
	unlocked.sort_ascending()
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
	if not  FileAccess.file_exists(CODEX_PATH):
		return {"unlocked_ids": [], "last_unlocked": -1}
	var f := FileAccess.open(CODEX_PATH, FileAccess.READ)
	if f == null:
		return {"unlocked_ids": [], "last_unlocked": -1}
	var data: Variant
	var err := f.get_var(data)
	f.close()
	if err != OK or typeof(data) != TYPE_DICTIONARY:
		return {"unlocked_ids": [], "last_unlocked": -1}
	if not  data.has("unlocked_ids"):
		data["unlocked_ids"] = []
	if not  data.has("last_unlocked"):
		data["last_unlocked"] = -1
	return data

func get_unlocked_count() -> int:
	return load_codex()["unlocked_ids"].size()

func is_ending_unlocked(ending_id: int) -> bool:
	return ending_id in load_codex()["unlocked_ids"]

# ---------------------------------------------------------------------------
# Save-slot merge helper used by gameplay systems
# ---------------------------------------------------------------------------
func merge_flags(flags: Dictionary) -> void:
	if current_slot < 0 or current_slot >= SAVE_SLOTS:
		return
	var data := _slots[current_slot]
	var existing: Dictionary = data.get("narrative_flags", {})
	for key in flags:
		existing[key] = flags[key]
	data["narrative_flags"] = existing
	_write_slot_file(current_slot, data)
