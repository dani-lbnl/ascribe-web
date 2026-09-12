---
name: bundling-volumes
description: Use when baking an ascribe-web bundle from a volume file (.npy/.tif), tuning how a volume looks in the viewer, or diagnosing a rendering artifact (banding, moire, fog, a black screen). Covers the ascribe-bundle CLI flags, transfer functions, and the measurement harness.
---

# Baking and tuning ascribe-web bundles

## Bake

```powershell
.venv\Scripts\ascribe-bundle build data.tif --story story.md --title "..." `
    --dtype u8 --max-dim 384 --smooth 1.5 --window 1,99.8 -o out/
.venv\Scripts\ascribe-bundle inspect out/     # validates and prints the manifest
```

Flag order of importance for real reconstructions:

- **`--window LOW,HIGH`** (percentiles). Almost always needed. Real tomography packs most voxels
  into a narrow band with far-out outliers — the ALS sample has 90% of its voxels inside 15 of
  256 levels — so plain min/max scaling renders as flat fog. `1,99.8` is a good start.
- **`--smooth SIGMA`** (voxels). The main control over how "striped" a surface looks. Fine
  layered structure in the data reads as hard banding once a steep transfer function amplifies
  it. On the ALS sample, 1.5 cuts banding ~75% while keeping ridges legible; 0.6 keeps more
  texture but bands visibly. Applied after downsampling.
- **`--max-dim N`** caps the longest axis. Decimation block-averages (an anti-alias prefilter);
  striding instead would fold fine structure into moire.
- **`--dtype u8`** halves the payload. Tested against float16 on the ALS sample: no visible
  difference, including on banding. Prefer u8 unless a specific artifact points at quantization.

## Transfer function

Three ways to set it, in order of preference:

- `ascribe-bundle build --colormap viridis --colormap-alpha 0.15,0.5` at bake time. Available:
  viridis, magma, inferno, plasma, cividis, turbo, jet, mako, rocket, flare, crest, icefire, gray.
- **Edit mode** (below) — pose the specimen and move the sliders, then save.
- `python demo/apply_display.py <manifest.json> --colormap ... | --preset ...` to re-apply after
  a rebake, which otherwise overwrites `display` with the default gradient.

Whatever you do, **the transparent low end must carry a real colour, not black.** The viewer
interpolates the gradient in straight alpha, so a `#00000000` stop drags the colour of every
sample blending toward it — dark fringing wherever material fades in. `colormaps.py` pads with
the colormap's own lowest colour for exactly this reason.

**Do not couple colour to the steep part of the alpha ramp.** Front-to-back compositing weights
the first sample with meaningful alpha by `(1 - 0)`, so that one sample effectively picks the
pixel's hue — and exactly where it lands varies with sub-voxel geometry. Ramping colour and alpha
together therefore converts sampling variation into visible *colour* banding. Measured: the ALS
bundle's banding peak drops ~63% with the `early-colour` preset, and on the synthetic cube the
R/B ratio swing collapses from 3.8% to 0.2% with a single flat colour. The cost is a paler image,
so it is a genuine trade-off rather than a free win. `demo/apply_display.py` ships
`dense-structure`, `early-colour`, `flat-colour` and `full-range` for comparing.

It is the single biggest lever on how a volume reads, and easy to overdo:

- A steep alpha ramp over a narrow density band makes structure pop but amplifies every small
  density oscillation into hard banding.
- Flattening the ramp too far makes the whole volume semi-opaque — the image degenerates into
  uniform fog. **Always look at the render, not just a metric**: a "successful" 80% drop in
  banding energy was once just the image turning into a brown rectangle.
- `display.max_steps`/`step_size` in the manifest are overridden at startup by the automatic
  quality tier (`viewer/scripts/quality.gd`), so setting them there has no effect.

## Edit mode (authoring a bundle's presentation)

```powershell
ascribe-bundle serve build\web --edit
```

**Re-export the viewer first** (`godot --headless --path viewer --export-release Web
../build/web/index.html`). `build/web` is a build artifact that CI never writes back, so a local
preview silently runs whatever was last exported by hand -- a missing button here usually means a
stale `.pck`, not a broken feature.

Open `...?bundle=<dir>&edit=1`, frame the specimen, set the sliders, press **Save view +
settings**. The viewer POSTs the manifest back to the server, which validates and rewrites it;
the gradient, story and specimen ids pass through untouched. A saved `view` becomes the bundle's
default framing (an explicit `?view=` still wins). Both halves are opt-in, so a deployed bundle
never offers a button that cannot work.

## Preview

```powershell
.venv\Scripts\ascribe-bundle serve build\web        # sends no-store; use this, not http.server
```

Then `http://localhost:8060/index.html?bundle=<dir>`. A plain `python -m http.server` sends no
cache headers, and a browser will happily keep running a stale `index.pck` after a re-export —
which presents as fixed bugs coming back from the dead.

Note what local preview cannot catch: it does not compress, so encoding bugs (Godot double-
inflating a gzipped response) only appear on a real static host.

## Publishing

Commit the bundle under `demo/` and stage it in `.github/workflows/pages.yml`; pushing to `main`
deploys to GitHub Pages. Pages serves HTTPS, which WebXR requires — a headset will not enter VR
from a plain `http://` LAN server.

## Diagnosing a rendering artifact

