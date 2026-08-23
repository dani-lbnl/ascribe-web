## Main scene: loads a content bundle (from `?bundle=` on web, or a fixture bundle otherwise),
## stages its first specimen, and offers WebXR entry.
extends Node3D

var xr_interface: WebXRInterface
var _loader: BundleLoader
var _manifest: Dictionary = {}
var _specimens: Dictionary = {}
var _bundle_base_url: String = ""

## Set true the moment the user manually adjusts the display settings panel; once set, automatic
## quality-tier application (startup, XR enter/exit) stops overriding their choice.
var _user_touched_quality: bool = false

const DEFAULT_BUNDLE := "res://tests/fixtures/tiny_bundle"


func _ready() -> void:
	xr_interface = XRServer.find_interface("WebXR")
	if xr_interface:
		xr_interface.session_supported.connect(_on_session_supported)
		xr_interface.session_started.connect(_on_session_started)
		xr_interface.session_ended.connect(_on_session_ended)
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
	_bundle_base_url = _resolve_bundle_url()
	_loader.load_bundle(_bundle_base_url)

	_wire_xr_grab()
	_wire_display_panels()
	_wire_story_panels()
	_apply_quality_tier()


## Wires the grab controller node to the two hand controllers and the staged specimen. Left as a
## separate step (rather than tscn export properties) so it stays simple to keep in sync with the
## scene tree above.
func _wire_xr_grab() -> void:
	var grab: XRGrab = $XRGrab
	grab.left_controller = $XROrigin3D/LeftController
	grab.right_controller = $XROrigin3D/RightController
	grab.specimen_stage = $SpecimenStage

	var pointer := $XROrigin3D/XRPanelPointer
	pointer.right_controller = $XROrigin3D/RightController
	pointer.left_controller = $XROrigin3D/LeftController
	pointer.panel_quad = $XROrigin3D/PanelQuad
	pointer.panel_viewport = $XROrigin3D/PanelViewport
	pointer.laser_dot = $XROrigin3D/LaserDot

	# Story panel gets its own pointer instance (same ray-cast mechanism, different quad); it has
	# no left-controller toggle wired so it simply stays visible.
	var story_pointer := $XROrigin3D/StoryPanelPointer
	story_pointer.right_controller = $XROrigin3D/RightController
	story_pointer.panel_quad = $XROrigin3D/StoryQuad
	story_pointer.panel_viewport = $XROrigin3D/StoryViewport
	story_pointer.laser_dot = $XROrigin3D/StoryLaserDot


## Connects both the desktop and in-VR display settings panels to the staged specimen. They are
## separate instances of the same `display_settings_panel.tscn` scene (one drawn to the desktop
## CanvasLayer, one rendered into the SubViewport behind the in-VR quad) so each can be adjusted
## independently without either mode fighting the other.
func _wire_display_panels() -> void:
	var on_display_changed := func(display: Dictionary) -> void:
		_user_touched_quality = true
		$SpecimenStage.apply_display(display)
	$CanvasLayer/DisplaySettingsPanel.display_changed.connect(on_display_changed)
	$XROrigin3D/PanelViewport/DisplaySettingsPanel.display_changed.connect(on_display_changed)


## Connects both the desktop and in-VR story panels: on page navigation that pins a different
## specimen than the one currently staged, stage it.
func _wire_story_panels() -> void:
	var on_page_pinned := func(specimen_id: String) -> void:
		if specimen_id == $SpecimenStage.current_id:
			return
		var data = _specimens.get(specimen_id, null)
		if data == null:
			return
		var spec_display := _display_for_specimen(specimen_id)
		$SpecimenStage.stage(specimen_id, data, spec_display)
	$CanvasLayer/StoryPanel.page_pinned.connect(on_page_pinned)
	$XROrigin3D/StoryViewport/StoryPanel.page_pinned.connect(on_page_pinned)


## Looks up a specimen's `display` dict from the manifest, or `{}` if not found.
func _display_for_specimen(specimen_id: String) -> Dictionary:
	for spec in _manifest.get("specimens", []):
		if spec.get("id", "") == specimen_id:
			return spec.get("display", {})
	return {}


## Applies the current quality tier (desktop/mobile/XR) to the staged specimen, unless the user
## has already manually adjusted quality via a settings panel.
func _apply_quality_tier() -> void:
	if _user_touched_quality:
		return
	var features := PackedStringArray()
	if OS.has_feature("web_android"):
		features.append("web_android")
	if OS.has_feature("web_ios"):
		features.append("web_ios")
	var xr_active := get_viewport().use_xr
	var tier := Quality.pick_tier(features, xr_active)
	$SpecimenStage.apply_display(tier)
	$CanvasLayer/DisplaySettingsPanel.set_display(tier)
	$XROrigin3D/PanelViewport/DisplaySettingsPanel.set_display(tier)


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
	_apply_quality_tier()

	var story: Array = manifest.get("story", [])
	$CanvasLayer/StoryPanel.set_story(story, _bundle_base_url)
	$XROrigin3D/StoryViewport/StoryPanel.set_story(story, _bundle_base_url)


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
	_apply_quality_tier()


func _on_session_ended() -> void:
	get_viewport().use_xr = false
	_apply_quality_tier()
