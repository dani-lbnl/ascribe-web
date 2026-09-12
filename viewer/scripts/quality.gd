## Picks a render-quality tier for the volume raymarch shader based on injected feature flags,
## so production callers pass real `OS.get_...` data while tests inject arrays directly.
class_name Quality
extends RefCounted

# Sampling density is the dominant quality control: too few steps and a ray skips through
# structure it should have integrated. Judged in the viewer, anything under ~512 steps is not
# worth offering -- so that is the floor rather than a setting a user can wander into, and the
# range extends upward instead.
const MIN_USABLE_STEPS := 512
const MAX_STEPS := 2048

const DESKTOP_STEPS := 1024
const MOBILE_STEPS := 512
const XR_STEPS := 768

## Anchor points (max_steps, step_size) that `step_size_for` interpolates between. This is the
## single source of truth for the steps -> step_size mapping: both `pick_tier` (desktop/mobile/XR
## tiers) and the manual quality slider in `display_settings_panel.gd` go through it, so they can
## never disagree. Each tier constant above lands exactly on one of these anchors; values off an
## anchor are linearly interpolated between their neighbours.
##
## Step counts are paired with a step size such that `steps * step_size` stays around 1.3 -- far
## enough to cross the staged box, which is at most 1m on its longest axis. (The shader widens
## the step further if a particular ray is still longer than the budget covers.)
## Anchors are written out literally rather than in terms of the tier constants: when they were
## expressed as `[DESKTOP_STEPS, ...]`, raising a tier onto an existing anchor's step count
## silently produced a duplicate and returned the wrong step size.
const _STEP_SIZE_POINTS := [
	[512.0, 0.0025],
	[768.0, 0.00170],
	[1024.0, 0.00125],
	[2048.0, 0.000625],
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
