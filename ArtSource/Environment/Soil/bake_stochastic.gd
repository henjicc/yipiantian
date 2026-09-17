extends SceneTree
## Offline material baking, not part of the game. Run with the pinned native renderer.
var view: SubViewport
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Use the native renderer for offline material baking")
		quit(1)
		return
	view = SubViewport.new()
	view.size = Vector2i(4096,4096)
	view.disable_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var rect := ColorRect.new()
	rect.size = Vector2(4096,4096)
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
render_mode unshaded;
#include "res://scenes/environment/terrain_surface.gdshaderinc"
#include "res://../ArtSource/Environment/Soil/stochastic_bake.gdshaderinc"
uniform int channel = 0;
void fragment() {
 vec3 albedo, normal, surface;
 sample_loam(UV*4.0,albedo,normal,surface);
 COLOR = vec4(channel == 0 ? albedo : (channel == 1 ? normal.xzy*.5+.5 : surface),1.0);
}
"""
	material.shader = shader
	for name: String in ["albedo","normal","surface"]:
		var image: Image = Image.load_from_file("res://../ArtSource/Environment/Soil/20260917-granular/maps/loam_"+name+".png")
		assert(image != null)
		image.generate_mipmaps()
		material.set_shader_parameter("loam_"+name,ImageTexture.create_from_image(image))
	rect.material = material
	view.add_child(rect)
	var names: Array[String] = ["albedo","normal","surface"]
	for channel: int in 3:
		material.set_shader_parameter("channel",channel)
		await process_frame
		await RenderingServer.frame_post_draw
		await process_frame
		await RenderingServer.frame_post_draw
		var result: Error = view.get_texture().get_image().save_png("res://art/environment/soil/loam_baked_"+names[channel]+".png")
		assert(result == OK)
	view.queue_free()
	await process_frame
	print("LOAM_STOCHASTIC_BAKE_COMPLETE 4096x4096 / 4m periodic")
	quit()
