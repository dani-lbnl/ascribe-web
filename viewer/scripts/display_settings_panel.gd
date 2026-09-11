## UI panel with sliders for gamma, opacity, and render quality (steps). Emits `display_changed`
## with a display dictionary whenever a slider moves, so callers can feed it straight to
## `SpecimenStage.apply_display`.
class_name DisplaySettingsPanel
extends Control

signal display_changed(display: Dictionary)

const MIN_STEPS := 32
const MAX_STEPS := 512


func _ready() -> void:
	$VBox/Gamma.min_value = 0.1
	$VBox/Gamma.max_value = 4.0
	$VBox/Gamma.value = 1.0
	$VBox/Gamma.value_changed.connect(func(_v): _emit_changed())

	$VBox/Opacity.min_value = 0.0
	$VBox/Opacity.max_value = 2.0
	$VBox/Opacity.value = 1.0
	$VBox/Opacity.value_changed.connect(func(_v): _emit_changed())

	$VBox/Quality.min_value = MIN_STEPS
	$VBox/Quality.max_value = MAX_STEPS
	$VBox/Quality.value = 128
	$VBox/Quality.value_changed.connect(func(_v): _emit_changed())


func _emit_changed() -> void:
	display_changed.emit(get_display())


## Returns the current slider state as a display dictionary. `step_size` is derived from the
## quality slider via `Quality.step_size_for`, the same lookup `Quality.pick_tier` uses, so the
## manual slider and the automatic desktop/mobile/XR tiers never disagree at the same step count.
func get_display() -> Dictionary:
	var steps: int = int($VBox/Quality.value)
	return {
		"gamma": $VBox/Gamma.value,
		"opacity": $VBox/Opacity.value,
		"max_steps": steps,
		"step_size": Quality.step_size_for(steps),
	}


## Sets slider positions from a display dictionary without emitting `display_changed`.
func set_display(display: Dictionary) -> void:
	if display.has("gamma"):
		$VBox/Gamma.set_value_no_signal(display["gamma"])
	if display.has("opacity"):
		$VBox/Opacity.set_value_no_signal(display["opacity"])
	if display.has("max_steps"):
		$VBox/Quality.set_value_no_signal(display["max_steps"])
