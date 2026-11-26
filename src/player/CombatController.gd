# CombatController.gd
# Gunsmith ballistics (16 weapons, 7 attachment slots, max 5 equipped),
# 3 Wukong Kinetic Staff Stances, 4 Spells, 6 Boss Transformations.
# 100% offline ballistic math — no network, no cloud.
extends Node

const WEAPONS_PATH: String = "res://data/weapons.json"
const ENEMIES_PATH: String = "res://data/enemies.json"

const STANCE_SMASH := "smash"
const STANCE_PILLAR := "pillar"
const STANCE_THRUST := "thrust"

const STANCE_DAMAGE := {
	STANCE_SMASH: 42.0,
	STANCE_PILLAR: 36.0,
	STANCE_THRUST: 30.0,
}

const SPELL_STASIS_COST: float = 25.0
const SPELL_MIRAGE_COST: float = 25.0
const SPELL_SWARM_COST: float = 35.0
const SPELL_AEGIS_COST: float = 20.0

const SPELL_DURATIONS := {
	"stasis": 3.2,
	"mirage": 4.0,
	"swarm": 6.5,
	"aegis": 1.1,
}

const FINISHER_HEAL: float = 20.0
const FINISHER_STAGGER_HP_THRESHOLD: float = 0.25

const TRANSFORMATIONS: Array[String] = [
	"stone_colossus", "scorch_wolf_exo", "thunder_loong",
	"frost_wraith", "blight_stalker", "cinder_seraph",
]

@export var player: Node2D = null

var _weapons: Dictionary = {}
var _weapon_order: Array[String] = []
var _attachments_equipped: Array[String] = []
var _current_weapon: String = "m4_x_pulse"
var _stance: String = STANCE_SMASH
var _energy: float = 100.0
var _max_energy: float = 100.0
var _might: float = 0.0
var _max_might: float = 100.0
var _transformation_active: String = ""
var _spells_active: Dictionary = {}
var _fire_cooldown: float = 0.0
var _melee_cooldown: float = 0.0

signal weapon_fired(weapon_id: String)
signal stance_changed(stance: String)
signal spell_cast(spell_name: String)
signal transformation_activated(name: String)

func _ready() -> void:
	_load_weapons()

func _load_weapons() -> void:
	if not  ResourceLoader.exists(WEAPONS_PATH):
		push_error("CombatController: weapons.json missing at %s" % WEAPONS_PATH)
		return
	var data: Variant = load(WEAPONS_PATH)
	if typeof(data) != TYPE_DICTIONARY:
		return
	var weapons: Array = data.get("weapons", [])
	for w in weapons:
		_weapons[w["id"]] = w
		_weapon_order.append(w["id"])
	var gunsmith: Dictionary = data.get("gunsmith", {})
	_attachments_equipped.clear()
	_current_weapon = "m4_x_pulse" if _weapons.has("m4_x_pulse") else (_weapon_order[0] if _weapon_order.size() > 0 else "")

# ---------------------------------------------------------------------------
# Gunsmith ballistics
# ---------------------------------------------------------------------------
func get_weapon(weapon_id: String) -> Dictionary:
	return _weapons.get(weapon_id, {})

func get_attachments_equipped() -> Array[String]:
	return _attachments_equipped.duplicate()

func equip_attachment(attachment_id: String) -> bool:
	if _attachments_equipped.size() >= 5:
		return false
	if attachment_id in _attachments_equipped:
		return false
	_attachments_equipped.append(attachment_id)
	_attachments_equipped.sort()
	return true

func unequip_attachment(attachment_id: String) -> void:
	_attachments_equipped.erase(attachment_id)

func get_effective_stats(weapon_id: String) -> Dictionary:
	var w: Dictionary = _weapons.get(weapon_id, {})
	if w.is_empty():
		return w
	var stats := w.duplicate(true)
	var dmg_mult := 1.0
	var mag_mult := 1.0
	var spread_mult := 1.0
	var reload_mult := 1.0
	var pierce_bonus: int = 0
	var crit_bonus := 0.0
	for att in _attachments_equipped:
		var effects: Dictionary = _get_attachment_effects(att)
		dmg_mult *= effects.get("damage_multiplier", 1.0)
		mag_mult *= effects.get("mag_multiplier", 1.0)
		spread_mult *= effects.get("spread_multiplier", 1.0)
		reload_mult *= effects.get("reload_multiplier", 1.0)
		pierce_bonus += effects.get("pierce_bonus", 0)
		crit_bonus += effects.get("crit_chance_bonus", 0.0)
	stats["damage"] = stats.get("damage", 10.0) * dmg_mult
	stats["mag_size"] = int(stats.get("mag_size", 10) * mag_mult)
	stats["spread"] = stats.get("spread", 0.05) * spread_mult
	stats["reload_time"] = stats.get("reload_time", 1.5) * reload_mult
	stats["pierce"] = stats.get("pierce", 0) + pierce_bonus
	stats["crit_chance"] = crit_bonus
	return stats

func _get_attachment_effects(attachment_id: String) -> Dictionary:
	if not  ResourceLoader.exists(WEAPONS_PATH):
		return {}
	var data: Variant = load(WEAPONS_PATH)
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	var attachments: Dictionary = data.get("gunsmith", {}).get("attachments", {})
	return attachments.get(attachment_id, {})

