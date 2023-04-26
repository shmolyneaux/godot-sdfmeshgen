extends Node3D

var mouse_2d = Vector2()

# Called when the node enters the scene tree for the first time.
func _ready():
	%SdfViewer.sdf_objects = []

func _input(event):
	if event is InputEventMouseMotion:
		mouse_2d = event.position

func _process(delta):
	if Input.is_action_just_pressed("create_sphere"):
		var mouse_3d = %SdfViewer.screen_to_depth(mouse_2d)
		if not mouse_3d:
			mouse_3d = Vector3(randf_range(-2.0, 2.0), randf_range(0.0, 3.0), randf_range(-2.0, 2.0))
		var radius = randf_range(0.1, 0.4)
		var node = StaticBody3D.new()
		var shape = CollisionShape3D.new()
		shape.shape = SphereShape3D.new()
		shape.shape.radius = radius
		$WidgetViewport.add_child(node)
		node.add_child(shape)
		node.position = mouse_3d
		%SdfViewer.sdf_objects = %SdfViewer.sdf_objects + [
			{
				"shape": "sphere",
				"radius": radius,
				"position": mouse_3d,
				"blending": 0.2,
				"color": Color(randf_range(0.0, 1.0), randf_range(0.0, 1.0), randf_range(0.0, 1.0))
			}
		]
