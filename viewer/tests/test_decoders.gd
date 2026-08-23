extends GdUnitTestSuite

const FIXTURE := "res://tests/fixtures/tiny_bundle/"


func _load_fixture_envelope() -> PackedByteArray:
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE + "manifest.json"))
	return FileAccess.get_file_as_bytes(FIXTURE + manifest["specimens"][0]["data"])


func test_envelope_parse_ok() -> void:
	var parsed := BinaryEnvelope.parse(_load_fixture_envelope())
	assert_that(parsed.has("error")).is_false()
	assert_that(parsed["preamble"]["type"]).is_equal("volume")
	assert_that(parsed["preamble"]["dtype"]).is_equal("float16")


func test_envelope_truncated() -> void:
	var parsed := BinaryEnvelope.parse(PackedByteArray([1, 2]))
	assert_that(parsed.has("error")).is_true()


func test_volume_set_from_bytes() -> void:
	var body := _load_fixture_envelope()
	var parsed := BinaryEnvelope.parse(body)
	var vol := WebVolumetricData.new()
	assert_that(vol.set_from_bytes(parsed["preamble"], body, parsed["offset"])).is_true()
	assert_that(vol.get_dimensions()).is_equal(Vector3i(16, 16, 16))
	assert_that(vol.get_texture()).is_not_null()


func test_volume_rejects_float32() -> void:
	var pre := {"type": "volume", "shape": [1, 1, 1], "dtype": "float32"}
	var body := PackedByteArray([0, 0, 0, 0])
	var vol := WebVolumetricData.new()
	assert_that(vol.set_from_bytes(pre, body, 0)).is_false()
