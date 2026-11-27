# BossBase.gd
extends CharacterBody2D

const TELEGRAPH_WINDUP: float = 0.8
const ARMOR_SHEAR_PER_HIT: float = 0.15
const BASH_ROCKET_DAMAGE: float = 120.0
const ROCKET_SPEED: float = 420.0

const PHASE_STATE_IDLE := 0
const PHASE_STATE_TELEGRAPH := 1
const PHASE_STATE_ATTACK := 2
const PHASE_STATE_STUNNED := 3

@export var boss_id: String = "stone_colossus"

var boss_data: Dictionary = {}
var hp: float = 0.0
var max_hp: float = 0.0
var current_phase: int = 1
var max_phases: int = 3
var armor_integrity: float = 1.0
var _state: int = PHASE_STATE_IDLE
var _attack_timer: float = 0.0
var _telegraph_timer: float = 0.0
var _current_attack: String = ""
var _stun_timer: float = 0.0
var _rockets_bashable: bool = false
var facing: int = 1

signal phase_changed(phase: int)
signal boss_defeated()
signal boss_enraged()

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	_load_boss_data()

func _load_boss_data() -> void:
	if not FileAccess.file_exists("res://data/enemies.json"):
		push_error("BossBase: enemies.json missing")
		return
	var f := FileAccess.open("res://data/enemies.json", FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY:
		return
	for b in data.get("bosses", []):
		if b["id"] == boss_id:
			boss_data = b
			max_hp = float(b.get("hp", 1000.0))
			hp = max_hp
			max_phases = int(b.get("phases", 1))
			armor_integrity = 1.0 if b.get("armor_shearing", false) else 0.0
			_rockets_bashable = bool(b.get("bashable_rockets", false))
			break

func _process(delta: float) -> void:
	_update_timers(delta)
	_update_state(delta)

func _update_timers(delta: float) -> void:
	_attack_timer = max(0.0, _attack_timer - delta)
	_telegraph_timer = max(0.0, _telegraph_timer - delta)
	_stun_timer = max(0.0, _stun_timer - delta)

func _update_state(delta: float) -> void:
	if _state == PHASE_STATE_STUNNED:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if _state == PHASE_STATE_TELEGRAPH:
		if _telegraph_timer <= 0.0:
			_execute_attack()
		move_and_slide()
		return
	if _state == PHASE_STATE_ATTACK:
		if _attack_timer <= 0.0:
			_change_state(PHASE_STATE_IDLE)
		move_and_slide()
		return
	if _attack_timer <= 0.0:
		_begin_telegraph()
	move_and_slide()

func _begin_telegraph() -> void:
	var attacks: Array = boss_data.get("attacks", [])
	if attacks.is_empty():
		return
	_current_attack = attacks[randi() % attacks.size()] 
	_telegraph_timer = TELEGRAPH_WINDUP
	_change_state(PHASE_STATE_TELEGRAPH)

func _execute_attack() -> void:
	_change_state(PHASE_STATE_ATTACK)
	_attack_timer = 1.0
	match _current_attack:
		"rocket_barrage":
			_spawn_rockets(3)
		"summon_mutants":
			_summon_minions("mutants", 2)
		"charge_rush", "drill_charge", "flame_dash":
			velocity = Vector2(facing * 480.0, 0.0)

func _spawn_rockets(count: int) -> void:
	if not _rockets_bashable:
		return
	for i in count:
		var rocket := _make_rocket()
		if rocket != null:
			get_tree().current_scene.add_child(rocket)
			rocket.global_position = global_position + Vector2(randf_range(-30.0, 30.0), -40.0)
			rocket.call("set_velocity", Vector2(facing * ROCKET_SPEED, 120.0))

func _make_rocket() -> Node:
	var rocket_scene := load("res://src/physics/BossRocket.tscn") as PackedScene
	if rocket_scene == null:
		return null
	var instance := rocket_scene.instantiate() as Area2D
	instance.set("speed", ROCKET_SPEED)
	instance.set("bash_damage", BASH_ROCKET_DAMAGE)
	instance.add_to_group("boss_rocket")
	return instance

func _summon_minions(faction: String, count: int) -> void:
	var agent_scene := load("res://src/ai/FactionAgent.tscn") as PackedScene
	if agent_scene == null:
		return
	for i in count:
		var agent := agent_scene.instantiate() as CharacterBody2D
		agent.set("faction", faction)
		agent.set("max_hp", hp * 0.1)
		agent.set("hp", hp * 0.1)
		get_tree().current_scene.add_child(agent)
		agent.global_position = global_position + Vector2(randf_range(-80.0, 80.0), 20.0)

func _change_state(new_state: int) -> void:
	if _state == new_state:
		return
	_state = new_state

func take_damage(amount: float) -> void:
	var effective := amount
	if armor_integrity > 0.0:
		var shear := amount * ARMOR_SHEAR_PER_HIT
		armor_integrity = max(0.0, armor_integrity - shear)
		effective = amount * (1.0 - armor_integrity)
	hp -= effective
	_check_phase_progression()
	if hp <= 0.0:
		defeat()

func _check_phase_progression() -> void:
	var threshold := max_hp / float(max_phases)
	var new_phase := int(ceil(hp / threshold))
	if new_phase != current_phase and new_phase >= 1 and new_phase <= max_phases:
		current_phase = new_phase
		phase_changed.emit(current_phase)

func apply_bash_launch(direction: Vector2) -> void:
	velocity = direction * 400.0
	_stun_timer = 0.8
	_change_state(PHASE_STATE_STUNNED)

func stun(duration: float) -> void:
	_stun_timer = duration
	_change_state(PHASE_STATE_STUNNED)

func defeat() -> void:
	boss_defeated.emit()
	queue_free()

func get_phase() -> int:
	return current_phase

func get_hp_fraction() -> float:
	return hp / max_hp if max_hp > 0.0 else 0.0
