extends GdUnitTestSuite

const MAIN := preload("res://scenes/main.tscn")


func _make_main() -> Node3D:
	var main: Node3D = auto_free(MAIN.instantiate())
	add_child(main)
	await get_tree().process_frame
	return main


# Regression: the quads' materials carry ViewportTexture sub-resources addressed by
# `viewport_path`, which does not reliably resolve at runtime -- the quad then falls back to the
# missing-texture material, which is the pink checkerboard the panels showed in the headset.
func test_panel_quads_use_their_viewport_texture() -> void:
	var main := await _make_main()

	for pair in [["PanelQuad", "PanelViewport"], ["StoryQuad", "StoryViewport"]]:
		var quad: MeshInstance3D = main.get_node("XROrigin3D/%s" % pair[0])
		var viewport: SubViewport = main.get_node("XROrigin3D/%s" % pair[1])
		var mat: StandardMaterial3D = quad.get_surface_override_material(0)
		assert_that(mat).is_not_null()
		assert_that(mat.albedo_texture).is_not_null()
		assert_that(mat.albedo_texture).is_same(viewport.get_texture())


# Regression: the specimen was staged at the world origin, which in a headset is the floor
# between the user's feet -- it spawned underneath them instead of in front.
func test_specimen_is_staged_ahead_at_roughly_eye_height() -> void:
	var main := await _make_main()
	var stage: Node3D = main.get_node("SpecimenStage")

	assert_float(stage.position.y).is_greater(1.0)   # off the floor
	assert_float(stage.position.z).is_less(-0.5)     # in front of the origin


# ...and the desktop camera has to orbit that same point, or moving the specimen off the origin
# would push it out of frame on desktop.
func test_desktop_camera_orbits_the_specimen() -> void:
	var main := await _make_main()
	var stage: Node3D = main.get_node("SpecimenStage")
	var cam: OrbitCamera = main.get_node("Camera3D")

	assert_vector(cam.target).is_equal(stage.position)


# A headset has no browser chrome to fall back on, and the system gesture is not obvious to a
# first-time user, so the in-VR panel needs its own way out. The desktop panel must not show it.
func test_only_the_vr_panel_offers_an_exit() -> void:
	var main := await _make_main()

	var vr_button: Button = main.get_node(
		"XROrigin3D/PanelViewport/DisplaySettingsPanel/VBox/ExitVR")
	var desktop_button: Button = main.get_node(
		"CanvasLayer/DisplaySettingsPanel/VBox/ExitVR")

	assert_bool(vr_button.visible).is_true()
	assert_bool(desktop_button.visible).is_false()


func test_exit_button_emits_exit_vr_requested() -> void:
	var main := await _make_main()
	var panel: DisplaySettingsPanel = main.get_node(
		"XROrigin3D/PanelViewport/DisplaySettingsPanel")
	var seen := [false]
	panel.exit_vr_requested.connect(func(): seen[0] = true)

	panel.get_node("VBox/ExitVR").pressed.emit()

	assert_bool(seen[0]).is_true()
