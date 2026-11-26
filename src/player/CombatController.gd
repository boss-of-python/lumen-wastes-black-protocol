# CombatController.gd
class_name CombatController
extends Node

const WEAPONS_PATH := "res://data/weapons.json"
const STANCE_SMASH := "smash"
const STANCE_PILLAR := "pillar"
const STANCE_THRUST := "thrust"
const STANCE_DAMAGE := {STANCE_SMASH: 42.0, STANCE_PILLAR: 36.0, STANCE_THRUST: 30.0}
const SPELL_STASIS_COST := 25.0
const SPELL_MIRAGE_COST := 25.0
const SPELL_SWARM_COST := 35.0
const SPELL_AEGIS_COST := 20.0
const SPELL_DURATIONS := {"stasis": 3.2, "mirage": 4.0, "swarm": 6.5, "aegis": 1.1}
const FINISHER_HEAL := 20.0
const FINISHER_STAGGER_HP_THRESHOLD := 0.25
const TRANSFORMATIONS: Array[String] = ["stone_colossus", "scorch_wolf_exo", "thunder_loong", "frost_wraith", "blight_stalker", "cinder_seraph"]

@export var player: CharacterBody2D = null

var _weapons: Dictionary = {}
var _attachment_definitions: Dictionary = {}
var _weapon_order: Array[String] = []
var _attachments_equipped: Array[String] = []
var _current_weapon := "m4_x_pulse"
var _stance := STANCE_SMASH
var _energy := 100.0
var _max_energy := 100.0
var _might := 0.0
var _max_might := 100.0
var _transformation_active := ""
var _spells_active: Dictionary = {}
var _fire_cooldown := 0.0
var _melee_cooldown := 0.0

signal weapon_fired(weapon_id: String)
signal stance_changed(stance: String)
signal spell_cast(spell_name: String)
signal transformation_activated(name: String)

func _ready() -> void:
	add_to_group("combat_controller")
	_load_weapons()

func _load_weapons() -> void:
	var f := FileAccess.open(WEAPONS_PATH, FileAccess.READ)
	if f == null:
		push_error("CombatController: cannot open weapons.json")
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY:
		push_error("CombatController: invalid weapons.json")
		return
	for weapon in data.get("weapons", []):
		_weapons[weapon["id"]] = weapon
		_weapon_order.append(weapon["id"])
	_attachment_definitions = data.get("gunsmith", {}).get("attachments", {})
	if not _weapons.has(_current_weapon) and not _weapon_order.is_empty():
		_current_weapon = _weapon_order[0]

func get_weapon(weapon_id: String) -> Dictionary:
	return _weapons.get(weapon_id, {})

func get_attachments_equipped() -> Array[String]:
	return _attachments_equipped.duplicate()

func equip_attachment(attachment_id: String) -> bool:
	if _attachments_equipped.size() >= 5 or _attachments_equipped.has(attachment_id) or not _attachment_definitions.has(attachment_id):
		return false
	_attachments_equipped.append(attachment_id)
	return true

func unequip_attachment(attachment_id: String) -> void:
	_attachments_equipped.erase(attachment_id)

func get_effective_stats(weapon_id: String) -> Dictionary:
	var weapon: Dictionary = _weapons.get(weapon_id, {})
	if weapon.is_empty():
		return {}
	var stats := weapon.duplicate(true)
	var dmg_mult := 1.0
	var mag_mult := 1.0
	var spread_mult := 1.0
	var reload_mult := 1.0
	var pierce_bonus := 0
	var crit_bonus := 0.0
	for id in _attachments_equipped:
		var effects: Dictionary = _attachment_definitions.get(id, {}).get("effects", {})
		dmg_mult *= float(effects.get("damage_multiplier", 1.0))
		mag_mult *= float(effects.get("mag_multiplier", 1.0))
		spread_mult *= float(effects.get("spread_multiplier", 1.0))
		reload_mult *= float(effects.get("reload_multiplier", 1.0))
		pierce_bonus += int(effects.get("pierce_bonus", 0))
		crit_bonus += float(effects.get("crit_chance_bonus", 0.0))
	stats["damage"] = float(stats.get("damage", 10.0)) * dmg_mult
	stats["mag_size"] = int(stats.get("mag_size", 10) * mag_mult)
	stats["spread"] = float(stats.get("spread", 0.05)) * spread_mult
	stats["reload_time"] = float(stats.get("reload_time", 1.5)) * reload_mult
	stats["pierce"] = int(stats.get("pierce", 0)) + pierce_bonus
	stats["crit_chance"] = crit_bonus
	return stats

