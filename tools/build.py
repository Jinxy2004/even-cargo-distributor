"""Build a development archive using only the mod-owned source directory."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "cargo_distribution_1"
VERSION = "0.1.2-prototype"


def build():
    parser = argparse.ArgumentParser()
    parser.add_argument("--release", action="store_true")
    args = parser.parse_args()
    if args.release:
        parser.error("Public release is blocked: native feasibility and acceptance checks have not passed.")
    manifest = json.loads((SOURCE / "mod.json").read_text(encoding="utf-8"))
    assert manifest["modId"] == SOURCE.name
    content = sorted(p.relative_to(SOURCE / "content").as_posix()
                     for p in (SOURCE / "content").rglob("*") if p.is_file())
    (SOURCE / "_content.json").write_text(json.dumps({"archives": None, "files": content}, indent=2) + "\n",
                                          encoding="utf-8")
    out = ROOT / "dist"
    out.mkdir(exist_ok=True)
    archive = out / f"cargo_distribution-{VERSION}.zip"
    hashes = {}
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as package:
        for path in sorted(SOURCE.rglob("*")):
            if not path.is_file():
                continue
            assert not path.is_symlink(), f"Unexpected symlink: {path}"
            assert path.suffix.lower() not in {".exe", ".dll", ".sav", ".zip"}
            name = path.relative_to(SOURCE).as_posix()
            blob = path.read_bytes()
            hashes[name] = hashlib.sha256(blob).hexdigest()
            # Fixed timestamp makes identical sources yield identical packages.
            info = zipfile.ZipInfo(f"{SOURCE.name}/{name}", date_time=(2026, 10, 5, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            package.writestr(info, blob)
    with zipfile.ZipFile(archive) as package:
        assert package.testzip() is None
        for name, expected in hashes.items():
            assert hashlib.sha256(package.read(f"{SOURCE.name}/{name}")).hexdigest() == expected
    report = {"version": VERSION, "modId": manifest["modId"], "files": hashes,
              "archiveSha256": hashlib.sha256(archive.read_bytes()).hexdigest(),
              "nativeValidation": "NOT RUN", "gameplayGate": "PENDING", "publishable": False}
    (out / "package-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"Built {archive} ({len(hashes)} mod-owned files). Native validation still required.")


if __name__ == "__main__":
    build()
