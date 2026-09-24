extends RefCounted
## Fixed-size joinery and openings; structural spans follow the chosen footprint.
const Parts = preload("res://scenes/procedural_lab/kit_parts.gd")
const DEFAULTS := {"bays":3,"depth":4.2,"height":2.7,"pitch":30.0,"porch":1,"openings":0}
const BAY: float=2.15
const FLOOR: float=.48

static func plan(seed_text: String,options: Dictionary) -> Dictionary:
	var p: Dictionary=DEFAULTS.duplicate()
	for key: String in p: p[key]=options.get(key,p[key])
	p.bays=clampi(int(p.bays),2,3); p.depth=clampf(p.depth,3.6,5.2)
	p.height=clampf(p.height,2.4,3.2); p.pitch=clampf(p.pitch,22,38)
	p.porch=clampi(int(p.porch),0,1); p.openings=clampi(int(p.openings),0,2)
	var width: float=p.bays*BAY
	var door_bay: int=(p.bays-1)/2 if p.openings==0 else (0 if p.openings==1 else p.bays-1)
	var door_x: float=-width*.5+BAY*(door_bay+.5)
	return {"kind":"house","seed":seed_text.strip_edges(),"settings":p,"width":width,"door_bay":door_bay,"door_x":door_x,"front_extent":p.depth*.5+.38+p.porch*.9,"back_extent":p.depth*.5+.38,"joint":Vector3(width*.5,FLOOR+p.height,p.depth*.5)}

static func roof_y(z: float,p: Dictionary) -> float:
	var half: float=p.depth*.5
	var core: float=minf(absf(z),half)
	var extra: float=maxf(0,absf(z)-half)
	return FLOOR+p.height+(half-core)*tan(deg_to_rad(p.pitch))-extra*.16+.075*extra*extra

static func build(data: Dictionary) -> Node3D:
	var parts := Parts.new()
	var p: Dictionary=data.settings
	var rng := RandomNumberGenerator.new(); rng.seed=data.seed.hash()
	var w: float=data.width; var d: float=p.depth
	var porch: float=p.porch*.95
	_add(parts,"house_stone",Vector3(0,.3015,porch*.5),Vector3(w+.26,.98,(d+porch+.26)/.42))
	# Separate masonry joints stay at a consistent scale along the outer edge.
	for side: int in [-1,1]:
		var z: float=side*(d*.5+.13)+(porch if side==1 else 0.0)
		var count: int=ceili((w+.26)/.85)
		var length: float=(w+.26)/count
		for i: int in count:
			_add(parts,"house_stone",Vector3(-(w+.26)*.5+length*(i+.5),.305,z),Vector3(length-.014,1,.65))
	for side: int in [-1,1]:
		var count: int=ceili((d+porch)/.85)
		var length: float=(d+porch)/count
		for i: int in count:
			_add(parts,"house_stone",Vector3(side*(w*.5+.13),.305,-d*.5+length*(i+.5)),Vector3(length-.014,1,.65),PI*.5)
	for side: int in [-1,1]:
		var z: float=side*d*.5
		var yaw: float=0 if side==1 else PI
		for i: int in p.bays:
			var x: float=-w*.5+BAY*(i+.5)
			var style: String="door" if side==1 and i==data.door_bay else ("plain" if side==-1 and i%2==1 else "window")
			_panel(parts,Vector3(x,FLOOR,z),yaw,BAY-.18,p.height-.09,style,p.openings%2)
		for i: int in p.bays+1:
			_add(parts,"house_post",Vector3(-w*.5+i*BAY,FLOOR,z),Vector3(1,p.height-.08,1))
		parts.span("house_beam",Vector3(-w*.5,FLOOR+p.height-.16,z),Vector3(w*.5,FLOOR+p.height-.16,z))
	for side: int in [-1,1]:
		var x: float=side*w*.5
		for j: int in 2:
			var z: float=(j-.5)*d*.5
			_panel(parts,Vector3(x,FLOOR,z),side*PI*.5,d*.5-.18,p.height-.09,"window" if j==1 else "plain",p.openings%2)
		_add(parts,"house_post",Vector3(x,FLOOR,0),Vector3(1,p.height-.08,1))
		parts.span("house_beam",Vector3(x,FLOOR+p.height-.16,-d*.5),Vector3(x,FLOOR+p.height-.16,d*.5))
		_add(parts,"house_gable",Vector3(x,FLOOR+p.height-.084,0),Vector3(d,d*.5*tan(deg_to_rad(p.pitch))-.01,.17),side*PI*.5)
		# Gable bargeboards lie directly under each roof slope.
		for end: int in [-1,1]:
			parts.span("house_beam",Vector3(x,roof_y(end*d*.5,p)-.16,end*d*.5),Vector3(x,roof_y(0,p)-.16,0),.8)
	if p.porch==1:
		var z: float=d*.5+.83
		for i: int in p.bays+1:
			_add(parts,"house_post",Vector3(-w*.5+i*BAY,FLOOR-.007,z),Vector3(1,roof_y(z,p)-FLOOR-.123,1))
		parts.span("house_beam",Vector3(-w*.5,roof_y(z,p)-.15,z),Vector3(w*.5,roof_y(z,p)-.15,z))
	for i: int in 2:
		_add(parts,"house_stone",Vector3(data.door_x,.13+.08*(i+1),d*.5+porch+.32+(1-i)*.30),Vector3(1.8,.16*(i+1)/.35,.75))
	_roof(parts,data,rng)
	var root: Node3D=parts.build()
	root.set_meta("plan",data)
	return root

