extends Camera3D

class_name Sdf

var shader: RID
var color_output_format : RDTextureFormat
var half_color_output_format : RDTextureFormat

var sdf_objects = []:
	get:
		return sdf_objects
	set(value):
		sdf_objects = value
		var sdf = sdf_from_list(value)
		
		var ops_bytes = sdf.to_ops()
		var object_data_bytes = PackedByteArray()
		object_data_bytes.append_array(PackedInt32Array([ops_bytes.size()/4]).to_byte_array())
		object_data_bytes.append_array(ops_bytes)
		
		print("display size ", object_data_bytes.size())
		
		rd.buffer_update(object_info_rid, 0, object_data_bytes.size(), object_data_bytes)
		viewport_needs_update = true

var rd := RenderingServer.create_local_rendering_device()
var uniform_set
var half_uniform_set

var color_output_rid
var color_output_uniform

var half_color_output_rid
var half_color_output_uniform

var camera_xform_rid
var camera_xform_uniform

var object_info_rid
var object_info_uniform

var pipeline

var viewport_needs_update = true
var last_xform = Transform3D()
var last_update_was_half_rez = true

static func sdf_from_list(lst):
	if lst == []:
		return SdfSphere.new(0.0)
	var sdf = null
	for item in lst:
		var blending = 0.0
		if "blending" in item:
			blending = item["blending"]
			
		if "shape" in item:
			var new_sdf = sdf_from_value(item)
			if sdf == null:
				# The first item in a list doesn't get blending since there's nothing to blend with
				sdf = new_sdf
			else:
				if blending:
					sdf = SdfSmoothUnion.new(sdf, new_sdf, blending)
				else:
					sdf = SdfUnion.new(sdf, new_sdf)
		else:
			# If it wasn't a shape it has to be an operation
			assert("op" in item)
			# An operation can't be the first thing since there's nothing to operate on.
			# Exit early since this is likely a bug
			assert(sdf != null or (item["op"] == "union" and blending == 0.0))
			var new_sdf = sdf_from_list(item["children"])

			match [item["op"], blending]:
				["union", 0.0]:
					if sdf == null:
						sdf = new_sdf
					else:
						sdf = SdfUnion.new(sdf, new_sdf)
				["union", _]:
					sdf = SdfSmoothUnion.new(sdf, new_sdf, blending)
				["subtraction", 0.0]:
					sdf = SdfSubtraction.new(sdf, new_sdf)
				["subtraction", _]:
					sdf = SdfSmoothSubtraction.new(sdf, new_sdf, blending)
				["intersection", 0.0]:
					sdf = SdfIntersection.new(sdf, new_sdf)
				["intersection", _]:
					sdf = SdfSmoothIntersection.new(sdf, new_sdf, blending)
				_:
					assert(false)
	return sdf

static func sdf_from_value(value):
	assert("shape" in value)
	var sdf = null
	if value["shape"] == "sphere":
		sdf = SdfSphere.new(value["radius"])
	if value["shape"] == "box":
		sdf = SdfBox.new(value["size"])

	if value["position"] != Vector3.ZERO:
		sdf = SdfTranslate.new(sdf, value["position"])
		
	if "color" in value:
		sdf = SdfColor.new(sdf, value["color"])

	assert(sdf)
	return sdf

static func sdf_op(op: int, args: Array[float]):
	var ops = PackedByteArray()
	ops.append_array(PackedInt32Array([op]).to_byte_array())
	ops.append_array(PackedFloat32Array(args).to_byte_array())
	
	return ops
	
static func union_op():
	return sdf_op(0, [])
static func subtraction_op():
	return sdf_op(1, [])
static func intersection_op():
	return sdf_op(2, [])

static func smooth_union_op(radius: float):
	return sdf_op(10, [radius])
static func smooth_subtraction_op(radius: float):
	return sdf_op(11, [radius])
static func smooth_intersection_op(radius: float):
	return sdf_op(12, [radius])
	
static func move_op(amount: Vector3):
	return sdf_op(101, [amount.x, amount.y, amount.z])
	
static func pop_pos_op():
	return sdf_op(100, [])
	
static func sphere_op(radius: float):
	return sdf_op(200, [radius])
static func box_op(b: Vector3):
	return sdf_op(201, [b.x, b.y, b.z])
