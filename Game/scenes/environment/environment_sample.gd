extends Node3D
## Isolated render and geometric validation; no save or live main-scene dependencies.
const COURTYARD=preload("res://scenes/environment/courtyard.tscn")
var yard:Node3D
var camera:Camera3D
var sunlight:DirectionalLight3D
var fields:Array[StaticBody3D]=[]
var attributes:CameraAttributesPractical
var sample_lantern:Node3D

func _ready() -> void:
	yard=COURTYARD.instantiate();add_child(yard)
	var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("e0e7d8")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("e6ecdc");env.ambient_light_energy=.40
	env.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	env.fog_enabled=true;env.fog_light_color=Color("c6d7cc");env.fog_density=.0015
	var world:=WorldEnvironment.new();world.environment=env;add_child(world)
	sunlight=DirectionalLight3D.new();sunlight.light_color=Color("fff8ea");sunlight.light_energy=.8;sunlight.rotation_degrees=Vector3(-52,-24,0);sunlight.shadow_enabled=true;add_child(sunlight)
	camera=Camera3D.new();camera.fov=35;camera.far=150;camera.current=true;add_child(camera)
	attributes=CameraAttributesPractical.new();camera.attributes=attributes
	_build_fields()
	for pair in [["pot","ground_01"],["flowerpot","ground_02"],["lantern","hanging_01"]]:
		var decoration:Node3D=yard.get_decoration_scene(pair[0]).instantiate();add_child(decoration);decoration.global_transform=yard.get_slot_marker(pair[1]).global_transform
		if pair[0]=="lantern":sample_lantern=decoration
	_pose(Vector3(0,.6,0),32,34,29.5)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):_capture(arg.trim_prefix("--capture-dir="))

func _build_fields() -> void:
	var soil:=StandardMaterial3D.new();soil.albedo_color=Color("77694a");soil.roughness=1
	for row in 2:
		for col in 3:
			var field:=StaticBody3D.new();field.name="field_%02d"%(row*3+col+1);field.position=Vector3(-3.3+col*3.25,.2,row*2.8);add_child(field);fields.append(field)
			var shape:=BoxShape3D.new();shape.size=Vector3(2.6,.10,2.05)
			var collider:=CollisionShape3D.new();collider.shape=shape;field.add_child(collider)
			var mesh:=BoxMesh.new();mesh.size=shape.size
			var visible_soil:=MeshInstance3D.new();visible_soil.mesh=mesh;visible_soil.material_override=soil;field.add_child(visible_soil)
			for x in 3:
				for z in 3:
					var plant:Node3D=(load("res://art/crops/greens/greens_mature.glb") as PackedScene).instantiate();field.add_child(plant);plant.position=Vector3(-.8+x*.8,.06,-.60+z*.60)

func _pose(point:Vector3,yaw:float,pitch:float,distance:float)->void:
	var y:float=deg_to_rad(yaw);var p:float=deg_to_rad(pitch)
	camera.position=point+Vector3(sin(y)*cos(p),sin(p),cos(y)*cos(p))*distance
	camera.look_at(point)

func _save(folder:String,name:String)->void:
	await get_tree().process_frame;await get_tree().process_frame;await RenderingServer.frame_post_draw
	var error:int=get_viewport().get_texture().get_image().save_png(folder.path_join(name+".png"))
	assert(error==OK);print("ENV_SCREENSHOT ",name)

func _capture(folder:String)->void:
	DirAccess.make_dir_recursive_absolute(folder)
	await get_tree().physics_frame
	if OS.get_cmdline_user_args().has("--support-only"):
		sample_lantern.global_transform=yard.get_slot_marker("hanging_04").global_transform
		_pose(sample_lantern.global_position+Vector3(0,-.25,0),32,28,4.3)
		await _save(folder,"16-support-hanging_04")
		get_tree().quit();return
	await _save(folder,"01-overview-high")
	yard.set_low_detail_enabled(true);await _save(folder,"02-overview-low");yard.set_low_detail_enabled(false)
	_pose(Vector3(.2,1.6,-3.7),24,23,17);await _save(folder,"03-house-veranda")
	_pose(Vector3(8,.45,1.2),34,25,11);await _save(folder,"04-bridge-boat-high")
	yard.set_low_detail_enabled(true);await _save(folder,"05-bridge-boat-low");yard.set_low_detail_enabled(false)
	_pose(Vector3(7.8,.45,3.2),-90,12,7);await _save(folder,"06-boat-canopy-opening")
	_pose(Vector3(-5.9,1.5,-1.2),30,24,11);await _save(folder,"07-tree-trellis-high")
	yard.set_low_detail_enabled(true);await _save(folder,"08-tree-trellis-low");yard.set_low_detail_enabled(false)
	_pose(Vector3(0,.55,2.8),32,36,9.5);await _save(folder,"09-focus-field")
	attributes.dof_blur_far_enabled=true;attributes.dof_blur_far_distance=11.5;attributes.dof_blur_far_transition=5;attributes.dof_blur_amount=.045
	await _save(folder,"10-focus-gentle-dof");attributes.dof_blur_far_enabled=false
	for view in [[-12,28,34,-2,-2],[68,28,34,2,2],[-12,58,22,-2,2],[68,58,22,2,-2]]:
		_pose(Vector3(view[3],.6,view[4]),view[0],view[1],view[2]);await _save(folder,"11-legal-limit-%d-%d"%[view[0],view[1]])
	_pose(Vector3(0,1.5,-4.5),180,25,15);await _save(folder,"12-rear-structure")
	_pose(Vector3(-5.1,.65,-1.85),28,25,3.2);await _save(folder,"13-jar")
	_pose(Vector3(4.7,.7,-1.8),28,25,3);await _save(folder,"14-flowerpot")
	_pose(Vector3(-2.5,1.85,-2.05),28,18,3);await _save(folder,"15-unlit-lantern")
	for id in ["hanging_01","hanging_02","hanging_03","hanging_04"]:
		sample_lantern.global_transform=yard.get_slot_marker(id).global_transform
		_pose(sample_lantern.global_position+Vector3(0,-.25,0),32,28,4.3);await _save(folder,"16-support-"+id)
	sample_lantern.global_transform=yard.get_slot_marker("hanging_01").global_transform
	_pose(Vector3(0,.6,0),32,34,29.5)
	var checks:Dictionary={"slots":yard.get_decoration_slots().size(),"fields":[],"asset_keys":yard.get_asset_keys(),"camera_extremes":"captured"}
	for field in fields:
		var q:=PhysicsRayQueryParameters3D.create(camera.position,field.global_position);q.collision_mask=1
		var hit:Dictionary=get_world_3d().direct_space_state.intersect_ray(q)
		var passed:bool=not hit.is_empty() and hit.collider==field
		checks.fields.append({"id":str(field.name),"ray_hit":passed});assert(passed)
	assert(checks.slots==8)
	var f:=FileAccess.open(folder.path_join("validation.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	print("ENV_VALIDATION passed");get_tree().quit()
