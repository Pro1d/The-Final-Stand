class_name TroopsSpawner
extends Node2D

enum Level { EASY, MEDIUM, HARD, MAX, BOSS }

@export var spawn_nodes : Array[Node2D]

var _troops : Dictionary = {
	Level.EASY: [],
	Level.MEDIUM: [],
	Level.HARD: [],
	Level.MAX: [],
	Level.BOSS: []
}

var _last_spawn_time : Array[float]
var _time := 0.0
const MIN_SPAWN_DELAY := 5.5 * 16 / 10.0  # s = tile * px / enemy_speed

func _enter_tree() -> void:
	pass #global_position = Vector2.ONE * 1000000

func _ready() -> void:
	_last_spawn_time.resize(spawn_nodes.size())
	_last_spawn_time.fill(-1000.0)
	for c: Node2D in get_children():
		if c == null: continue
		var l := Level.EASY
		if c.name.begins_with("Easy"):
			l = Level.EASY
		elif c.name.begins_with("Intermediate"):
			l = Level.MEDIUM
		elif c.name.begins_with("Hard"):
			l = Level.HARD
		elif c.name.begins_with("Insane"):
			l = Level.MAX
		elif c.name.begins_with("Boss"):
			l = Level.BOSS
		else:
			printerr("unknown troops level: ", c.name)
		(_troops[l] as Array).append(c)

func _physics_process(delta: float) -> void:
	_time += delta

func make_troops(allowed_levels: Array) -> Array[Enemy]: # Array[Level]
	# Random level
	var l := allowed_levels.pick_random() as Level
	# Random Group
	var group := (_troops[l] as Array).pick_random() as Node2D
	# Random position
	var available_spawns : Array[int]
	for i in range(spawn_nodes.size()):
		if _time - _last_spawn_time[i] > MIN_SPAWN_DELAY:
			available_spawns.append(i)
	var enemies : Array[Enemy] = []
	
	if not available_spawns.is_empty():
		var sp_index := available_spawns.pick_random() as int
		_last_spawn_time[sp_index] = _time
		
		# Instantiate enemies
		var origin := spawn_nodes[sp_index].global_position
		var castle_center := Config.castle_node._center
		var orientation := origin.angle_to_point(castle_center)
		
		var dmax := 0.0
		var dir := origin.direction_to(castle_center)
		for ip: InstancePlaceholder in group.get_children():
			var p := ip.get_stored_values().get("position", Vector2.ZERO) as Vector2
			dmax = maxf(dmax, absf(p.rotated(orientation).cross(dir)))
		for ip: InstancePlaceholder in group.get_children():
			if ip == null: continue
			var clone := ip.create_instance() as Enemy
			var local_pos := clone.position.rotated(orientation)
			var pos := origin + local_pos
			clone.get_parent().remove_child(clone)
			Config.root_2d.add_child(clone)
			clone.target_castle = Config.castle_node
			clone.global_position = pos
			var i : Variant = Geometry2D.line_intersects_line(pos, dir, castle_center, dir.rotated(PI/2))
			if i is Vector2 and dmax > 1e-4:
				clone.follow_offset = Config.castle_node.ensure_inside(i as Vector2, dmax) - castle_center
			enemies.append(clone)
	
	return enemies
