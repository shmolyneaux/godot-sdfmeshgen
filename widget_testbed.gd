extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _update_box():
	$MeshInstance3D.mesh.size.x = ($Right.global_position - $Left.global_position).length()
	$MeshInstance3D.mesh.size.y = ($Top.global_position - $Bottom.global_position).length()
	$MeshInstance3D.mesh.size.z = ($Front.global_position - $Back.global_position).length()
	$MeshInstance3D.global_position = ($Right.global_position + $Left.global_position)*0.5


func _on_right_position_changed(movement_along_axis, new_position):
	$Top.global_position.x += movement_along_axis*0.5
	$Bottom.global_position.x += movement_along_axis*0.5
	$Front.global_position.x += movement_along_axis*0.5
	$Back.global_position.x += movement_along_axis*0.5
	_update_box()


func _on_left_position_changed(movement_along_axis, new_position):
	$Top.global_position.x -= movement_along_axis*0.5
	$Bottom.global_position.x -= movement_along_axis*0.5
	$Front.global_position.x -= movement_along_axis*0.5
	$Back.global_position.x -= movement_along_axis*0.5
	_update_box()


func _on_top_position_changed(movement_along_axis, new_position):
	$Right.global_position.y += movement_along_axis*0.5
	$Left.global_position.y += movement_along_axis*0.5
	$Front.global_position.y += movement_along_axis*0.5
	$Back.global_position.y += movement_along_axis*0.5
	_update_box()


func _on_bottom_position_changed(movement_along_axis, new_position):
	$Right.global_position.y -= movement_along_axis*0.5
	$Left.global_position.y -= movement_along_axis*0.5
	$Front.global_position.y -= movement_along_axis*0.5
	$Back.global_position.y -= movement_along_axis*0.5
	_update_box()


func _on_front_position_changed(movement_along_axis, new_position):
	$Right.global_position.z += movement_along_axis*0.5
	$Left.global_position.z += movement_along_axis*0.5
	$Top.global_position.z += movement_along_axis*0.5
	$Bottom.global_position.z += movement_along_axis*0.5
	_update_box()


func _on_back_position_changed(movement_along_axis, new_position):
	$Right.global_position.z -= movement_along_axis*0.5
	$Left.global_position.z -= movement_along_axis*0.5
	$Top.global_position.z -= movement_along_axis*0.5
	$Bottom.global_position.z -= movement_along_axis*0.5
	_update_box()
