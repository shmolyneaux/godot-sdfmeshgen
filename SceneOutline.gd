extends VBoxContainer

var scene:
	get:
		return scene
	set(value):
		scene = value
		_update_outline()

var root
@onready var tree = $Tree

# Called when the node enters the scene tree for the first time.
func _ready():
	_update_outline()


func _update_outline():
	tree.clear()
	
	if scene == null or scene == []:
		return
	
	var root = tree.create_item()
	tree.hide_root = true
	
	for item in scene:
		var child = tree.create_item(root)
		child.set_text(0, str(item))
		child.set_metadata(0, item)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _pfmt(item, indent=2):
	var output
	if item is Dictionary:
		var lines = []
		lines.append("{")
		var inner_lines = []
		for key in item:
			var value_text = _pfmt(item[key], indent+2)
			inner_lines.append(" ".repeat(indent) + key + ": " + value_text)
			
		lines.append("\n".join(inner_lines))
		lines.append("}")
		output = "\n".join(lines)
	elif item is Vector3:
		output = "Vector3" + str(item)
	else:
		output = str(item)
	return output

func _on_tree_item_selected():
	$Label.text = _pfmt(tree.get_selected().get_metadata(0))
