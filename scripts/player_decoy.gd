class_name PlayerDecoy
extends Node2D


@onready var _sprite := (%Sprite2D as Sprite2D)

func _ready() -> void:
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.2) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	
	await tween.finished
	queue_free()

func set_facing(facing: Vector2) -> void:
	_sprite.flip_h = facing.x < 0
