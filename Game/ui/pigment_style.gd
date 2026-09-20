extends StyleBox
## One continuous UV field inside runtime geometry: no nine-patch junctions.
const PIGMENT: Texture2D = preload("res://art/ui/pigment/wash-tile.png")
var fill := Color.WHITE
var edge := Color("a2a079")
var radius: float = 12.0
var selected: bool = false

func _draw(canvas_item: RID, rect: Rect2) -> void:
	var box := rect.grow(-1.0)
	var r: float = minf(radius, minf(box.size.x, box.size.y) * .5)
	var points := PackedVector2Array()
	var uv := PackedVector2Array()
	var centers: Array[Vector2] = [box.position+Vector2(r,r), Vector2(box.end.x-r,box.position.y+r), box.end-Vector2(r,r), Vector2(box.position.x+r,box.end.y-r)]
	for corner: int in 4:
		for step: int in 17:
			var p: Vector2 = centers[corner]+Vector2.from_angle(PI+corner*PI*.5+step*PI/32.0)*r
			points.append(p)
			uv.append((p-rect.position)/216.0)
	RenderingServer.canvas_item_set_default_texture_repeat(canvas_item, RenderingServer.CANVAS_ITEM_TEXTURE_REPEAT_ENABLED)
	RenderingServer.canvas_item_add_polygon(canvas_item, points, PackedColorArray([fill]), uv, PIGMENT.get_rid())
	points.append(points[0])
	RenderingServer.canvas_item_add_polyline(canvas_item, points, PackedColorArray([edge]), 1.0, true)
	if selected:
		var line := PackedVector2Array([Vector2(box.position.x+r,box.end.y-1), Vector2(box.end.x-r,box.end.y-1)])
		RenderingServer.canvas_item_add_polyline(canvas_item,line,PackedColorArray([preload("res://ui/ui_tokens.gd").ACCENT]),1.0,true)
