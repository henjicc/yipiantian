extends SceneTree
## Rebuild after changing default layout, shoreline models or the soil generator.
## Run with pinned Godot --headless --path Game --script ../scripts/bake-wallpaper-data.gd.
const Courtyard = preload("res://scenes/environment/courtyard.gd")
const Plan = preload("res://layout/courtyard_plan.gd")
const Soil = preload("res://presentation/tilled_soil.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var courtyard := Courtyard.new()
	courtyard.bake_static_data = true
	root.add_child(courtyard)
	var points: Dictionary = {}
	for entry: Dictionary in courtyard.get_node("NeighborIslets")._islets:
		var bins: Dictionary = {}
		entry.plants._slice(entry.high, bins)
		var keys: Array = bins.keys()
		keys.sort()
		var shoreline := PackedVector3Array()
		for key: int in keys: shoreline.append(bins[key])
		points[entry.plants.shore_key(entry.high)] = shoreline
	var shorelines := Resource.new()
	shorelines.set_meta("points", points)
	assert(ResourceSaver.save(shorelines, "res://art/environment/islets/shorelines.tres") == OK)
	var water: Texture2D = courtyard.get_water_surface().material_override.get_shader_parameter("shore_distance")
	water.set_meta("layout", courtyard.plan.snapshot())
	assert(ResourceSaver.save(water, "res://art/environment/islets/default_water.res", ResourceSaver.FLAG_COMPRESS) == OK)
	var meshes: Dictionary = {}
	for field: Dictionary in Plan.new().fields:
		var half: Vector2 = (field.size - Vector2(.20,.29)) * .5
		var span: Vector2 = Plan.cell_span(field)
		for cell: String in field.cells:
			var center: Vector3 = Plan.cell_position(field,cell)
			meshes[Soil.patch_key(center,span,field.seed,half)] = Soil.patch(center,span,field.seed,half,false)
	var soil := Resource.new()
	soil.set_meta("meshes", meshes)
	assert(ResourceSaver.save(soil, "res://art/environment/soil/patches.res", ResourceSaver.FLAG_COMPRESS) == OK)
	print("WALLPAPER_DATA_BAKED shorelines=", points.size(), " soil_patches=", meshes.size())
	courtyard.free()
	quit()