static func _add(parts: RefCounted,part: String,at: Vector3,size: Vector3=Vector3.ONE,yaw: float=0,detail: String="both") -> void:
	parts.add(part,Transform3D(Basis(Vector3.UP,yaw).scaled_local(size),at),detail)

static func _detail(parts: RefCounted,part: String,pose: Transform3D) -> void:
	parts.add(part,pose,"near"); parts.add(part+"_low",pose,"far")

static func _panel(parts: RefCounted,at: Vector3,yaw: float,width: float,height: float,style: String,pattern: int) -> void:
	var frame := Transform3D(Basis(Vector3.UP,yaw),at)
	if style=="plain":
		parts.add("house_wall",frame*Transform3D(Basis.from_scale(Vector3(width,height,.18)),Vector3(0,height*.5,0)))
		return
	var opening_w: float=1.47 if style=="door" else 1.36
	var bottom: float=0 if style=="door" else .88
	var top: float=2.25 if style=="door" else 2.10
	var side_w: float=(width-opening_w)*.5
	for side: int in [-1,1]:
		parts.add("house_wall",frame*Transform3D(Basis.from_scale(Vector3(side_w,height,.18)),Vector3(side*(opening_w+side_w)*.5,height*.5,0)))
	if bottom>0:
		parts.add("house_wall",frame*Transform3D(Basis.from_scale(Vector3(opening_w,bottom,.18)),Vector3(0,bottom*.5,0)))
	parts.add("house_wall",frame*Transform3D(Basis.from_scale(Vector3(opening_w,height-top,.18)),Vector3(0,(height+top)*.5,0)))
	if style=="door":
		_detail(parts,"house_door",frame*Transform3D(Basis.IDENTITY,Vector3(0,0,.035)))
	else:
		_detail(parts,"house_window_a" if pattern==0 else "house_window_b",frame*Transform3D(Basis.IDENTITY,Vector3(0,1.50,.035)))

static func _roof(parts: RefCounted,data: Dictionary,rng: RandomNumberGenerator) -> void:
	var p: Dictionary=data.settings
	var width: float=data.width+.70
	var columns: int=ceili(width/.30)
	var interval: float=width/columns
	for side: int in [-1,1]:
		var run: float=data.front_extent if side==1 else data.back_extent
		# Continuous backing follows the same profile, including the eave bend.
		# Ceramic overlaps then remain small dark joints, never holes to the sky.
		var deck_steps: int=ceili(run/.16)
		for i: int in deck_steps:
			var za: float=side*run*i/deck_steps
			var zb: float=side*run*(i+1)/deck_steps
			var a:=Vector3(0,roof_y(za,p)-.07,za)
			var b:=Vector3(0,roof_y(zb,p)-.07,zb)
			var along: Vector3=(b-a).normalized()
			var right: Vector3=Vector3.RIGHT*side
			parts.add("house_roof_deck",Transform3D(Basis(right,along.cross(right),along).scaled_local(Vector3(width,1,a.distance_to(b)+.008)),(a+b)*.5))
		var rows: int=ceili((run-.12)/.35)+1
		var step: float=(run-.12)/maxi(1,rows-1)
		for row: int in rows:
			var z: float=side*(.12+row*step)
			var slope: float=(roof_y(z+side*.012,p)-roof_y(z-side*.012,p))/.024
			var along := Vector3(0,slope,side).normalized()
			var right: Vector3=Vector3.RIGHT*side
			var basis := Basis(right,along.cross(right),along)
			for column: int in columns:
				var x: float=-width*.5+interval*(column+.5)
				var tone: int=rng.randi_range(0,2)
				_detail(parts,"house_tile_pan%d"%tone,Transform3D(basis,Vector3(x,roof_y(z,p)+.015,z)))
				if column<columns-1:
					_detail(parts,"house_tile_cap%d"%rng.randi_range(0,2),Transform3D(basis,Vector3(x+interval*.5,roof_y(z,p)+.023,z)))
		var edge_z: float=side*run
		parts.span("house_beam",Vector3(-width*.5,roof_y(edge_z,p)-.12,edge_z),Vector3(width*.5,roof_y(edge_z,p)-.12,edge_z))
	# Ridge overlaps the two roof halves; caps lie across the slope tiles.
	_add(parts,"house_roof_deck",Vector3(0,roof_y(0,p)-.023,0),Vector3(width,5,.25))
	var ridge_count: int=ceili(width/.31)
	for i: int in ridge_count:
		var x: float=-width*.5+width/ridge_count*(i+.5)
		_detail(parts,"house_tile_cap1",Transform3D(Basis(Vector3.UP,PI*.5).scaled_local(Vector3(2.0,1.3,1)),Vector3(x,roof_y(0,p)+.065,0)))
	for side: int in [-1,1]:
		_detail(parts,"house_finial",Transform3D(Basis(Vector3.UP,0 if side==1 else PI),Vector3(side*(width*.5-.05),roof_y(0,p)+.07,0)))
