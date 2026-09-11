import json
from pathlib import Path

import numpy as np

from ascribe_bundle.cli import main


def test_build_creates_bundle(tmp_path: Path):
    vol = tmp_path / "v.npy"
    np.save(vol, np.random.rand(8, 8, 8).astype(np.float32))
    story = tmp_path / "story.md"
    story.write_text("Hello volume.")
    out = tmp_path / "out"
    rc = main(["build", str(vol), "--story", str(story), "--title", "T", "-o", str(out)])
    assert rc == 0
    manifest = json.loads((out / "manifest.json").read_text())
    assert manifest["version"] == 1
    assert (out / manifest["specimens"][0]["data"]).exists()


def test_build_warns_on_size(tmp_path: Path, capsys):
    vol = tmp_path / "v.npy"
    np.save(vol, np.zeros((64, 64, 64), dtype=np.float32))
    out = tmp_path / "out"
    main(["build", str(vol), "-o", str(out), "--size-warn-mb", "0"])
    assert "exceeds" in capsys.readouterr().err


def test_build_preserves_story_image_subdirs(tmp_path: Path):
    vol = tmp_path / "v.npy"
    np.save(vol, np.random.rand(8, 8, 8).astype(np.float32))

    figs_dir = tmp_path / "figs"
    figs_dir.mkdir()
    (figs_dir / "fig1.png").write_bytes(b"\x89PNG\r\n\x1a\n")

    story = tmp_path / "story.md"
    story.write_text("![a figure](figs/fig1.png)\n")

    out = tmp_path / "out"
    rc = main(["build", str(vol), "--story", str(story), "-o", str(out)])
    assert rc == 0

    # Text keeps the subdir path, so the copied image must live at the same relative path.
    assert (out / "figs" / "fig1.png").exists()
    manifest = json.loads((out / "manifest.json").read_text())
    assert "figs/fig1.png" in manifest["story"][0]["text"]


def test_build_rejects_story_image_path_escape(tmp_path: Path, capsys):
    vol = tmp_path / "v.npy"
    np.save(vol, np.random.rand(8, 8, 8).astype(np.float32))

    outside_dir = tmp_path.parent / "outside_secret"
    outside_dir.mkdir(exist_ok=True)
    (outside_dir / "leak.png").write_bytes(b"\x89PNG\r\n\x1a\n")

    story = tmp_path / "story.md"
    story.write_text("![leak](../outside_secret/leak.png)\n")

    out = tmp_path / "out"
    rc = main(["build", str(vol), "--story", str(story), "-o", str(out)])
    assert rc == 1
    assert "escapes bundle" in capsys.readouterr().err
    assert not (out / "leak.png").exists()


def test_window_flag_is_applied(tmp_path):
    import numpy as np
    from ascribe_bundle.cli import main
    from ascribe_bundle.envelope import read_envelope

    arr = np.full((8, 8, 8), 100.0, dtype=np.float32)
    arr.reshape(-1)[0] = 0.0
    arr.reshape(-1)[1] = 1000.0
    arr.reshape(-1)[2:250] = 96.0
    src = tmp_path / "v.npy"
    np.save(src, arr)

    out = tmp_path / "out"
    assert main(["build", str(src), "--dtype", "u8", "--window", "1,99",
                 "-o", str(out)]) == 0
    _, payload = read_envelope((out / "specimen_0.bin").read_bytes())
    voxels = np.frombuffer(payload, dtype=np.uint8)
    assert voxels.max() == 255 and voxels.min() == 0


def test_window_flag_rejects_bad_range(tmp_path, capsys):
    import numpy as np
    import pytest
    from ascribe_bundle.cli import main

    src = tmp_path / "v.npy"
    np.save(src, np.zeros((4, 4, 4), dtype=np.float32))
    with pytest.raises(SystemExit):
        main(["build", str(src), "--window", "99,1", "-o", str(tmp_path / "o")])


def test_smooth_flag_is_applied(tmp_path):
    import numpy as np
    from ascribe_bundle.cli import main
    from ascribe_bundle.envelope import read_envelope

    rng = np.random.default_rng(1)
    arr = rng.normal(0.5, 0.2, (12, 12, 12)).astype(np.float32)
    src = tmp_path / "v.npy"
    np.save(src, arr)

    plain_out = tmp_path / "plain"
    smooth_out = tmp_path / "smooth"
    assert main(["build", str(src), "-o", str(plain_out)]) == 0
    assert main(["build", str(src), "--smooth", "1.0", "-o", str(smooth_out)]) == 0

    def voxels(d):
        _, payload = read_envelope((d / "specimen_0.bin").read_bytes())
        return np.frombuffer(payload, dtype=np.float16).astype(np.float32).reshape(12, 12, 12)

    assert np.abs(np.diff(voxels(smooth_out), axis=0)).mean() < \
        np.abs(np.diff(voxels(plain_out), axis=0)).mean() / 2
