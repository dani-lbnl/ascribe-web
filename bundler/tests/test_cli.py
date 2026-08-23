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