**Start with the synthetic control.** Load `?bundle=cube` (generated by `demo/gen_cube.py`): a
uniform solid cube rotated off every axis. Its interior std is ~1e-6, so any pattern on its faces
is the renderer's, not the specimen's. This settles "is it my data or my renderer?" in one render,
which is otherwise very hard to answer on real data where structure dominates every metric.

Do not tune by eye. `viewer/tools/shader_probe.gd` renders a fixed view so variants are
comparable:

```powershell
& "<godot>" --path viewer --quit-after 6000 --fixed-fps 30 --write-movie out\p.png `
    -s res://tools/shader_probe.gd -- --bundle=http://localhost:8060/<dir> `
    --view=2.9267,0.4002,0.5811 --param=max_steps:512
```

Get `--view=` from a real session: press **V** in the viewer and copy the URL it prints to the
browser console. `--param=name:value` overrides a shader uniform (ints, floats, and
`true`/`false`).

Then measure with a 2D FFT of a crop inside the artifact and compare peak/period/angle across
variants. What each result tells you:

| Observation | Meaning |
|---|---|
| Changes with `max_steps`/`step_size` | Ray-step sampling noise — raise the quality tier |
| Invariant to step size, pitch fixed | Not sampling. Look at the data or the transfer function |
| Sharpens as voxels get finer | Real structure being resolved, not an artifact |
| Pattern stays put on screen as you orbit | Screen-space render bug |
| Pattern rotates with the object | It is in the data |
| Identical in u8 and float16 | Not quantization |

Measured on the synthetic cube (renderer-side, no data structure involved). Face variation
started at 7.25/255 std under the `dense-structure` preset. Findings so far:

| Change | Face std | Note |
|---|---|---|
| baseline (512 steps) | 7.25 | |
| 1024 / 4096 steps | 7.46 / 8.16 | no better; and the *mean* drifts darker |
| float16 instead of u8 | 7.27 | not value quantization |
| `smooth_sampling` (quintic) | 10.12 | worse — trilinear is already exact on a linear ramp |
| `manual_filter` (float32 trilinear) | 7.25 | **not** hardware filter precision |
| flat-colour LUT | 5.72 | colour-from-first-hit is real (-21%) |
| premultiplied blending fix | 5.28 | double-multiply bug (-27%) |

**Removing the error beats dithering it.** Ron's lateral (screen-plane) dither does break up the
coherent moire -- it decorrelates the sampling phase between neighbouring pixels, which the
along-ray jitter cannot -- but it converts structure into grain rather than removing it
(coherent -24%, grain +27%). Raising the transfer-function sub-step budget instead removes the
error at source: at maximum gamma/opacity the residual goes from 2.148 to 0.930 and the fine
grain from 1.840 to 0.463, with no dither at all. `lateral_jitter` remains available per-bundle
for content where the sub-stepping cannot keep up.

**Quality and dithering interact, which is confusing if you meet them separately.** With
`lateral_jitter` off the quality slider does almost nothing -- sub-step integration makes the
render step-invariant, which was the point (512 vs 2048 steps differ by 0.2 of 255 on the ALS
bundle). With dithering on, quality matters a lot, because more steps means less per-ray error to
scatter: grain 10.7 / 7.0 / 4.3 at 128 / 512 / 2048 steps. So dithering is what creates the need
for a high quality setting, and that cost lands on XR framerate.

Diagnostic uniforms: `manual_filter` replaces the hardware sampler with a
float32 trilinear blend (8 texelFetches), and `jitter_amount` scales the per-ray start jitter
(0 turns sampling-phase error from noise into coherent banding, which makes it identifiable).

Then ruled out by later work: **compositing is not the cause of the residual banding on real
data.** `projection_mode:1` (maximum intensity projection) reduces each ray to one number and
applies the transfer function once -- no compositing at all -- and the ALS banding is *stronger*
there (peak 132k vs 23k) and completely invariant to step count (512 vs 4096 identical) and to
`manual_filter`. Whatever remains is in the scalar field.

Tracing the pipeline stage by stage on the ALS volume, the periodic component is present in the
**raw file** (period 86.8 voxels along the short axis, which is exactly the 29.0 seen after
stride-3 decimation). The pipeline does not create it -- but `--smooth` raises its *relative*
prominence sharply (peak/median 3.91 -> 9.11 at sigma 1.5), because smoothing removes broadband
detail while leaving a low-frequency periodic component untouched. So heavier smoothing trades
texture for a cleaner-looking but relatively *more* periodic image.

The older lead, **transfer-function under-resolution**: brightness still drifts with step
count even with a flat colour (197.6 -> 189.9 from 512 to 4096 steps), which means the LUT is
being point-sampled between consecutive density samples rather than integrated across them. The
textbook fix is a pre-integrated transfer function (Engel et al. 2001). A cheap form of it is
implemented as `lut_substeps` (integrate the LUT across the density interval between consecutive
samples). It ships off: it reduces the drift (2.4% -> 1.7%) but does not fix the banding and
marginally worsens face variation.

Hypotheses already tested and rejected for the ALS bundle's banding: ray-step aliasing,
trilinear interpolation (quintic-smoothed texel coordinates made no difference — the flag is
`smooth_sampling`, off by default), ring artifacts, 8-bit quantization, and transparent-black
LUT stops. Smoothing the data is what helped. Don't re-run those without new evidence.
