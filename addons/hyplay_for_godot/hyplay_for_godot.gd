@tool
extends EditorPlugin

# code for storing custom project settings panel, currently unused
# var ui: Control

func _enter_tree() -> void:
	# init
	
	# so in Godot, you have the "root" node which represents the main window
	# the currently loaded scene will be a child of the root
	# you can give the root more children that are loaded before the main scene and act as singletons, called "autoloads"
	# the advantage of these over static classes is that they have access to Node and SceneTree APIs
	# relevant to us is they know when a frame passes
	add_autoload_singleton("Hyplay", "./api.gd")

	# code for adding panel to project settings, currently unused
	# ui = preload("./config_ui.tscn").instantiate()
	# add_control_to_container(CONTAINER_PROJECT_SETTING_TAB_RIGHT, ui)


func _exit_tree() -> void:
	# cleanup
	remove_autoload_singleton("Hyplay")
	
	# code for removing panel from project settings, currently unused
	# remove_control_from_container(CONTAINER_PROJECT_SETTING_TAB_RIGHT, ui)
	# ui.queue_free()
