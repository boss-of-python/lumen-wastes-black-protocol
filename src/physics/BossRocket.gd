# BossRocket.gd
# Boss rocket projectile. Bashable: Kinetic Bash flings it at 1.45x speed
# and it deals bash damage (120) to enemies on impact.
extends Area2D

@export var speed: float = 420.0
@export var bash_damage: float = 120.0

var velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("boss_rocket")

func _process(delta: float) -> void:
	global_position += velocity * delta

func set_velocity(new_velocity: Vector2) -> void:
	velocity = new_velocity

func _on_body_entered(body: Node) -> void:
	if body.has_group("player") or body.has_group("enemy"):
		if body.has_method("take_damage"):
			body.call("take_damage", bash_damage)
	if AudioDirector != null:
		AudioDirector.play_sfx("explosion")
	queue_free()
