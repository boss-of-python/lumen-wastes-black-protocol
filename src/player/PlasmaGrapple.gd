# PlasmaGrapple.gd
# Ceiling grapple anchors + Ultra Grapple enemy zip.
# Fires a grappling line to ceiling anchors (layer 6), pulls the player
# toward them, and can zip from the player to a hooked enemy.
extends RayCast2D

const ANCHOR_LAYER: int = 6
const GRAPPLE_RANGE: float = 480.0
const GRAPPLE_SPEED: float = 1400.0
const GRAPPLE_COOLDOWN: float = 0.5
const ULTRA_ZIP_SPEED: float = 1900.0

@export var player: CharacterBody2D = null

var _cooldown: float = 0.0
var _grappling: bool = false
var _anchor: Node = null
var _zip_target: Node = null

signal grapple_fired(anchor: Node)
signal grapple_released()
signal ultra_zip_performed(target: Node)

func _ready() -> void:
	collision_mask = ANCHOR_LAYER
	set_process(true)

func _process(delta: float) -> void:
	_cooldown = max(0.0, _cooldown - delta)
	if player == null:
		return

	if _grappling and _anchor != null:
		_pull_to_anchor(delta)
		return

	if Input.is_action_just_pressed("grapple") and _cooldown <= 0.0:
		_try_grapple()

func _try_grapple() -> void:
	_cooldown = GRAPPLE_COOLDOWN
	# Aim upward-ish; anchors live on ceilings above the player.
	var direction := Vector2.UP if not  Input.is_action_pressed("shoot") else \
		(Input.get_vector("move_left", "move_right", "jump", "-jump") * -1.0).normalized()
	if direction.y >= 0.0:
		direction = Vector2.UP
	# Ray toward the ceiling.
	var ray := RayCast2D.new()
	ray.position = player.global_position
	ray.target_position = direction * GRAPPLE_RANGE
	ray.collision_mask = ANCHOR_LAYER
	ray.enabled = true
	add_child(ray)
	var hit := ray.is_colliding()
	var hit_point := ray.get_collision_point()
	var hit_node := ray.get_collider()
	ray.queue_free()

	if hit and hit_node != null:
		_grappling = true
		_anchor = hit_node
		grapple_fired.emit(_anchor)
		if AudioDirector != null:
			AudioDirector.play_sfx("dash")

func _pull_to_anchor(delta: float) -> void:
	if _anchor == null:
		_release()
		return
	var target_point := _anchor.global_position
	var to_anchor := target_point - player.global_position
	var pull_strength := 12.0
	# Pull toward the anchor point directly above.
	var pull := (to_anchor.normalized() * GRAPPLE_SPEED) * delta * pull_strength
	player.velocity += Vector2(pull.x, -abs(pull.y) * 0.5)
	if to_anchor.length() < 14.0:
		_release()

func _release() -> void:
	if not  _grappling:
		return
	_grappling = false
	_anchor = null
	grapple_released.emit()

func ultra_zip_to_enemy(target: Node) -> bool:
	if player == null or target == null:
		return false
	_zip_target = target
	_grappling = true
	_anchor = target
	ultra_zip_performed.emit(target)
	if player.has_method("reset_air_ability"):
		player.reset_air_ability()
	# Snap the player toward the enemy at high speed.
	var dir := (target.global_position - player.global_position).normalized()
	player.velocity = dir * ULTRA_ZIP_SPEED
	if AudioDirector != null:
		AudioDirector.play_sfx("dash")
	return true

func is_grappling() -> bool:
	return _grappling
