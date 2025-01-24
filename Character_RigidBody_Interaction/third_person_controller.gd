extends CharacterBody3D

# NOTE: When a rigid body weighs 1KG and is pushed against heavier rigid bodies it may fly away due to the forces aplied to it. Bodies above 2kg work much better when pushed a lot.

const WALK_SPEED:float = 5.0
const SPRINT_SPEED:float = 16.0

var gravity = 18.0   # Use any gravity you like here. 18 gives a better feel for most games.
var speed = 6.0
var jump_speed = 11.0
var mouse_sensitivity = 0.002

@onready var spring_arm = $SpringArm3D

@onready var ground_check: ShapeCast3D = $ground_check
@export var player_strength:float = 100
var strength_multiplier:float = 1.4


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		# Adjust vertical rotation of the spring arm
		spring_arm.rotation.x = clamp(spring_arm.rotation.x - event.relative.y * mouse_sensitivity, -PI/4, PI/4)
	
	if event.is_action_pressed("jump") and is_on_floor():
		velocity.y = jump_speed
	
	if Input.is_action_just_pressed("exit"): #Just exit the game when the escape button is pressed
		get_tree().quit()
	# Handle Sprint.
	if Input.is_action_pressed("sprint"):
		speed = SPRINT_SPEED
	else:
		speed = WALK_SPEED

func _physics_process(delta):
	# Check if the ground_check shapecast is colliding with a RigidBody3D
	# ground_check.force_shapecast_update() #NOTE:Un-comment this line if the shapecast is not updating properly in your game
	if ground_check.is_colliding():
		var collider
		collider = ground_check.get_collider(0)  # Get the first collider
		if collider is RigidBody3D:
			collider.linear_velocity = Vector3(0.0,0.0,0.0) # Not a perfect solution but it helps to keep a body we step on stable and not get pulled towards the players direction when sliding down. 

	if not is_on_floor():
		velocity.y -= gravity * delta

	var input = Input.get_vector("left", "right", "forward", "backward")
	var movement_dir = transform.basis * Vector3(input.x, 0, input.y).normalized()
	if movement_dir:
		velocity.x = movement_dir.x * speed 
		velocity.z = movement_dir.z * speed
	else:
		velocity.x = lerp(velocity.x, movement_dir.x * speed, delta * 7.0)
		velocity.z = lerp(velocity.z, movement_dir.z * speed, delta * 7.0)
	
	move_and_slide()
	push_rigid_body()
	
	
