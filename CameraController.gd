extends Node

# Holding middle mouse button orbits around some target point when the mouse is moved
# Holding middle mouse button+shift pans
# Holding right mouse button is FPS mode

var last_mouse_position = Vector2()
var mouse_position = Vector2()

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


func _unhandled_input(event):
	if event is InputEventMouseButton:
		
		if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			
		if (not event.pressed) and event.button_index == MOUSE_BUTTON_RIGHT:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			
	if event is InputEventMouseMotion:
		if Input.get_mouse_button_mask() & MOUSE_BUTTON_MASK_RIGHT:
			get_parent().rotation.y -= event.relative.x/1000.0
			get_parent().rotation.x -= event.relative.y/1000.0
			get_parent().rotation.x = clamp(get_parent().rotation.x, deg_to_rad(-90), deg_to_rad(90))
			
		elif Input.get_mouse_button_mask() & MOUSE_BUTTON_MASK_MIDDLE and Input.is_key_pressed(KEY_SHIFT):
			get_parent().global_transform.origin = get_parent().global_transform.origin + (
				get_parent().global_transform.basis.y*event.relative.y -
				get_parent().global_transform.basis.x*event.relative.x
			)/500.0
		
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var move_dir = Vector3()
	last_mouse_position = mouse_position
	mouse_position = get_viewport().get_mouse_position()
	
	if Input.get_mouse_button_mask() & MOUSE_BUTTON_MASK_RIGHT:
		if Input.is_action_pressed("move_forward"):
			move_dir.y -= 1.0
		if Input.is_action_pressed("move_backward"):
			move_dir.y += 1.0
		if Input.is_action_pressed("move_left"):
			move_dir.x -= 1.0
		if Input.is_action_pressed("move_right"):
			move_dir.x += 1.0
		if Input.is_action_pressed("move_up"):
			move_dir.z += 1.0
		if Input.is_action_pressed("move_down"):
			move_dir.z -= 1.0
		
		if move_dir.x != 0 or move_dir.y != 0 or move_dir.z != 0:
			var speed = 2.5
			if Input.is_action_pressed("sprint"):
				speed = 5.0
			move_dir = move_dir.normalized()*speed
			
			get_parent().global_transform.origin = get_parent().global_transform.origin + (
				get_parent().global_transform.basis.z*move_dir.y +
				get_parent().global_transform.basis.x*move_dir.x +
				Vector3(0.0, 1.0, 0.0)*move_dir.z
			)*delta
		
	elif Input.get_mouse_button_mask() & MOUSE_BUTTON_MASK_MIDDLE:
		pass
