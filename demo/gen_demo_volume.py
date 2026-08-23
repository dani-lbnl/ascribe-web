"""Generates the 64^3 demo volume for the ascribe-web demo bundle.

Reproduces the gyroid-sphere formula from viewer/scripts/procedural_volume.gd (the walking
skeleton's test volume) at a larger, more visually interesting resolution. Output is float32 -- a
size the CLI's default float16 conversion will happily accept (float32 is only rejected as a
*bundle envelope* dtype, never as CLI input).
"""
from __future__ import annotations

from pathlib import Path

import numpy as np

SIZE = 64


def make_volume(size: int) -> np.ndarray:
    coords = np.linspace(-1.0, 1.0, size, dtype=np.float32)
    z, y, x = np.meshgrid(coords, coords, coords, indexing="ij")

    sphere = np.clip(1.0 - np.sqrt(x * x + y * y + z * z), 0.0, 1.0)
    gyroid = np.abs(
        np.sin(x * 6.0) * np.cos(y * 6.0) + np.sin(y * 6.0) * np.cos(z * 6.0)
    )
    gyroid = np.clip(gyroid, 0.0, 1.0)

    return (sphere * gyroid).astype(np.float32)


def main() -> None:
    out_dir = Path(__file__).parent
    out_dir.mkdir(exist_ok=True)
    vol = make_volume(SIZE)
    np.save(out_dir / "gyroid_sphere_64.npy", vol)
    print(f"wrote {out_dir / 'gyroid_sphere_64.npy'} shape={vol.shape} dtype={vol.dtype}")


if __name__ == "__main__":
    main()
