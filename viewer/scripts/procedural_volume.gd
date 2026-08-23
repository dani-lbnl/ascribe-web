## Generates a small float16 test volume (soft sphere + gyroid shell) for
## the walking skeleton, tests, and the demo bundle.
class_name ProceduralVolume
extends RefCounted


static func make_slices(size: int) -> Array[Image]:
	var images: Array[Image] = []
	for z in range(size):
		var buf := PackedFloat32Array()
		buf.resize(size * size)
		for y in range(size):
			for x in range(size):
				var p := (Vector3(x, y, z) / float(size - 1)) * 2.0 - Vector3.ONE
				var sphere := clampf(1.0 - p.length(), 0.0, 1.0)
				var g := absf(sin(p.x * 6.0) * cos(p.y * 6.0) + sin(p.y * 6.0) * cos(p.z * 6.0))
				buf[y * size + x] = sphere * clampf(g, 0.0, 1.0)
		var img32 := Image.create_from_data(size, size, false, Image.FORMAT_RF, buf.to_byte_array())
		img32.convert(Image.FORMAT_RH)
		images.append(img32)
	return images


static func make_texture(size: int) -> ImageTexture3D:
	var slices := make_slices(size)
	var tex := ImageTexture3D.new()
	tex.create(Image.FORMAT_RH, size, size, size, false, slices)
	return tex