func get_current_weapon_id() -> String:
	return _current_weapon

func switch_weapon(weapon_id: String) -> bool:
	if not  _weapons.has(weapon_id):
		return false
	_current_weapon = weapon_id
	return true

func cycle_weapon(direction: int) -> String:
	if _weapon_order.size() <= 1:
		return _current_weapon
	var idx := _weapon_order.find(_current_weapon)
	if idx < 0:
		idx = 0
	idx = wrapi(idx + direction, 0, _weapon_order.size() - 1)
	_current_weapon = _weapon_order[idx]
	return _current_weapon

func _process(delta: float) -> void:
	if _fire_cooldown > 0.0:
		_fire_cooldown -= delta
	if _melee_cooldown > 0.0:
		_melee_cooldown -= delta
	_regen_energy(delta)
	_tick_spells(delta)
	_handle_input()

func _handle_input() -> void:
	if Input.is_action_just_pressed("swap_weapon"):
		cycle_weapon(1)
	if Input.is_action_just_pressed("reload"):
		start_reload()
	if Input.is_action_just_pressed("shoot") and _fire_cooldown <= 0.0:
		fire_weapon()
	if Input.is_action_just_pressed("melee") and _melee_cooldown <= 0.0:
		perform_melee()

func fire_weapon() -> Dictionary:
	var w := get_effective_stats(_current_weapon)
	_fire_cooldown = w.get("fire_rate", 0.15)
	weapon_fired.emit(_current_weapon)
	# Return the computed ballistic profile for the projectile system.
	return {
		"weapon_id": _current_weapon,
		"damage": w.get("damage", 10.0),
		"spread": w.get("spread", 0.05),
		"bullet_speed": w.get("bullet_speed", 800.0),
		"pierce": w.get("pierce", 0),
		"pellets": w.get("pellets", 1),
		"status": w.get("status", ""),
		"crit_chance": w.get("crit_chance", 0.0),
	}

func start_reload() -> String:
	# Returns the animation name: tactical vs dry reload.
	var w := get_effective_stats(_current_weapon)
	var mag: int = w.get("mag_size", 10)
	return "tactical" if mag > 10 else "dry"

# ---------------------------------------------------------------------------
# Wukong Kinetic Staff — 3 Stances
# ---------------------------------------------------------------------------
func set_stance(stance: String) -> bool:
	if not  STANCE_DAMAGE.has(stance):
		return false
	_stance = stance
	stance_changed.emit(_stance)
	return true

func get_stance() -> String:
	return _stance

func perform_melee() -> Dictionary:
	_melee_cooldown = 0.45
	var dmg: float = STANCE_DAMAGE.get(_stance, 30.0)
	var result := {
		"stance": _stance,
		"damage": dmg,
		"knockback": 180.0,
	}
	# Pillar stance grants a vertical staff vault.
	if _stance == STANCE_PILLAR:
		if player != null and player.is_on_floor():
			result["vault_vy"] = -340.0
		# Thrust stance grants "Seeing Through" perfect-dodge counter.
	elif _stance == STANCE_THRUST:
		result["perfect_dodge_window"] = 0.25
	return result

func can_finisher(target_hp_fraction: float) -> bool:
	return target_hp_fraction <= FINISHER_STAGGER_HP_THRESHOLD

func perform_finisher() -> float:
	return FINISHER_HEAL

# ---------------------------------------------------------------------------
# 4 Spells (Energy)
# ---------------------------------------------------------------------------
func cast_spell(spell_name: String) -> bool:
	var costs := {
		"stasis": SPELL_STASIS_COST,
		"mirage": SPELL_MIRAGE_COST,
		"swarm": SPELL_SWARM_COST,
		"aegis": SPELL_AEGIS_COST,
	}
	if not  costs.has(spell_name):
		return false
	if _energy < costs[spell_name]:
		return false
	_energy -= costs[spell_name]
	_spells_active[spell_name] = SPELL_DURATIONS[spell_name]
	spell_cast.emit(spell_name)
	return true

func _tick_spells(delta: float) -> void:
	for spell_name in _spells_active.keys():
		_spells_active[spell_name] -= delta
		if _spells_active[spell_name] <= 0.0:
			_spells_active.erase(spell_name)

func is_spell_active(spell_name: String) -> bool:
	return _spells_active.has(spell_name)

func _regen_energy(delta: float) -> void:
	_energy = min(_max_energy, _energy + 6.0 * delta)

func get_energy() -> float:
	return _energy

func add_might(amount: float) -> void:
	_might = clamp(_might + amount, 0.0, _max_might)

func is_transformation_active() -> bool:
	return _transformation_active != ""

# ---------------------------------------------------------------------------
# 6 Boss Transformations (100% Might)
# ---------------------------------------------------------------------------
func can_transform(transformation_name: String) -> bool:
	if not  TRANSFORMATIONS.has(transformation_name):
		return false
	return _might >= _max_might

func transform(transformation_name: String) -> bool:
	if not  can_transform(transformation_name):
		return false
	_transformation_active = transformation_name
	_might = 0.0
	transformation_activated.emit(_transformation_active)
	return true

func end_transformation() -> void:
	_transformation_active = ""
