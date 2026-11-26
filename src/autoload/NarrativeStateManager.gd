# NarrativeStateManager.gd
extends Node

const LAYER_STRATEGY := "pre_mission_strategy"
const LAYER_POWER := "haven_power_core_allocation"
const LAYER_FACTION := "faction_reputations"
const LAYER_BOSS := "boss_fates"
const LAYER_RESISTANCE := "interrogation_resistance"

const LAYERS: Array[String] = [LAYER_STRATEGY, LAYER_POWER, LAYER_FACTION, LAYER_BOSS, LAYER_RESISTANCE]
const CROSSROADS_COUNT: int = 18
const TOTAL_ENDINGS: int = 30
const ENDINGS_PATH: String = "res://data/endings.json"

var _flags: Dictionary = {}
var _crossroads_visited: Array[int] = []
var _endings_data: Array = []

signal ending_resolved(ending_id: int, ending_name: String)

func _ready() -> void:
	_load_endings_data()

func _load_endings_data() -> void:
	if not FileAccess.file_exists(ENDINGS_PATH):
		push_error("NarrativeStateManager: endings.json not found")
		return
	var f := FileAccess.open(ENDINGS_PATH, FileAccess.READ)
	if f == null:
		push_error("NarrativeStateManager: cannot open endings.json")
		return
	var res: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(res) != TYPE_DICTIONARY:
		push_error("NarrativeStateManager: endings.json did not parse")
		return
	_endings_data = res.get("endings", [])

func set_flag(flag: String, value: Variant = true) -> void:
	_flags[flag] = value

func get_flag(flag: String, default: Variant = null) -> Variant:
	return _flags.get(flag, default)

func has_flag(flag: String) -> bool:
	return bool(_flags.get(flag, false))

func all_flags() -> Dictionary:
	return _flags.duplicate(true)

func clear_flags() -> void:
	_flags.clear()
	_crossroads_visited.clear()

func visit_crossroads(crossroad_id: int) -> void:
	if crossroad_id < 1 or crossroad_id > CROSSROADS_COUNT:
		push_warning("NarrativeStateManager: invalid crossroad %d" % crossroad_id)
		return
	if not crossroad_id in _crossroads_visited:
		_crossroads_visited.append(crossroad_id)
		_crossroads_visited.sort()

func get_crossroads_visited() -> Array[int]:
	return _crossroads_visited.duplicate()

func get_crossroads_progress() -> float:
	return _crossroads_visited.size() / float(CROSSROADS_COUNT)

func resolve_ending() -> int:
	if _flags.get("ng_plus_veteran", false) and _flags.get("eternal_spark_equipped", false) and _flags.get("all_endings_seen", false) and _flags.get("cycle_reset_chosen", false):
		var e30 := _find_ending(30)
		if not e30.is_empty():
			ending_resolved.emit(30, e30["name"])
			return 30
	if bool(_flags.get("extraction_before_biome_3", false)):
		var e26 := _find_ending(26)
		if not e26.is_empty():
			ending_resolved.emit(26, e26["name"])
			return 26
	var best_id: int = -1
	for ending in _endings_data:
		var eid: int = ending["id"]
		if _ending_satisfied(eid, ending):
			best_id = eid
			break
	if best_id != -1:
		var chosen := _find_ending(best_id)
		ending_resolved.emit(best_id, chosen["name"])
		return best_id
	return -1

func _ending_satisfied(ending_id: int, ending: Dictionary) -> bool:
	if ending.get("ng_plus_only", false) and not bool(_flags.get("ng_plus_veteran", false)):
		return false
	for flag in ending.get("required_flags", []):
		if not bool(_flags.get(flag, false)):
			return false
	return true

func _find_ending(ending_id: int) -> Dictionary:
	for ending in _endings_data:
		if ending["id"] == ending_id:
			return ending
	return {}

func get_ending_name(ending_id: int) -> String:
	var e := _find_ending(ending_id)
	return e.get("name", "Unknown Ending") if not e.is_empty() else "Unknown Ending"

func get_ending_branch(ending_id: int) -> String:
	return _find_ending(ending_id).get("branch", "?")

func get_all_endings() -> Array:
	return _endings_data.duplicate(true)

func strategy_layer_value() -> String:
	if bool(_flags.get("strategy_nvg_stealth", false)): return "NVG Stealth"
	if bool(_flags.get("strategy_loud_sabotage", false)): return "Loud Sabotage"
	if bool(_flags.get("strategy_faction_hack", false)): return "Faction Hack"
	return "Unset"
