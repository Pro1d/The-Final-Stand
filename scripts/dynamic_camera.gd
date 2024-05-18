extends Camera2D

@export var dynamic_strength := 48.0
@export var dynamic_enabled := true :
	set(d):
		dynamic_enabled = d
		if not d:
			position = Vector2.ZERO

func _process(_delta: float) -> void:
	if dynamic_enabled:
		#var cursor_pos := Config.mouse_global_position()
		var vp_rect := get_viewport_rect()
		var vp_center := vp_rect.get_center()
		var vp_cursor := get_viewport().get_mouse_position()
		position = (vp_cursor - vp_center).limit_length(dynamic_strength)
