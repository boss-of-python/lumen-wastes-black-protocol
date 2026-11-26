# SplashScreen.gd
# Opening animated splash: "A GAME BY TARUN LOGANATHAN"
# Auto-advances to the Main Menu after the intro animation.
extends Control

const SPLASH_DURATION: float = 4.0
const BILLING_TEXT: String = "A GAME BY TARUN LOGANATHAN"
const DEV_FOOTER: String = "Developed & Created by Tarun Loganathan"

@onready var _title_label: Label = $TitleLabel if has_node("TitleLabel") else null
@onready var _footer_label: Label = $FooterLabel if has_node("FooterLabel") else null
@onready var _splash_root: Control = $SplashRoot if has_node("SplashRoot") else self

var _intro_tween: Tween = null
var _skip_pressed: bool = false

signal splash_finished()

func _ready() -> void:
	_play_intro()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel") or _skip_pressed:
		_finish_splash()

func _play_intro() -> void:
	if _title_label != null:
		_title_label.text = BILLING_TEXT
		_title_label.modulate = Color(1.0, 0.84, 0.36)
	if _footer_label != null:
		_footer_label.text = DEV_FOOTER

	_intro_tween = create_tween()
	_intro_tween.set_chains_mode(Tween.CHAIN_SIMULTANEOUS)

	# Fade in the billing text with a glow pulse.
	if _title_label != null:
		_title_label.modulate.a = 0.0
		_intro_tween.tween_method(
			func(a: float) -> void: _title_label.modulate.a = a,
			0.0, 1.0, 1.4)
		# Scale pulse.
		var start_scale: Vector2 = Vector2(0.8, 0.8)
		_intro_tween.tween_method(
			func(s: Vector2) -> void: _title_label.scale = s,
			start_scale, Vector2(1.0, 1.0), 1.2)

	# Hold, then fade out and finish.
	_intro_tween.tween_interval(SPLASH_DURATION - 2.4)
	_intro_tween.tween_method(
		func(a: float) -> void: _title_label.modulate.a = a,
		1.0, 0.0, 1.2)
	_intro_tween.tween_callback(_finish_splash)

func _finish_splash() -> void:
	if _intro_tween != null:
		_intro_tween.kill()
	splash_finished.emit()
	# Transition to the main menu scene.
	get_tree().change_scene_to_file("res://src/ui/MainMenu.tscn")
