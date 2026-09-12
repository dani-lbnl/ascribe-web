extends GdUnitTestSuite

const PANEL := preload("res://scenes/display_settings_panel.tscn")


func _make_panel() -> DisplaySettingsPanel:
	var panel: DisplaySettingsPanel = auto_free(PANEL.instantiate())
	add_child(panel)
	return panel


# Regression: the sliders live under a VBox, but the script used to address them as `$Gamma`,
# so _ready() failed with "Node not found" and the panel was inert -- moving a slider changed
# nothing and set_display() crashed on a null instance.
func test_ready_wires_sliders_and_reports_defaults() -> void:
	var panel := _make_panel()

	var display := panel.get_display()
	assert_that(display["gamma"]).is_equal(1.0)
	assert_that(display["opacity"]).is_equal(1.0)
	assert_that(display["max_steps"]).is_equal(Quality.DESKTOP_STEPS)
	assert_that(display["step_size"]).is_equal(Quality.step_size_for(Quality.DESKTOP_STEPS))


func test_moving_a_slider_emits_display_changed() -> void:
	var panel := _make_panel()
	var seen: Array[Dictionary] = []
	panel.display_changed.connect(func(d: Dictionary): seen.append(d))

	panel.get_node("VBox/Gamma").value = 2.0

	assert_that(seen.size()).is_equal(1)
	assert_that(seen[0]["gamma"]).is_equal(2.0)
	assert_that(panel.get_display()["gamma"]).is_equal(2.0)


func test_set_display_moves_sliders_without_emitting() -> void:
	var panel := _make_panel()
	var seen: Array[Dictionary] = []
	panel.display_changed.connect(func(d: Dictionary): seen.append(d))

	panel.set_display({"gamma": 1.7, "opacity": 0.4, "max_steps": 768})

	var display := panel.get_display()
	assert_float(display["gamma"]).is_equal_approx(1.7, 0.001)
	assert_float(display["opacity"]).is_equal_approx(0.4, 0.001)
	assert_that(display["max_steps"]).is_equal(768)
	assert_that(seen).is_empty()


# A "Saved" label must not linger over settings that have since been edited.
func test_changing_a_slider_restores_the_save_label() -> void:
	var panel := _make_panel()
	panel.set_save_status("Saved")

	panel.get_node("VBox/Gamma").value = 2.0

	assert_str(panel.get_node("VBox/Save").text).is_equal(DisplaySettingsPanel.SAVE_TEXT)


func test_save_label_survives_until_something_changes() -> void:
	var panel := _make_panel()
	panel.set_save_status("Saved")
	assert_str(panel.get_node("VBox/Save").text).is_equal("Saved")
