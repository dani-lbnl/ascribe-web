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


## step_size_for is the single source of truth behind pick_tier's step sizes; the display
## settings panel's manual quality slider goes through the same function, so it must reproduce
## these exact tier pairs too.
func test_step_size_for_matches_desktop_tier() -> void:
	assert_that(Quality.step_size_for(256)).is_equal(0.005)


func test_step_size_for_matches_xr_tier() -> void:
	assert_that(Quality.step_size_for(128)).is_equal(0.008)


func test_step_size_for_matches_mobile_tier() -> void:
	assert_that(Quality.step_size_for(96)).is_equal(0.012)


func test_step_size_for_interpolates_between_anchors() -> void:
	var mid := Quality.step_size_for(192)
	assert_that(mid).is_greater(0.005)
	assert_that(mid).is_less(0.008)
