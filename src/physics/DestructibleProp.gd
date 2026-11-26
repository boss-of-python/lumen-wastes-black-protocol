# DestructibleProp.gd
# Crates, explosive barrels, and daisy-chain dynamite.
# Explosive barrels: radius 130, damage 90. Daisy chains propagate to
# other linked barrels within the blast radius.
extends Area2D

const BARREL_BLAST_RADIUS: float = 130.0
const BARREL_BLAST_DAMAGE: float = 90.0
const CRATE_HP: float = 30.0
const DYNAMITE_FUSE: float = 1.2

enum PropKind { CRATE, BARREL, DYNAMITE }

@export var prop_kind: PropKind = PropKind.CRATE
@export var max_hp: float = CRATE_HP
@export var linked_barrels: Array[Node] = []

var hp: float = 0.0
var _dynamite_timer: float = 0.0
var _dynamite_armed: bool = false

signal destroyed()
signal barrel_exploded(origin: Node)

func _ready() -> void:
	if prop_kind == PropKind.BARREL:
		add_to_group("bashable_barrel")
	if prop_kind == PropKind.DYNAMITE:
		_dynamite_timer = DYNAMITE_FUSE
	hp = max_hp

func _process(delta: float) -> void:
	if prop_kind == PropKind.DYNAMITE and _dynamite_armed:
		_dynamite_timer -= delta
		if _dynamite_timer <= 0.0:
			explode_barrel(self)

func take_damage(amount: float) -> void:
	if prop_kind == PropKind.BARREL:
		# Barrels rupture when damaged enough.
		hp -= amount
		if hp <= 0.0:
			explode_barrel(self)
		return
	hp -= amount
	if hp <= 0.0:
		_destroy_crate()

func apply_bash_launch(direction: Vector2) -> void:
	if prop_kind == PropKind.BARREL:
		# Bash launches the barrel; it explodes on impact.
		var body := get_parent() as RigidBody2D
		if body != null:
			body.apply_central_impulse(direction * 300.0)
		_dynamite_armed = true
		_dynamite_timer = DYNAMITE_FUSE
	else:
		var body := get_parent() as RigidBody2D
		if body != null:
			body.apply_central_impulse(direction * 220.0)

func explode_barrel(origin: Node) -> void:
	if not  is_inside_tree():
		return
	# Damage everything within blast radius.
	var tree := get_tree()
	for node in tree.get_nodes_in_group("enemy"):
		if global_position.distance_to(node.global_position) <= BARREL_BLAST_RADIUS:
			if node.has_method("take_damage"):
				node.take_damage(BARREL_BLAST_DAMAGE)
	for node in tree.get_nodes_in_group("player"):
		if global_position.distance_to(node.global_position) <= BARREL_BLAST_RADIUS:
			if node.has_method("take_damage"):
				node.take_damage(BARREL_BLAST_DAMAGE)

	# Daisy-chain: propagate to linked barrels.
	for linked in linked_barrels:
		if linked != null and linked.is_inside_tree() and linked != origin:
			if global_position.distance_to(linked.global_position) <= BARREL_BLAST_RADIUS:
				if linked.has_method("explode_barrel"):
					var delay := float(global_position.distance_to(linked.global_position)) / 200.0
					await get_tree().create_timer(delay).timeout
					linked.explode_barrel(linked)

	if AudioDirector != null:
		AudioDirector.play_sfx("explosion")
	if TimeManager != null:
		TimeManager.trigger_hit_stop(40)
	barrel_exploded.emit(origin)
	queue_free()

func _destroy_crate() -> void:
	if AudioDirector != null:
		AudioDirector.play_sfx("melee")
	destroyed.emit()
	queue_free()
