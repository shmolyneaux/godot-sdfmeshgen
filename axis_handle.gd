extends Node3D

signal position_changed(movement_along_axis, new_position)


# True when the mouse is hovered over the sphere
var _hover = false:
	get:
		return _hover
	set(value):
		print("hover: ", value)
		_hover = value
		_update_materials()


# True when the mouse was pressed on the sphere and hasn't been released yet
var _active = false:
	get:
		return _active
	set(value):
		print("active: ", value)
		_active = value
		_update_materials()


func _update_materials():
	if _active:
		%Mesh.set_instance_shader_parameter("color", Color(0.43, 1, 0.38))
		%AxisGuide.visible = true
	elif _hover:
		%Mesh.set_instance_shader_parameter("color", Color(0.45, 0.78, 1.0))
		%AxisGuide.visible = true
	else:
		%Mesh.set_instance_shader_parameter("color", Color(1, 1, 1))
		%AxisGuide.visible = false


func _ready():
	_update_materials()


func _input(event):
	if not _active:
		return
		
	print(event)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_active = false
		
	if event is InputEventMouseMotion:
		# Get guide line segment
		var p1 = global_transform.translated_local(Vector3(0, 0, 100)).origin
		var p2 = global_transform.translated_local(Vector3(0, 0, -100)).origin
		
		# Get mouse ray line segment
		var q1 = get_viewport().get_camera_3d().project_ray_origin(event.position)
		var q2 = q1 + 100*get_viewport().get_camera_3d().project_ray_normal(event.position)
		
		# Find closest point on guide line
		var results = Geometry3D.get_closest_points_between_segments(p1, p2, q1, q2)
		
		var new_position = results[0]
		var old_position = global_position
		
		var movement_along_axis = (new_position - old_position).dot((p2-p1).normalized())
		emit_signal("position_changed", movement_along_axis, new_position)


func _on_handle_body_mouse_entered():
	_hover = true


func _on_handle_body_mouse_exited():
	_hover = false


func _on_handle_body_input_event(_camera, event, _position, _normal, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_active = true
