class_name Projectile
extends CharacterBody2D

enum Type { ARROW=0, BOLT, NONE }
const TYPE_ANIM := [&"arrow", &"large_bolt"]
const MOVE_SPEED := 50.0

@export var direction := Vector2.RIGHT :
	set(d):
		direction = d
		if _sprite != null:
			_sprite.rotation = Quadrant.round_q4(d.angle()) + PI / 2
@export var type := Type.ARROW :
	set(t):
		type = t
		if _sprite != null:
			_sprite.animation = TYPE_ANIM[type]
@export var damage := 1

@onready var _sprite := %AnimatedSprite2D as AnimatedSprite2D

func _ready() -> void:
	type = type
	direction = direction
	
	# Auto delete after delay
	await get_tree().create_timer(5.0).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	var collision := move_and_collide(direction * MOVE_SPEED * delta)
	if collision != null:
		var castle := collision.get_collider() as Castle
		#var player := collision.get_collider() as Player
		if castle != null:
			castle.take_hit(damage)
		#elif player != null:
			#pass # player.take_hit(damage)
		
		# fx
		queue_free()
