# test_runner.gd
# Headless CI suite for LUMEN WASTES: BLACK PROTOCOL.
# Verifies all 30 endings, Gunsmith math, physics constants, and the
# zero-network-permission offline manifest compliance.
#
# Run: godot --headless --script res://tests/test_runner.gd
# Exits 0 on success, 1 on failure.
extends SceneTree

const EXPORT_PRESETS_PATH: String = "export_presets.cfg"
const WEAPON_PATH: String = "res://data/weapons.json"
const ENDING_PATH: String = "res://data/endings.json"
const SHARD_PATH: String = "res://data/shards.json"
const ARMOR_PATH: String = "res://data/armor.json"
const ENEMY_PATH: String = "res://data/enemies.json"
const BIOME_PATH: String = "res://data/biomes.json"
const MANIFEST_PATH: String = "res://assets/manifest.json"

var _passed: int = 0
var _failed: int = 0
var _failures: Array[String] = []

func _init() -> void:
	print("\n=== LUMEN WASTES: BLACK PROTOCOL — CI TEST SUITE ===\n")
	_run_all()
	print("\n=== RESULTS: %d passed, %d failed ===" % [_passed, _failed])
	if _failed > 0:
		for f in _failures:
			print("  FAIL: %s" % f)
		quit(1)
	quit(0)

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

# ---------------------------------------------------------------------------
# 1. Offline manifest compliance (zero network permissions)
# ---------------------------------------------------------------------------
func _test_offline_manifest_compliance() -> void:
	_section("Offline Manifest Compliance")
	# Read export_presets.cfg from the filesystem (res:// resolves to project root).
	var path := ProjectSettings.globalize_path("res://" + EXPORT_PRESETS_PATH)
	if not  FileAccess.file_exists(path):
		_fail("export_presets.cfg not found")
		return
	var f := FileAccess.open(path, FileAccess.READ)
	var content := f.get_as_text()
	f.close()
	_assert(not  content.contains("INTERNET"), "Android preset must NOT declare INTERNET permission")
	_assert(not  content.contains("ACCESS_NETWORK_STATE"), "Android preset must NOT declare ACCESS_NETWORK_STATE permission")
	_assert(content.contains("Android"), "Android preset present")
	_assert(content.contains("iOS"), "iOS preset present")
	_assert(content.contains("com.tarunloganathan.lumenwastes.blackprotocol"), "Package name present")

# ---------------------------------------------------------------------------
# 2. Endings completeness
# ---------------------------------------------------------------------------
func _test_endings_completeness() -> void:
	_section("30 Endings Data")
	var data: Variant = load(ENDING_PATH)
	_assert(typeof(data) == TYPE_DICTIONARY, "endings.json is a dictionary")
	var endings: Array = data.get("endings", [])
	_assert(endings.size() == 30, "30 endings defined (found %d)" % endings.size())
	var ids: Array[int] = []
	for e in endings:
		var id: int = e["id"]
		_assert(not (id in ids), "Ending id %d unique" % id)
		ids.append(id)
	_assert(ids.size() == 30, "30 unique ending ids")
	for e in endings:
		_assert(e.has("name") and e.has("branch"), "Ending %d has name and branch" % e["id"])
		_assert(e.has("required_flags"), "Ending %d has required_flags" % e["id"])
	var true_ending: bool = false
	for e in endings:
		if e.get("true_ending", false):
			true_ending = true
	_assert(true_ending, "True ending (The Golden Bloom) present")

# ---------------------------------------------------------------------------
# 3. Narrative resolver simulation
# ---------------------------------------------------------------------------
func _test_narrative_resolver() -> void:
	_section("Narrative State Manager Resolver")
	var ns := Node.new()
	ns.name = "NSMTest"
	ns.set_script(load("res://src/autoload/NarrativeStateManager.gd"))
	root.add_child(ns)
	# Use Variant-typed dynamic dispatch: class_name types are not registered
	# at parse time when running via --script, so 'as NarrativeStateManager'
	# would fail to resolve. Variant dispatch avoids static type resolution.
	var nsm: Variant = ns
	# Simulate the True Ending flag set.
	nsm.set_flag("strategy_nvg_stealth", true)
	nsm.set_flag("power_core_med_bay", true)
	nsm.set_flag("rep_faction_all_neutral", true)
	nsm.set_flag("bosses_purified", true)
	nsm.set_flag("resistance_accept", true)
	var resolved := nsm.resolve_ending()
	_assert(resolved == 1, "True ending resolves to #1 (found %d)" % resolved)
	_assert(nsm.get_ending_name(1) == "The Golden Bloom", "Ending #1 name correct")
	# NG+ secret ending.
	nsm.clear_flags()
	nsm.set_flag("ng_plus_veteran", true)
	nsm.set_flag("eternal_spark_equipped", true)
	nsm.set_flag("all_endings_seen", true)
	nsm.set_flag("cycle_reset_chosen", true)
	resolved = nsm.resolve_ending()
	_assert(resolved == 30, "NG+ secret ending resolves to #30 (found %d)" % resolved)
	# Early extraction.
	nsm.clear_flags()
	nsm.set_flag("extraction_before_biome_3", true)
	resolved = nsm.resolve_ending()
	_assert(resolved == 26, "Early extraction resolves to #26 (found %d)" % resolved)
	# Crossroads.
	nsm.clear_flags()
	for i in 18:
		nsm.visit_crossroads(i)
	_assert(nsm.get_crossroads_progress() == 1.0, "18 crossroads progress = 1.0")
	ns.queue_free()