static func ellipsoid_op(radius: Vector3):
	return sdf_op(201, [radius.x, radius.y, radius.z])
	
static func puff_op(radius: float):
	return sdf_op(300, [radius])
	
static func color_op(color: Color):
	return sdf_op(400, [color.r, color.g, color.b])

class SdfUnion:
	var d1
	var d2
	
	func _init(d1, d2):
		self.d1 = d1
		self.d2 = d2
	
	func to_ops():
		return d1.to_ops() + d2.to_ops() + Sdf.union_op()

class SdfSmoothUnion:
	var d1
	var d2
	var r
	
	func _init(d1, d2, r):
		self.d1 = d1
		self.d2 = d2
		self.r = r
	
	func to_ops():
		return d1.to_ops() + d2.to_ops() + Sdf.smooth_union_op(r)

class SdfSubtraction:
	var d1
	var d2
	
	func _init(d1, d2):
		self.d1 = d1
		self.d2 = d2
	
	func to_ops():
		return d1.to_ops() + d2.to_ops() + Sdf.subtraction_op()

class SdfSmoothSubtraction:
	var d1
	var d2
	var r
	
	func _init(d1, d2, r):
		self.d1 = d1
		self.d2 = d2
		self.r = r
	
	func to_ops():
		return d1.to_ops() + d2.to_ops() + Sdf.smooth_subtraction_op(r)

class SdfIntersection:
	var d1
	var d2
	
	func _init(d1, d2):
		self.d1 = d1
		self.d2 = d2
	
	func to_ops():
		return d1.to_ops() + d2.to_ops() + Sdf.intersection_op()

class SdfSmoothIntersection:
	var d1
	var d2
	var r
	
	func _init(d1, d2, r):
		self.d1 = d1
		self.d2 = d2
		self.r = r
	
	func to_ops():
		return d1.to_ops() + d2.to_ops() + Sdf.smooth_intersection_op(r)

class SdfSphere:
	var radius
	
	func _init(radius):
		self.radius = radius
	
	func to_ops():
		return Sdf.sphere_op(radius)

class SdfBox:
	var b
	
	func _init(b):
		self.b = b
	
	func to_ops():
		return Sdf.box_op(b)

class SdfTranslate:
	var d
	var amount
	
	func _init(d, amount):
		self.d = d
		self.amount = amount
	
	func to_ops():
		return Sdf.move_op(amount) + d.to_ops() + Sdf.move_op(-amount)

class SdfColor:
	var d
	var color
	
	func _init(d, color):
		self.d = d
		self.color = color
	
	func to_ops():
		return Sdf.color_op(color) + d.to_ops()

func screen_to_depth(screen_pos):
	return null

func _ready():
	color_output_format = RDTextureFormat.new()
	color_output_format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	color_output_format.width = 2048
	color_output_format.height = 1024
	color_output_format.usage_bits = \
			RenderingDevice.TEXTURE_USAGE_STORAGE_BIT + \
			RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT + \
			RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
			
	half_color_output_format = RDTextureFormat.new()
	half_color_output_format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	half_color_output_format.width = color_output_format.width/16
	half_color_output_format.height = color_output_format.height/16
	half_color_output_format.usage_bits = \
			RenderingDevice.TEXTURE_USAGE_STORAGE_BIT + \
			RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT + \
			RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	
	# Load GLSL shader
	var shader_file := load("res://compute_example.glsl")
	print(shader_file)
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	
	color_output_rid = rd.texture_create(color_output_format, RDTextureView.new())
	half_color_output_rid = rd.texture_create(half_color_output_format, RDTextureView.new())

	color_output_uniform = RDUniform.new()
	color_output_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	color_output_uniform.binding = 0  # This matches the binding in the shader.
	color_output_uniform.add_id(color_output_rid)
	
	half_color_output_uniform = RDUniform.new()
	half_color_output_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	half_color_output_uniform.binding = 0  # This matches the binding in the shader.
	half_color_output_uniform.add_id(half_color_output_rid)

	var camera_data := PackedFloat32Array(
		[
			0.0, 0.0, 0.0,
			0.0, 0.0, 0.0,
			0.0, 0.0, 0.0,
			0.0, 0.0, 0.0,
		]
	)
	var camera_data_bytes := camera_data.to_byte_array()
	camera_xform_rid = rd.storage_buffer_create(camera_data_bytes.size(), camera_data_bytes)
	camera_xform_uniform = RDUniform.new()
	camera_xform_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	camera_xform_uniform.binding = 1
	camera_xform_uniform.add_id(camera_xform_rid)

	var object_data_bytes = PackedByteArray()
	
	var sdf = SdfSphere.new(0.3)
	
	var ops_bytes = sdf.to_ops()
	object_data_bytes.append_array(PackedInt32Array([ops_bytes.size()/4]).to_byte_array())
	object_data_bytes.append_array(ops_bytes)
	
	for _idx in 6000:
		object_data_bytes.append_array(PackedInt32Array([0]).to_byte_array())
		
	print("initial size ", object_data_bytes.size())

	object_info_rid = rd.storage_buffer_create(object_data_bytes.size(), object_data_bytes)
	object_info_uniform = RDUniform.new()
	object_info_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	object_info_uniform.binding = 2
	object_info_uniform.add_id(object_info_rid)

	shader = rd.shader_create_from_spirv(shader_spirv)
	pipeline = rd.compute_pipeline_create(shader)
	uniform_set = rd.uniform_set_create([color_output_uniform, camera_xform_uniform, object_info_uniform], shader, 0)
	half_uniform_set = rd.uniform_set_create([half_color_output_uniform, camera_xform_uniform, object_info_uniform], shader, 0)


