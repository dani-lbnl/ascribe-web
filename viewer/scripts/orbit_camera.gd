## Desktop orbit/pan/zoom camera controller. Attach to a Camera3D in the scene tree.
## Left-drag orbits, right-drag/two-finger pan pans, wheel/pinch zooms.
## Ignores all input while the viewport is in XR mode so it never fights the HMD pose.
extends Camera3D
class_name OrbitCamera

const MIN_DISTANCE := 0.2
const MAX_DISTANCE := 10.0
# ~85 degrees. Must stay on the near side of the |dir . UP| > 0.999 up-vector swap in
# orbit_transform() (~87.4 degrees) -- clamping past it let the view snap through a roll flip at
# the top and bottom of the orbit.
const PITCH_LIMIT := 1.48352986
const ORBIT_SENSITIVITY := 0.01  # rad per pixel
const PAN_SENSITIVITY := 0.001  # fraction of distance per pixel
const ZOOM_STEP := 0.1  # fraction of current distance per wheel notch
const PINCH_SENSITIVITY := 0.01  # fraction of distance per magnify-gesture unit

var yaw: float = 0.0
var pitch: float = 0.0
var distance: float = 1.5
var target: Vector3 = Vector3.ZERO

var _orbiting: bool = false
var _panning: bool = false

## Active touch points by finger index, so pinch/two-finger pan can be resolved from raw touch
## events. Godot does not synthesise magnify/pan gestures on Android or web, so a touch device
## gets nothing from the InputEventMagnifyGesture path a laptop trackpad uses.
var _touches: Dictionary = {}
## Distance and centroid between two fingers on the previous frame, for pinch/pan deltas.
var _last_pinch_distance: float = 0.0
var _last_centroid: Vector2 = Vector2.ZERO


func _ready() -> void:
	_sync_transform()


## Pure math: camera transform that orbits `target` at `distance`, rotated by `yaw` (around Y)
## and `pitch` (around the local X axis), looking at `target`. No clamping is applied here —
## callers are expected to pass already-clamped pitch/distance.
static func orbit_transform(yaw: float, pitch: float, distance: float, target: Vector3) -> Transform3D:
	var dir := Vector3(cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw))
	var origin := target + dir * distance
	var up := Vector3.UP
	if absf(dir.dot(Vector3.UP)) > 0.999:
		up = Vector3.FORWARD
	var basis := Basis.looking_at(-dir, up)
	return Transform3D(basis, origin)


static func clamp_pitch(value: float) -> float:
	return clampf(value, -PITCH_LIMIT, PITCH_LIMIT)


static func clamp_distance(value: float) -> float:
	return clampf(value, MIN_DISTANCE, MAX_DISTANCE)


## Sets distance so a specimen of the given (roughly cubic) AABB size fits comfortably in frame.
func frame(aabb_size: float) -> void:
	distance = clamp_distance(aabb_size * 1.5)
	_sync_transform()


func _unhandled_input(event: InputEvent) -> void:
	if get_viewport().use_xr:
		return

	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)
	elif event is InputEventMouseButton:
		# With emulate_mouse_from_touch on (the default), a touch also produces mouse events;
		# handling both would apply every gesture twice.
		if _touches.is_empty():
			_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		if _touches.is_empty():
			_handle_mouse_motion(event)
	elif event is InputEventPanGesture:
		_pan(event.delta.x, event.delta.y)
	elif event is InputEventMagnifyGesture:
		_zoom_by_factor(event.factor)


## Tracks fingers going down and up. Coming out of a two-finger gesture resets the pinch state
## so the remaining finger does not jump the view.
func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touches[event.index] = event.position
	else:
		_touches.erase(event.index)
	_reset_gesture_state()


## One finger orbits; two fingers pinch to zoom and move together to pan. Both are derived from
## the frame-to-frame change in the fingers' separation and centroid, so they work simultaneously
## the way they do in every other viewer.
func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	_touches[event.index] = event.position

	if _touches.size() == 1:
		_orbit(event.relative.x, event.relative.y)
		return
	if _touches.size() != 2:
		return

	var points: Array = _touches.values()
	var a: Vector2 = points[0]
	var b: Vector2 = points[1]
	var distance := a.distance_to(b)
	var centroid := (a + b) * 0.5

	if _last_pinch_distance > 0.0:
		# Fingers moving apart (distance growing) zooms in, i.e. shrinks the orbit distance.
		if distance > 0.0:
			_zoom_by_factor(distance / _last_pinch_distance)
		var drag := centroid - _last_centroid
		_pan(drag.x, drag.y)

	_last_pinch_distance = distance
	_last_centroid = centroid


func _reset_gesture_state() -> void:
	_last_pinch_distance = 0.0
	_last_centroid = Vector2.ZERO


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		_orbiting = event.pressed
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_panning = event.pressed
	elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		_zoom_by_delta(-ZOOM_STEP)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		_zoom_by_delta(ZOOM_STEP)


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _orbiting:
		_orbit(event.relative.x, event.relative.y)
	elif _panning:
		_pan(event.relative.x, event.relative.y)


func _orbit(dx: float, dy: float) -> void:
	# Drag direction follows the specimen, not the camera: dragging down pulls the top of the
	# specimen toward the viewer, which means raising the camera (increasing pitch).
	yaw -= dx * ORBIT_SENSITIVITY
	pitch = clamp_pitch(pitch + dy * ORBIT_SENSITIVITY)
	_sync_transform()


func _pan(dx: float, dy: float) -> void:
	var right := global_transform.basis.x
	var up := global_transform.basis.y
	var scale := distance * PAN_SENSITIVITY
	target -= right * dx * scale
	target += up * dy * scale
	_sync_transform()


func _zoom_by_delta(fraction: float) -> void:
	distance = clamp_distance(distance + distance * fraction)
	_sync_transform()


func _zoom_by_factor(factor: float) -> void:
	# InverseMagnify > 1.0 means "zoom in" (pinch out); shrink distance accordingly.
	distance = clamp_distance(distance / factor)
	_sync_transform()


func _sync_transform() -> void:
	transform = orbit_transform(yaw, pitch, distance, target)


## Serializes the current pose as a `?view=` query value: "yaw,pitch,distance" in radians/metres.
func pose_string() -> String:
	return "%.4f,%.4f,%.4f" % [yaw, pitch, distance]


## Applies a pose produced by `pose_string`. Returns false (leaving the camera untouched) if the
## value is malformed, so a hand-edited URL can't wedge the view.
func apply_pose_string(value: String) -> bool:
	var parts := value.split(",")
	if parts.size() != 3:
		return false
	for part in parts:
		if not part.strip_edges().is_valid_float():
			return false
	yaw = float(parts[0])
	pitch = clamp_pitch(float(parts[1]))
	distance = clamp_distance(float(parts[2]))
	_sync_transform()
	return true
