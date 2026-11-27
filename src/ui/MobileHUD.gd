# MobileHUD.gd
extends Control

const SAFE_AREA_MARGIN: float = 24.0
const THUMB_RADIUS: float = 48.0
const RADIAL_TRIGGER_RATIO: float = 0.25
const TARGET_FPS: int = 60

@onready var _left_stick: Control = $LeftStick
@onready var _right_stick: Control = $RightStick
@onready var _radial: Control = $QuickSpellRadial
@onready var _top_strip: Control = $TopStrip

var _left_vector := Vector2.ZERO
var _right_vector := Vector2.ZERO
var _left_touch_id: int = -1
var _right_touch_id: int = -1
var _left_origin := Vector2.ZERO
var _right_origin := Vector2.ZERO
var _using_gamepad: bool = false

signal aim_vector_changed(vector: Vector2)
signal move_vector_changed(vector: Vector2)

func _ready() -> void:
	Engine.max_fps = TARGET_FPS
	_apply_safe_area()
	_update_gamepad_detection()

func _process(_delta: float) -> void:
	_update_gamepad_detection()
	if _using_gamepad:
		var device := 0
		_left_vector = _clamp_stick(Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)))
		_right_vector = _clamp_stick(Vector2(Input.get_joy_axis(device, JOY_AXIS_RIGHT_X), Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y)))
	else:
		_read_touch_vectors()
	move_vector_changed.emit(_left_vector)
	aim_vector_changed.emit(_right_vector)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _left_touch_id < 0 and _is_point_in_control(touch.position, _left_stick):
				_left_touch_id = touch.index
				_left_origin = touch.position
			elif _right_touch_id < 0 and _is_point_in_control(touch.position, _right_stick):
				_right_touch_id = touch.index
				_right_origin = touch.position
		else:
			if touch.index == _left_touch_id:
				_left_touch_id = -1
				_left_vector = Vector2.ZERO
			if touch.index == _right_touch_id:
				_right_touch_id = -1
				_right_vector = Vector2.ZERO
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _left_touch_id:
			_left_vector = _stick_vector(drag.position, _left_origin)
		elif drag.index == _right_touch_id:
			_right_vector = _stick_vector(drag.position, _right_origin)

func _update_gamepad_detection() -> void:
	_using_gamepad = Input.get_connected_joypads().size() > 0

func _read_touch_vectors() -> void:
	# Screen-touch vectors are updated by _input().
	# Keep this function as a no-op unless additional touch state is available.
	pass

func _stick_vector(point: Vector2, origin: Vector2) -> Vector2:
	var offset := point - origin
	if offset.length() > THUMB_RADIUS:
		offset = offset.normalized() * THUMB_RADIUS
	return offset / THUMB_RADIUS

func _is_point_in_control(point: Vector2, control: Control) -> bool:
	return control.get_global_rect().has_point(point)

func _clamp_stick(vec: Vector2) -> Vector2:
	if vec.length() > 1.0:
		return vec.normalized()
	return vec

func _apply_safe_area() -> void:
	var safe := DisplayServer.get_display_safe_area()
	var viewport := get_viewport_rect().size
	if safe.size.x <= 0 or safe.size.y <= 0:
		return
	var scale := viewport / Vector2(DisplayServer.window_get_size())
	var inset := Rect2(Vector2(safe.position) * scale, Vector2(safe.size) * scale)
	if _top_strip != null:
		_top_strip.position = inset.position + Vector2(inset.size.x - 480.0, SAFE_AREA_MARGIN)
	if _left_stick != null:
		_left_stick.position = inset.position + Vector2(SAFE_AREA_MARGIN, inset.size.y - 220.0)
	if _right_stick != null:
		_right_stick.position = inset.position + Vector2(inset.size.x - 220.0, inset.size.y - 220.0)

func vibrate(duration_ms: int) -> void:
	if duration_ms > 0:
		Input.vibrate_handheld(duration_ms)

func get_move_vector() -> Vector2:
	return _left_vector

func get_aim_vector() -> Vector2:
	return _right_vector

func is_radial_flick_active() -> bool:
	return _right_vector.length() > RADIAL_TRIGGER_RATIO
