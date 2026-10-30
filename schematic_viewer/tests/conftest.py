import os
import sys
import zipfile

import pytest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)
ZIP = os.path.join(os.path.dirname(ROOT), "Drawing_DXF.zip")


@pytest.fixture(scope="session")
def dxf_dir(tmp_path_factory):
    """Extract the supplied drawing set once per test session."""
    env = os.environ.get("SCHEMATIC_DXF_DIR")
    if env and os.path.isdir(env):
        return env
    if not os.path.exists(ZIP):
        pytest.skip("Drawing_DXF.zip not available")
    target = tmp_path_factory.mktemp("dxf")
    with zipfile.ZipFile(ZIP) as zf:
        for m in zf.namelist():
            if m.lower().endswith(".dxf"):
                zf.extract(m, target)
    return os.path.join(target, "Drawing_DXF")


def dxf(dxf_dir, name):
    return os.path.join(dxf_dir, name)


def sheet_json(out_dir, sid):
    """Load a generated sheet data file (gzip JSON)."""
    import gzip
    import json
    with gzip.open(os.path.join(str(out_dir), "sheets", f"{sid}.json.gz"), "rt", encoding="utf-8") as fh:
        return json.load(fh)
