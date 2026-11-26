# GunsmithUI.gd
# Modern Warfare 5-attachment workbench.
# Shows the 16-weapon arsenal, the 7 attachment slots, and allows equipping
# up to 5 attachments. Live ballistic preview reflects attachment math.
extends Control

const MAX_ATTACHMENTS: int = 5
const WEAPON_LIST_PATH: String = "res://data/weapons.json"

@onready var _weapon_list: ItemList = $WeaponList if has_node("WeaponList") else null
@onready var _attachment_slots: GridContainer = $AttachmentSlots if has_node("AttachmentSlots") else null
@onready var _stats_label: Label = $StatsLabel if has_node("StatsLabel") else null

var _combat: CombatController = null
var _weapons: Dictionary = {}
var _weapon_ids: Array[String] = []

func _ready() -> void:
	# CombatController is not an autoload singleton; fetch the active instance
	# via the "combat_controller" group (set by CombatController._ready).
	_combat = get_tree().get_first_node_in_group("combat_controller") as CombatController
	_load_weapons()
	_build_attachment_slots()

func _load_weapons() -> void:
	if not  FileAccess.file_exists(WEAPON_LIST_PATH):
		push_error("GunsmithUI: weapons.json missing at %s" % WEAPON_LIST_PATH)
		return
	# In Godot 4, load() on a .json returns a JSON Resource (TYPE_OBJECT),
	# not a Dictionary. Parse the raw text with JSON.parse_string instead.
	var f := FileAccess.open(WEAPON_LIST_PATH, FileAccess.READ)
	if f == null:
		push_error("GunsmithUI: cannot open %s" % WEAPON_LIST_PATH)
		return
	var raw := f.get_as_text()
	f.close()
	var data: Variant = JSON.parse_string(raw)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("GunsmithUI: weapons.json did not parse to a Dictionary")
		return
	var weapons: Array = data.get("weapons", [])
	for w in weapons:
		_weapons[w["id"]] = w
		_weapon_ids.append(w["id"])
	_refresh_weapon_list()

func _refresh_weapon_list() -> void:
	if _weapon_list == null:
		return
	_weapon_list.clear()
	for id in _weapon_ids:
		var w: Dictionary = _weapons[id]
		_weapon_list.add_item(w.get("name", id))
	_weapon_list.select(0)

func _on_weapon_selected(index: int) -> void:
	if index < 0 or index >= _weapon_ids.size():
		return
	var id := _weapon_ids[index]
	if _combat != null:
		_combat.switch_weapon(id)
	_refresh_stats()

func _build_attachment_slots() -> void:
	if _attachment_slots == null:
		return
	for i in 7:
		var slot := _make_slot_button(i)
		_attachment_slots.add_child(slot)

func _make_slot_button(slot_index: int) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(110.0, 90.0)
	btn.text = "Slot %d" % (slot_index + 1)
	btn.tooltip_text = "Attachment slot %d" % (slot_index + 1)
	btn.pressed.connect(_on_slot_pressed.bind(slot_index))
	return btn

func _on_slot_pressed(slot_index: int) -> void:
	# Cycle through available attachments into the pressed slot.
	var attachment_ids := ["suppressor", "extended_mag", "fmj", "ir_laser", "sleight", "compensator", "laser_sight"]
	if _combat == null:
		return
	var equipped := _combat.get_attachments_equipped()
	var candidate := ""
	for id in attachment_ids:
		if not  id in equipped:
			candidate = id
			break
	if candidate == "" and equipped.size() > 0:
		candidate = equipped[0]  # toggle off
	if candidate == "":
		return
	if candidate in equipped:
		_combat.unequip_attachment(candidate)
	else:
		_combat.equip_attachment(candidate)
	_refresh_stats()

func _refresh_stats() -> void:
	if _combat == null or _stats_label == null:
		return
	var id := _combat.get_current_weapon_id()
	var stats := _combat.get_effective_stats(id)
	var lines := [
		"%s" % _weapons.get(id, {}).get("name", id),
		"Damage: %d" % int(stats.get("damage", 0)),
		"Mag: %d" % int(stats.get("mag_size", 0)),
		"Reload: %.2fs" % stats.get("reload_time", 0.0),
		"Pierce: %d" % int(stats.get("pierce", 0)),
		"Attachments: %d/%d" % [_combat.get_attachments_equipped().size(), MAX_ATTACHMENTS],
	]
	_stats_label.text = "\n".join(lines)
