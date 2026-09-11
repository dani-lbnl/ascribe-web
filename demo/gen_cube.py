"""Generate a synthetic control volume: a solid cube rotated off every axis.

The point is that the object is perfectly uniform inside (interior standard deviation ~1e-6)
and its faces are flat planes at oblique angles to the voxel grid. Anything patterned that
shows up on those faces in the viewer therefore comes from the rendering pipeline, not from
specimen structure -- which makes this the control to reach for when diagnosing banding or
moire on a real dataset.

The edges are given a soft ramp a couple of voxels wide rather than being binary, so that
stair-stepping on a hard edge cannot be mistaken for the artifact under investigation.

    python demo/gen_cube.py out.npy [--size 256] [--edge-voxels 2]
"""
from __future__ import annotations

import argparse
import math

import numpy as np


def rotation_matrix(angle: float, axis: int) -> np.ndarray:
    c, s = math.cos(angle), math.sin(angle)
    if axis == 0:
        return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])
    if axis == 1:
        return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])


def rotated_cube(size: int = 256, edge_voxels: float = 2.0, half: float = 0.45,
                 angles_deg: tuple[float, float, float] = (27.0, 34.0, 19.0)) -> np.ndarray:
    """A cube of half-width `half` (in units where the volume spans -1..1), rotated by
    `angles_deg` about x, y and z so that no face is parallel to a bounding-box plane."""
    ax, ay, az = (math.radians(a) for a in angles_deg)
    rotation = rotation_matrix(az, 2) @ rotation_matrix(ay, 1) @ rotation_matrix(ax, 0)

    grid = (np.arange(size) - (size - 1) / 2.0) / (size / 2.0)
    zz, yy, xx = np.meshgrid(grid, grid, grid, indexing="ij")
    points = np.stack([xx, yy, zz], axis=-1) @ rotation

    # Chebyshev distance to the cube surface: negative inside, positive outside.
    distance = np.max(np.abs(points), axis=-1) - half
    edge = edge_voxels / (size / 2.0)
    return np.clip(0.5 - distance / edge, 0.0, 1.0).astype(np.float32)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", help="path to write the .npy volume to")
    parser.add_argument("--size", type=int, default=256)
    parser.add_argument("--edge-voxels", type=float, default=2.0)
    args = parser.parse_args(argv)

    volume = rotated_cube(args.size, args.edge_voxels)
    np.save(args.output, volume)
    interior = volume[volume > 0.999]
    print(f"wrote {args.output}: {volume.shape}, "
          f"filled {float((volume > 0.5).mean()):.1%}, "
          f"interior std {float(interior.std()):.2e}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
