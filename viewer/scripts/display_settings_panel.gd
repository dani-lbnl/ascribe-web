## UI panel with sliders for gamma, opacity, and render quality (steps). Emits `display_changed`
## with a display dictionary whenever a slider moves, so callers can feed it straight to
## `SpecimenStage.apply_display`.
class_name DisplaySettingsPanel
extends Control

signal display_changed(display: Dictionary)

const MIN_STEPS := 32
const MAX_STEPS := 512


func _ready() -> void:
	$Gamma.min_value = 0.1
	$Gamma.max_value = 4.0
	$Gamma.value = 1.0
	$Gamma.value_changed.connect(func(_v): _emit_changed())

	$Opacity.min_value = 0.0
	$Opacity.max_value = 2.0
	$Opacity.value = 1.0
	$Opacity.value_changed.connect(func(_v): _emit_changed())

	$Quality.min_value = MIN_STEPS
	$Quality.max_value = MAX_STEPS
	$Quality.value = 128
	$Quality.value_changed.connect(func(_v): _emit_changed())


func _emit_changed() -> void:
	display_changed.emit(get_display())


## Returns the current slider state as a display dictionary. `step_size` is derived from the
## quality slider via `Quality.step_size_for`, the same lookup `Quality.pick_tier` uses, so the
## manual slider and the automatic desktop/mobile/XR tiers never disagree at the same step count.
func get_display() -> Dictionary:
	var steps: int = int($Quality.value)
	return {
		"gamma": $Gamma.value,
		"opacity": $Opacity.value,
		"max_steps": steps,
		"step_size": Quality.step_size_for(steps),
	}


## Sets slider positions from a display dictionary without emitting `display_changed`.
func set_display(display: Dictionary) -> void:
	if display.has("gamma"):
		$Gamma.set_value_no_signal(display["gamma"])
	if display.has("opacity"):
		$Opacity.set_value_no_signal(display["opacity"])
	if display.has("max_steps"):
		$Quality.set_value_no_signal(display["max_steps"])
