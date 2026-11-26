# CreditsScreen.gd
# Cinematic rolling End Credits after every one of the 30 endings.
# Skippable after 3s, replayable from Main Menu. Displays the Ending Unlock
# Card (Ending #X / 30 Unlocked) and mandatory lead billing for
# Tarun Loganathan.
extends Control

const SKIP_DELAY: float = 3.0
const CREDIT_SPEED: float = 40.0  # px/s rolling speed

const BILLING_LINES: Array[String] = [
	"Created, Directed & Developed by: Tarun Loganathan",
	"",
	"Game Design, Narrative & 30-Ending Architecture: Tarun Loganathan",
	"",
	"100% Offline Mobile Edition • Powered by Godot 4",
]

@onready var _roll: Control = $RollingCredits if has_node("RollingCredits") else null
@onready var _unlock_card: Label = $UnlockCard if has_node("UnlockCard") else null
@onready var _skip_hint: Label = $SkipHint if has_node("SkipHint") else null

var _ending_id: int = -1
var _elapsed: float = 0.0
var _skippable: bool = false
var _roll_position: float = 0.0

signal credits_finished()

func _ready() -> void:
	_setup_credits()

func _process(delta: float) -> void:
	_elapsed += delta
	if _skippable:
		if Input.is_action_just_pressed("ui_cancel"):
			credits_finished.emit()
			get_tree().change_scene_to_file("res://src/ui/MainMenu.tscn")
			return
		if _skip_hint != null:
			_skip_hint.text = "Tap to skip"
		if _roll != null:
			_roll_position -= CREDIT_SPEED * delta
			_roll.position.y = _roll_position
		if _roll_position < -_roll.size.y - 400.0:
			credits_finished.emit()
			get_tree().change_scene_to_file("res://src/ui/MainMenu.tscn")

func show_credits(ending_id: int) -> void:
	_ending_id = ending_id
	_elapsed = 0.0
	_roll_position = 0.0
	_skippable = false
	_setup_credits()

func _setup_credits() -> void:
	if _roll != null:
		_roll.position.y = _roll_position
		# Build the rolling credit text.
		_roll.clear()
		var y_offset := 0.0
		for line in BILLING_LINES:
			var label := Label.new()
			label.text = line
			label.add_theme_font_size_override("font_size", 36)
			label.position = Vector2(0.0, y_offset)
			label.add_theme_color_override("font_color", Color(0.95, 0.87, 0.62))
			_roll.add_child(label)
			y_offset += 52.0
		# Padding so the roll starts off-screen above.
		_roll.position.y = 0.0

	# Ending Unlock Card.
	if _unlock_card != null:
		if _ending_id > 0:
			_unlock_card.text = "Ending #%d / 30 Unlocked" % _ending_id
			_unlock_card.modulate = Color(1.0, 0.84, 0.36)
		else:
			_unlock_card.text = ""

	# Skip hint appears after 3 seconds.
	if _skip_hint != null:
		_skip_hint.text = "Skip available in 3s"
	_skippable = false
	# Arm the skip timer.
	_skip_hint_timer()

func _skip_hint_timer() -> void:
	var timer := Timer.new()
	timer.wait_time = SKIP_DELAY
	timer.one_shot = true
	timer.timeout.connect(_on_skip_ready)
	add_child(timer)
	timer.start()

func _on_skip_ready() -> void:
	_skippable = true
	if _skip_hint != null:
		_skip_hint.text = "Tap to skip"