func get_current_weapon_id() -> String:
	return _current_weapon

func switch_weapon(weapon_id: String) -> bool:
	if not _weapons.has(weapon_id): return false
	_current_weapon = weapon_id
	return true

func cycle_weapon(direction: int) -> String:
	if _weapon_order.size() <= 1: return _current_weapon
	var idx := _weapon_order.find(_current_weapon)
	_current_weapon = _weapon_order[wrapi(idx + direction, 0, _weapon_order.size())]
	return _current_weapon

func _process(delta: float) -> void:
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	_melee_cooldown = maxf(0.0, _melee_cooldown - delta)
	_regen_energy(delta)
	_tick_spells(delta)
	_handle_input()

func _handle_input() -> void:
	if Input.is_action_just_pressed("swap_weapon"): cycle_weapon(1)
	if Input.is_action_just_pressed("reload"): start_reload()
	if Input.is_action_just_pressed("shoot") and _fire_cooldown <= 0.0: fire_weapon()
	if Input.is_action_just_pressed("melee") and _melee_cooldown <= 0.0: perform_melee()
	for spell in ["stasis", "mirage", "swarm", "aegis"]:
		if Input.is_action_just_pressed("spell_" + spell): cast_spell(spell)

func fire_weapon() -> Dictionary:
	var stats := get_effective_stats(_current_weapon)
	if stats.is_empty(): return {}
	_fire_cooldown = float(stats.get("fire_rate", 0.15))
	weapon_fired.emit(_current_weapon)
	return {"weapon_id": _current_weapon, "damage": stats.get("damage", 10.0), "spread": stats.get("spread", 0.05), "bullet_speed": stats.get("bullet_speed", 800.0), "pierce": stats.get("pierce", 0), "pellets": stats.get("pellets", 1), "status": stats.get("status", ""), "crit_chance": stats.get("crit_chance", 0.0)}

func start_reload() -> String:
	return "tactical" if int(get_effective_stats(_current_weapon).get("mag_size", 10)) > 10 else "dry"

func set_stance(stance: String) -> bool:
	if not STANCE_DAMAGE.has(stance): return false
	_stance = stance
	stance_changed.emit(stance)
	return true

func get_stance() -> String:
	return _stance

func perform_melee() -> Dictionary:
	_melee_cooldown = 0.45
	var result := {"stance": _stance, "damage": STANCE_DAMAGE.get(_stance, 30.0), "knockback": 180.0}
	if _stance == STANCE_PILLAR and player != null and player.is_on_floor(): result["vault_vy"] = -340.0
	elif _stance == STANCE_THRUST: result["perfect_dodge_window"] = 0.25
	return result

func can_finisher(target_hp_fraction: float) -> bool:
	return target_hp_fraction <= FINISHER_STAGGER_HP_THRESHOLD

func perform_finisher() -> float:
	return FINISHER_HEAL

func cast_spell(spell_name: String) -> bool:
	var costs := {"stasis": SPELL_STASIS_COST, "mirage": SPELL_MIRAGE_COST, "swarm": SPELL_SWARM_COST, "aegis": SPELL_AEGIS_COST}
	if not costs.has(spell_name) or _energy < costs[spell_name]: return false
	_energy -= costs[spell_name]
	_spells_active[spell_name] = SPELL_DURATIONS[spell_name]
	spell_cast.emit(spell_name)
	return true

func _tick_spells(delta: float) -> void:
	for spell in _spells_active.keys():
		_spells_active[spell] -= delta
		if _spells_active[spell] <= 0.0: _spells_active.erase(spell)

func is_spell_active(spell_name: String) -> bool:
	return _spells_active.has(spell_name)

func _regen_energy(delta: float) -> void:
	_energy = minf(_max_energy, _energy + 6.0 * delta)

func get_energy() -> float:
	return _energy

func add_might(amount: float) -> void:
	_might = clampf(_might + amount, 0.0, _max_might)

func is_transformation_active() -> bool:
	return _transformation_active != ""

func can_transform(name: String) -> bool:
	return TRANSFORMATIONS.has(name) and _might >= _max_might

func transform(name: String) -> bool:
	if not can_transform(name): return false
	_transformation_active = name
	_might = 0.0
	transformation_activated.emit(name)
	return true

func end_transformation() -> void:
	_transformation_active = ""
