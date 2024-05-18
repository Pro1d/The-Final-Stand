class_name HUD
extends Control

@onready var _health_range := %HealthRange as TextureProgressBar
@onready var _health_label := %HealthLabel as Label
@onready var _health_particles := %HealthCPUParticles2D as CPUParticles2D
@onready var _health_timer := %HealthCPUParticles2D/Timer as Timer
@onready var _score_container := %ScoreContainer as Control
@onready var _combo_label := %ComboLabel as Label
var _displayed_health := 0
var _displayed_score := 0
var _h_tween : Tween
var _s_tween : Tween

func _ready() -> void:
	# Health
	_health_range.max_value = Config.CASTLE_MAX_HP + 1
	_health_range.custom_minimum_size.x = Config.CASTLE_MAX_HP + 2
	_health_range.size.x = _health_range.custom_minimum_size.x
	_health_range.pivot_offset = _health_range.size / 2
	_update_particle_shape()
	_health_timer.timeout.connect(_health_particles.set_emitting.bind(false))
	_health_particles.get_parent().remove_child(_health_particles)
	_health_particles.emitting = false
	_health_particles.visible = false
	Config.root_2d.add_child(_health_particles)
	visibility_changed.connect(func() -> void:_health_particles.visible = visible)
	# Score
	_init_score_container()
	_display_score(_displayed_score)

func update_combo(combo_level: int) -> void:
	var combo_index :=Config.to_combo_index(combo_level)
	_combo_label.text = "%s x%d" % [
		Config.combo_level_name[combo_index],
		Config.combo_level_factor[combo_index],
	]
	_combo_label.modulate = Config.get_combo_color(combo_level)

func _update_particle_shape() -> void:
	_health_particles.emission_rect_extents.x = maxf(_displayed_health / 2, 1.0)

func _process(_delta: float) -> void:
	if visible:
		var vp := _health_range.get_global_transform_with_canvas() * Vector2(1 + _displayed_health / 2, 0)
		_health_particles.global_position = Config.viewport_to_global(vp)

func update_health(health: int) -> void:
	var diff := health - _displayed_health
	if diff < 0:
		_health_particles.emitting = true
		_health_timer.start()
		if _h_tween == null or not _h_tween.is_running():
			_h_tween = create_tween()
			_h_tween.tween_property(_health_range, "rotation", 0, 0.3) \
				.from(deg_to_rad(10) * ((randi() & 2) - 1)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SPRING)
	_health_label.text = str(health)
	_health_range.value = health
	_displayed_health = health
	_update_particle_shape()

func _init_score_container() -> void:
	var max_width := 0
	for c: Label in _score_container.get_children():
		assert(c != null)
		max_width = maxi(c.size.x, max_width)
	for c: Label in _score_container.get_children():
		c.custom_minimum_size.x = max_width

func update_score(score: int) -> void:
	if score < _displayed_score: # reset score
		_display_score(score)
	elif score != _displayed_score:
		if _s_tween != null:
			_s_tween.kill()
		_s_tween = create_tween()
		_s_tween.tween_method(_display_score, _displayed_score, score, 2.0) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func _display_score(score: int) -> void:
	# Make string
	var digits := _score_container.get_child_count()
	var text := str(score).lpad(digits, "0")
	if text.length() > digits:
		text = "999999999".substr(0, digits)
	# set Label text
	var i := 0
	for c: Label in _score_container.get_children():
		c.text = text[i]
		i += 1
	
	_displayed_score = score
