# DecisionFlowchartUI.gd
extends Control

const ENDINGS_PATH: String = "res://data/endings.json"
const TOTAL_ENDINGS: int = 30
@onready var _flow_container: FlowContainer = $FlowChart
@onready var _codex_label: Label = $CodexLabel
@onready var _progress_bar: ProgressBar = $CrossroadProgress
var _endings: Array = []

func _ready() -> void:
	_load_endings()
	_build_flowchart()
	_refresh_codex()

func _load_endings() -> void:
	var f := FileAccess.open(ENDINGS_PATH, FileAccess.READ)
	if f == null:
		push_error("DecisionFlowchartUI: endings.json cannot be opened")
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) == TYPE_DICTIONARY:
		_endings = data.get("endings", [])

func _build_flowchart() -> void:
	for child in _flow_container.get_children():
		_flow_container.remove_child(child)
		child.queue_free()
	var branches := {"A": [], "B": [], "C": [], "D": [], "E": [], "F": []}
	for ending in _endings:
		var branch: String = ending.get("branch", "?")
		if branches.has(branch):
			branches[branch].append(ending)
	for branch in branches:
		var header := Label.new()
		header.text = "Branch %s" % branch
		header.add_theme_font_size_override("font_size", 22)
		_flow_container.add_child(header)
		for ending in branches[branch]:
			_flow_container.add_child(_make_ending_node(ending))

func _make_ending_node(ending: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(260.0, 56.0)
	var id: int = ending["id"]
	var unlocked: bool = GameState.is_ending_unlocked(id)
	btn.text = "%d. %s" % [id, ending.get("name", "")]
	btn.disabled = not unlocked
	btn.modulate = Color(1.0, 0.84, 0.36) if unlocked else Color(0.4, 0.4, 0.4)
	btn.tooltip_text = "Ending %d / %d" % [id, TOTAL_ENDINGS]
	return btn

func _refresh_codex() -> void:
	_codex_label.text = "Ending Codex: %d / %d Unlocked" % [GameState.get_unlocked_count(), TOTAL_ENDINGS]
	_progress_bar.value = NarrativeStateManager.get_crossroads_progress() * 100.0

func jump_to_checkpoint(crossroad_id: int) -> void:
	NarrativeStateManager.visit_crossroads(crossroad_id)
	_refresh_codex()

func select_strategy(strategy: String) -> void:
	for key in ["strategy_nvg_stealth", "strategy_loud_sabotage", "strategy_faction_hack"]:
		NarrativeStateManager.set_flag(key, false)
	if strategy in ["nvg_stealth", "loud_sabotage", "faction_hack"]:
		NarrativeStateManager.set_flag("strategy_" + strategy, true)
	_refresh_codex()

func resolve_current_ending() -> int:
	var ending_id := NarrativeStateManager.resolve_ending()
	if ending_id > 0:
		GameState.unlock_ending(ending_id)
	_refresh_codex()
	return ending_id
