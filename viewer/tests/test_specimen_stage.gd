extends GdUnitTestSuite

const FIXTURE := "res://tests/fixtures/tiny_bundle/"


func _load_fixture_volume() -> WebVolumetricData:
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE + "manifest.json"))
	var body := FileAccess.get_file_as_bytes(FIXTURE + manifest["specimens"][0]["data"])
	var parsed := BinaryEnvelope.parse(body)
	var vol := WebVolumetricData.new()
	vol.set_from_bytes(parsed["preamble"], body, parsed["offset"])
	return vol


func _count_mesh_children(node: Node) -> int:
	var count := 0
	for child in node.get_children():
		if child is MeshInstance3D:
			count += 1
	return count


func test_stage_volume_sets_id_and_shader_params() -> void:
	var stage: SpecimenStage = auto_free(SpecimenStage.new())
	add_child(stage)

	var vol := _load_fixture_volume()
	stage.stage("specimen_0", vol, {"gamma": 1.5, "opacity": 0.8})

	assert_that(stage.current_id).is_equal("specimen_0")
	assert_that(_count_mesh_children(stage)).is_equal(1)

	var mesh_child: MeshInstance3D = null
	for child in stage.get_children():
		if child is MeshInstance3D:
			mesh_child = child
	assert_that(mesh_child).is_not_null()

	var mat: ShaderMaterial = mesh_child.get_surface_override_material(0)
	assert_that(mat).is_not_null()
	assert_that(float(mat.get_shader_parameter("gamma"))).is_equal(1.5)


func test_stage_second_specimen_replaces_first() -> void:
	var stage: SpecimenStage = auto_free(SpecimenStage.new())
	add_child(stage)

	var vol := _load_fixture_volume()
	stage.stage("specimen_0", vol, {"gamma": 1.0})
	var first_child: Node = stage.get_child(0)

	stage.stage("specimen_1", vol, {"gamma": 2.0})

	assert_that(stage.current_id).is_equal("specimen_1")
	assert_that(_count_mesh_children(stage)).is_equal(1)
	assert_that(is_instance_valid(first_child) and first_child.is_inside_tree()).is_false()


func test_gradient_from_stops() -> void:
	var stage: SpecimenStage = auto_free(SpecimenStage.new())
	add_child(stage)

	var tex: GradientTexture1D = stage._gradient_from_stops([[0.0, "#00000000"], [1.0, "#ffffffff"]])
	assert_that(tex).is_not_null()
	assert_that(tex.gradient.get_point_count()).is_equal(2)
