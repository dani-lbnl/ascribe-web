## UI panel with sliders for gamma, opacity, and render quality (steps). Emits `display_changed`
## with a display dictionary whenever a slider moves, so callers can feed it straight to
## `SpecimenStage.apply_display`.
class_name DisplaySettingsPanel
extends Control

signal display_changed(display: Dictionary)
## Emitted when the panel's Exit VR button is pressed. The desktop copy of this panel hides the
## button (there is nothing to exit), so only the in-VR instance ever emits it.
signal exit_vr_requested
## Emitted by the Save button in edit mode. Only shown when the viewer is being served locally
## with saving enabled, so a deployed bundle never offers an action that cannot work.
signal save_requested

# The slider spans only the usable range. Below ~512 steps the render is not worth looking at,
# so the bottom of the travel is the lowest setting anyone would ship rather than a value that
# makes the viewer look broken. The top leaves headroom above the desktop tier (1024), since a
# default sitting at the ceiling reads as "raising quality does nothing".
## The Save button's resting label. After a save it reports the outcome instead, until
## something changes -- a stale "Saved" sitting over edited settings is a lie.
const SAVE_TEXT := "Save view + settings"

const MIN_STEPS := Quality.MIN_USABLE_STEPS
const MAX_STEPS := Quality.MAX_STEPS


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
	# Start at the desktop tier; _apply_quality_tier overwrites this with the real tier once a
	# specimen is staged, but the panel must never show a value outside the slider's travel.
	$VBox/Quality.value = Quality.DESKTOP_STEPS
	$VBox/Quality.value_changed.connect(func(_v): _emit_changed())

	$VBox/ExitVR.pressed.connect(func(): exit_vr_requested.emit())
	$VBox/Save.pressed.connect(func(): save_requested.emit())
	$VBox/Save.visible = false
	# Shown only in VR; set_exit_vr_visible() turns it on for the in-headset instance.
	$VBox/ExitVR.visible = false


func _emit_changed() -> void:
	clear_save_status()
	display_changed.emit(get_display())


## Puts the Save button back to its resting label, so it never claims settings are saved when
## they have since been changed.
func clear_save_status() -> void:
	if $VBox/Save.text != SAVE_TEXT:
		$VBox/Save.text = SAVE_TEXT


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


## Shows or hides the Exit VR button. A headset has no browser chrome to fall back on, so the
## in-VR panel needs its own way out; the desktop panel keeps it hidden.
func set_exit_vr_visible(shown: bool) -> void:
	$VBox/ExitVR.visible = shown


## Shows or hides the Save button, and reports the result of a save on it.
func set_edit_enabled(enabled: bool) -> void:
	$VBox/Save.visible = enabled


func set_save_status(text: String) -> void:
	$VBox/Save.text = text
