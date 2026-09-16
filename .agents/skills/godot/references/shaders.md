---
type: Reference
title: "Shaders Reference (gdshader)"
description: "Godot's shading language (`.gdshader`) is GLSL-like."
tags: [godot, gamedev, gdscript]
generated: { by: claude-code/unversioned, at: 2026-06-19T00:00:00Z }
---
# Shaders Reference (gdshader)

**Verified 2026-06-19** against Godot 4.7. Godot 4 renamed shader essentials: `hint_color` is now `source_color`, the `SCREEN_TEXTURE` built-in is gone (declare `uniform sampler2D screen_texture : hint_screen_texture`), and `set_shader_param` is now `set_shader_parameter`. The 4.7 editor adds inline previews of text-based shader operations as you edit. Re-verify built-ins if a newer minor changes them.

Godot's shading language (`.gdshader`) is GLSL-like. Attach a shader to a node through a `ShaderMaterial`. Most 2D effects are `canvas_item` shaders.

## Anatomy

```glsl
shader_type canvas_item;          // canvas_item | spatial | particles | sky | fog
render_mode blend_mix;            // optional pipeline flags

uniform vec4 tint : source_color = vec4(1.0);     // color picker in inspector
uniform float strength : hint_range(0.0, 1.0) = 0.5;
instance uniform float wobble = 0.0;              // per-instance override

void vertex() {                   // optional: move/transform vertices
    VERTEX += vec2(sin(TIME + VERTEX.y) * wobble, 0.0);
}

void fragment() {                 // per-pixel color
    vec4 tex = texture(TEXTURE, UV);
    COLOR = mix(tex, tex * tint, strength);
}
```

Processor functions: `vertex()`, `fragment()`, and (spatial/canvas) `light()`. Common `canvas_item` built-ins: `COLOR` (output), `UV`, `TEXTURE`, `TIME`, `SCREEN_UV`, `MODULATE`, `VERTEX`. Each shader type exposes its own set, listed per type in the docs.

## Setting uniforms from GDScript

```gdscript
var mat: ShaderMaterial = $Sprite2D.material
mat.set_shader_parameter("strength", 0.8)              # NOT set_shader_param (3.x)
mat.set_shader_parameter("tint", Color.RED)
var v: float = mat.get_shader_parameter("strength")
```
Tween a uniform for animated effects (a hit flash, a fade):
```gdscript
create_tween().tween_method(
    func(v: float) -> void: mat.set_shader_parameter("flash", v), 1.0, 0.0, 0.2)
```

## Practical 2D examples

### Hit flash (tint sprite white briefly)
```glsl
shader_type canvas_item;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    COLOR = vec4(mix(tex.rgb, vec3(1.0), flash), tex.a);
}
```

### Scrolling texture
```glsl
shader_type canvas_item;
uniform vec2 scroll = vec2(0.1, 0.0);
void fragment() {
    COLOR = texture(TEXTURE, UV + TIME * scroll);
}
```

### Screen-reading effect (post-process on a full-rect ColorRect)
```glsl
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
void fragment() {
    COLOR = texture(screen_texture, SCREEN_UV) * vec4(0.6, 0.8, 1.0, 1.0);  // blue wash
}
```

## When NOT to write a shader

- Flat tint or transparency: set `modulate` / `self_modulate` on the node.
- Tint a whole canvas: use a `CanvasModulate` node.
- Standard 2D lights/shadows: use `Light2D` + `LightOccluder2D`, not a custom light shader.

Reach for a shader when the effect is per-pixel and dynamic (dissolves, outlines, distortion, palette swaps, screen post-processing).

## Drawing onto a texture from code (DrawableTexture2D, Godot 4.7)

For brush/stamp effects (fog-of-war reveal, decals, paint-on textures) without a shader or a `SubViewport`, `DrawableTexture2D` (a `Texture2D`) lets you blit one texture onto another from code. It is a blit/copy API, not a `draw_line`/`draw_rect` canvas.
```gdscript
var canvas := DrawableTexture2D.new()
canvas.setup(256, 256, DrawableTexture2D.DRAWABLE_FORMAT_RGBA8)   # also _RGBA8_SRGB / _RGBAH / _RGBAF
canvas.blit_rect(Rect2i(0, 0, 32, 32), brush_texture)            # stamp brush at top-left
$Sprite2D.texture = canvas
```
`setup(width, height, format, color := Color(1,1,1,1), use_mipmaps := false)` allocates the texture; `blit_rect(rect, source, modulate := Color(1,1,1,1), mipmap := 0, material := null)` copies a source texture into a region.

## Pitfalls

- 3.x names: `hint_color` (now `source_color`), `SCREEN_TEXTURE` (now a `hint_screen_texture` uniform), `set_shader_param` (now `set_shader_parameter`).
- Forgetting the `source_color` hint on a color uniform makes the inspector treat it as raw values and skips sRGB conversion, so colors look wrong.
- Editing the `Shader` resource shared across many materials changes all of them; duplicate the `ShaderMaterial` (not the shader) for per-instance values, or use `instance uniform`.
- Heavy `fragment()` math runs per pixel; move constants to uniforms and prefer cheap operations in hot shaders.
