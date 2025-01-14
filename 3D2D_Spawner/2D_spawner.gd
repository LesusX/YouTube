# 2D Spawner script V1.0
# It allows the spawner to spawn either one or multiple objects in a single or multiple positions.
# A basic spawner scene to which this script will be attached should be something like a Node2D with a Timer node attached in it. Optionally add a Sprite for visual representation.
# Use the Start/Stop functions to control the spawner.

extends Node2D

@export var spawn_objects: Array[PackedScene]           ## Array with scenes that can be used
@export var random_selection: bool = false              ## Spawn random objects from the Array. If its not turned on the first object in the Array will be spawned instead.
@export var random_position: bool = true                ## Spawn object/s in a random place arround the spawner's position. 
@export var random_spawn_radius: float = 400.0          ## Radius in meters for random spawning
@export var random_rotation: bool = false               ## Enable random rotation on spawn

@export var spawn_count: int = 1                        ## Number of objects to spawn per cycle
@export var max_instances: int = -1                     ## Max instances allowed. Set a limit for the number of objects that can be spawned. Useful for efficiency. Set -1 for unlimited.

@export var spawn_interval: float = 0.1                 ## Time interval between spawns in seconds. Ex. Spawn x amount of objects (defined by spawn_count) every 10 seconds.
@export var spawn_frequency_variation: float = 0.0      ## Variation in seconds for spawn interval. Set to 0 for constant spawn rate.

@export_group("Throw")
@export var should_throw: bool = false                  ## Toggle if objects should be thrown upon spawning
@export var throw_force: float = 3.0                    ## Force applied to thrown objects
@export var use_random_direction: bool = false          ## Toggle if throw direction should be random or specific
@export var throw_direction: Vector2                    ## Direction in which objects will be thrown if not random

@export_group("Despawn")
@export var should_despawn: bool = false                ## Toggle if spawned objects should despawn
@export var despawn_time: float = 1.0                   ## Time in seconds after which spawned objects will despawn if should_despawn is true

@onready var timer: Timer = $Timer  # Get the Timer node of the spawner. 

var objects_spawned: int = 0 # Count of spawned objects

func _ready() -> void:
	timer.wait_time =  spawn_interval # Initial wait time
	_update_timer()  # Set initial variation

func spawn_object():
	randomize()  # Ensure randomness
	
	for _i in range(spawn_count):  # Spawn as many objects as specified. 
		# Determine if we should pick randomly from Array or use the first object
		var scene_to_spawn
		if random_selection:
			scene_to_spawn = spawn_objects[randi() % spawn_objects.size()]
		else:
			scene_to_spawn = spawn_objects[0]  # Always use the first object if not random/multiple

		var object_instance = scene_to_spawn.instantiate()
		
		# Determine if we spawn the object/s in one place or random places
		if random_position:
			# Generate a random position within a specified radius from spawners center
			var angle = randf_range(0, 2 * PI)
			var radius = randf_range(0, random_spawn_radius)
			var position_offset = Vector2(cos(angle) * radius, sin(angle) * radius)
			object_instance.position = Vector2.ZERO + position_offset
		else:
			# Spawn at the exact position of the spawner
			object_instance.position = Vector2.ZERO

		# Apply random rotation if enabled
		if random_rotation:
			object_instance.rotation = randf_range(0, 2 * PI)

		# Add the object to the scene tree before applying physics
		add_child(object_instance)
		objects_spawned += 1
		
		# Apply force if throwing is enabled
		if should_throw:
			var direction: Vector2
			if use_random_direction:
				direction = Vector2(randf_range(-250, 250), randf_range(-250, 250)) 
			else:
				direction = throw_direction
				
			if object_instance is PhysicsBody2D:  # Check if the object can react to physics
				# Ensure the object is in the scene tree before applying physics
				await get_tree().physics_frame  # Wait for the next physics frame
				
				# Apply a larger impulse to counteract gravity or achieve desired speed
				object_instance.apply_impulse(direction * throw_force)
				# Optionally, apply a torque for spinning or visual effect
				object_instance.apply_torque_impulse(randf_range(-20, 20)) # Random torque for variety. Change values or completely remove if not needed.
			else:
				print("Warning: Object does not support physics. Force could not be applied.")
		
		# Add a Timer to the object for despawn functionality if enabled
		if should_despawn:
			var despawn_timer = Timer.new()
			despawn_timer.wait_time = despawn_time
			despawn_timer.one_shot = true
			despawn_timer.timeout.connect(_on_despawn_timeout.bind(object_instance))
			object_instance.add_child(despawn_timer)
			despawn_timer.start()

		# Check if we've reached max instances 
		if max_instances != -1 and objects_spawned >= max_instances:
			print("Max instances reached, not spawning more.")
			stop_spawning()
			objects_spawned = 0
			print("Spawner is reset.")
			break  # Stop the loop if max instances are reached

func _on_despawn_timeout(object_instance: Node) -> void:
	if is_instance_valid(object_instance):
		object_instance.queue_free()

func _on_timer_timeout() -> void:
	spawn_object()
	_update_timer()  # Update timer variation each spawn cycle

func _update_timer() -> void:
	# Ensure the new wait time is always positive to avoid errors.
	var new_wait_time = spawn_interval + randf_range(-spawn_frequency_variation, spawn_frequency_variation)
	timer.wait_time = max(0.05, new_wait_time)  # Minimum time of 0.05 seconds to avoid instability

func start_spawning():
	timer.start()

func stop_spawning():
	timer.stop()
