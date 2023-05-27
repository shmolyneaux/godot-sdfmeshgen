extends Node3D

var size = Vector3(1, 1, 1):
	get:
		return size
	set(value):
		size = value
		$Top.position.y = size.y
		$Bottom.position.y = -size.y
		$Right.position.x = size.x
		$Left.position.x = -size.x
		$Front.position.z = size.z
		$Back.position.z = -size.z

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _input(event):
	if event is InputEventMouseMotion:
		size = Vector3(event.position.x / 2000.0, 1, 1)
		$Right.position.x = event.position.x / 2000.0
		position.x = size.x

func _on_right_input_event(camera, event, position, normal, shape_idx):
	print(event)
