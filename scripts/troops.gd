class_name Troops
extends Node2D

signal cleared

var _enemies : Array[Enemy]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_find_enemies(self)
	for e in _enemies:
		var pos := e.global_position
		e.get_parent().remove_child(e)
		Config.root_2d.add_child(e)
		e.global_position = pos
		e.target_castle = Config.castle_node
		e.died.connect(_on_enemy_left_battlefield.bind(e))
		#e.left_battlefield.connect(_on_enemy_left_battlefield.bind(e))

func _on_enemy_left_battlefield(e: Enemy) -> void:
	if e in _enemies:
		_enemies.erase(e)
		#e.queue_free()
		if _enemies.is_empty():
			cleared.emit()
			queue_free()

func _find_enemies(node: Node2D) -> void:
	if node == null:
		return
	if node is Enemy:
		_enemies.append(node)
	else:
		for c: Node2D in node.get_children():
			_find_enemies(c)

func get_enemies_count() -> int:
	return _enemies.size()

const patterns := {
	"": [Vector2i()]
}
static func make_troops(difficulty: int) -> int:
	return difficulty
