extends Node3D

var size: float = 0.2:
	get:
		return size
	set(value):
		size = value
		$Sphere.mesh.radius = size
		$Sphere.mesh.height = size*2

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
