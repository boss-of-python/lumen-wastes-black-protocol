# CreditsScreen.gd
extends Control

const SKIP_DELAY: float = 3.0
const CREDIT_SPEED: float = 40.0
const MAIN_MENU_SCENE := "res://src/ui/MainMenu.tscn"
const BILLING_LINES: Array[String] = [
	"Created, Directed & Developed by: Tarun Loganathan",
	"",
	"Game Design, Narrative & 30-Ending Architecture: Tarun Loganathan",
	"",
	"100% Offline Mobile Edition • Powered by Godot 4",
]

@onready var _roll: Control = $RollingCredits
@onready var _unlock_card: Label = $UnlockCard
@onready var _skip_hint: Label = $SkipHint
var _ending_id: int = -1
var _roll_position: float = 0.0
var _skip_timer: Timer
var _finished := false
signal credits_finished()

func _ready() -> void:
	_setup_credits()

func _process(delta: float) -> void:
	if not _finished and _skip_timer != null and _skip_timer.is_stopped():
		_roll_position -= CREDIT_SPEED * delta
		_roll.position.y = _roll_position
		if _roll_position < -_roll.size.y - 400.0:
			_finish_credits()

func _unhandled_input(event: InputEvent) -> void:
	if _skip_timer != null and _skip_timer.is_stopped() and (event.is_action_pressed("ui_cancel") or event is InputEventScreenTouch and event.pressed):
		_finish_credits()

func show_credits(ending_id: int) -> void:
	_ending_id = ending_id
	_roll_position = 0.0
	_finished = false
	_setup_credits()

func _setup_credits() -> void:
	for child in _roll.get_children():
		_roll.remove_child(child)
		child.queue_free()
	var y_offset := 0.0
	for line in BILLING_LINES:
		var label := Label.new()
		label.text = line
		label.add_theme_font_size_override("font_size", 36)
		label.position = Vector2(0.0, y_offset)
		label.add_theme_color_override("font_color", Color(0.95, 0.87, 0.62))
		_roll.add_child(label)
		y_offset += 52.0
	_roll.position.y = 0.0
	_roll.size.y = y_offset
	_unlock_card.text = "Ending #%d / 30 Unlocked" % _ending_id if _ending_id > 0 else ""
	_unlock_card.modulate = Color(1.0, 0.84, 0.36)
	_skip_hint.text = "Skip available in 3s"
	if _skip_timer != null:
		_skip_timer.queue_free()
	_skip_timer = Timer.new()
	_skip_timer.one_shot = true
	_skip_timer.wait_time = SKIP_DELAY
	_skip_timer.timeout.connect(_on_skip_ready)
	add_child(_skip_timer)
	_skip_timer.start()

func _on_skip_ready() -> void:
	_skip_hint.text = "Tap to skip"

func _finish_credits() -> void:
	if _finished:
		return
	_finished = true
	credits_finished.emit()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
