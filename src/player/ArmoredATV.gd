# ArmoredATV.gd
extends RigidBody2D

const WHEEL_RADIUS: float = 22.0
const WHEEL_BASE: float = 70.0
const ENGINE_FORCE: float = 1400.0
const MAX_SPEED: float = 520.0
const BOOST_FORCE: float = 2200.0
const BOOST_MAX: float = 100.0
const BOOST_DRAIN: float = 45.0
const BOOST_REGEN: float = 8.0
const TURN_TORQUE: float = 900.0

@onready var _chassis: CollisionShape2D = $Chassis/CollisionShape2D if has_node("Chassis/CollisionShape2D") else null
@onready var _front_wheel: RigidBody2D = $FrontWheel if has_node("FrontWheel") else null
@onready var _rear_wheel: RigidBody2D = $RearWheel if has_node("RearWheel") else null
@onready var _front_joint: PinJoint2D = $FrontWheelJoint if has_node("FrontWheelJoint") else null
@onready var _rear_joint: PinJoint2D = $RearWheelJoint if has_node("RearWheelJoint") else null
@onready var _turret: Node2D = $RoofTurret if has_node("RoofTurret") else null
@onready var _boost_bar: ProgressBar = $BoostBar if has_node("BoostBar") else null

var boost_charge: float = BOOST_MAX
var _is_boosting: bool = false

func _ready() -> void:
	set_physics_process(true)
	if _front_joint != null:
		_front_joint.local_a = Vector2(-WHEEL_BASE / 2.0, WHEEL_RADIUS)
	if _rear_joint != null:
		_rear_joint.local_a = Vector2(WHEEL_BASE / 2.0, WHEEL_RADIUS)
	add_to_group("vehicle")

func _physics_process(delta: float) -> void:
	_regen_boost(delta)
	_handle_drive(delta)
	_update_boost_bar()

func _regen_boost(delta: float) -> void:
	if not _is_boosting:
		boost_charge = min(BOOST_MAX, boost_charge + BOOST_REGEN * delta)

func _handle_drive(delta: float) -> void:
	var throttle: float = Input.get_axis("move_left", "move_right")
	var turn: float = Input.get_axis("move_left", "move_right")
	var want_boost := Input.is_action_pressed("vehicle_boost") and boost_charge > 1.0
	if want_boost:
		_is_boosting = true
		boost_charge = max(0.0, boost_charge - BOOST_DRAIN * delta)
	else:
		_is_boosting = false
	var force := ENGINE_FORCE
	if _is_boosting:
		force = BOOST_FORCE
	var forward := global_transform.x.normalized()
	if forward.x < 0.0:
		forward = -forward
	apply_central_force(forward * force * throttle * delta)
	if _front_wheel != null:
		_front_wheel.apply_torque(throttle * force * WHEEL_RADIUS * delta)
	if _rear_wheel != null:
		_rear_wheel.apply_torque(throttle * force * WHEEL_RADIUS * delta)
	if _is_boosting:
		turn *= 0.8
	apply_torque(-turn * TURN_TORQUE * delta)
	if linear_velocity.length() > MAX_SPEED:
		linear_velocity = linear_velocity.normalized() * MAX_SPEED

func _update_boost_bar() -> void:
	if _boost_bar != null:
		_boost_bar.value = boost_charge / BOOST_MAX * 100.0

func is_boosting() -> bool:
	return _is_boosting

func get_turret() -> Node2D:
	return _turret

func aim_turret(world_point: Vector2) -> void:
	if _turret != null:
		var angle := (world_point - _turret.global_position).angle()
		_turret.rotation = angle

func take_damage(amount: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("take_damage"):
		player.call("take_damage", amount * 0.5)
