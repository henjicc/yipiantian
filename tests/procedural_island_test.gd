extends SceneTree
const Generator = preload("res://scenes/procedural_lab/island_generator.gd")
var failures: int = 0
var cases: int = 0

func _initialize() -> void:
	for variant: int in 3:
		for seed_index: int in 8:
			var settings: Dictionary = Generator.DEFAULTS.duplicate()
			if variant == 1:
				settings.merge({"count":5,"radius":6.5,"coast":1.0,"gap":2.0,"density":28,"bridge_width":2.2,"rack_length":4.0},true)
			elif variant == 2:
				settings.merge({"count":1,"radius":10.0,"coast":0.0,"density":0,"arch":0.0},true)
			var key: String = "边界-%d"%seed_index
			var plan: Dictionary = Generator.generate(key,settings)
			check(plan.error.is_empty(),"layout generation: %s/%d"%[key,variant])
			if not plan.error.is_empty(): continue
			check(var_to_str(plan)==var_to_str(Generator.generate(key,settings)),"same seed and options reproduce the layout")
			check(plan.islands.size()==settings.count and plan.links.size()==settings.count-1,"island count and connected tree")
			var reached: Array[int] = [0]
			for edge: Dictionary in plan.links:
				check(edge.a in reached and not edge.b in reached,"bridge adds a reachable island")
				reached.append(edge.b)
				for pair: Array in [[edge.a,edge.start],[edge.b,edge.end]]:
					var island: Dictionary = plan.islands[pair[0]]
					check(Generator.fits_disk(pair[1]-island.center,settings.bridge_width*.5+.29,island.land),"bridge full mouth supported by land")
			for i: int in plan.islands.size():
				var island: Dictionary = plan.islands[i]
				check(not Geometry2D.triangulate_polygon(island.land).is_empty(),"coast triangulates")
				for j: int in range(i+1,plan.islands.size()):
					check(island.center.distance_to(plan.islands[j].center)>=island.bound+plan.islands[j].bound+settings.gap-.02,"islands and submerged slopes do not overlap")
				for path: PackedVector2Array in island.paths:
					# Independent polygon clipping checks the complete road, including bends.
					var corridors: Array[PackedVector2Array] = Geometry2D.offset_polyline(path,.49,Geometry2D.JOIN_ROUND,Geometry2D.END_ROUND)
					for corridor: PackedVector2Array in corridors:
						check(Geometry2D.clip_polygons(corridor,island.land).is_empty(),"full road corridor stays on land: %s/%d"%[key,variant])
				for j: int in island.objects.size():
					var obj: Dictionary = island.objects[j]
					check(Generator.fits_disk(obj.at,obj.radius,island.land),"whole object footprint is supported")
					for zone: Dictionary in island.bridge_zones:
						check(Generator.distance_to_path(obj.at,zone.path)>=obj.radius+zone.radius,"wide bridge mouth stays clear of objects")
					for k: int in range(j+1,island.objects.size()):
						check(obj.at.distance_to(island.objects[k].at)>=obj.radius+island.objects[k].radius,"objects do not overlap")
					for path: PackedVector2Array in island.paths:
						check(Generator.distance_to_path(obj.at,path)>=obj.radius+.09,"access roads stop outside objects")
			cases += 1
	var a: Dictionary = Generator.generate("甲",{})
	var b: Dictionary = Generator.generate("乙",{})
	check(var_to_str(a.islands[0].knots)!=var_to_str(b.islands[0].knots),"different seeds vary the coast")
	var square := PackedVector2Array([Vector2(-2,-2),Vector2(2,-2),Vector2(2,2),Vector2(-2,2)])
	check(Generator.fits_disk(Vector2.ZERO,1.9,square),"interior disk accepted")
	check(not Generator.fits_disk(Vector2(1.8,0),.3,square),"edge-crossing disk rejected")
	check(not Generator.fits_disk(Vector2(3,0),.2,square),"exterior disk rejected")
	print("PROCEDURAL_ISLAND_TEST cases=%d failures=%d"%[cases,failures])
	quit(0 if failures==0 else 1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
