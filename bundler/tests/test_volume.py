from pathlib import Path

import numpy as np
import pytest

from ascribe_bundle.volume import convert_volume, load_volume


def test_load_npy(tmp_path: Path):
    arr = np.random.rand(4, 5, 6).astype(np.float32)
    p = tmp_path / "v.npy"
    np.save(p, arr)
    assert load_volume(p).shape == (4, 5, 6)


def test_load_tiff(tmp_path: Path):
    import tifffile
    arr = (np.random.rand(3, 4, 4) * 255).astype(np.uint8)
    p = tmp_path / "v.tif"
    tifffile.imwrite(p, arr)
    assert np.array_equal(load_volume(p), arr)


def test_convert_to_float16_preserves_values():
    arr = np.linspace(0, 1000, 27, dtype=np.float32).reshape(3, 3, 3)
    out = convert_volume(arr, "float16")
    assert out.dtype == np.float16
    assert np.allclose(out.astype(np.float32), arr, rtol=1e-3)


def test_convert_to_uint8_windows_minmax():
    arr = np.array([[[-5.0, 5.0]]], dtype=np.float32)
    out = convert_volume(arr, "uint8")
    assert out.dtype == np.uint8
    assert out.min() == 0 and out.max() == 255


def test_max_dim_downsamples():
    arr = np.zeros((100, 40, 100), dtype=np.float16)
    out = convert_volume(arr, "float16", max_dim=50)
    assert max(out.shape) <= 50


def test_rejects_bad_dtype():
    with pytest.raises(ValueError, match="float16 or uint8"):
        convert_volume(np.zeros((2, 2, 2)), "float32")
