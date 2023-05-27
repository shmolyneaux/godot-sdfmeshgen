extends Node3D

@export
var shape: String = "":
	get:
		return shape
	set(value):
		shape = value
		$SphereBody.visible = false
		$BoxBody.visible = false
		
		if shape == "box":
			$BoxBody.visible = true
		if shape == "sphere":
			$SphereBody.visible = true


var size: float = 1.0:
	get:
		return size
	set(value):
		size = value
		$SphereMesh.mesh.radius = size
		$SphereMesh.mesh.height = size*2
		$SphereBody/SphereCollider.shape.radius = size
		
		$BoxMesh.mesh.size = Vector3(size, size, size)
		$BoxBody/BoxCollider.shape.size = Vector3(size*2, size*2, size*2)

# Called when the node enters the scene tree for the first time.
func _ready():
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _shape_entered(shape):
	$SphereMesh.visible = false
	$BoxMesh.visible = false
	
	if shape == "box":
		$BoxMesh.visible = true
	if shape == "sphere":
		$SphereMesh.visible = true

func _shape_exited():
	$SphereMesh.visible = false
	$BoxMesh.visible = false
