## Grab interaction for WebXR: holding one controller's grip moves/rotates the SpecimenStage by
## that controller's pose delta; holding both grips scales the stage by the change in distance
## between the controllers (clamped to 0.1x-10x the scale at the start of the two-hand grab).
## Releasing leaves the specimen exactly where it was left. Input polling is kept thin here --
## all the actual math lives in the two static functions below, which are unit-tested directly.
class_name XRGrab
extends Node

const GRIP_THRESHOLD := 0.7
const MIN_SCALE_FACTOR := 0.1
const MAX_SCALE_FACTOR := 10.0

@export var left_controller: XRController3D
@export var right_controller: XRController3D
@export var specimen_stage: Node3D

var _left_gripped: bool = false
var _right_gripped: bool = false
var _left_prev_transform: Transform3D
var _right_prev_transform: Transform3D

# Two-hand scale state.
var _two_hand_active: bool = false
var _two_hand_start_distance: float = 0.0
var _two_hand_start_scale: float = 1.0


## Returns `s` scaled by the ratio `d1 / d0` (distance now / distance at grab start), clamped to
## `[0.1 * s, 10 * s]`. If `d0` is ~0 (degenerate, e.g. controllers coincide), returns `s`
## unchanged rather than dividing by zero.
static func two_hand_scale(d0: float, d1: float, s: float) -> float:
	if absf(d0) < 0.0001:
		return s
	var new_scale := s * (d1 / d0)
	return clampf(new_scale, s * MIN_SCALE_FACTOR, s * MAX_SCALE_FACTOR)


## Returns the relative transform a controller moved through between `prev` and `curr`, expressed
## as a transform that can be left-multiplied onto any other transform to carry it through the
## same relative rotation/translation (`new_target = one_hand_delta(prev, curr) * target`).
static func one_hand_delta(prev: Transform3D, curr: Transform3D) -> Transform3D:
	return curr * prev.affine_inverse()


func _physics_process(_delta: float) -> void:
	if specimen_stage == null or left_controller == null or right_controller == null:
		return
	if not get_viewport().use_xr:
		return

	var left_grip := left_controller.get_float("grip") > GRIP_THRESHOLD
	var right_grip := right_controller.get_float("grip") > GRIP_THRESHOLD

	if left_grip and right_grip:
		_process_two_hand()
	else:
		if _two_hand_active:
			_end_two_hand()
		_process_one_hand(left_grip, right_grip)


func _process_two_hand() -> void:
	var d1 := left_controller.global_transform.origin.distance_to(right_controller.global_transform.origin)
	if not _two_hand_active:
		_two_hand_active = true
		_two_hand_start_distance = d1
		_two_hand_start_scale = specimen_stage.scale.x
		# A two-hand grab supersedes any in-progress one-hand grab.
		_left_gripped = false
		_right_gripped = false

	var new_scale := two_hand_scale(_two_hand_start_distance, d1, _two_hand_start_scale)
	specimen_stage.scale = Vector3.ONE * new_scale


func _end_two_hand() -> void:
	_two_hand_active = false
	# Re-arm one-hand tracking from the current pose so releasing one grip while the other is
	# still held doesn't cause a pose jump on the next frame.
	_left_prev_transform = left_controller.global_transform
	_right_prev_transform = right_controller.global_transform


func _process_one_hand(left_grip: bool, right_grip: bool) -> void:
	if left_grip:
		if not _left_gripped:
			_left_gripped = true
			_left_prev_transform = left_controller.global_transform
		else:
			var curr := left_controller.global_transform
			var delta := one_hand_delta(_left_prev_transform, curr)
			specimen_stage.global_transform = delta * specimen_stage.global_transform
			_left_prev_transform = curr
	else:
		_left_gripped = false

	if right_grip:
		if not _right_gripped:
			_right_gripped = true
			_right_prev_transform = right_controller.global_transform
		else:
			var curr := right_controller.global_transform
			var delta := one_hand_delta(_right_prev_transform, curr)
			specimen_stage.global_transform = delta * specimen_stage.global_transform
			_right_prev_transform = curr
	else:
		_right_gripped = false
