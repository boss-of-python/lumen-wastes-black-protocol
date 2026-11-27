extends RayCast2D

const ANCHOR_LAYER: int = 6
const ANCHOR_LAYER_MASK: int = 1 << (ANCHOR_LAYER - 1)
const GRAPPLE_RANGE: float = 480.0
const GRAPPLE_SPEED: float = 1400.0
const GRAPPLE_COOLDOWN: float = 0.5
const ULTRA_ZIP_SPEED: float = 1900.0
@export var player: CharacterBody2D
var _cooldown := 0.0
var _grappling := false
var _anchor: Node2D
var _zip_target: Node
signal grapple_fired(anchor: Node)
signal grapple_released()
signal ultra_zip_performed(target: Node)

func _ready() -> void:
	collision_mask = ANCHOR_LAYER_MASK
	set_process(true)

func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if player == null: return
	if _grappling and is_instance_valid(_anchor):
		_pull_to_anchor(delta)
	elif _grappling:
		_release()
	elif Input.is_action_just_pressed("grapple") and _cooldown <= 0.0:
		_try_grapple()

func _try_grapple() -> void:
	_cooldown = GRAPPLE_COOLDOWN
	var from := player.global_position
	var to := from + Vector2.UP * GRAPPLE_RANGE
	var query := PhysicsRayQueryParameters2D.create(from, to, collision_mask)
	query.exclude = [player.get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): return
	var collider := hit.get("collider") as Node2D
	if collider == null: return
	_anchor = collider
	_grappling = true
	grapple_fired.emit(_anchor)
	AudioDirector.play_sfx("dash")

func _pull_to_anchor(delta: float) -> void:
	var to_anchor := _anchor.global_position - player.global_position
	player.velocity += to_anchor.normalized() * GRAPPLE_SPEED * delta
	if to_anchor.length() < 14.0: _release()

func _release() -> void:
	if not _grappling: return
	_grappling = false
	_anchor = null
	grapple_released.emit()

func ultra_zip_to_enemy(target: Node) -> bool:
	if player == null or not is_instance_valid(target) or not target is Node2D: return false
	_zip_target = target
	_anchor = target as Node2D
	_grappling = true
	ultra_zip_performed.emit(target)
	if player.has_method("reset_air_ability"):
		player.call("reset_air_ability")
	# Snap the player toward the enemy at high speed.
	var dir := (target.global_position - player.global_position).normalized()
	if player.has_method("set_velocity"):
		player.call("set_velocity", dir * ULTRA_ZIP_SPEED)
	else:
		player.velocity = dir * ULTRA_ZIP_SPEED
	if AudioDirector != null:
		AudioDirector.play_sfx("dash")
	return true

func is_grappling() -> bool:
	return _grappling
