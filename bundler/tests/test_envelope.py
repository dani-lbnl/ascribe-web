import json
import struct

import numpy as np
import pytest

from ascribe_bundle.envelope import read_envelope, volume_envelope, write_envelope


def test_roundtrip():
    pre = {"type": "volume", "shape": [2, 3, 4], "dtype": "uint8"}
    payload = bytes(range(24))
    data = write_envelope(pre, [payload])
    got_pre, got_payload = read_envelope(data)
    assert got_pre == pre
    assert got_payload == payload


def test_layout_is_u32le_prefixed_json():
    data = write_envelope({"a": 1}, [b"XY"])
    n = struct.unpack("<I", data[:4])[0]
    assert json.loads(data[4 : 4 + n]) == {"a": 1}
    assert data[4 + n :] == b"XY"


def test_volume_envelope_float16():
    arr = np.arange(24, dtype=np.float16).reshape(2, 3, 4)
    pre, payload = read_envelope(volume_envelope(arr, spacing=(2, 1, 1)))
    assert pre["type"] == "volume"
    assert pre["shape"] == [2, 3, 4]
    assert pre["dtype"] == "float16"
    assert pre["spacing"] == [2, 1, 1]
    assert np.frombuffer(payload, dtype="<f2").reshape(2, 3, 4).tolist() == arr.tolist()


def test_volume_envelope_rejects_float32():
    with pytest.raises(ValueError, match="float16 or uint8"):
        volume_envelope(np.zeros((2, 2, 2), dtype=np.float32))
