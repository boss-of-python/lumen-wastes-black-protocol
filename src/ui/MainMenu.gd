# MainMenu.gd
# Main menu with mandatory developer credit footer.
# Routes to New Game (slot 1), Continue (save slots), Gunsmith, Codex/Flowchart.
extends Control

const DEV_FOOTER: String = "Developed & Created by Tarun Loganathan"
const GAMEPLAY_SCENE: String = "res://src/levels/Act1Level.tscn"

@onready var _footer_label: Label = $FooterLabel if has_node("FooterLabel") else null
@onready var _continue_button: Button = $ContinueButton if has_node("ContinueButton") else null
@onready var _new_game_button: Button = $NewGameButton if has_node("NewGameButton") else null
@onready var _gunsmith_button: Button = $GunsmithButton if has_node("GunsmithButton") else null
@onready var _codex_button: Button = $CodexButton if has_node("CodexButton") else null

func _ready() -> void:
	if _footer_label != null:
		_footer_label.text = DEV_FOOTER
	if GameState != null:
		_refresh_continue_button()

func _refresh_continue_button() -> void:
	if _continue_button == null:
		return
	var has_save := false
	for i in GameState.SAVE_SLOTS:
		if not  GameState.is_slot_empty(i):
			has_save = true
			break
	_continue_button.disabled = not  has_save

func _on_new_game_pressed() -> void:
	GameState.save_to_slot(0, "New Game")
	get_tree().change_scene_to_file(GAMEPLAY_SCENE)

func _on_continue_pressed() -> void:
	for i in GameState.SAVE_SLOTS:
		if not  GameState.is_slot_empty(i):
			GameState.load_from_slot(i)
			get_tree().change_scene_to_file(GAMEPLAY_SCENE)
			return

func _on_gunsmith_pressed() -> void:
	get_tree().change_scene_to_file("res://src/ui/GunsmithUI.tscn")

func _on_codex_pressed() -> void:
	get_tree().change_scene_to_file("res://src/ui/DecisionFlowchartUI.tscn")
