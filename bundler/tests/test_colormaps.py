import pytest

from ascribe_bundle.colormaps import COLORMAPS, gradient_stops, list_colormaps


def _rgba(stop):
    """['#rrggbbaa'] -> (r, g, b, a) as ints."""
    h = stop[1].lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4, 6))


def test_the_requested_colormaps_are_available():
    for name in ["viridis", "jet", "inferno", "plasma", "magma", "cividis", "mako", "rocket"]:
        assert name in COLORMAPS
    assert "viridis" in list_colormaps()


def test_stops_are_ordered_and_span_the_range():
    stops = gradient_stops("viridis")
    offsets = [s[0] for s in stops]
    assert offsets == sorted(offsets)
    assert offsets[0] == 0.0
    assert offsets[-1] == 1.0


def test_low_end_is_transparent_and_padded_with_the_lowest_colour():
    stops = gradient_stops("viridis", alpha_lo=0.2, alpha_hi=0.6)

    first_r, first_g, first_b, first_a = _rgba(stops[0])
    assert first_a == 0

    # The transparent padding must carry the colormap's own low colour, not black: the gradient
    # is interpolated in straight alpha, so a black stop drags the colour of everything that
    # blends toward it.
    assert (first_r, first_g, first_b) != (0, 0, 0)
    low = COLORMAPS["viridis"][0]
    assert abs(first_r / 255.0 - low[1]) < 0.02
    assert abs(first_g / 255.0 - low[2]) < 0.02
    assert abs(first_b / 255.0 - low[3]) < 0.02


def test_alpha_ramps_between_the_given_bounds():
    stops = gradient_stops("magma", alpha_lo=0.3, alpha_hi=0.7)
    for offset, hexcode in stops:
        alpha = int(hexcode.lstrip("#")[6:8], 16)
        if offset <= 0.3 + 1e-6:
            assert alpha == 0
        if offset >= 0.7 - 1e-6:
            assert alpha == 255
    # ...and something in between is partially transparent, i.e. it really is a ramp.
    mids = [int(h.lstrip("#")[6:8], 16) for o, h in stops if 0.3 < o < 0.7]
    assert mids and any(0 < a < 255 for a in mids)


def test_opaque_alpha_bounds_give_a_fully_opaque_gradient():
    stops = gradient_stops("viridis", alpha_lo=0.0, alpha_hi=0.0)
    assert all(int(h.lstrip("#")[6:8], 16) == 255 for _, h in stops)


def test_unknown_colormap_is_rejected_with_the_available_names():
    with pytest.raises(ValueError) as excinfo:
        gradient_stops("not-a-colormap")
    assert "viridis" in str(excinfo.value)


def test_rejects_inverted_alpha_bounds():
    with pytest.raises(ValueError):
        gradient_stops("viridis", alpha_lo=0.8, alpha_hi=0.2)


def test_stops_are_manifest_shaped():
    from ascribe_bundle.manifest import validate_manifest, make_manifest
    specimen = {"id": "specimen_0", "type": "volume", "data": "specimen_0.bin",
                "display": {"gamma": 1.0, "opacity": 1.0,
                            "gradient": gradient_stops("rocket")}}
    validate_manifest(make_manifest("t", [specimen], []))
