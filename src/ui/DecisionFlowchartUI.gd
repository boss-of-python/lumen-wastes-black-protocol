# DecisionFlowchartUI.gd
# Interactive branching flowchart + 30-Ending Codex.
# Visualizes the 5 strategic narrative layers across 18 crossroads,
# supports checkpoint jump-back, and shows the X / 30 Ending Codex.
extends Control

const ENDINGS_PATH: String = "res://data/endings.json"
const TOTAL_ENDINGS: int = 30

@onready var _flow_container: FlowContainer = $FlowChart if has_node("FlowChart") else null
@onready var _codex_label: Label = $CodexLabel if has_node("CodexLabel") else null
@onready var _progress_bar: ProgressBar = $CrossroadProgress if has_node("CrossroadProgress") else null

var _endings: Array = []
var _codex_unlocked: Array[int] = []

func _ready() -> void:
	_load_endings()
	_build_flowchart()
	_refresh_codex()

func _load_endings() -> void:
	if not  FileAccess.file_exists(ENDINGS_PATH):
		push_error("DecisionFlowchartUI: endings.json missing at %s" % ENDINGS_PATH)
		return
	# load() on a .json returns a JSON Resource, not a Dictionary — parse text.
	var f := FileAccess.open(ENDINGS_PATH, FileAccess.READ)
	if f == null:
		return
	var raw := f.get_as_text()
	f.close()
	var data: Variant = JSON.parse_string(raw)
	if typeof(data) != TYPE_DICTIONARY:
		return
	_endings = data.get("endings", [])

func _build_flowchart() -> void:
	if _flow_container == null:
		return
	_flow_container.clear()
	# Render one node per ending branch (A-F), grouped.
	var branches := {"A": [], "B": [], "C": [], "D": [], "E": [], "F": []}
	for e in _endings:
		var branch: String = e.get("branch", "?")
		if branches.has(branch):
			branches[branch].append(e)
	for branch in branches:
		var header := Label.new()
		header.text = "Branch %s" % branch
		header.add_theme_font_size_override("font_size", 22)
		_flow_container.add_child(header)
		for e in branches[branch]:
			var node := _make_ending_node(e)
			_flow_container.add_child(node)

func _make_ending_node(ending: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(260.0, 56.0)
	var id: int = ending["id"]
	var unlocked := GameState != null and GameState.is_ending_unlocked(id)
	btn.text = "%d. %s" % [id, ending.get("name", "")]
	btn.disabled = not  unlocked
	if unlocked:
		btn.modulate = Color(1.0, 0.84, 0.36)
	else:
		btn.modulate = Color(0.4, 0.4, 0.4)
	btn.tooltip_text = "Ending %d / %d" % [id, TOTAL_ENDINGS]
	return btn

func _refresh_codex() -> void:
	if _codex_label == null:
		return
	var unlocked_count := GameState.get_unlocked_count() if GameState != null else 0
	_codex_label.text = "Ending Codex: %d / %d Unlocked" % [unlocked_count, TOTAL_ENDINGS]

func jump_to_checkpoint(crossroad_id: int) -> void:
	if NarrativeStateManager != null:
		NarrativeStateManager.visit_crossroads(crossroad_id)

func select_strategy(strategy: String) -> void:
	if NarrativeStateManager == null:
		return
	# Clear previous strategy flags, then set the new one.
	NarrativeStateManager.set_flag("strategy_nvg_stealth", false)
	NarrativeStateManager.set_flag("strategy_loud_sabotage", false)
	NarrativeStateManager.set_flag("strategy_faction_hack", false)
	NarrativeStateManager.set_flag("strategy_" + strategy, true)
	_refresh_codex()

func resolve_current_ending() -> int:
	if NarrativeStateManager == null:
		return -1
	var ending_id := NarrativeStateManager.resolve_ending()
	if ending_id > 0 and GameState != null:
		GameState.unlock_ending(ending_id)
	_refresh_codex()
	return ending_id
