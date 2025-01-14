extends Node
# This is a very simple script used in order to test if a 3D/2D spawner in a main scene works. 

@onready var spawner = $Spawner  # Get the spawner

func start_spawner():
	spawner.start_spawning()

func stop_spawner():
	spawner.stop_spawning()

# Example usage in game logic
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("start"):
		start_spawner()
	if event.is_action_pressed("stop"):
		stop_spawner()
	
	#Optional
	if event.is_action_pressed("exit"):
		get_tree().quit()
