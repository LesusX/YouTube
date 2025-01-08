extends RigidBody3D

@export var earth_material: MeshInstance3D

func _ready():
	# Find the DirectionalLight in the parent scene
	var light = find_light_source()
	if light:
		update_light_direction(light)

func find_light_source() -> DirectionalLight3D:
	# Find DirectionalLight dynamically
	var light = get_tree().get_root().get_node("World").get_node("DirectionalLight3D")
	if light == null:
		print("DirectionalLight3D not found!")
	else:
		print("DirectionalLight3D found: ", light.name)
	return light

func update_light_direction(light: DirectionalLight3D):
	# Calculate the light direction (negative Z-axis of the light's transform)
	var light_direction = light.global_transform.basis.z
	print("Light direction: ", light_direction)
	earth_material.mesh.material.set_shader_parameter("light_direction", light_direction)

func _physics_process(delta):
	# Optionally, update the light direction dynamically in case the light moves
	var light = find_light_source()
	if light:
		update_light_direction(light)
