# KineticBash.gd
# Slow-mo 360-degree launch off enemies, incoming boss rockets, and
# explosive barrels within 120px. Propels the player (vy = -450) and flings
# the target in the opposite vector (1.45x rocket speed, 120 damage).
extends Node2D

const DETECTION_RANGE: float = 120.0
const BASH_DAMAGE: float = 120.0
const PLAYER_PROPULSION_VY: float = -450.0
const ROCKET_SPEED_MULTIPLIER: float = 1.45
const BASH_COOLDOWN: float = 0.9

@export var player: CharacterBody2D = null

var _cooldown: float = 0.0

signal bash_performed(target: Node)
signal bash_failed()

func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	_cooldown = max(0.0, _cooldown - delta)
	if player == null:
		return
	if Input.is_action_just_pressed("bash") and _cooldown <= 0.0:
		try_bash()

func try_bash() -> Node:
	if player == null:
		return null
	_cooldown = BASH_COOLDOWN
	var target := _find_bash_target()
	if target == null:
		bash_failed.emit()
		return null
	_execute_bash(target)
	bash_performed.emit(target)
	return target

func _find_bash_target() -> Node:
	# 1. Explosive barrels / daisy-chain dynamite.
	for node in get_tree().get_nodes_in_group("bashable_barrel"):
		if node.is_inside_tree() and global_position.distance_to(node.global_position) <= DETECTION_RANGE:
			return node
	# 2. Enemies (any faction agent or boss).
	for node in get_tree().get_nodes_in_group("enemy"):
		if node.is_inside_tree() and global_position.distance_to(node.global_position) <= DETECTION_RANGE:
			return node
	# 3. Incoming boss rockets.
	for node in get_tree().get_nodes_in_group("boss_rocket"):
		if node.is_inside_tree() and global_position.distance_to(node.global_position) <= DETECTION_RANGE:
			return node
	return null

func _execute_bash(target: Node) -> void:
	var dir := (player.global_position - target.global_position)
	if dir.length() < 1.0:
		dir = Vector2.UP
	dir = dir.normalized()

	# Player gets a 360-degree launch — vertical boost plus horizontal push.
	if player.has_method("reset_air_ability"):
		player.reset_air_ability()
	player.velocity = Vector2(dir.x * 240.0, PLAYER_PROPULSION_VY)

	# Fling the target in the opposite vector.
	if target.has_method("apply_bash_launch"):
		target.apply_bash_launch(-dir)
	elif target.has_method("take_damage"):
		target.take_damage(BASH_DAMAGE)

	# Boss rockets are flung at 1.45x speed and deal bash damage on impact.
	if target.has_group("boss_rocket") and target.has_method("set_velocity"):
		var rocket_speed: float = target.get("speed") if target.has_method("get") else 600.0
		target.set_velocity(-dir * rocket_speed * ROCKET_SPEED_MULTIPLIER)
		target.set("bash_damage", BASH_DAMAGE)

	# Trigger TimeManager slow-mo.
	if TimeManager != null:
		TimeManager.activate_bash_slow_mo(0.75)

	if AudioDirector != null:
		AudioDirector.play_sfx("dash")
