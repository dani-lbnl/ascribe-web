extends GdUnitTestSuite

const PITCH_LIMIT := 1.48352986  # ~85 degrees


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


# Regression: PITCH_LIMIT used to be ~89 degrees, but orbit_transform() swaps its up-vector to
# FORWARD once |dir . UP| > 0.999 to dodge gimbal lock -- and sin(89 deg) = 0.9998 is already
# past that threshold, so the view snapped through a roll flip at the top and bottom of the
# orbit. The clamp has to keep the camera on the safe side of the up-vector swap.
func test_pitch_limit_stays_clear_of_the_up_vector_swap() -> void:
	var at_limit := OrbitCamera.clamp_pitch(10.0)
	assert_float(absf(sin(at_limit))).is_less(0.999)
	var near := OrbitCamera.orbit_transform(0.0, at_limit - 0.02, 1.5, Vector3.ZERO)
	var at := OrbitCamera.orbit_transform(0.0, at_limit, 1.5, Vector3.ZERO)
	assert_float(near.basis.y.dot(at.basis.y)).is_greater(0.9)


# Regression: dragging the mouse down used to lower the camera, which reads as inverted --
# pulling down should tilt the specimen's top toward the viewer, i.e. raise the camera.
func test_dragging_down_raises_the_camera() -> void:
	var cam: OrbitCamera = auto_free(OrbitCamera.new())
	add_child(cam)
	var before := cam.pitch

	cam._orbit(0.0, 20.0)  # positive dy means the mouse moved down

	assert_float(cam.pitch).is_greater(before)
	assert_float(cam.global_transform.origin.y).is_greater(0.0)


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


func test_pose_string_round_trips() -> void:
	var cam: OrbitCamera = auto_free(OrbitCamera.new())
	add_child(cam)
	cam.yaw = 1.2345
	cam.pitch = 0.4
	cam.distance = 2.5

	var other: OrbitCamera = auto_free(OrbitCamera.new())
	add_child(other)
	assert_bool(other.apply_pose_string(cam.pose_string())).is_true()

	assert_float(other.yaw).is_equal_approx(1.2345, 0.001)
	assert_float(other.pitch).is_equal_approx(0.4, 0.001)
	assert_float(other.distance).is_equal_approx(2.5, 0.001)


func test_apply_pose_string_rejects_junk_without_moving_the_camera() -> void:
	var cam: OrbitCamera = auto_free(OrbitCamera.new())
	add_child(cam)
	cam.yaw = 0.5

	assert_bool(cam.apply_pose_string("not,a,pose")).is_false()
	assert_bool(cam.apply_pose_string("1.0,2.0")).is_false()
	assert_float(cam.yaw).is_equal_approx(0.5, 0.001)


func test_apply_pose_string_clamps_out_of_range_values() -> void:
	var cam: OrbitCamera = auto_free(OrbitCamera.new())
	add_child(cam)

	assert_bool(cam.apply_pose_string("0.0,99.0,999.0")).is_true()
	assert_float(absf(sin(cam.pitch))).is_less(0.999)
	assert_float(cam.distance).is_less_equal(10.0)
