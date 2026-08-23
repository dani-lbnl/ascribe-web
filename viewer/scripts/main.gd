## Main scene: loads a content bundle (from `?bundle=` on web, or a fixture bundle otherwise),
## stages its first specimen, and offers WebXR entry.
extends Node3D

var xr_interface: WebXRInterface
var _loader: BundleLoader
var _manifest: Dictionary = {}
var _specimens: Dictionary = {}

const DEFAULT_BUNDLE := "res://tests/fixtures/tiny_bundle"


func _ready() -> void:
	xr_interface = XRServer.find_interface("WebXR")
	if xr_interface:
		xr_interface.session_supported.connect(_on_session_supported)
		xr_interface.session_started.connect(_on_session_started)
		xr_interface.session_failed.connect(func(msg): push_error("WebXR failed: " + msg))
		xr_interface.is_session_supported("immersive-vr")
	$CanvasLayer/EnterVR.pressed.connect(_enter_vr)
	$CanvasLayer/EnterVR.visible = false

	_loader = BundleLoader.new()
	add_child(_loader)
	_loader.progress.connect(_on_progress)
	_loader.loaded.connect(_on_loaded)
	_loader.failed.connect(_on_failed)

	$CanvasLayer/ProgressBar.value = 0.0
	_loader.load_bundle(_resolve_bundle_url())


## Resolves the bundle base URL: `?bundle=` query param on web, falling back to the fixture
## bundle when not running on web or the param is missing.
func _resolve_bundle_url() -> String:
	if OS.has_feature("web"):
		var search: String = JavaScriptBridge.eval("window.location.search", true)
		if search is String and search != "":
			var params := (search as String).trim_prefix("?").split("&")
			for pair in params:
				var kv := pair.split("=", true, 1)
				if kv.size() == 2 and kv[0] == "bundle" and kv[1] != "":
					return kv[1]
	return DEFAULT_BUNDLE


func _on_progress(_stage: String, ratio: float) -> void:
	$CanvasLayer/ProgressBar.value = ratio * 100.0


func _on_loaded(manifest: Dictionary, specimens: Dictionary) -> void:
	_manifest = manifest
	_specimens = specimens
	$CanvasLayer/ProgressBar.visible = false

	var spec_list: Array = manifest.get("specimens", [])
	if spec_list.is_empty():
		$ErrorScreen.show_error("Bundle '%s' has no specimens" % [manifest.get("title", "")])
		return

	var first_spec: Dictionary = spec_list.front()
	var spec_id: String = first_spec.get("id", "")
	var data = specimens.get(spec_id, null)
	if data == null:
		$ErrorScreen.show_error("Specimen '%s' failed to decode" % [spec_id])
		return

	$SpecimenStage.stage(spec_id, data, first_spec.get("display", {}))


func _on_failed(message: String) -> void:
	$CanvasLayer/ProgressBar.visible = false
	$ErrorScreen.show_error(message)


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
