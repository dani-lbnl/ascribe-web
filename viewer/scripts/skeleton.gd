extends Node3D

var xr_interface: WebXRInterface


func _ready() -> void:
	var mat: ShaderMaterial = $Volume.get_surface_override_material(0)
	if mat == null:
		mat = $Volume.mesh.surface_get_material(0)
	mat.set_shader_parameter("texture_volume", ProceduralVolume.make_texture(64))
	mat.set_shader_parameter("gradient", _default_gradient())
	xr_interface = XRServer.find_interface("WebXR")
	if xr_interface:
		xr_interface.session_supported.connect(_on_session_supported)
		xr_interface.session_started.connect(_on_session_started)
		xr_interface.session_failed.connect(func(msg): push_error("WebXR failed: " + msg))
		xr_interface.is_session_supported("immersive-vr")
	$CanvasLayer/EnterVR.pressed.connect(_enter_vr)
	$CanvasLayer/EnterVR.visible = false


func _default_gradient() -> GradientTexture1D:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(1, 0.9, 0.7, 1))
	var tex := GradientTexture1D.new()
	tex.gradient = g
	return tex


func _on_session_supported(mode: String, supported: bool) -> void:
	if mode == "immersive-vr":
		$CanvasLayer/EnterVR.visible = supported


func _enter_vr() -> void:
	xr_interface.session_mode = "immersive-vr"
	xr_interface.requested_reference_space_types = "local-floor, local"
	xr_interface.required_features = "local-floor"
	if not xr_interface.initialize():
		push_error("WebXR initialize() failed")


func _on_session_started() -> void:
	get_viewport().use_xr = true
	$CanvasLayer/EnterVR.visible = false
