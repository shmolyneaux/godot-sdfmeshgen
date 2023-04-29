extends Node3D

var mouse_2d = Vector2()

var mouse_3d = Vector3()
var mouse_3d_normal = Vector3()

var shape_color = Color.WHITE

# Called when the node enters the scene tree for the first time.
func _ready():
	%SdfViewer.sdf_objects = [
		{
			"shape": "sphere",
			"radius": 0.5,
			"position": Vector3(),
			"blending": 0.2,
			"color": Color(randf_range(0.0, 1.0), randf_range(0.0, 1.0), randf_range(0.0, 1.0))
		}
	]

func update_shape_color(color: Color):
	shape_color = color

func _input(event):
	if event is InputEventMouseMotion:
		mouse_2d = event.position
		_update_cursor()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			%"3D Cursor".size *= 1.2
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			%"3D Cursor".size /= 1.2
		

func _update_cursor():
	# TODO: don't show mouse cursor while moving camera
	
	var viewport_size = get_viewport().get_visible_rect().size
	var screen_pos = Vector2(
		mouse_2d.x/viewport_size.x,
		mouse_2d.y/viewport_size.y
	)
	
	var depth = %SdfViewer.screen_to_depth(screen_pos)
	var new_mouse_3d_normal = %SdfViewer.screen_to_normal(screen_pos)
	if depth != null and new_mouse_3d_normal != null:
		var origin = get_viewport().get_camera_3d().project_ray_origin(mouse_2d)
		var normal = get_viewport().get_camera_3d().project_ray_normal(mouse_2d)
		mouse_3d = origin + depth*normal
		mouse_3d_normal = new_mouse_3d_normal
		
		%"3D Cursor".visible = true
		%"3D Cursor".look_at_from_position(mouse_3d, mouse_3d+mouse_3d_normal)
		
	else:
		mouse_3d = null
		%"3D Cursor".visible = false

func _process(delta):
	if Input.is_action_just_pressed("create_sphere") or Input.is_action_just_pressed("remove_sphere"):
		if mouse_3d == null:
			# TODO: show warning somehow
			return
		var radius = randf_range(0.2, 0.2)
		var node = StaticBody3D.new()
		var shape = CollisionShape3D.new()
		shape.shape = SphereShape3D.new()
		shape.shape.radius = radius
		$WidgetViewport.add_child(node)
		node.add_child(shape)
		node.position = mouse_3d
		
		var blending = %"3D Cursor".size/5
		
		var new_obj = {
			"shape": "sphere",
			"radius": %"3D Cursor".size,
			"position": mouse_3d,
			"blending": blending,
			"color": shape_color,
		}
		if Input.is_action_just_pressed("remove_sphere"):
			new_obj = {
				"op": "subtraction",
				"children": [new_obj],
				"blending": blending
			}
			
		%SdfViewer.sdf_objects = %SdfViewer.sdf_objects + [new_obj]
