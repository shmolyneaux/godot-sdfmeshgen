extends Node3D

var size: float = 0.2:
	get:
		return size
	set(value):
		size = value
		$Sphere.mesh.radius = size
		$Sphere.mesh.height = size*2
		
		$rounded_cube.scale = Vector3(size, size, size)


var shape = "cube":
	get:
		return shape
	set(value):
		assert(value == "cube" or value == "sphere" or value == null)
		shape = value
		
		$Sphere.visible = false
		$rounded_cube.visible = false
		
		if value == "cube":
			$rounded_cube.visible = true
		if value == "sphere":
			$Sphere.visible = true
			

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
