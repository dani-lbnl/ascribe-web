## Picks a render-quality tier for the volume raymarch shader based on injected feature flags,
## so production callers pass real `OS.get_...` data while tests inject arrays directly.
class_name Quality
extends RefCounted

# Sampling noise scales directly with step size: the shader jitters each ray's start, which
# trades coherent banding for a fine dither whose amplitude is set by how far apart the samples
# are. Measured on the ALS bundle, halving the step roughly halves the visible striping
# (laplacian 34.5 -> 12.6 -> 3.9 at 256/512/1024 steps), so the desktop tier buys the clean
# image and the constrained tiers accept some noise to hold framerate.
const DESKTOP_STEPS := 512
const MOBILE_STEPS := 128
const XR_STEPS := 256

## Anchor points (max_steps, step_size) that `step_size_for` interpolates between. This is the
## single source of truth for the steps -> step_size mapping: both `pick_tier` (desktop/mobile/XR
## tiers) and the manual quality slider in `display_settings_panel.gd` go through it, so they can
## never disagree. Each tier constant above lands exactly on one of these anchors; values off an
## anchor are linearly interpolated between their neighbours.
##
## Step counts are paired with a step size such that `steps * step_size` stays around 1.3 -- far
## enough to cross the staged box, which is at most 1m on its longest axis. (The shader widens
## the step further if a particular ray is still longer than the budget covers.)
const _STEP_SIZE_POINTS := [
	[32.0, 0.02],
	[64.0, 0.016],
	[MOBILE_STEPS, 0.008],
	[XR_STEPS, 0.005],
	[DESKTOP_STEPS, 0.0025],
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