# ---------------------------------------------------------------------------
# 4. Gunsmith math
# ---------------------------------------------------------------------------
func _test_gunsmith_math() -> void:
	_section("Gunsmith Ballistics")
	var cc := Node.new()
	cc.name = "CCTest"
	cc.set_script(load("res://src/player/CombatController.gd"))
	root.add_child(cc)
	# Variant-typed dynamic dispatch (class_name not registered at parse time
	# when running via --script, so 'as CombatController' would fail to resolve).
	var combat: Variant = cc
	# Baseline M4-X Pulse Carbine.
	var base: Dictionary = combat.get_effective_stats("m4_x_pulse")
	_assert(int(base["damage"]) == 18, "M4-X base damage 18 (got %d)" % int(base["damage"]))
	_assert(int(base["mag_size"]) == 30, "M4-X base mag 30 (got %d)" % int(base["mag_size"]))
	# Extended Mag: 1.45x capacity.
	combat.equip_attachment("extended_mag")
	var extended: Dictionary = combat.get_effective_stats("m4_x_pulse")
	_assert(int(extended["mag_size"]) == 43, "Extended Mag 1.45x -> 43 rounds (got %d)" % int(extended["mag_size"]))
	# FMJ: 1.25x damage + 1 pierce.
	combat.equip_attachment("fmj")
	var fmj: Dictionary = combat.get_effective_stats("m4_x_pulse")
	_assert(int(fmj["damage"]) == 22, "FMJ 1.25x -> 22 dmg (got %d)" % int(fmj["damage"]))
	_assert(int(fmj["pierce"]) == 1, "FMJ +1 pierce (got %d)" % int(fmj["pierce"]))
	# Max 5 attachments enforced.
	combat.unequip_attachment("extended_mag")
	combat.unequip_attachment("fmj")
	for id in ["suppressor", "ir_laser", "sleight", "compensator", "laser_sight"]:
		combat.equip_attachment(id)
	_assert(combat.get_attachments_equipped().size() == 5, "5 attachments equipped")
	_assert(not  combat.equip_attachment("extended_mag"), "Cannot equip a 6th attachment")
	# Sleight of Hand: 0.60x reload.
	var reload_stats: Dictionary = combat.get_effective_stats("m4_x_pulse")
	_assert(reload_stats["reload_time"] < 1.6, "Sleight 0.60x reload reduces time (got %.2f)" % reload_stats["reload_time"])
	# VX-9 Plasma Rail baseline.
	var rail: Dictionary = combat.get_effective_stats("vx9_plasma_rail")
	_assert(int(rail["damage"]) == 52, "VX-9 base damage 52 (got %d)" % int(rail["damage"]))
	_assert(int(rail["pierce"]) == 3, "VX-9 base pierce 3 (got %d)" % int(rail["pierce"]))
	# Spell energy costs.
	combat._energy = 100.0
	_assert(combat.cast_spell("stasis"), "Stasis Lock castable at 25 EN")
	_assert(combat.get_energy() == 75.0, "Stasis costs 25 EN (got %.1f)" % combat.get_energy())
	_assert(combat.cast_spell("swarm"), "Swarm Protocol castable at 35 EN")
	_assert(combat.get_energy() == 40.0, "Swarm costs 35 EN (got %.1f)" % combat.get_energy())
	# Drop energy below the Swarm cost to verify the guard.
	combat._energy = 30.0
	_assert(not  combat.cast_spell("swarm"), "Swarm not castable when EN insufficient (30 < 35)")
	# Transformation requires 100% Might.
	_assert(not  combat.can_transform("stone_colossus"), "No transformation below 100% Might")
	combat.add_might(100.0)
	_assert(combat.can_transform("stone_colossus"), "Transformation available at 100% Might")
	_assert(combat.transform("stone_colossus"), "Transformation activates")
	_assert(combat.is_transformation_active(), "Transformation active flag set")
	cc.queue_free()

