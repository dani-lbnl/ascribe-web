extends GdUnitTestSuite

const SHADER_PATH := "res://shaders/volume_web.gdshader"


func _source() -> String:
	return FileAccess.get_file_as_string(SHADER_PATH)


# Regression: `zoom` defaulted to 2, which scaled every sample coordinate past the [0, 1]
# texture range, so the raymarch loop broke on its first step and the volume rendered black.
# 1.0 maps the staged box exactly onto the volume texture.
func test_zoom_defaults_to_one_so_samples_land_inside_the_texture() -> void:
	assert_str(_source()).contains("uniform float zoom = 1;")


# Regression: the upstream shader added EYE_OFFSET to the camera position for multiview stereo,
# but Godot 4.6's Compatibility (GLES3) backend only declares `eye_offset` in the multiview
# variant -- referencing it fails to compile the mono variant ("undefined variable eye_offset")
# and the whole volume renders black in a non-XR browser tab.
func test_shader_does_not_reference_eye_offset() -> void:
	assert_str(_source()).not_contains("+= EYE_OFFSET")


# The shader must actually load and instantiate as a material (catches syntax errors that
# would otherwise only surface as a silent black screen at runtime).
func test_shader_loads_as_a_material() -> void:
	var shader: Shader = load(SHADER_PATH)
	assert_that(shader).is_not_null()
	var mat := ShaderMaterial.new()
	mat.shader = shader
	assert_that(mat.shader).is_not_null()
