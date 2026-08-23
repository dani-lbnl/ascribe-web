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


def convert_volume(arr: np.ndarray, dtype: str = "float16", max_dim: int | None = None) -> np.ndarray:
    if dtype not in ("float16", "uint8"):
        raise ValueError(f"dtype must be float16 or uint8, got {dtype}")
    if max_dim is not None and max(arr.shape) > max_dim:
        stride = math.ceil(max(arr.shape) / max_dim)
        arr = arr[::stride, ::stride, ::stride]
    if dtype == "uint8":
        a = arr.astype(np.float64)
        lo, hi = a.min(), a.max()
        scale = 255.0 / (hi - lo) if hi > lo else 0.0
        return ((a - lo) * scale).astype(np.uint8)
    return arr.astype(np.float16)
