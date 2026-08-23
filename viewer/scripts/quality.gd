## Picks a render-quality tier for the volume raymarch shader based on injected feature flags,
## so production callers pass real `OS.get_...` data while tests inject arrays directly.
class_name Quality
extends RefCounted

const DESKTOP := {"max_steps": 256, "step_size": 0.005}
const MOBILE := {"max_steps": 96, "step_size": 0.012}
const XR := {"max_steps": 128, "step_size": 0.008}


## `features` mirrors `OS.has_feature(...)` checks the caller has already done (e.g.
## `["web_android"]` when `OS.has_feature("web_android")` is true). XR wins over mobile.
static func pick_tier(features: PackedStringArray, xr_active: bool) -> Dictionary:
	if xr_active:
		return XR.duplicate()
	if features.has("web_android") or features.has("web_ios"):
		return MOBILE.duplicate()
	return DESKTOP.duplicate()
