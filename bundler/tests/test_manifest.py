import pytest

from ascribe_bundle.manifest import make_manifest, validate_manifest


def _specimen():
    return {"id": "vol0", "type": "volume", "data": "specimen_0.bin",
            "display": {"gamma": 1.0, "opacity": 1.0,
                        "gradient": [[0.0, "#00000000"], [1.0, "#ffe6b3ff"]]}}


def test_make_and_validate_roundtrip():
    m = make_manifest("My Data", [_specimen()], [{"text": "hello", "specimen": "vol0"}])
    validate_manifest(m)  # should not raise
    assert m["version"] == 1


def test_validate_rejects_wrong_version():
    m = make_manifest("t", [_specimen()], [])
    m["version"] = 2
    with pytest.raises(ValueError, match="version"):
        validate_manifest(m)


def test_validate_rejects_story_referencing_unknown_specimen():
    m = make_manifest("t", [_specimen()], [{"text": "x", "specimen": "nope"}])
    with pytest.raises(ValueError, match="unknown specimen"):
        validate_manifest(m)