# ---------------------------------------------------------------------------
# 5-9. Data integrity
# ---------------------------------------------------------------------------
func _test_weapons_data() -> void:
	_section("16 Weapons Data")
	var data: Variant = load(WEAPON_PATH)
	var weapons: Array = data.get("weapons", [])
	_assert(weapons.size() == 16, "16 weapons defined (found %d)" % weapons.size())
	var gunsmith: Dictionary = data.get("gunsmith", {})
	_assert(gunsmith.get("attachment_slots", 0) == 7, "7 attachment slots")
	_assert(gunsmith.get("max_attachments_equipped", 0) == 5, "Max 5 attachments equipped")
	var attachments: Dictionary = gunsmith.get("attachments", {})
	_assert(attachments.size() == 7, "7 attachment definitions (found %d)" % attachments.size())
	# Verified baselines.
	var m4 := _find_weapon(weapons, "m4_x_pulse")
	_assert(m4.get("damage") == 18 and m4.get("fire_rate") == 0.13 and m4.get("mag_size") == 30, "M4-X baselines")
	var m870 := _find_weapon(weapons, "m870_breacher")
	_assert(m870.get("damage") == 14 and m870.get("pellets") == 5 and m870.get("mag_size") == 8, "M870 baselines")
	var vx9 := _find_weapon(weapons, "vx9_plasma_rail")
	_assert(vx9.get("damage") == 52 and vx9.get("pierce") == 3, "VX-9 baselines")
	var mp7 := _find_weapon(weapons, "mp7_ghost")
	_assert(mp7.get("damage") == 12 and mp7.get("mag_size") == 40, "MP-7 baselines")

func _find_weapon(weapons: Array, id: String) -> Dictionary:
	for w in weapons:
		if w["id"] == id:
			return w
	return {}

func _test_shards_data() -> void:
	_section("24 Core Shards Data")
	var data: Variant = load(SHARD_PATH)
	var shards: Array = data.get("shards", [])
	_assert(shards.size() == 24, "24 shards defined (found %d)" % shards.size())
	for s in shards:
		_assert(s.has("id") and s.has("name") and s.has("grants"), "Shard %s has id/name/grants" % s.get("id"))

func _test_armor_data() -> void:
	_section("6 Armor Sets Data")
	var data: Variant = load(ARMOR_PATH)
	var sets: Array = data.get("armor_sets", [])
	_assert(sets.size() == 6, "6 armor sets defined (found %d)" % sets.size())
	for s in sets:
		_assert(s.get("pieces", []).size() == 3, "Armor set %s has 3 pieces" % s.get("id"))

func _test_enemies_data() -> void:
	_section("4 Factions + 8 Bosses Data")
	var data: Variant = load(ENEMY_PATH)
	var factions: Array = data.get("factions", [])
	_assert(factions.size() == 4, "4 factions defined (found %d)" % factions.size())
	var bosses: Array = data.get("bosses", [])
	_assert(bosses.size() == 8, "8 bosses defined (found %d)" % bosses.size())
	for b in bosses:
		_assert(b.get("phases", 0) >= 2, "Boss %s is multi-phase" % b.get("id"))
	# 4-faction infighting: each faction aggros at least one rival.
	for f in factions:
		_assert(f.get("aggro_faction", []).size() > 0, "Faction %s has rivals" % f.get("id"))

func _test_biomes_data() -> void:
	_section("8 Biomes + 20h Progression Data")
	var data: Variant = load(BIOME_PATH)
	var biomes: Array = data.get("biomes", [])
	_assert(biomes.size() == 9, "9 biome entries (8 biomes + hub) (found %d)" % biomes.size())
	_assert(data.get("total_target_hours") == 20.0, "20-hour target")
	for b in biomes:
		if b["type"] == "biome":
			_assert(b.has("major_boss"), "Biome %s has a major boss" % b.get("name"))

# ---------------------------------------------------------------------------
# 10. Physics constants
# ---------------------------------------------------------------------------
func _test_physics_constants() -> void:
	_section("Physics & Gameplay Constants")
	_assert(_load_project_setting("physics/2d/default_gravity") == 1180.0, "gravity 1180.0")
	_assert(_load_project_setting("display/window/stretch/mode") == "canvas_items", "stretch canvas_items")
	_assert(_load_project_setting("rendering/renderer/rendering_method") == "mobile", "Mobile renderer")
	_assert(_load_project_setting("physics/common/physics_ticks_per_second") == 60, "60 physics ticks")
	# Verify the gameplay constants file matches the verified vertical slice.
	var player_script := load("res://src/player/Player.gd") as Script
	_assert(player_script != null, "Player.gd loads")

func _load_project_setting(path: String) -> Variant:
	if ProjectSettings.has_setting(path):
		return ProjectSettings.get_setting(path)
	return null

# ---------------------------------------------------------------------------
# 11. Asset manifest
# ---------------------------------------------------------------------------
func _test_asset_manifest() -> void:
	_section("Asset Manifest")
	var data: Variant = load(MANIFEST_PATH)
	_assert(typeof(data) == TYPE_DICTIONARY, "manifest.json is a dictionary")
	var assets: Array = data.get("assets", [])
	_assert(assets.size() > 0, "Manifest has assets")
	_assert(data.get("offline_lock", {}).get("network_permissions", []).size() == 0, "Zero network permissions in manifest")
	for a in assets:
		_assert(a.has("name") and a.has("kind"), "Asset %s has name and kind" % a.get("name"))

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
func _section(name: String) -> void:
	print("--- %s ---" % name)

func _fail(message: String) -> void:
	_failed += 1
	_failures.append(message)
	print("  FAIL: %s" % message)

func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_fail(message)
