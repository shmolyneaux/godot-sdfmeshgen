extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _update_handles():
	%Right.global_transform.origin = $Box.global_transform.translated_local(Vector3($Box.mesh.size.x*0.5, 0, 0)).origin
	%Left.global_transform.origin = $Box.global_transform.translated_local(Vector3(-$Box.mesh.size.x*0.5, 0, 0)).origin
	%Top.global_transform.origin = $Box.global_transform.translated_local(Vector3(0, $Box.mesh.size.y*0.5, 0)).origin
	%Bottom.global_transform.origin = $Box.global_transform.translated_local(Vector3(0, -$Box.mesh.size.y*0.5, 0)).origin
	%Front.global_transform.origin = $Box.global_transform.translated_local(Vector3(0, 0, $Box.mesh.size.z*0.5)).origin
	%Back.global_transform.origin = $Box.global_transform.translated_local(Vector3(0, 0,  -$Box.mesh.size.z*0.5)).origin


func _on_right_position_changed(movement_along_axis, new_position):
	$Box.mesh.size.x += movement_along_axis
	$Box.global_transform = $Box.global_transform.translated_local(Vector3(movement_along_axis*0.5, 0, 0))
	_update_handles()


func _on_left_position_changed(movement_along_axis, new_position):
	$Box.mesh.size.x += movement_along_axis
	$Box.global_transform = $Box.global_transform.translated_local(Vector3(-movement_along_axis*0.5, 0, 0))
	_update_handles()


func _on_top_position_changed(movement_along_axis, new_position):
	$Box.mesh.size.y += movement_along_axis
	$Box.global_transform = $Box.global_transform.translated_local(Vector3(0, movement_along_axis*0.5, 0))
	_update_handles()


func _on_bottom_position_changed(movement_along_axis, new_position):
	$Box.mesh.size.y += movement_along_axis
	$Box.global_transform = $Box.global_transform.translated_local(Vector3(0, -movement_along_axis*0.5, 0))
	_update_handles()


func _on_front_position_changed(movement_along_axis, new_position):
	$Box.mesh.size.z += movement_along_axis
	$Box.global_transform = $Box.global_transform.translated_local(Vector3(0, 0, movement_along_axis*0.5))
	_update_handles()


func _on_back_position_changed(movement_along_axis, new_position):
	$Box.mesh.size.z += movement_along_axis
	$Box.global_transform = $Box.global_transform.translated_local(Vector3(0, 0, -movement_along_axis*0.5,))
	_update_handles()
