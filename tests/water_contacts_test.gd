extends SceneTree
## Vertical walls have no useful shallow-depth ramp: their true waterline must
## still produce a continuous metric distance, including transformed instances.
const Contacts = preload("res://presentation/water_contacts.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var wall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2, 2, 4)
	wall.mesh = box
	holder.add_child(wall)
	wall.position = Vector3(5, -0.25, -3)
	wall.rotation.y = 0.43
	wall.scale = Vector3(1.2, 1, 0.8)
	var dry := MeshInstance3D.new()
	dry.mesh = box
	holder.add_child(dry)
	dry.position = Vector3(-6, 3, 4)
	var sources: Array[Node3D] = [holder]
	var start: int = Time.get_ticks_usec()
	var field: Image = Contacts.build(sources, -0.25).get_image()
	print("WATER_CONTACT_BAKE fixture_ms=%.2f" % ((Time.get_ticks_usec() - start) / 1000.0))
	for side: float in [-1.0, 1.0]:
		for distance: float in [0.0, 0.3, 0.8, 1.5]:
			var p: Vector3 = wall.to_global(Vector3(side * (1.0 + distance / 1.2), 0, 0))
			var measured: float = _sample(field, Vector2(p.x, p.z))
			_expect(absf(measured - distance) < 0.10, "Rotated/scaled bank has correct distance %.2f (got %.2f)" % [distance, measured])
	_expect(is_equal_approx(_sample(field, Vector2(-6, 4)), Contacts.REACH), "Dry geometry does not create water rings")
	_expect(is_equal_approx(_sample(field, Vector2(-18, -18)), Contacts.REACH), "Open lake remains outside the contact band")
	# A different water height must be resliced, rather than reuse the old contour.
	var above: Image = Contacts.build(sources, 5.0).get_image()
	_expect(is_equal_approx(_sample(above, Vector2(5, -3)), Contacts.REACH), "Geometry wholly below the surface does not invent a shoreline")
	holder.free()
	for failure: String in failures: push_error(failure)
	print("WATER_CONTACTS_TEST checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _sample(field: Image, point: Vector2) -> float:
	var uv: Vector2 = (point + Vector2.ONE * Contacts.EXTENT) / (2.0 * Contacts.EXTENT)
	return sqrt(field.get_pixel(floori(uv.x * Contacts.SIZE), floori(uv.y * Contacts.SIZE)).r)

func _expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)
