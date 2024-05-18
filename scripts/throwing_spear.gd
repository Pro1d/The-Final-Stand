@tool
class_name ThrowingSpear
extends Node2D

@export var direction := 0.0: set=_set_direction

@onready var _sprite := $SpearSprite as AnimatedSprite2D
@onready var _material := _sprite.material as ShaderMaterial
@onready var _peak_marker := %PeakMarker2D as Node2D

var _quadrant := 0
var _hightlight_tween : Tween
var _stick_to_node : Node2D
var _stick_offset : Vector2

func _ready() -> void:
	_set_direction(direction)

func _set_direction(angle: float) -> void:
	_quadrant = clampi(roundi(wrapf(angle, -PI / 4, 7 * PI / 4) / (PI / 2)), 0, 3)
	var a8 := clampi(roundi(wrapf(angle, -PI / 8, 15 * PI / 8) / (PI / 4)), 0, 7)
	#_sprite.rotation = (~_quadrant & 1) * PI / 2
	#_sprite.flip_v = ((_quadrant & 1) ^ (_quadrant >> 1)) == 1
	_sprite.flip_h = (_quadrant == 2)
	direction = angle
	_sprite.rotation = a8 * PI / 4 + PI / 2

func peak_position() -> Vector2:
	return _sprite.transform * _peak_marker.position

func make_highlight(duration: float) -> void:
	if _hightlight_tween != null:
		_hightlight_tween.kill()
		
	var color := Color(1, 1, 1)
	var transparent := Color(1, 1, 1, 0)
	
	_hightlight_tween = create_tween()
	_hightlight_tween.tween_method(
		func(c: Color) -> void: _material.set_shader_parameter("color", c),
		color, transparent, duration) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

func is_sticked() -> bool:
	return _stick_to_node != null

func stick_to(node: Node2D, offset: Vector2) -> void:
	_stick_to_node = node
	_stick_offset = offset
	top_level = true

func unstick() -> void:
	_stick_to_node = null
	top_level = false

func _process(_delta: float) -> void:
	if _stick_to_node != null:
		global_position = _stick_offset + _stick_to_node.global_position
