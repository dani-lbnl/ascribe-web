## Small orientation gadget: draws the world X/Y/Z axes as they currently appear from the
## camera, so it is obvious which way the volume is turned. Drawn on the 2D CanvasLayer, so it
## shows on desktop and in a browser and is simply absent in a headset.
class_name AxesGadget
extends Control

const AXIS_COLORS := {
	"X": Color(0.92, 0.33, 0.33),
	"Y": Color(0.45, 0.85, 0.45),
	"Z": Color(0.40, 0.60, 0.95),
}
const AXIS_VECTORS := {
	"X": Vector3.RIGHT,
	"Y": Vector3.UP,
	"Z": Vector3.BACK,
}

## Radius of the gadget in pixels (length of a fully side-on axis).
@export var radius: float = 34.0

var camera: Camera3D


func _process(_delta: float) -> void:
	if camera != null:
		queue_redraw()


## Where a world-space axis points on screen, in Control-local pixels, given the camera's basis.
## Godot's 2D y axis grows downward while 3D's grows up, hence the flip.
##
## Returned as a pair: the screen vector, and the axis's depth component (negative = pointing
## away from the viewer, since a Godot camera looks down its own -Z).
static func axis_screen_vector(camera_basis: Basis, axis: Vector3, length: float) -> Array:
	var view_space := camera_basis.inverse() * axis
	return [Vector2(view_space.x, -view_space.y) * length, view_space.z]


func _draw() -> void:
	if camera == null:
		return

	var centre := size / 2.0
	var basis := camera.global_transform.basis
	var font := ThemeDB.fallback_font
	var font_size := 12

	draw_circle(centre, radius + 8.0, Color(0, 0, 0, 0.35))

	for name in AXIS_VECTORS:
		var result := axis_screen_vector(basis, AXIS_VECTORS[name], radius)
		var offset: Vector2 = result[0]
		var depth: float = result[1]
		var color: Color = AXIS_COLORS[name]
		# An axis pointing away from the viewer is drawn dimmer, so the gadget reads as 3D
		# rather than as three ambiguous lines.
		if depth > 0.0:
			color.a = 0.35
		draw_line(centre, centre + offset, color, 2.0, true)
		draw_string(font, centre + offset + Vector2(3, 4), name,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
