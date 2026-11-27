# Player.gd
# Tuned Ori-grade movement, Skeleton2D IK aiming, scarf Verlet physics,
# dual reloads, and ability-reset rules. Godot 4 CharacterBody2D.
extends CharacterBody2D

const GRAVITY: float = 1180.0
const MAX_RUN_SPEED: float = 265.0
const MAX_RUN_SPEED_TITAN: float = 290.0
const JUMP_VELOCITY: float = -475.0
const WALL_KICK_VELOCITY: Vector2 = Vector2(340.0, -460.0)
const WALL_SLIDE_MAX_VY: float = 120.0
const COYOTE_TIME: float = 0.12
const JUMP_BUFFER: float = 0.12
const DOUBLE_JUMP_COUNT: int = 2
const DOUBLE_JUMP_COUNT_TRIPLE: int = 3
const PHASE_DASH_SPEED: float = 640.0
const PHASE_DASH_DURATION: float = 0.16
const PHASE_DASH_IFRAMES: float = 0.24
const PHASE_DASH_COOLDOWN: float = 0.65

const PHYSICS_LAYER_PLAYER: int = 1
const FIRE_LAYER_PLAYER: int = 4

@onready var _anim_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null
@onready var _skeleton: Skeleton2D = $Skeleton2D if has_node("Skeleton2D") else null
@onready var _scarf_point: Node2D = $ScarfPoint if has_node("ScarfPoint") else null

var max_hp: float = 100.0
var hp: float = 100.0
var is_titan_form: bool = false
var triple_jump_unlocked: bool = false
var wall_jump_unlocked: bool = false
var dash_unlocked: bool = false

var _velocity := Vector2.ZERO
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _air_jumps_used: int = 0
var _dash_cooldown: float = 0.0
var _dash_timer: float = 0.0
var _iframes: float = 0.0
var _facing: int = 1
var _on_wall_left: bool = false
var _on_wall_right: bool = false
var _wall_slide_timer: float = 0.0
var _scarf_pos := Vector2.ZERO
var _scarf_vel := Vector2.ZERO
var _velocity_locked: bool = false

signal air_jump_reset()
signal dash_executed()

func _ready() -> void:
	add_to_group("player")
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	if TimeManager == null:
		# Allow headless/test runs without the autoload.
		_apply_gravity(delta)
		_move_and_slide_local(delta)
		return

	_handle_time_scale(delta)
	_handle_input(delta)
	_handle_movement(delta)
	_handle_scarf(delta)

# ---------------------------------------------------------------------------
# Time scale handling
# ---------------------------------------------------------------------------
func _handle_time_scale(delta: float) -> void:
	var scale: float = TimeManager.get_time_scale() if TimeManager != null else 1.0
	_tick(delta * scale)

# NOTE: _tick holds the per-frame logic so time-scale scaling works.
func _tick(delta: float) -> void:
	_update_timers(delta)
	_update_i_frames(delta)

func _update_timers(delta: float) -> void:
	_coyote_timer = max(0.0, _coyote_timer - delta)
	_jump_buffer_timer = max(0.0, _jump_buffer_timer - delta)
	_dash_cooldown = max(0.0, _dash_cooldown - delta)
	_dash_timer = max(0.0, _dash_timer - delta)
	_wall_slide_timer = max(0.0, _wall_slide_timer - delta)

func _update_i_frames(delta: float) -> void:
	_iframes = max(0.0, _iframes - delta)

# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------
func _handle_input(delta: float) -> void:
	# Jump buffering.
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = JUMP_BUFFER

	# Phase-Dash.
	if dash_unlocked and Input.is_action_just_pressed("dash") and _dash_cooldown <= 0.0 \
			and not  _is_dashing():
		_start_dash()

	# Kinetic Bash / Grapple / Melee delegate to CombatController.
	if has_node("/root/CombatController"):
		pass  # CombatController reads input directly.

# ---------------------------------------------------------------------------
# Movement
# ---------------------------------------------------------------------------
func _handle_movement(delta: float) -> void:
	var input_x := _get_input_x()

	# Horizontal acceleration — skipped while an external system (dash,
	# bash launch, grapple zip) has locked the velocity.
	if not  _velocity_locked:
		var target_speed := MAX_RUN_SPEED_TITAN if is_titan_form else MAX_RUN_SPEED
		if input_x != 0.0:
			_facing = 1 if input_x > 0.0 else -1
			_velocity.x = _approach(_velocity.x, input_x * target_speed, 2400.0 * delta)
		else:
			_velocity.x = _approach(_velocity.x, 0.0, 2000.0 * delta)

	# Wall detection.
	_update_wall_state()

	# Gravity with wall-slide clamp.
	if not  is_on_floor():
		_velocity.y += GRAVITY * delta
		if _on_wall_left or _on_wall_right:
			_wall_slide_timer = 0.05
			if _wall_slide_timer > 0.0 and _velocity.y > WALL_SLIDE_MAX_VY:
				_velocity.y = WALL_SLIDE_MAX_VY

	# Jump execution (buffered + coyote).
	if _jump_buffer_timer > 0.0:
		if is_on_floor() or _coyote_timer > 0.0:
			_perform_jump()
			_jump_buffer_timer = 0.0
		elif _air_jumps_used < _max_air_jumps():
			_perform_jump()
			_jump_buffer_timer = 0.0

	if is_on_floor():
		_coyote_timer = COYOTE_TIME
		_air_jumps_used = 0
		_on_wall_left = false
		_on_wall_right = false

	# Wall-kick.
	if Input.is_action_just_pressed("jump") and (_on_wall_left or _on_wall_right):
		if wall_jump_unlocked and not  is_on_floor():
			_velocity = _facing * WALL_KICK_VELOCITY
			_air_jumps_used = _max_air_jumps() - 1
			_jump_buffer_timer = 0.0

	# Commit velocity.
	velocity = _velocity
	move_and_slide()
	# Release the velocity lock once the dash is over so normal input resumes.
	if not  _is_dashing():
		_velocity_locked = false

