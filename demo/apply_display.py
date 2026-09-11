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
    args = parser.parse_args(argv)

    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    for specimen in manifest.get("specimens", []):
        specimen.setdefault("display", {}).update({
            "gradient": PRESETS[args.preset],
            "gamma": args.gamma,
        })
    args.manifest.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"applied preset '{args.preset}' (gamma {args.gamma}) to {args.manifest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
