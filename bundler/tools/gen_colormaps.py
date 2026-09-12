"""Regenerate the literal colormap tables in `ascribe_bundle/colormaps.py`.

Run only when adding or changing a colormap:

    pip install matplotlib seaborn
    python bundler/tools/gen_colormaps.py

The output is pasted into COLORMAPS. The tables are kept literal so the bundler itself depends
on nothing beyond numpy and tifffile -- matplotlib and seaborn are build-time tools here, not
runtime requirements.
"""
import matplotlib
import seaborn  # noqa: F401  (registers mako/rocket/flare/crest/icefire)
import numpy as np

NAMES = ["viridis", "magma", "inferno", "plasma", "cividis", "turbo", "jet",
         "mako", "rocket", "flare", "crest", "icefire", "gray"]
# Colormaps with sharp transitions need more stops to survive piecewise-linear interpolation.
STOPS = {"jet": 24, "turbo": 24, "icefire": 20}
DEFAULT_STOPS = 16

lines = []
for name in NAMES:
    n = STOPS.get(name, DEFAULT_STOPS)
    cmap = matplotlib.colormaps[name]
    xs = np.linspace(0.0, 1.0, n)
    entries = []
    for x in xs:
        r, g, b, _ = cmap(float(x))
        entries.append(f"({x:.4f}, {r:.4f}, {g:.4f}, {b:.4f})")
    body = ",\n        ".join(", ".join(entries[i:i+2]) for i in range(0, len(entries), 2))
    lines.append(f'    "{name}": [\n        {body},\n    ],')
print("\n".join(lines))
