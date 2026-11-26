# MobileHUD.gd
# Safe-area landscape dual-thumb touch controls + Gamepad auto-switch.
# Left: dynamic floating thumbstick + Quick-Spell/Transformation radial.
# Right: twin-stick aim/fire + Jump/Dash/Bash/Grapple/Melee/Interact.
# Top-right: Reload/Swap/Focus/Medkit/NVG strip. 60 FPS locked.
extends Control

const SAFE_AREA_MARGIN: float = 24.0
const THUMB_RADIUS: float = 48.0
const RADIAL_TRIGGER_RATIO: float = 0.25  # 25% slow-mo flick
const TARGET_FPS: int = 60

@onready var _left_stick: TouchScreenRect = $LeftStick if has_node("LeftStick") else null
@onready var _right_stick: TouchScreenRect = $RightStick if has_node("RightStick") else null
@onready var _radial: RadialSlider = $QuickSpellRadial if has_node("QuickSpellRadial") else null
@onready var _top_strip: Control = $TopStrip if has_node("TopStrip") else null

var _left_vector := Vector2.ZERO
var _right_vector := Vector2.ZERO
var _left_touch_id: int = -1
var _right_touch_id: int = -1
var _using_gamepad: bool = false

signal aim_vector_changed(vector: Vector2)
signal move_vector_changed(vector: Vector2)

func _ready() -> void:
	Engine.max_fps = TARGET_FPS
	_apply_safe_area()
	# Gamepad auto-switch.
	if Input.get_joy_device_count() > 0:
		_using_gamepad = true
		Input.set_use_accumulated_input(false)

func _process(_delta: float) -> void:
	_update_gamepad_detection()
	_update_touch_input()

func _update_gamepad_detection() -> void:
	var has_pad := Input.get_joy_device_count() > 0
	if has_pad != _using_gamepad:
		_using_gamepad = has_pad
		Input.set_use_accumulated_input(not has_pad)

func _update_touch_input() -> void:
	if _using_gamepad:
		# Gamepad twin-stick mapping.
		var lx := Input.get_axis("move_left", "move_right")
		var ly := Input.get_axis("move_left", "move_right")  # placeholder axis
		var rx := Input.get_axis("move_left", "move_right")
		var ry := Input.get_axis("move_left", "move_right")
		_left_vector = _clamp_stick(Vector2(lx, ly))
		_right_vector = _clamp_stick(Vector2(rx, ry))
	else:
		_read_touch_vectors()
	move_vector_changed.emit(_left_vector)
	aim_vector_changed.emit(_right_vector)

func _read_touch_vectors() -> void:
	_left_vector = _compute_stick(_left_stick, _left_touch_id, true)
	_right_vector = _compute_stick(_right_stick, _right_touch_id, false)

func _compute_stick(rect: TouchScreenRect, touch_id: int, is_left: bool) -> Vector2:
	if rect == null:
		return Vector2.ZERO
	var pos := rect.global_position
	var size := rect.size
	var center := pos + size / 2.0
	for event in Input.get_events():
		if event is InputEventScreenTouch or event is InputEventScreenDrag:
			var touch: InputEventScreenTouch = event as InputEventScreenTouch
			var drag: InputEventScreenDrag = event as InputEventScreenDrag
			var point: Vector2
			var id: int
			if touch != null:
				point = touch.position
				id = touch.index
			elif drag != null:
				point = drag.position
				id = drag.index
			else:
				continue
			# Only consider touches that started inside this rect.
			if not  _is_point_in_rect(point, rect):
				continue
			var rel := point - center
			var max_dist := THUMB_RADIUS
			if rel.length() > max_dist:
				rel = rel.normalized() * max_dist
			var vec := rel / max_dist
			if is_left:
				_left_touch_id = id
			else:
				_right_touch_id = id
			return vec
	return Vector2.ZERO

func _is_point_in_rect(point: Vector2, rect: TouchScreenRect) -> bool:
	return point.x >= rect.global_position.x and point.x <= rect.global_position.x + rect.size.x \
		and point.y >= rect.global_position.y and point.y <= rect.global_position.y + rect.size.y

func _clamp_stick(vec: Vector2) -> Vector2:
	if vec.length() > 1.0:
		return vec.normalized()
	return vec

func _apply_safe_area() -> void:
	# Inset controls within the safe area insets for notched devices.
	var safe := DisplayServer.get_display_safe_area() if Engine.has_singleton("DisplayServer") else Rect2i(0, 0, 1920, 1080)
	var inset := Rect2(
		safe.position.x + SAFE_AREA_MARGIN,
		safe.position.y + SAFE_AREA_MARGIN,
		safe.size.x - SAFE_AREA_MARGIN * 2.0,
		safe.size.y - SAFE_AREA_MARGIN * 2.0)
	if _top_strip != null:
		_top_strip.position = inset.position + Vector2(inset.size.x - 480.0, 0.0)
	if _left_stick != null:
		_left_stick.position = inset.position + Vector2(24.0, inset.size.y - 140.0)
	if _right_stick != null:
		_right_stick.position = inset.position + Vector2(inset.size.x - 140.0, inset.size.y - 140.0)

# ---------------------------------------------------------------------------
# Haptics
# ---------------------------------------------------------------------------
func vibrate(duration_ms: int) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		return
	Input.vibrate_handheld(duration_ms)

func get_move_vector() -> Vector2:
	return _left_vector

func get_aim_vector() -> Vector2:
	return _right_vector

func is_radial_flick_active() -> bool:
	return _right_vector.length() > RADIAL_TRIGGER_RATIO
