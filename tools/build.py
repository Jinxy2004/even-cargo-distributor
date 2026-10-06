"""Build the release ZIP from the mod folder and check it is publishable.

Usage: python tools/build.py
Output: dist/cargo_distribution-<version>.zip and dist/package-report.json
"""
import hashlib
import json
from pathlib import Path
import re
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "cargo_distribution_1"
FORBIDDEN_SUFFIXES = {".exe", ".dll", ".sav", ".zip", ".log", ".tmp", ".py", ".ps1"}


def version() -> str:
    text = (SOURCE / "content/cargo_distribution/config.lua").read_text(encoding="utf-8")
    match = re.search(r'version\s*=\s*"([^"]+)"', text)
    assert match, "config.lua has no version"
    return match.group(1)


def checks(ver: str) -> None:
    manifest = json.loads((SOURCE / "mod.json").read_text(encoding="utf-8"))
    assert manifest["modId"] == SOURCE.name, "mod.json modId must match the folder name"
    info = json.loads((SOURCE / "_metadata/modinfo.json").read_text(encoding="utf-8"))
    blob = json.dumps(info).upper()
    for marker in ("TO BE SELECTED", "PLACEHOLDER", "PROTOTYPE", "PROBE"):
        assert marker not in blob, f"modinfo.json still contains {marker!r}"
    assert info.get("authors"), "modinfo.json needs an author"
    assert (SOURCE / "LICENSE").is_file(), "LICENSE missing from the mod folder"
    assert (SOURCE / "_metadata/0.png").is_file(), "cover image _metadata/0.png missing (copy media/logo.png)"
    config = (SOURCE / "content/cargo_distribution/config.lua").read_text(encoding="utf-8")
    assert re.search(r"verbose\s*=\s*false", config), "config.lua: verbose must be false for a release"
    changelog = (SOURCE / "CHANGELOG.md").read_text(encoding="utf-8")
    assert f"## {ver}" in changelog, f"CHANGELOG.md has no entry for {ver}"
    content = sorted(p.relative_to(SOURCE / "content").as_posix()
                     for p in (SOURCE / "content").rglob("*") if p.is_file())
    listed = json.loads((SOURCE / "_content.json").read_text(encoding="utf-8"))["files"]
    assert sorted(listed) == content, f"_content.json out of date: {listed} vs {content}"


def build() -> None:
    ver = version()
    checks(ver)
    out = ROOT / "dist"
    out.mkdir(exist_ok=True)
    archive = out / f"cargo_distribution-{ver}.zip"
    hashes = {}
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as package:
        for path in sorted(SOURCE.rglob("*")):
            if not path.is_file():
                continue
            assert not path.is_symlink(), f"Unexpected symlink: {path}"
            assert path.suffix.lower() not in FORBIDDEN_SUFFIXES, f"Not allowed in the package: {path}"
            name = path.relative_to(SOURCE).as_posix()
            data = path.read_bytes()
            hashes[name] = hashlib.sha256(data).hexdigest()
            # Fixed timestamp: identical sources give identical archives.
            info = zipfile.ZipInfo(f"{SOURCE.name}/{name}", date_time=(2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            package.writestr(info, data)
    with zipfile.ZipFile(archive) as package:
        assert package.testzip() is None
        for name, expected in hashes.items():
            assert hashlib.sha256(package.read(f"{SOURCE.name}/{name}")).hexdigest() == expected
    report = {"version": ver, "modId": SOURCE.name, "files": hashes,
              "archiveSha256": hashlib.sha256(archive.read_bytes()).hexdigest()}
    (out / "package-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"Built {archive.relative_to(ROOT)} ({len(hashes)} files).")


if __name__ == "__main__":
    build()
