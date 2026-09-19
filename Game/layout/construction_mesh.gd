extends RefCounted
## Assemble boxes and constant-radius poles in CPU arrays; upload only the result.
var vertices:=PackedVector3Array()
var normals:=PackedVector3Array()
var tangents:=PackedFloat32Array()
var uvs:=PackedVector2Array()
var indices:=PackedInt32Array()

func append(arrays: Array, pose: Transform3D) -> void:
	var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var directions: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var frame: PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT]
	var offset: int=vertices.size()
	# These primitives scale along surface tangents. Rotate their shading frame
	# without amplifying the primitive buffer's quantized near-zero components.
	var normal_basis: Basis=pose.basis.orthonormalized()
	for i: int in points.size():
		vertices.append(pose*points[i])
		normals.append((normal_basis*directions[i]).normalized())
		var tangent: Vector3=(normal_basis*Vector3(frame[i*4],frame[i*4+1],frame[i*4+2])).normalized()
		tangents.append_array(PackedFloat32Array([tangent.x,tangent.y,tangent.z,frame[i*4+3]]))
	uvs.append_array(arrays[Mesh.ARRAY_TEX_UV])
	for index: int in arrays[Mesh.ARRAY_INDEX]: indices.append(offset+index)

func commit() -> ArrayMesh:
	var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_TANGENT]=tangents;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh
