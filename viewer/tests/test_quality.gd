extends GdUnitTestSuite


func test_desktop_tier() -> void:
	var tier := Quality.pick_tier(PackedStringArray(), false)
	assert_that(tier["max_steps"]).is_equal(256)
	assert_that(float(tier["step_size"])).is_equal(0.005)


func test_mobile_web_android_tier() -> void:
	var tier := Quality.pick_tier(PackedStringArray(["web_android"]), false)
	assert_that(tier["max_steps"]).is_equal(96)
	assert_that(float(tier["step_size"])).is_equal(0.012)


func test_mobile_web_ios_tier() -> void:
	var tier := Quality.pick_tier(PackedStringArray(["web_ios"]), false)
	assert_that(tier["max_steps"]).is_equal(96)
	assert_that(float(tier["step_size"])).is_equal(0.012)


func test_xr_tier() -> void:
	var tier := Quality.pick_tier(PackedStringArray(), true)
	assert_that(tier["max_steps"]).is_equal(128)
	assert_that(float(tier["step_size"])).is_equal(0.008)


func test_xr_wins_over_mobile() -> void:
	var tier := Quality.pick_tier(PackedStringArray(["web_android"]), true)
	assert_that(tier["max_steps"]).is_equal(128)
	assert_that(float(tier["step_size"])).is_equal(0.008)
