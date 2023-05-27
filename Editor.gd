extends Node3D

var mouse_2d = Vector2()

var mouse_3d = Vector3()
var mouse_3d_normal = Vector3()

var shape_color = Color.WHITE

var blending = 0.2:
	get:
		return blending
	set(value):
		blending = clamp(value, 0.0, 1.0)
		$"Control2/Control/VBoxContainer/HBoxContainer/Blending Slider".value = blending
		$"Control2/Control/VBoxContainer/HBoxContainer/Blending Input".value = blending

var shape = "cube":
	get:
		return shape
	set(value):
		assert(value == "cube" or value == "sphere" or value == null)
		shape = value
		%"3D Cursor".shape = value

func set_blending(value):
	blending = value
	
func set_shape(value):
	if value == "":
		value = null
	shape = value

# Called when the node enters the scene tree for the first time.
func _ready():
	var objs = []

	var color = Color(randf_range(0.0, 1.0), randf_range(0.0, 1.0), randf_range(0.0, 1.0))
	
	objs.append(
		{
			"shape": "quad_bezier",
			"a": Vector3(-1.875, 0.1+1, 1.359),
			"b": Vector3(0,      2+1,        1.359),
			"c": Vector3(1.249,  0.393+2, 1.359),
			"blending": 0.0,
			"color": color
		}
	)
	%SdfViewer.sdf_objects = objs
	%SceneOutline.scene = objs

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
	
	if screen_pos.x < 0.0 or screen_pos.y < 0.0:
		return
	if screen_pos.x > 1.0 or screen_pos.y > 1.0:
		return
	
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
	if Input.is_action_just_pressed("cancel_tool"):
		shape = null
	if Input.is_action_just_pressed("create_sphere") or Input.is_action_just_pressed("remove_sphere") and shape != null:
		if mouse_3d == null:
			# TODO: show warning somehow
			return

		
		var xform = %"3D Cursor".global_transform
		xform.origin = Vector3.ZERO
		
		var scaled_blending = blending * %"3D Cursor".size
		var size = %"3D Cursor".size
		
		var new_obj
		if shape == "cube":
			var radius = randf_range(0.2, 0.2)
			var node = StaticBody3D.new()
			var collision_shape = CollisionShape3D.new()
			collision_shape.shape = BoxShape3D.new()
			collision_shape.shape.size = Vector3(size*2, size*2, size*2)
			$WidgetViewport.add_child(node)
			node.add_child(collision_shape)
			node.global_transform = xform
			node.position = mouse_3d
			
#			node = MeshInstance3D.new()
#			node.mesh = BoxMesh.new()
#			node.mesh.size = Vector3(size*2, size*2, size*2)
#			node.mesh.material = preload("res://ShapeHighlightMat.tres")
#			$WidgetViewport.add_child(node)
#			node.add_child(collision_shape)
#			node.global_transform = xform
#			node.position = mouse_3d
			
			new_obj = {
				"shape": "box",
				"size": Vector3(size, size, size),
				"position": mouse_3d,
				"rotation": xform,
				"blending": scaled_blending,
				"color": shape_color,
			}
		elif shape == "sphere":
			var scene = preload("res://PrimPicker.tscn")
			var node = scene.instantiate()
			node.shape = "sphere"
			node.size = size
			node.position = mouse_3d
			$WidgetViewport.add_child(node)
			
			new_obj = {
				"shape": "sphere",
				"radius": size,
				"position": mouse_3d,
				"blending": scaled_blending,
				"color": shape_color,
			}
			
		if Input.is_action_just_pressed("remove_sphere"):
			new_obj = {
				"op": "subtraction",
				"children": [new_obj],
				"blending": blending
			}
			
		%SdfViewer.sdf_objects = %SdfViewer.sdf_objects + [new_obj]
		%SceneOutline.scene = %SdfViewer.sdf_objects


func _on_static_body_3d_mouse_entered():
	print("mouse entered")
