# TimeManager.gd
# Hit-stop (30-50ms) & slow-mo control:
#   10% scale = Kinetic Bash, 25% scale = Radial Focus, 35% scale = Focus mode.
# Drives the global time_scale used by gameplay systems.
extends Node

const HIT_STOP_MIN_MS: int = 30
const HIT_STOP_MAX_MS: int = 50

const SCALE_BASH: float = 0.10
const SCALE_RADIAL: float = 0.25
const SCALE_FOCUS: float = 0.35

const SCALE_NORMAL: float = 1.0

var _time_scale: float = SCALE_NORMAL
var _target_scale: float = SCALE_NORMAL
var _hit_stop_remaining: float = 0.0
var _slow_mo_remaining: float = 0.0
var _manual_slow_mo: bool = false

signal scale_changed(new_scale: float)

func _ready() -> void:
	Engine.max_fps = 60

func _process(delta: float) -> void:
	# Tick hit-stop first: time freezes completely while active.
	if _hit_stop_remaining > 0.0:
		_hit_stop_remaining -= delta
		_apply_scale(0.0)
		return

	# Tick slow-mo timer.
	if _slow_mo_remaining > 0.0:
		_slow_mo_remaining -= delta
		if _slow_mo_remaining <= 0.0:
			_slow_mo_remaining = 0.0
			_manual_slow_mo = false

	if _manual_slow_mo:
		_apply_scale(_target_scale)
	else:
		_apply_scale(SCALE_NORMAL)

# ---------------------------------------------------------------------------
# Hit-stop
# ---------------------------------------------------------------------------
func trigger_hit_stop(duration_ms: int = -1) -> void:
	var ms: int = duration_ms
	if ms <= 0:
		ms = randf_range(HIT_STOP_MIN_MS, HIT_STOP_MAX_MS)
	ms = clampi(ms, HIT_STOP_MIN_MS, HIT_STOP_MAX_MS)
	_hit_stop_remaining = max(_hit_stop_remaining, float(ms) / 1000.0)

func is_in_hit_stop() -> bool:
	return _hit_stop_remaining > 0.0

# ---------------------------------------------------------------------------
# Slow-mo
# ---------------------------------------------------------------------------
func activate_slow_mo(scale: float, duration: float = 0.0) -> void:
	if scale <= 0.0 or scale >= SCALE_NORMAL:
		return
	_target_scale = scale
	_manual_slow_mo = true
	if duration > 0.0:
		_slow_mo_remaining = duration

func activate_bash_slow_mo(duration: float = 0.75) -> void:
	activate_slow_mo(SCALE_BASH, duration)

func activate_radial_slow_mo(duration: float = 2.0) -> void:
	activate_slow_mo(SCALE_RADIAL, duration)

func activate_focus_slow_mo(duration: float = 0.0) -> void:
	activate_slow_mo(SCALE_FOCUS, duration)

func release_slow_mo() -> void:
	_manual_slow_mo = false
	_slow_mo_remaining = 0.0

func is_in_slow_mo() -> bool:
	return _manual_slow_mo

# ---------------------------------------------------------------------------
# Accessors
# ---------------------------------------------------------------------------
func _apply_scale(scale: float) -> void:
	if is_similar(_time_scale, scale):
		return
	_time_scale = scale
	scale_changed.emit(_time_scale)

func get_time_scale() -> float:
	return _time_scale

func apply_scale_override(scale: float) -> void:
	_apply_scale(clamp(scale, 0.0, SCALE_NORMAL))
