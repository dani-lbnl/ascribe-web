"""Apply display settings (transfer function, gamma) to an already-baked bundle manifest.

`ascribe-bundle build` always writes the default gradient, so any tuned transfer function has
to be applied afterwards -- and re-applied after every rebake. Keeping that in a script rather
than hand-editing JSON means the settings survive a rebake and are reviewable in version
control.

    python demo/apply_display.py out/manifest.json --preset dense-structure
    python demo/apply_display.py out/manifest.json --gamma 1.0 --preset full-range
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

# Named transfer functions. A stop is [offset, "#rrggbbaa"].
PRESETS = {
    # Keeps the bulk material transparent so the dense structure carries the image. This is
    # what the ALS sample bundle uses; it is deliberately steep, which makes structure pop but
    # also amplifies fine density variation into visible banding.
    "dense-structure": [
        [0.0, "#00000000"], [0.30, "#00000000"], [0.50, "#4a3a2820"],
        [0.72, "#c99a5ca0"], [0.88, "#ffd9a0e0"], [1.0, "#fffaf0ff"],
    ],
    # Colour reaches nearly its final value while alpha is still low, so the first sample a ray
    # commits to is not also the sample that picks the hue. Under front-to-back compositing the
    # first sample with meaningful alpha is weighted by (1 - 0) and dominates the pixel, so
    # coupling colour to the steep part of the alpha ramp turns sub-voxel sampling variation
    # into visible colour banding. Measured on the ALS bundle this cuts the banding peak ~63%
    # (and on the synthetic cube it collapses the R/B ratio swing from 3.8% to 0.2%), at the
    # cost of a paler image with less tonal depth.
    "early-colour": [
        [0.0, "#c9a87800"], [0.30, "#d8b88800"], [0.50, "#e8c89820"],
        [0.72, "#f2dcb8a0"], [0.88, "#fdf2e0e0"], [1.0, "#fffaf0ff"],
    ],
    # A single colour with only alpha varying: removes the chromatic component entirely. Useful
    # as a diagnostic -- what is left is opacity variation, not colour.
    "flat-colour": [
        [0.0, "#e8c89800"], [0.30, "#e8c89800"], [0.50, "#e8c89820"],
        [0.72, "#e8c898a0"], [0.88, "#e8c898e0"], [1.0, "#e8c898ff"],
    ],
    # A gentler ramp across the whole range: less banding, but everything reads as semi-opaque
    # and a volume with a lot of low-density material can end up as fog.
    "full-range": [
        [0.0, "#00000000"], [0.25, "#3a2c1c10"], [0.55, "#9c7b4c50"],
        [0.80, "#d8b07ca0"], [1.0, "#fff6e8d0"],
    ],
}


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--preset", choices=sorted(PRESETS), default="dense-structure")
    parser.add_argument("--gamma", type=float, default=1.3)
    parser.add_argument("--lateral-jitter", type=float, default=None, metavar="STEPS",
                        help="dither each ray sideways by up to this many march steps; trades "
                             "coherent moire for per-pixel grain (try 2-4)")
    args = parser.parse_args(argv)

    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    for specimen in manifest.get("specimens", []):
        display = specimen.setdefault("display", {})
        display.update({"gradient": PRESETS[args.preset], "gamma": args.gamma})
        if args.lateral_jitter is not None:
            display["lateral_jitter"] = args.lateral_jitter
    args.manifest.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"applied preset '{args.preset}' (gamma {args.gamma}) to {args.manifest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
