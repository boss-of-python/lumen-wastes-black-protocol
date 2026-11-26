# HangingGirder.gd
# Shootable PinJoint2D chains dropping crushing steel girders (dmg 200).
# The chain hangs from a ceiling anchor; shooting the pin severs it and
# the girder swings/falls onto enemies below.
extends RigidBody2D

const GIRDDER_DAMAGE: float = 200.0
const CHAIN_SEGMENTS: int = 4
const SEVE_RADIUS: float = 24.0

@export var sever_node: NodePath = "SeverPoint"

var _severed: bool = false
var _sever_point: Node2D = null
var _chain_joint: PinJoint2D = null
var _fall_timer: float = 0.0

signal girder_dropped()

func _ready() -> void:
	if sever_node != NodePath():
		_sever_point = get_node_or_null(sever_node)
	_find_chain_joint()
	add_to_group("destructible_girder")

func _find_chain_joint() -> void:
	var chain := get_parent() as Node
	if chain == null:
		return
	_chain_joint = chain.get_node_or_null("ChainPin") as PinJoint2D

func _on_sever_shot(_damage: float) -> void:
	sever_chain()

func sever_chain() -> void:
	if _severed:
		return
	_severed = true
	if _chain_joint != null:
		_chain_joint.disabled = true
	# Drop the girder onto enemies below.
	_fall_timer = 0.25
	girder_dropped.emit()
	if AudioDirector != null:
		AudioDirector.play_sfx("explosion")

func _process(delta: float) -> void:
	if not  _severed:
		return
	_fall_timer -= delta
	if _fall_timer <= 0.0:
		_crush_enemies()

func _crush_enemies() -> void:
	var tree := get_tree()
	for node in tree.get_nodes_in_group("enemy"):
		# Crushing zone: directly beneath the girder's horizontal span.
		if node.global_position.x >= global_position.x - 60.0 \
				and node.global_position.x <= global_position.x + 60.0:
			if node.global_position.y >= global_position.y - 10.0:
				if node.has_method("take_damage"):
					node.take_damage(GIRDDER_DAMAGE)
		if TimeManager != null:
			TimeManager.trigger_hit_stop(45)
	queue_free()
