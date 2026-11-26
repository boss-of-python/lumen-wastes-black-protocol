# SplashScreen.gd
extends Control

const SPLASH_DURATION: float = 4.0
const BILLING_TEXT: String = "A GAME BY TARUN LOGANATHAN"
const DEV_FOOTER: String = "Developed & Created by Tarun Loganathan"
@onready var _title_label: Label = $SplashRoot/TitleLabel
@onready var _footer_label: Label = $SplashRoot/FooterLabel
var _finished := false

signal splash_finished()

func _ready() -> void:
	_footer_label.text = DEV_FOOTER
	_title_label.text = BILLING_TEXT
	_title_label.modulate = Color(1.0, 0.84, 0.36, 0.0)
	var tween := create_tween()
	tween.tween_property(_title_label, "modulate:a", 1.0, 1.2)
	tween.tween_interval(SPLASH_DURATION - 2.4)
	tween.tween_property(_title_label, "modulate:a", 0.0, 1.2)
	tween.tween_callback(_finish_splash)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_finish_splash()

func _finish_splash() -> void:
	if _finished:
		return
	_finished = true
	splash_finished.emit()
	get_tree().change_scene_to_file("res://src/ui/MainMenu.tscn")
