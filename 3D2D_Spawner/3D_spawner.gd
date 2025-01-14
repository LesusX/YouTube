# 3D Spawner script V1.1.
# It allows the spawner to spawn either one or multiple objects in a single or multiple positions.
# A basic spawner scene to which this script will be attached should be something like a Node3D with a Timer node attached in it. Optionally add a mesh instance for visual representation.
# Use the Start/Stop functions to control the spawner.

extends Node3D

@export var spawn_objects: Array[PackedScene]           ## Array with scenes that can be used
@export var random_selection: bool = false              ## Spawn random objects from the Array. If it's not turned on, the first object in the Array will be spawned instead.
@export var random_position: bool = true                ## Spawn object/s in a random place around the spawner's position. 
@export var random_spawn_radius: float = 25.0           ## Radius in meters for random spawning.
@export var spawn_height_variation: float = 0.0         ## Vertical variation for spawn position. Set to 0 if a random y position is not desired. NOTE: Setting very high values may cause rigid bodies to fall with great speed and avoid collisions.
@export var random_rotation: bool = false               ## Enable random rotation on spawn.

@export var spawn_count: int = 1                        ## Number of objects to spawn per cycle. The cycle is defined in the spawn_interval
@export var max_instances: int = -1                     ## Max instances allowed. Set a limit for the number of objects that can be spawned. Useful for efficiency. Set -1 for unlimited.

@export var spawn_interval: float = 1.0                 ## Time interval between spawns in seconds. Ex. Spawn x amount of objects (defined by spawn_count) every 10 seconds.
@export var spawn_frequency_variation: float = 0.0      ## Variation in seconds for spawn interval. Set to 0 for constant spawn rate.

@export_group("Throw")
@export var should_throw: bool = false                  ## Toggle if objects should be thrown upon spawning.
@export var throw_force: float = 10.0                   ## Force applied to thrown objects.
@export var use_random_direction: bool = false          ## Toggle if throw direction should be random or specific.
@export var throw_direction: Vector3 = Vector3.LEFT     ## Direction in which objects will be thrown if not random.
@export var throw_multiple_directions: bool = false     ## Toggle to allow throwing in multiple directions per spawn.
@export var throw_directions: Array[Vector3] = [Vector3.LEFT, Vector3.RIGHT, Vector3.MODEL_REAR, Vector3.MODEL_FRONT] ## Directions for multi-throw. By default all 4 directions are added. Add more or remove directions as needed.

@export_group("Despawn")
@export var should_despawn: bool = false                ## Toggle if spawned objects should despawn.
@export var despawn_time: float = 1.0                   ## Time in seconds after which spawned objects will despawn if should_despawn is true.

@onready var timer: Timer = $Timer  # Get the Timer node of the spawner. 

var objects_spawned: int = 0 # Count of spawned objects

func _ready() -> void:
	timer.wait_time = spawn_interval  # Initial wait time
	_update_timer()  # Set initial variation

func spawn_object():
	randomize()  # Ensure randomness
	
	for _i in range(spawn_count):  # Spawn multiple objects if specified
		# Determine if we should pick randomly from Array or use the first object
		var scene_to_spawn
		if random_selection:
			scene_to_spawn = spawn_objects[randi() % spawn_objects.size()]
		else:
			scene_to_spawn = spawn_objects[0]  # Always use the first object if not random or multiple

		var object_instance = scene_to_spawn.instantiate()
		
		# Determine if we spawn the object/s in one place or random places
		if random_position:
			# Generate a random position within the specified radius and height
			var angle = randf_range(0, 2 * PI)
			var radius = randf_range(0, random_spawn_radius)
			var height_offset = randf_range(-spawn_height_variation, spawn_height_variation)
			var position_offset = Vector3(cos(angle) * radius, height_offset, sin(angle) * radius)
			object_instance.position = Vector3.ZERO + position_offset
		else:
			# Spawn at the exact position of the spawner
			object_instance.position = Vector3.ZERO

		# Apply random rotation if enabled
		if random_rotation:
			object_instance.rotation = Vector3(randf_range(0, TAU), randf_range(0, TAU), randf_range(0, TAU))

		# Add the object to the scene tree before applying physics
		add_child(object_instance)
		objects_spawned += 1
		
		# Apply force if throwing is enabled
		if should_throw:
			var direction: Vector3
			if use_random_direction:
				direction = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
			else:
				if throw_multiple_directions and throw_directions.size() > 0:
					direction = throw_directions[randi() % throw_directions.size()]
				else:
					direction = throw_direction
				
			if object_instance is PhysicsBody3D:  # Check if the object can react to physics
				await get_tree().physics_frame  # Wait for the next physics frame
				object_instance.apply_impulse(direction * throw_force)
			else:
				print("Warning: Object does not support physics. Force not applied.")
		
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
