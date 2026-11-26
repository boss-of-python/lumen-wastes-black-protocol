# FactionAgent.gd
# 100% Offline 4-Faction live infighting AI.
# Deterministic state machine: each faction agent detects the player and
# enemies of rival factions, engages, and fights them in real time —
# no network, no cloud, no random cloud APIs.
extends CharacterBody2D

const DETECT_RADIUS: float = 320.0
const ATTACK_RANGE: float = 50.0
const FIRING_RANGE: float = 280.0
const WANDER_RADIUS: float = 180.0
const STATE_IDLE := 0
const STATE_PATROL := 1
const STATE_CHASE := 2
const STATE_ATTACK := 3
const STATE_STAGGER := 4
const STATE_STUNNED := 5

@export var faction: String = "mutants"
@export var max_hp: float = 60.0
@export var damage: float = 12.0
@export var move_speed: float = 95.0
@export var firing_range: float = FIRING_RANGE

var hp: float = 0.0
var state: int = STATE_IDLE
var _target: Node = null
var _stagger_timer: float = 0.0
var _stun_timer: float = 0.0
var _fire_cooldown: float = 0.0
var _wander_target: Vector2 = Vector2.ZERO
var _aggro_factions: Array[String] = []

signal state_changed(new_state: int)

func _ready() -> void:
	hp = max_hp
	add_to_group("enemy")
	_load_faction_config()

func _load_faction_config() -> void:
	if not  FileAccess.file_exists("res://data/enemies.json"):
		return
	var f := FileAccess.open("res://data/enemies.json", FileAccess.READ)
	if f == null:
		return
	var raw := f.get_as_text()
	f.close()
	var data: Variant = JSON.parse_string(raw)
	if typeof(data) != TYPE_DICTIONARY:
		return
	var factions: Array = data.get("factions", [])
	for fct in factions:
		if fct["id"] == faction:
			hp = float(fct.get("hp", max_hp))
			damage = float(fct.get("damage", damage))
			move_speed = float(fct.get("speed", move_speed))
			detection_radius := float(fct.get("detection_radius", DETECT_RADIUS))
			firing_range = float(fct.get("attack_range", firing_range))
			for aggro in fct.get("aggro_faction", []):
				_aggro_factions.append(aggro)
			break

func _process(delta: float) -> void:
	_update_timers(delta)
	_update_ai(delta)

func _update_timers(delta: float) -> void:
	_fire_cooldown = max(0.0, _fire_cooldown - delta)
	_stagger_timer = max(0.0, _stagger_timer - delta)
	_stun_timer = max(0.0, _stun_timer - delta)

func _update_ai(delta: float) -> void:
	if state == STATE_STAGGER:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if state == STATE_STUNNED:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	_detect_targets()
	if _target != null:
		_chase_or_attack(delta)
	else:
		_patrol(delta)

func _detect_targets() -> void:
	var best_target: Node = null
	var best_score: float = -1.0
	var tree := get_tree()

	# Player is always a valid target.
	var player := tree.get_first_node_in_group("player")
	if player != null:
		var dist_p := global_position.distance_to(player.global_position)
		if dist_p <= DETECT_RADIUS:
			best_target = player
			best_score = 2.0 - dist_p / DETECT_RADIUS

	# Rival faction agents are valid targets (offline infighting).
	for node in tree.get_nodes_in_group("enemy"):
		if node == self or not  node.is_inside_tree():
			continue
		var other_faction: String = node.get("faction") if node.has_method("get") else ""
		if not  _is_rival(other_faction):
			continue
		var dist := global_position.distance_to(node.global_position)
		if dist <= DETECT_RADIUS:
			var score := 1.0 - dist / DETECT_RADIUS
			if score > best_score:
				best_score = score
				best_target = node

	_target = best_target
	if (best_target != null and state != STATE_CHASE and state != STATE_ATTACK) \
			or (best_target == null and (state == STATE_CHASE or state == STATE_ATTACK)):
		_change_state(STATE_CHASE if best_target != null else STATE_PATROL)

func _is_rival(other_faction: String) -> bool:
	if other_faction == faction:
		return false
	return other_faction in _aggro_factions

func _chase_or_attack(delta: float) -> void:
	if _target == null:
		_change_state(STATE_PATROL)
		return
	var dist := global_position.distance_to(_target.global_position)
	if dist > firing_range:
		_change_state(STATE_CHASE)
		_move_towards(_target.global_position, delta)
	else:
		_change_state(STATE_ATTACK)
		velocity = Vector2.ZERO
		_face_target()
		if _fire_cooldown <= 0.0 and _target.has_method("take_damage"):
			_target.take_damage(damage)
			_fire_cooldown = 0.8

func _move_towards(target_pos: Vector2, delta: float) -> void:
	var dir := (target_pos - global_position).normalized()
	velocity = dir * move_speed
	move_and_slide()

func _face_target() -> void:
	if _target != null:
		facing = 1 if _target.global_position.x > global_position.x else -1

func _patrol(delta: float) -> void:
	_change_state(STATE_PATROL)
	var dist := global_position.distance_to(_wander_target)
	if dist < 12.0:
		_wander_target = global_position + Vector2(
			randf_range(-WANDER_RADIUS, WANDER_RADIUS),
			randf_range(-WANDER_RADIUS / 2.0, WANDER_RADIUS / 2.0))
	var dir := (_wander_target - global_position)
	if dir.length() > 1.0:
		dir = dir.normalized()
		velocity = dir * move_speed * 0.6
	move_and_slide()

func _change_state(new_state: int) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(state)

# ---------------------------------------------------------------------------
# Combat interface
# ---------------------------------------------------------------------------
func take_damage(amount: float) -> void:
	hp -= amount
	if hp <= 0.0:
		die()

func stun(duration: float) -> void:
	_stun_timer = duration
	_change_state(STATE_STUNNED)

func stagger(duration: float = 0.6) -> void:
	_stagger_timer = duration
	_change_state(STATE_STAGGER)

func apply_bash_launch(direction: Vector2) -> void:
	velocity = direction * 520.0
	stagger(0.8)

func die() -> void:
	if not  is_inside_tree():
		return
	queue_free()

func get_faction() -> String:
	return faction
