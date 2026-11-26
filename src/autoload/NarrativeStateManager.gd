# NarrativeStateManager.gd
# 5 strategic narrative layers, 18 crossroads, 30-Ending resolver.
# 100% offline: deterministic state machine resolving endings from flags.
class_name NarrativeStateManager
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
	if not  FileAccess.file_exists(ENDINGS_PATH):
		push_error("NarrativeStateManager: endings.json not found at %s" % ENDINGS_PATH)
		return
	# load() on a .json returns a JSON Resource, not a Dictionary — parse text.
	var f := FileAccess.open(ENDINGS_PATH, FileAccess.READ)
	if f == null:
		push_error("NarrativeStateManager: cannot open %s" % ENDINGS_PATH)
		return
	var raw := f.get_as_text()
	f.close()
	var res: Variant = JSON.parse_string(raw)
	if typeof(res) != TYPE_DICTIONARY:
		push_error("NarrativeStateManager: endings.json did not parse to a Dictionary")
		return
	_endings_data = res.get("endings", [])

# ---------------------------------------------------------------------------
# Flags
# ---------------------------------------------------------------------------
func set_flag(flag: String, value: Variant = true) -> void:
	_flags[flag] = value

func get_flag(flag: String, default: Variant = null) -> Variant:
	return _flags.get(flag, default)

func has_flag(flag: String) -> bool:
	return _flags.has(flag)

func all_flags() -> Dictionary:
	return _flags.duplicate(true)

func clear_flags() -> void:
	_flags.clear()
	_crossroads_visited.clear()

# ---------------------------------------------------------------------------
# Crossroads (18 decision points across the campaign)
# ---------------------------------------------------------------------------
func visit_crossroads(crossroad_id: int) -> void:
	if crossroad_id < 1 or crossroad_id > CROSSROADS_COUNT:
		push_warning("NarrativeStateManager: invalid crossroad %d" % crossroad_id)
		return
	if not  crossroad_id in _crossroads_visited:
		_crossroads_visited.append(crossroad_id)
		_crossroads_visited.sort_ascending()

func get_crossroads_visited() -> Array[int]:
	return _crossroads_visited.duplicate()

func get_crossroads_progress() -> float:
	return _crossroads_visited.size() / float(CROSSROADS_COUNT)

# ---------------------------------------------------------------------------
# Ending resolution
# ---------------------------------------------------------------------------
func resolve_ending() -> int:
	# Priority order: NG+ secret ending first, then early extraction,
	# then the unique ending whose required flags are fully satisfied.
	if _flags.get("ng_plus_veteran", false) and _flags.get("eternal_spark_equipped", false) \
			and _flags.get("all_endings_seen", false) and _flags.get("cycle_reset_chosen", false):
		var e30 := _find_ending(30)
		if e30 != null:
			ending_resolved.emit(30, e30["name"])
			return 30

	if _flags.get("extraction_before_biome_3", false):
		var e26 := _find_ending(26)
		if e26 != null:
			ending_resolved.emit(26, e26["name"])
			return 26

	var best_id: int = -1
	var best_matches: int = 0
	for ending in _endings_data:
		var eid: int = ending["id"]
		if _ending_satisfied(eid, ending):
			var matches := _count_matches(ending)
			if matches > best_matches:
				best_matches = matches
				best_id = eid

	if best_id != -1:
		var chosen := _find_ending(best_id)
		ending_resolved.emit(best_id, chosen["name"])
		return best_id
	return -1

func _ending_satisfied(ending_id: int, ending: Dictionary) -> bool:
	if ending_id == 30 and not ending.get("ng_plus_only", false):
		pass
	if ending.get("ng_plus_only", false) and not _flags.get("ng_plus_veteran", false):
		return false
	var required: Array = ending.get("required_flags", [])
	for flag in required:
		if not _flags.has(flag):
			return false
	return true

func _count_matches(ending: Dictionary) -> int:
	var required: Array = ending.get("required_flags", [])
	var count := 0
	for flag in required:
		if _flags.has(flag):
			count += 1
	return count

func _find_ending(ending_id: int) -> Dictionary:
	for ending in _endings_data:
		if ending["id"] == ending_id:
			return ending
	return {}

func get_ending_name(ending_id: int) -> String:
	var e := _find_ending(ending_id)
	if e.is_empty():
		return "Unknown Ending"
	return e.get("name", "Unknown Ending")

func get_ending_branch(ending_id: int) -> String:
	var e := _find_ending(ending_id)
	return e.get("branch", "?")

func get_all_endings() -> Array:
	return _endings_data.duplicate(true)

# ---------------------------------------------------------------------------
# Layer snapshots (for DecisionFlowchartUI)
# ---------------------------------------------------------------------------
func layer_snapshot(layer: String) -> Dictionary:
	var snap := {}
	for key in _flags:
		if key.begins_with(layer + "_") or key == layer:
			snap[key] = _flags[key]
	return snap

func strategy_layer_value() -> String:
	if _flags.get("strategy_nvg_stealth", false):
		return "NVG Stealth"
	if _flags.get("strategy_loud_sabotage", false):
		return "Loud Sabotage"
	if _flags.get("strategy_faction_hack", false):
		return "Faction Hack"
	return "Unset"

func power_core_layer_value() -> String:
	for key in ["power_core_defenses", "power_core_armory", "power_core_med_bay", "power_core_shuttle_fuel"]:
		if _flags.get(key, false):
			return key.replace("power_core_", "").capitalize()
	return "Unset"

func faction_layer_values() -> Dictionary:
	return {
		"mutants": _flags.get("rep_mutant_ally", false),
		"aeigis": _flags.get("rep_aeigis_ally", false),
		"xeno": _flags.get("rep_xeno_ally", false),
		"vanguard": _flags.get("rep_vanguard_ally", false),
	}

func boss_layer_values() -> Dictionary:
	return {
		"purified": _flags.get("bosses_purified", false),
		"harvested": _flags.get("bosses_harvested", false),
		"executed": _flags.get("bosses_executed", false),
	}

func resistance_layer_value() -> String:
	if _flags.get("resistance_accept", false):
		return "Accept"
	if _flags.get("resistance_endure", false):
		return "Endure"
	if _flags.get("resistance_defy", false):
		return "Defy"
	return "Unset"
