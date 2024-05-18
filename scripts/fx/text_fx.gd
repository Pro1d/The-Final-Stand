class_name TextFx
extends Node2D

const CHAR_OFFSET := 4

var _sprites : Array[AnimatedSprite2D]

@export var color := Color.WHITE : set=_set_color
@export var text := "" : set=_set_text

@onready var _line := %Line as Node2D
@onready var _rounded := %Rounded as Node2D
@onready var _prefix := %Prefix as AnimatedSprite2D
var _char_count := 0
var _prefix_width := 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for c: AnimatedSprite2D in _line.get_children():
		if c != null and c.name != "Prefix":
			c.position.x = _sprites.size() * CHAR_OFFSET
			c.pause()
			_sprites.append(c)
	_prefix.pause()
	color = color
	text = text
	
	const T := 1.0
	var tween := create_tween()
	(%Anchor as Node2D).scale = Vector2.ONE * 0.3
	tween.tween_property(%Anchor, "scale", Vector2.ONE, T * .25).from_current() \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_interval(T * .7)
	tween.tween_property(%Anchor, "scale", Vector2.ZERO, T * .1) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(queue_free)

func show_prefix(s: String) -> void:
	if _prefix.sprite_frames.has_animation(s):
		_prefix.play(s)
		_prefix.show()
		var size := _prefix.sprite_frames.get_frame_texture(s, 0).get_size()
		_prefix.offset.x = -size.x
		_prefix_width = size.x + 1
	else:
		print("no animation for -", s, "-")
		_prefix.hide()
		_prefix_width = 0
	_center()
		
func _set_color(c: Color) -> void:
	color = c
	if _line == null:
		return
	
	var mat := (_line.material as ShaderMaterial)
	mat.set_shader_parameter("color", Color(c.r, c.g, c.b, 1.0))

func _set_text(s: String) -> void:
	text = s
	if _line == null:
		return
	const table := "0123456789*?!ABCDEFGHIJKLMNOPQRSTUVWXYZ+abcdefghijklmnopqrstuvwxyz "
	var i := 0
	for c in s:
		var ti := table.find(c)
		if ti >= 0:
			_sprites[i].frame = ti
			i += 1
			if i >= _sprites.size():
				break
	_char_count = i
	for j in range(_sprites.size()):
		_sprites[j].visible = (j < _char_count)
	_center()

func _center() -> void:
	_line.position.x = -(_char_count * CHAR_OFFSET + 1) / 2 + _prefix_width / 2

func _process(_delta: float) -> void:
	_rounded.position = Vector2.ZERO
	_rounded.global_position = _rounded.global_position.round()

static func create(p: String, t: String, c: Color, pos: Vector2) -> TextFx:
	const TextFxScene := preload("res://scenes/fx/text_fx.tscn")
	var node := TextFxScene.instantiate() as TextFx
	node.color = c
	node.text = t
	Config.root_2d.add_child(node)
	node.show_prefix(p)
	node.global_position = pos
	return node
