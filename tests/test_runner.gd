# Headless CI suite.
extends SceneTree

const EXPORT_PRESETS_PATH := "res://export_presets.cfg"
const WEAPON_PATH := "res://data/weapons.json"
const ENDING_PATH := "res://data/endings.json"
const SHARD_PATH := "res://data/shards.json"
const ARMOR_PATH := "res://data/armor.json"
const ENEMY_PATH := "res://data/enemies.json"
const BIOME_PATH := "res://data/biomes.json"
const MANIFEST_PATH := "res://assets/manifest.json"
var _passed := 0
var _failed := 0
var _failures: Array[String] = []

func _initialize() -> void:
	_run_all.call_deferred()

func _run_all() -> void:
	_test_offline_manifest_compliance()
	_test_endings_completeness()
	_test_narrative_resolver()
	_test_gunsmith_math()
	_test_weapons_data()
	_test_shards_data()
	_test_armor_data()
	_test_enemies_data()
	_test_biomes_data()
	_test_physics_constants()
	_test_asset_manifest()
	print("RESULTS: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed else 0)

func _test_offline_manifest_compliance() -> void:
	_section("Offline Android permissions")
	var f := FileAccess.open(EXPORT_PRESETS_PATH, FileAccess.READ)
	_assert(f != null, "export presets readable")
	if f == null: return
	var text := f.get_as_text()
	f.close()
	var active_lines: Array[String] = []
	for line in text.split("\n"):
		if not line.strip_edges().begins_with(";"):
			active_lines.append(line)
	var active := "\n".join(active_lines)
	_assert(not active.contains("INTERNET"), "No INTERNET declaration in active preset config")
	_assert(not active.contains("ACCESS_NETWORK_STATE"), "No ACCESS_NETWORK_STATE declaration in active preset config")
	_assert(active.contains("Android"), "Android preset present")
	_assert(active.contains("iOS"), "iOS preset present")

func _test_endings_completeness() -> void:
	var data := _load_json(ENDING_PATH)
	var endings: Array = data.get("endings", [])
	_assert(endings.size() == 30, "30 endings defined")
	var ids: Array[int] = []
	for ending in endings:
		var id := int(ending.get("id", -1))
		_assert(not ids.has(id), "Ending IDs unique")
		ids.append(id)
		_assert(ending.has("name") and ending.has("branch") and ending.has("required_flags"), "Ending record schema")
	_assert(ids.size() == 30, "30 unique ending IDs")

func _test_narrative_resolver() -> void:
	var ns := Node.new()
	ns.set_script(load("res://src/autoload/NarrativeStateManager.gd"))
	root.add_child(ns)
	await process_frame
	ns.set_flag("strategy_nvg_stealth", true)
	ns.set_flag("power_core_med_bay", true)
	ns.set_flag("rep_faction_all_neutral", true)
	ns.set_flag("bosses_purified", true)
	ns.set_flag("resistance_accept", true)
	_assert(ns.resolve_ending() == 1, "True ending resolution")
	ns.clear_flags()
	ns.set_flag("strategy_nvg_stealth", false)
	ns.set_flag("power_core_med_bay", true)
	ns.set_flag("rep_faction_all_neutral", true)
	ns.set_flag("bosses_purified", true)
	ns.set_flag("resistance_accept", true)
	_assert(ns.resolve_ending() != 1, "False required flags are not satisfied")
	ns.clear_flags()
	for i in range(1, 19): ns.visit_crossroads(i)
	_assert(is_equal_approx(ns.get_crossroads_progress(), 1.0), "18 crossroads progress")
	ns.queue_free()

func _test_gunsmith_math() -> void:
	var combat := Node.new()
	combat.set_script(load("res://src/player/CombatController.gd"))
	root.add_child(combat)
	await process_frame
	var base: Dictionary = combat.get_effective_stats("m4_x_pulse")
	_assert(int(base.get("damage", 0)) == 18, "M4 base damage")
	_assert(combat.equip_attachment("extended_mag"), "Extended mag equips")
	_assert(int(combat.get_effective_stats("m4_x_pulse")["mag_size"]) == 43, "Extended magazine math")
	_assert(combat.equip_attachment("fmj"), "FMJ equips")
	var fmj: Dictionary = combat.get_effective_stats("m4_x_pulse")
	_assert(int(fmj["damage"]) == 22 and int(fmj["pierce"]) == 1, "FMJ math")
	for id in ["suppressor", "ir_laser", "sleight"]: combat.equip_attachment(id)
	_assert(not combat.equip_attachment("compensator"), "Attachment cap enforced")
	_assert(combat.get_effective_stats("m4_x_pulse")["reload_time"] < 1.6, "Sleight changes reload")
	combat.queue_free()

func _test_weapons_data() -> void:
	var data := _load_json(WEAPON_PATH)
	_assert(data.get("weapons", []).size() == 16, "16 weapons")
	_assert(data.get("gunsmith", {}).get("attachments", {}).size() == 7, "7 attachments")
func _test_shards_data() -> void: _assert(_load_json(SHARD_PATH).get("shards", []).size() == 24, "24 shards")
func _test_armor_data() -> void: _assert(_load_json(ARMOR_PATH).get("armor_sets", []).size() == 6, "6 armor sets")
func _test_enemies_data() -> void:
	var data := _load_json(ENEMY_PATH)
	_assert(data.get("factions", []).size() == 4 and data.get("bosses", []).size() == 8, "4 factions and 8 bosses")
func _test_biomes_data() -> void: _assert(_load_json(BIOME_PATH).get("biomes", []).size() == 9, "Hub plus 8 biomes")
func _test_physics_constants() -> void:
	_assert(ProjectSettings.get_setting("physics/2d/default_gravity") == 1180.0, "Gravity setting")
	_assert(ProjectSettings.get_setting("display/window/stretch/mode") == "canvas_items", "Canvas item stretch")
	_assert(load("res://src/player/Player.gd") != null, "Player script loads")
func _test_asset_manifest() -> void:
	var data := _load_json(MANIFEST_PATH)
	_assert(data.get("assets", []).size() > 0, "Asset manifest nonempty")

func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		_fail("Cannot open " + path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail("Invalid JSON dictionary: " + path)
		return {}
	return parsed
func _section(name: String) -> void: print("--- " + name + " ---")
func _fail(message: String) -> void:
	_failed += 1
	_failures.append(message)
	printerr("FAIL: " + message)
func _assert(condition: bool, message: String) -> void:
	if condition: _passed += 1
	else: _fail(message)
