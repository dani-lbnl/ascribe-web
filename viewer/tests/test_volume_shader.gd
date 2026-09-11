extends GdUnitTestSuite

const SHADER_PATH := "res://shaders/volume_web.gdshader"


func _source() -> String:
	return FileAccess.get_file_as_string(SHADER_PATH)


# The volume texture is normalized per-axis by `box_extents`, not by upstream's scalar `zoom`.
# (The old scalar mapping is what rendered everything black: its default of 2 pushed every
# sample coordinate outside [0, 1], so the march broke on its first step.)
func test_texture_coordinates_are_normalized_by_box_extents() -> void:
	var src := _source()
	assert_str(src).contains("uniform vec3 box_extents")
	assert_str(src).contains("(ray_pos / (2.0 * box_extents)) + vec3(0.5)")
	assert_str(src).not_contains("uniform float zoom")


# Regression: Godot 4.6's Compatibility (GLES3) backend only declares `eye_offset` in the
# multiview shader variant, so referencing it fails to compile the mono variant ("undefined
# variable eye_offset") and the whole volume renders black in a non-XR browser tab.
func test_shader_does_not_reference_eye_offset() -> void:
	assert_str(_source()).not_contains("EYE_OFFSET)")


# Fixed-step raymarching makes every ray sample the same evenly spaced planes, which beats
# against the volume's structure as banding. Upstream's interleaved gradient noise offsets each
# ray individually.
func test_ray_start_is_jittered() -> void:
	var src := _source()
	assert_str(src).contains("float jitter = fract(52.9829189")
	assert_str(src).contains("(float(i) + jitter) * march_step")


# Compositing must weight each sample by the remaining transmittance. Accumulating raw opacity
# (`total_opacity += sample_opacity`) saturates early and flattens the volume.
func test_compositing_weights_by_remaining_transmittance() -> void:
	assert_str(_source()).contains("total_opacity += sample_opacity * (1.0 - total_opacity);")


# The quality slider changes step_size, which would otherwise change how dense the volume looks.
# Correcting opacity against a reference step keeps appearance stable across quality tiers.
func test_opacity_is_corrected_for_step_size() -> void:
	var src := _source()
	assert_str(src).contains("REFERENCE_STEP")
	assert_str(src).contains("float step_ratio = march_step / REFERENCE_STEP;")


# The march is bounded by an exact ray/box interval rather than by max_steps * step_size, which
# is not guaranteed to span the box (a 1m volume's diagonal can exceed the desktop tier's reach).
func test_march_is_bounded_by_the_clipped_interval() -> void:
	var src := _source()
	assert_str(src).contains("void clip_to_box(")
	assert_str(src).contains("if (t > t_far)")


# The shader must load and instantiate as a material (catches syntax errors that would
# otherwise only surface as a silent black screen at runtime).
func test_shader_loads_as_a_material() -> void:
	var shader: Shader = load(SHADER_PATH)
	assert_that(shader).is_not_null()
	var mat := ShaderMaterial.new()
	mat.shader = shader
	assert_that(mat.shader).is_not_null()


# The march must span the clipped interval even when max_steps * step_size is shorter than it,
# and the opacity correction has to follow the step actually taken or density would shift on
# exactly those rays.
func test_march_step_widens_to_cover_the_interval() -> void:
	var src := _source()
	assert_str(src).contains("float march_step = max(step_size, span / float(max_steps));")
	assert_str(src).contains("float step_ratio = march_step / REFERENCE_STEP;")
	assert_str(src).contains("(float(i) + jitter) * march_step;")


# The per-eye origin must come from a uniform indexed by VIEW_INDEX. EYE_OFFSET cannot be named
# without breaking the mono variant under Godot 4.6's Compatibility backend, but simply dropping
# it made both eyes march from the same origin -- i.e. no stereo in a headset.
func test_per_eye_origin_uses_view_index() -> void:
	var src := _source()
	assert_str(src).contains("uniform vec3 eye_offsets[2];")
	assert_str(src).contains("vec4(eye_offsets[VIEW_INDEX], 1.0)")