func _get_input_x() -> float:
	var x := 0.0
	if Input.is_action_pressed("move_left"):
		x -= 1.0
	if Input.is_action_pressed("move_right"):
		x += 1.0
	return x

func _max_air_jumps() -> int:
	return DOUBLE_JUMP_COUNT_TRIPLE if triple_jump_unlocked else DOUBLE_JUMP_COUNT

func _perform_jump() -> void:
	_velocity.y = JUMP_VELOCITY
	if not  is_on_floor():
		_air_jumps_used += 1
	_coyote_timer = 0.0

# ---------------------------------------------------------------------------
# Phase-Dash
# ---------------------------------------------------------------------------
func _is_dashing() -> bool:
	return _dash_timer > 0.0

func _start_dash() -> void:
	_dash_timer = PHASE_DASH_DURATION
	_iframes = PHASE_DASH_IFRAMES
	_dash_cooldown = PHASE_DASH_COOLDOWN
	set_external_velocity(Vector2(_facing * PHASE_DASH_SPEED, _velocity.y))
	dash_executed.emit()

# Public: set velocity and lock it so _handle_movement won't overwrite it
# this frame (used by dash, Kinetic Bash launch, and Grapple zip).
# Named set_external_velocity to avoid overriding CharacterBody2D.set_velocity.
func set_external_velocity(vel: Vector2) -> void:
	_velocity = vel
	_velocity_locked = true

# ---------------------------------------------------------------------------
# Ability reset (mid-air melee hit, bash, grapple)
# ---------------------------------------------------------------------------
func reset_air_ability() -> void:
	_air_jumps_used = 0
	_dash_cooldown = 0.0
	air_jump_reset.emit()

func _apply_gravity(delta: float) -> void:
	if not  is_on_floor():
		_velocity.y += GRAVITY * delta

func _move_and_slide_local(delta: float) -> void:
	velocity = _velocity
	move_and_slide()

# ---------------------------------------------------------------------------
# Wall state
# ---------------------------------------------------------------------------
func _update_wall_state() -> void:
	_on_wall_left = false
	_on_wall_right = false
	if not  is_on_floor():
		var left := _wall_query(Vector2(-2.0, 0.0))
		var right := _wall_query(Vector2(2.0, 0.0))
		_on_wall_left = left
		_on_wall_right = right

func _wall_query(offset: Vector2) -> bool:
	var ray := RayCast2D.new()
	ray.enabled = true
	# RayCast2D position is relative to its parent (this player node),
	# so use the offset directly rather than the global position.
	ray.position = offset
	ray.target_position = Vector2(offset.x * 3.0, 0.0)
	ray.collision_mask = ~PHYSICS_LAYER_PLAYER
	ray.disabled = false
	add_child(ray)
	# A RayCast2D needs at least one physics tick to process after being
	# added to the tree; force an immediate update before querying.
	ray.force_raycast_update()
	var hit := ray.is_colliding()
	ray.queue_free()
	return hit

# ---------------------------------------------------------------------------
# Scarf Verlet
# ---------------------------------------------------------------------------
func _handle_scarf(delta: float) -> void:
	if _scarf_point == null:
		return
	var target: Vector2 = global_position + Vector2(_facing * 14.0, -8.0)
	var dir := target - _scarf_pos
	_scarf_vel += dir * 28.0 * delta
	_scarf_vel *= 0.88
	_scarf_pos += _scarf_vel * delta
	_scarf_point.global_position = _scarf_pos

# ---------------------------------------------------------------------------
# IK aiming
# ---------------------------------------------------------------------------
func aim_towards(world_point: Vector2) -> void:
	if _skeleton == null or _skeleton.get_bone_count() < 2:
		return
	var aim_dir := world_point - global_position
	var bone_idx: int = _skeleton.find_bone("aim_bone")
	if bone_idx >= 0:
		var angle := aim_dir.angle()
		_skeleton.set_bone_pose_rotation(bone_idx, angle)

# ---------------------------------------------------------------------------
# Combat interface
# ---------------------------------------------------------------------------
func take_damage(amount: float) -> bool:
	if _iframes > 0.0:
		return false
	hp = max(0.0, hp - amount)
	return true

func heal(amount: float) -> void:
	hp = min(max_hp, hp + amount)

func is_alive() -> bool:
	return hp > 0.0

func _approach(current: float, target: float, max_step: float) -> float:
	if current < target:
		return min(current + max_step, target)
	return max(current - max_step, target)
