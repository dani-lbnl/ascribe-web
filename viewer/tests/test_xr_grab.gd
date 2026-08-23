extends GdUnitTestSuite


func test_two_hand_scale_ratio_increase_scales_up() -> void:
	# Hands moved apart (d1 > d0): scale should increase proportionally.
	var result := XRGrab.two_hand_scale(1.0, 2.0, 1.0)
	assert_float(result).is_equal_approx(2.0, 0.0001)


func test_two_hand_scale_ratio_decrease_scales_down() -> void:
	var result := XRGrab.two_hand_scale(2.0, 1.0, 1.0)
	assert_float(result).is_equal_approx(0.5, 0.0001)


func test_two_hand_scale_is_relative_to_base_scale() -> void:
	var result := XRGrab.two_hand_scale(1.0, 2.0, 3.0)
	assert_float(result).is_equal_approx(6.0, 0.0001)


func test_two_hand_scale_clamps_to_upper_bound() -> void:
	var result := XRGrab.two_hand_scale(0.01, 1.0, 1.0)
	assert_float(result).is_equal_approx(10.0, 0.0001)


func test_two_hand_scale_clamps_to_lower_bound() -> void:
	var result := XRGrab.two_hand_scale(1.0, 0.001, 1.0)
	assert_float(result).is_equal_approx(0.1, 0.0001)


func test_two_hand_scale_zero_initial_distance_does_not_divide_by_zero() -> void:
	var result := XRGrab.two_hand_scale(0.0, 1.0, 1.0)
	assert_float(result).is_equal_approx(1.0, 0.0001)


func test_one_hand_delta_identity_when_controller_unmoved() -> void:
	var t := Transform3D(Basis.IDENTITY, Vector3(1, 2, 3))
	var delta := XRGrab.one_hand_delta(t, t)
	assert_vector(delta.origin).is_equal_approx(Vector3.ZERO, Vector3.ONE * 0.0001)
	assert_bool(delta.basis.is_equal_approx(Basis.IDENTITY)).is_true()


func test_one_hand_delta_translation_only() -> void:
	var prev := Transform3D(Basis.IDENTITY, Vector3.ZERO)
	var curr := Transform3D(Basis.IDENTITY, Vector3(0.5, 0.0, 0.0))
	var delta := XRGrab.one_hand_delta(prev, curr)
	assert_vector(delta.origin).is_equal_approx(Vector3(0.5, 0.0, 0.0), Vector3.ONE * 0.0001)


func test_one_hand_delta_rotation_composition() -> void:
	var prev := Transform3D(Basis.IDENTITY, Vector3.ZERO)
	var curr := Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3.ZERO)
	var delta := XRGrab.one_hand_delta(prev, curr)
	var expected := Basis(Vector3.UP, PI / 2.0)
	assert_bool(delta.basis.is_equal_approx(expected)).is_true()


func test_one_hand_delta_applied_to_target_composes_relative_motion() -> void:
	# Controller moved by translating +X by 1.0; applying the delta to an arbitrary target
	# transform should move it by the same relative amount.
	var prev := Transform3D(Basis.IDENTITY, Vector3(0, 0, 0))
	var curr := Transform3D(Basis.IDENTITY, Vector3(1, 0, 0))
	var delta := XRGrab.one_hand_delta(prev, curr)

	var target := Transform3D(Basis.IDENTITY, Vector3(5, 0, 0))
	var new_target := delta * target
	assert_vector(new_target.origin).is_equal_approx(Vector3(6, 0, 0), Vector3.ONE * 0.0001)