# Called when the node enters the scene tree for the first time.
func _process(delta):
	var xform = Transform3D()
	
	var an = 0.5*(Time.get_ticks_msec()/1000.0-10.0)
	var ro = 1.6 * Vector3( 1.0*cos(an), 0.0, 1.0*sin(an) )
	
	xform = global_transform
	
	var half_resolution = false
	
	viewport_needs_update = viewport_needs_update or xform != last_xform
	
	match [viewport_needs_update, last_update_was_half_rez]:
		[true, _]:
			# Viewport newly changed, so render at half rez
			half_resolution = true
		[false, false]:
			# Viewport did not change, and the last update was at full rez
			return
		[false, true]:
			# Viewport didn't change, but we need to update at full rez
			pass

	last_xform = xform
	
	var input := PackedFloat32Array(
		[
			-xform.basis.z.x, -xform.basis.z.y, -xform.basis.z.z,
			xform.basis.x.x, xform.basis.x.y, xform.basis.x.z,
			-xform.basis.y.x, -xform.basis.y.y, -xform.basis.y.z,
			xform.origin.x, xform.origin.y, xform.origin.z
		]
	)
	var input_bytes := input.to_byte_array()
	rd.buffer_update(camera_xform_rid, 0, input_bytes.size(), input_bytes)

	if half_resolution:
		var compute_list := rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
		rd.compute_list_bind_uniform_set(compute_list, half_uniform_set, 0)
		rd.compute_list_dispatch(compute_list, half_color_output_format.width/8, half_color_output_format.height/8, 1)
		rd.compute_list_end()
	else:
		var compute_list := rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
		rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
		rd.compute_list_dispatch(compute_list, color_output_format.width/8, color_output_format.height/8, 1)
		rd.compute_list_end()

	# Submit to GPU and wait for sync
	rd.submit()
	
	# Should wait some time for this to go through
	
	rd.sync()

	if half_resolution:
		var output_bytes := rd.texture_get_data(half_color_output_rid, 0)
		var output_time := rd.buffer_get_data(camera_xform_rid, 0)
		var island_img := Image.create_from_data(half_color_output_format.width, half_color_output_format.height, false, Image.FORMAT_RGBA8, output_bytes)
		var island_tex := ImageTexture.create_from_image(island_img)
		%TextureRect.texture = island_tex
	else:
		var output_bytes := rd.texture_get_data(color_output_rid, 0)
		var output_time := rd.buffer_get_data(camera_xform_rid, 0)
		var island_img := Image.create_from_data(color_output_format.width, color_output_format.height, false, Image.FORMAT_RGBA8, output_bytes)
		var island_tex := ImageTexture.create_from_image(island_img)
		%TextureRect.texture = island_tex
		
	last_update_was_half_rez = half_resolution
	viewport_needs_update = false
