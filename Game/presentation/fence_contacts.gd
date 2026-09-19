extends "res://presentation/contact_shading.gd"
## The contact pool belongs to the disposable fence, so openings and deletion
## cannot leave its old post shadows baked into the island's static texture.
func _ready() -> void:
	var source: Node3D=get_parent()
	var spans: Array[Dictionary]=source.get_meta("fence_spans")
	if spans.is_empty(): return
	var bounds:=Rect2(Vector2(spans[0].a.x,spans[0].a.z),Vector2.ZERO)
	var planes: Array=[]
	for span: Dictionary in spans:
		bounds=bounds.expand(Vector2(span.a.x,span.a.z)).expand(Vector2(span.b.x,span.b.z))
		if not planes.has(span.a.y+.002): planes.append(span.a.y+.002)
	configure_bounds(bounds.grow(.6))
	collect(source,planes);bake()
