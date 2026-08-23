## Picks a render-quality tier for the volume raymarch shader based on injected feature flags,
## so production callers pass real `OS.get_...` data while tests inject arrays directly.
class_name Quality
extends RefCounted

const DESKTOP_STEPS := 256
const MOBILE_STEPS := 96
const XR_STEPS := 128

## Anchor points (max_steps, step_size) that `step_size_for` interpolates between. This is the
## single source of truth for the steps -> step_size mapping: both `pick_tier` (desktop/mobile/XR
## tiers) and the manual quality slider in `display_settings_panel.gd` go through it, so they can
## never disagree. The three tier anchors (256/0.005, 96/0.012, 128/0.008) are exact by
## construction; values off an anchor are linearly interpolated between their neighbors.
const _STEP_SIZE_POINTS := [
	[32.0, 0.02],
	[MOBILE_STEPS, 0.012],
	[XR_STEPS, 0.008],
	[DESKTOP_STEPS, 0.005],
	[512.0, 0.0025],
]


## Returns the step size for a given step count, per `_STEP_SIZE_POINTS`. Reproduces the tier
## anchors exactly and linearly interpolates (or, past the ends, extrapolates flat) elsewhere.
static func step_size_for(steps: int) -> float:
	var s := float(steps)
	var pts := _STEP_SIZE_POINTS
	if s <= pts[0][0]:
		return pts[0][1]
	for i in range(pts.size() - 1):
		var a: Array = pts[i]
		var b: Array = pts[i + 1]
		if s <= b[0]:
			var t: float = (s - float(a[0])) / (float(b[0]) - float(a[0]))
			return lerpf(a[1], b[1], t)
	return pts[pts.size() - 1][1]


## `features` mirrors `OS.has_feature(...)` checks the caller has already done (e.g.
## `["web_android"]` when `OS.has_feature("web_android")` is true). XR wins over mobile.
static func pick_tier(features: PackedStringArray, xr_active: bool) -> Dictionary:
	var steps := DESKTOP_STEPS
	if xr_active:
		steps = XR_STEPS
	elif features.has("web_android") or features.has("web_ios"):
		steps = MOBILE_STEPS
	return {"max_steps": steps, "step_size": step_size_for(steps)}
