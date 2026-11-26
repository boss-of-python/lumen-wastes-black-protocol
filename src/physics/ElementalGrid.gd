# ElementalGrid.gd
# Elemental hazard interactions, 100% offline deterministic:
#   - Oil pools ignite with fire (burning damage zones)
#   - Water pools + EMP chain-stun enemies
#   - Acid pools dissolve grates (destroy destructible props above)
extends Area2D

enum Element { OIL, WATER, ACID }

const BURN_DAMAGE: float = 14.0
const BURN_DURATION: float = 2.5
const CHAIN_STUN_DURATION: float = 1.5
const ACID_DISSOLVE_DAMAGE: float = 40.0
const CHAIN_STUN_RADIUS: float = 160.0

@export var element: Element = Element.OIL
@export var burn_rate: float = 0.5

var _ignited: bool = false
var _burn_timer: float = 0.0

signal ignited()
signal chain_stunned(targets: Array)
signal grate_dissolved(grate: Node)

func _ready() -> void:
	add_to_group("elemental_hazard")

func _on_enter_body(body: Node) -> void:
	if element == Element.OIL and not  _ignited:
		# Oil alone is harmless until ignited.
		return
	if element == Element.ACID:
		_dissolve_grate_above(body)
	if _ignited and element == Element.OIL:
		if body.has_method("take_damage"):
			body.call("take_damage", BURN_DAMAGE * burn_rate)

func _on_body_entered(body: Node) -> void:
	# Water + EMP interaction: any EMP source electrifies the pool.
	if element == Element.WATER and body.has_group("emp_source"):
		_chain_stun(body)

func ignite() -> void:
	if element != Element.OIL or _ignited:
		return
	_ignited = true
	_burn_timer = BURN_DURATION
	ignited.emit()
	if AudioDirector != null:
		AudioDirector.play_sfx("explosion")

func extinguish() -> void:
	_ignited = false
	_burn_timer = 0.0

func _process(delta: float) -> void:
	if _ignited:
		_burn_timer -= delta
		if _burn_timer <= 0.0:
			extinguish()

func _chain_stun(source: Node) -> void:
	var stunned: Array = []
	var tree := get_tree()
	for node in tree.get_nodes_in_group("enemy"):
		if global_position.distance_to(node.global_position) <= CHAIN_STUN_RADIUS:
			if node.has_method("stun"):
				node.call("stun", CHAIN_STUN_DURATION)
				stunned.append(node)
	chain_stunned.emit(stunned)
	if AudioDirector != null:
		AudioDirector.play_sfx("radio")

func _dissolve_grate_above(_body: Node) -> void:
	# Find destructible props above the pool and dissolve them.
	var tree := get_tree()
	for node in tree.get_nodes_in_group("destructible_prop"):
		if node.global_position.y >= global_position.y - 80.0 \
				and abs(node.global_position.x - global_position.x) <= 40.0:
			if node.has_method("take_damage"):
				node.call("take_damage", ACID_DISSOLVE_DAMAGE)
				grate_dissolved.emit(node)
