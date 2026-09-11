"""Load volumes from disk and convert them to web-safe dtypes."""
from __future__ import annotations

import math
from pathlib import Path

import numpy as np


def load_volume(path: Path) -> np.ndarray:
    path = Path(path)
    if path.suffix == ".npy":
        arr = np.load(path)
    elif path.suffix in (".tif", ".tiff"):
        import tifffile

        arr = tifffile.imread(path)
    else:
        raise ValueError(f"unsupported volume file type: {path.suffix}")
    if arr.ndim != 3:
        raise ValueError(f"expected a 3D volume, got shape {arr.shape}")
    return arr


def convert_volume(
    arr: np.ndarray,
    dtype: str = "float16",
    max_dim: int | None = None,
    window: tuple[float, float] | None = None,
) -> np.ndarray:
    """Downsample, contrast-window and cast a volume to a web-safe dtype.

    `window` is a (low, high) pair of *percentiles*. Voxels at or below the low percentile
    clip to the bottom of the output range, voxels at or above the high percentile clip to
    the top, and everything between is stretched linearly across the full range. Real
    tomographic reconstructions often pack 90%+ of their voxels into a narrow band with a
    few far-out outliers; plain min/max scaling then leaves the interesting structure with
    almost no contrast, so windowing (e.g. `(0.5, 99.5)`) is usually what you want.

    Without `window`, uint8 output is min/max scaled and float16 output is passed through
    with its original values.
    """
    if dtype not in ("float16", "uint8"):
        raise ValueError(f"dtype must be float16 or uint8, got {dtype}")
    if max_dim is not None and max(arr.shape) > max_dim:
        stride = math.ceil(max(arr.shape) / max_dim)
        arr = arr[::stride, ::stride, ::stride]

    if window is not None:
        low, high = window
        if not 0.0 <= low < high <= 100.0:
            raise ValueError(
                f"window percentiles must satisfy 0 <= low < high <= 100, got {window}"
            )
        a = arr.astype(np.float64)
        lo, hi = np.percentile(a, [low, high])
        if hi <= lo:
            raise ValueError(
                f"window percentiles {window} map to a degenerate range "
                f"[{lo}, {hi}] -- the volume is (near-)constant"
            )
        a = np.clip((a - lo) / (hi - lo), 0.0, 1.0)
        if dtype == "uint8":
            return np.rint(a * 255.0).astype(np.uint8)
        return a.astype(np.float16)

    if dtype == "uint8":
        a = arr.astype(np.float64)
        lo, hi = a.min(), a.max()
        scale = 255.0 / (hi - lo) if hi > lo else 0.0
        return ((a - lo) * scale).astype(np.uint8)
    return arr.astype(np.float16)
