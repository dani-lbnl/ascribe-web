extends GdUnitTestSuite

const PITCH_LIMIT := 1.55334303  # ~89 degrees


func test_orbit_transform_zero_looks_down_negative_z_from_positive_z() -> void:
	var xform := OrbitCamera.orbit_transform(0.0, 0.0, 2.0, Vector3.ZERO)
	assert_vector(xform.origin).is_equal_approx(Vector3(0, 0, 2), Vector3.ONE * 0.0001)
	# Looking at the origin from (0,0,2) means basis.z (camera "back") points toward +Z.
	assert_vector(xform.basis.z).is_equal_approx(Vector3(0, 0, 1), Vector3.ONE * 0.0001)


func test_orbit_transform_respects_target_offset() -> void:
	var target := Vector3(1.0, 2.0, 3.0)
	var xform := OrbitCamera.orbit_transform(0.0, 0.0, 2.0, target)
	assert_vector(xform.origin).is_equal_approx(target + Vector3(0, 0, 2), Vector3.ONE * 0.0001)


func test_orbit_transform_yaw_quarter_turn_moves_to_positive_x() -> void:
	var xform := OrbitCamera.orbit_transform(PI / 2.0, 0.0, 2.0, Vector3.ZERO)
	assert_vector(xform.origin).is_equal_approx(Vector3(2, 0, 0), Vector3.ONE * 0.001)


func test_orbit_transform_pitch_up_moves_camera_above_target() -> void:
	var xform := OrbitCamera.orbit_transform(0.0, PI / 2.0, 2.0, Vector3.ZERO)
	assert_vector(xform.origin).is_equal_approx(Vector3(0, 2, 0), Vector3.ONE * 0.001)


func test_clamp_pitch_within_range_is_unchanged() -> void:
	assert_float(OrbitCamera.clamp_pitch(0.5)).is_equal_approx(0.5, 0.0001)


func test_clamp_pitch_clamps_above_limit() -> void:
	var clamped := OrbitCamera.clamp_pitch(2.0)
	assert_float(clamped).is_less(PITCH_LIMIT + 0.001)
	assert_float(clamped).is_greater(PITCH_LIMIT - 0.001)


func test_clamp_pitch_clamps_below_negative_limit() -> void:
	var clamped := OrbitCamera.clamp_pitch(-2.0)
	assert_float(clamped).is_less(-PITCH_LIMIT + 0.001)
	assert_float(clamped).is_greater(-PITCH_LIMIT - 0.001)


func test_clamp_distance_within_range_is_unchanged() -> void:
	assert_float(OrbitCamera.clamp_distance(1.5)).is_equal_approx(1.5, 0.0001)


func test_clamp_distance_clamps_to_minimum() -> void:
	assert_float(OrbitCamera.clamp_distance(0.05)).is_equal_approx(0.2, 0.0001)


func test_clamp_distance_clamps_to_maximum() -> void:
	assert_float(OrbitCamera.clamp_distance(50.0)).is_equal_approx(10.0, 0.0001)


func test_frame_sets_distance_to_fit_aabb() -> void:
	var cam: OrbitCamera = auto_free(OrbitCamera.new())
	cam.distance = 1.5
	cam.frame(2.0)
	assert_float(cam.distance).is_greater(1.5)


func test_frame_clamps_result() -> void:
	var cam: OrbitCamera = auto_free(OrbitCamera.new())
	cam.frame(1000.0)
	assert_float(cam.distance).is_equal_approx(10.0, 0.0001)
