extends Node

const CursorNormalIcon := preload("res://resources/textures/cursor_normal.atlastex")

const LAYER_ENEMY_PICK := 1 << 3
const LAYER_ENEMY_HITBOX := 1 << 4
const CASTLE_MAX_HP := 80
const MAX_ENEMIES := 100

const BOSS_SCORE := 10000

const level_per_index := 2
const combo_max_level := 7 # # 0=1 > 2 > 3 > 4
const combo_index_max := combo_max_level / level_per_index
const combo_level_name : Array[String] = ["calm", "wild", "brutal", "wrathful"]
const combo_level_factor : Array[int] = [1,2,4,8]
func to_combo_index(c: int) -> int: return clampi(c / level_per_index, 0, combo_index_max)
func get_combo_color(cl: int) -> Color:
	return Color.WHITE if cl == 0 else Color(0.847, 0.63, 0.7).lerp(
		Color(0.644, 0, 0.295), clampf(inverse_lerp(1, combo_max_level, cl), 0, 1))
func downgrade_combo_level(cl: int) -> int:
	return maxi(0, (cl / level_per_index - 1) * level_per_index)

var player_node : Player
var castle_node : Castle
var root_2d : Map2D

var hyplay : Dictionary

func _enter_tree() -> void:
	Input.set_custom_mouse_cursor(
		CursorNormalIcon, Input.CURSOR_ARROW, Vector2(6, 6)
	)
	hyplay = JSON.parse_string(FileAccess.get_file_as_string("res://keys.json"))

func _ready() -> void:
	var keys : Dictionary = hyplay
	Hyplay.auth = keys["x-auth"]
	Hyplay.app_auth = keys["x-app-auth"]

func viewport_to_global(screen_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos

func mouse_global_position() -> Vector2:
	return viewport_to_global(get_viewport().get_mouse_position())