# This function handles pushing a rigid body by calculating the effective mass, friction, and force to apply.
# Considers connected bodies and their mass, determines free sides, and restricts movement based on total mass
# and player's strength. Applies a realistic impulse to the pushed object.
func push_rigid_body() -> void:
	var col := get_last_slide_collision()
	if col:
		var col_collider := col.get_collider()
		var col_position := col.get_position()
		if col_collider is RigidBody3D:
			var body_mass = col_collider.mass
			var all_connected_bodies = get_all_connected_bodies(col_collider)
			var friction = calculate_friction(all_connected_bodies)

			var total_mass = 0.0
			for body in all_connected_bodies:
				total_mass += body.mass

			# Original assumption: all sides free except the bottom
			var free_sides = {
				"LEFT": true,
				"RIGHT": true,
				"FRONT": true,
				"BACK": true,
				"TOP": true,
				"BOTTOM": false
			}

			# Check each side for connected bodies
			for connected_body in all_connected_bodies:
				if connected_body == col_collider:
					continue

				var connected_local_pos = col_collider.to_local(connected_body.global_position)

				# Determine which sides are blocked
				if abs(connected_local_pos.x) > abs(connected_local_pos.z):
					if connected_local_pos.x < 0:
						free_sides["LEFT"] = false
					else:
						free_sides["RIGHT"] = false
				elif abs(connected_local_pos.z) > abs(connected_local_pos.x):
					if connected_local_pos.z < 0:
						free_sides["FRONT"] = false
					else:
						free_sides["BACK"] = false
				if abs(connected_local_pos.y) > max(abs(connected_local_pos.x), abs(connected_local_pos.z)):
					if connected_local_pos.y > 0:
						free_sides["TOP"] = false
					else:
						free_sides["BOTTOM"] = false

			# Adjust total mass if all sides are free
			if free_sides["LEFT"] and free_sides["RIGHT"] and free_sides["FRONT"] and free_sides["BACK"] and free_sides["TOP"]:
				total_mass = body_mass
				friction = 0.0

			# Calculate stacked weight and effective mass
			var stacked_weight = 0.0
			for connected_body in all_connected_bodies:
				if connected_body.global_position.y > col_collider.global_position.y:
					stacked_weight += connected_body.mass
			var effective_mass = total_mass + stacked_weight

			# Calculate strength multiplier
			var strength_multiplier = 1.4
			if total_mass < 25:
				strength_multiplier = lerp(1.5, 1.8, (25 - total_mass) / 25.0)
			elif total_mass < 50:
				strength_multiplier = lerp(1.8, 1.5, (total_mass - 25) / 25.0)

			# Handle pushing restrictions
			if total_mass > player_strength:
				var restricted_sides = []
				var opposite_sides = {
					"LEFT": "RIGHT",
					"RIGHT": "LEFT",
					"FRONT": "BACK",
					"BACK": "FRONT",
					"TOP": "BOTTOM",
					"BOTTOM": "TOP"
				}

				for connected_body in all_connected_bodies:
					if connected_body == col_collider:
						continue
					var connected_local_pos = col_collider.to_local(connected_body.global_position)
					var connected_side = ""
					if abs(connected_local_pos.x) > abs(connected_local_pos.z):
						connected_side = "LEFT" if connected_local_pos.x < 0 else "RIGHT"
					else:
						connected_side = "FRONT" if connected_local_pos.z < 0 else "BACK"
					if abs(connected_local_pos.y) > max(abs(connected_local_pos.x), abs(connected_local_pos.z)):
						connected_side = "TOP" if connected_local_pos.y > 0 else "BOTTOM"
					restricted_sides.append(opposite_sides[connected_side])

				var local_position = col_collider.to_local(global_position)
				var push_side = ""
				if abs(local_position.x) > abs(local_position.z):
					push_side = "LEFT" if local_position.x < 0 else "RIGHT"
				else:
					push_side = "FRONT" if local_position.z < 0 else "BACK"
				if abs(local_position.y) > max(abs(local_position.x), abs(local_position.z)):
					push_side = "TOP" if local_position.y > 0 else "BOTTOM"

				if push_side in restricted_sides:
					var applied_force_og = player_strength * strength_multiplier if body_mass >= player_strength * strength_multiplier else body_mass
					col_collider.apply_impulse(-col.get_normal().normalized() * applied_force_og * 0.2, col_position - col_collider.global_position)
					return

			# Apply impulse if allowed
			var max_speed = (player_strength * strength_multiplier) / effective_mass
			var applied_force = player_strength * strength_multiplier if effective_mass >= player_strength * strength_multiplier else effective_mass
			applied_force *= (1.0 - friction)
			if col_collider.linear_velocity.length() < max_speed:
				var push_direction = -col.get_normal().normalized()
				col_collider.apply_impulse(push_direction * applied_force, col_position - col_collider.global_position)

# Function to calculate friction based on connected bodies and their masses
func calculate_friction(connected_bodies: Array) -> float:
	var total_mass = 0.0
	for body in connected_bodies:
		total_mass += body.mass
	
	# Base friction with adjustments for body count and mass
	var base_friction = 0.1
	var friction_per_body = 0.05
	var mass_friction_factor = 0.001  # Small adjustment based on mass

	# Calculate friction and clamp it within a valid range
	var friction = base_friction + (connected_bodies.size() * friction_per_body) + (total_mass * mass_friction_factor)
	return clamp(friction, 0.0, 1.0)


# Function to get all connected RigidBody3D objects
func get_all_connected_bodies(start_body: RigidBody3D, max_bodies: int = 6) -> Array:
	var connected_bodies = []
	var visited_bodies = {}
	var stack = [start_body]

	while stack and connected_bodies.size() < max_bodies:
		var current_body = stack.pop_front()

		if current_body in visited_bodies:
			continue
		visited_bodies[current_body] = true
		connected_bodies.append(current_body)

		# Stop if the max number of bodies is reached
		if connected_bodies.size() >= max_bodies:
			break

		# Check for child collision shapes
		var collision_shape = current_body.get_child(0) if current_body.get_child_count() > 0 else null
		if collision_shape is CollisionShape3D:
			var shape = collision_shape.shape
			var query = PhysicsShapeQueryParameters3D.new()
			query.shape = shape
			query.transform = current_body.global_transform
			query.set_margin(0.01)

			# Find intersecting bodies
			var space_state = get_world_3d().direct_space_state
			var result = space_state.intersect_shape(query)

			for item in result:
				var collider = item.collider
				if collider is RigidBody3D and collider != current_body and collider not in visited_bodies:
					stack.append(collider)

	return connected_bodies
