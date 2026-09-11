extends GdUnitTestSuite

# A camera with an identity basis looks down its own -Z, with +X to the right and +Y up.
func test_identity_camera_maps_world_axes_to_screen() -> void:
	var basis := Basis()

	var x: Array = AxesGadget.axis_screen_vector(basis, Vector3.RIGHT, 30.0)
	var y: Array = AxesGadget.axis_screen_vector(basis, Vector3.UP, 30.0)
	var z: Array = AxesGadget.axis_screen_vector(basis, Vector3.BACK, 30.0)

	assert_vector(x[0]).is_equal_approx(Vector2(30, 0), Vector2(0.01, 0.01))
	# Screen y grows downward, so world "up" must draw upward, i.e. negative y.
	assert_vector(y[0]).is_equal_approx(Vector2(0, -30), Vector2(0.01, 0.01))
	# +Z points at the viewer: almost no screen extent, and positive depth.
	assert_vector(z[0]).is_equal_approx(Vector2(0, 0), Vector2(0.01, 0.01))
	assert_float(z[1]).is_greater(0.0)


func test_axis_pointing_away_reports_negative_depth() -> void:
	var result: Array = AxesGadget.axis_screen_vector(Basis(), Vector3.FORWARD, 30.0)
	assert_float(result[1]).is_less(0.0)


func test_rotating_the_camera_rotates_the_gadget() -> void:
	# Camera yawed +90 degrees about up now faces -X, so world +X points back at the viewer:
	# almost no screen extent, and positive depth (Godot cameras look down their own -Z).
	var basis := Basis(Vector3.UP, PI / 2.0)

	var x: Array = AxesGadget.axis_screen_vector(basis, Vector3.RIGHT, 30.0)
	var z: Array = AxesGadget.axis_screen_vector(basis, Vector3.BACK, 30.0)

	assert_float((x[0] as Vector2).length()).is_less(0.01)
	assert_float(x[1]).is_greater(0.0)
	# ...and world +Z, previously head-on, now lies across the screen.
	assert_float((z[0] as Vector2).length()).is_greater(29.0)
