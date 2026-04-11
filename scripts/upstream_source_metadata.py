from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path


SEMVER_RE = re.compile(r"\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?")
RTK_VERSION_RE = re.compile(r'export const RTK_VERSION = "([^"]+)"')


def prefetch_github_source(owner: str, repo: str, ref: str) -> dict[str, str]:
    result = subprocess.run(
        ["nix", "flake", "prefetch", "--json", f"github:{owner}/{repo}/{ref}"],
        check=True,
        capture_output=True,
        text=True,
    )
    payload = json.loads(result.stdout)
    hash_value = payload.get("hash")
    store_path = payload.get("storePath")
    if not hash_value or not store_path:
        raise RuntimeError("nix flake prefetch did not return hash and storePath")
    return {
        "hash": hash_value,
        "storePath": store_path,
    }


def prefetch_npm_deps(lockfile_path: Path) -> str:
    result = subprocess.run(
        ["nix", "run", "nixpkgs#prefetch-npm-deps", "--", str(lockfile_path)],
        check=True,
        capture_output=True,
        text=True,
    )

    for stream in (result.stdout, result.stderr):
        for line in reversed(stream.splitlines()):
            candidate = line.strip()
            if candidate.startswith("sha256-"):
                return candidate

    raise RuntimeError(f"prefetch-npm-deps did not return a hash for {lockfile_path}")


def parse_semver(raw_value: str, field_name: str) -> str:
    match = SEMVER_RE.search(raw_value)
    if not match:
        raise RuntimeError(f"could not parse semver from {field_name}: {raw_value!r}")
    return match.group(0)


def parse_rtk_version(source_root: Path) -> str:
    rtk_source = (source_root / "src" / "rtk.ts").read_text(encoding="utf-8")
    match = RTK_VERSION_RE.search(rtk_source)
    if not match:
        raise RuntimeError("could not find RTK_VERSION in src/rtk.ts")
    return match.group(1)


def collect_upstream_source_metadata(source_root: Path) -> dict[str, str]:
    package_json = json.loads((source_root / "package.json").read_text(encoding="utf-8"))

    playwright_spec = package_json.get("dependencies", {}).get("playwright")
    if not isinstance(playwright_spec, str):
        raise RuntimeError("package.json did not include dependencies.playwright")

    rtk_version = parse_rtk_version(source_root)
    rtk_source = prefetch_github_source("rtk-ai", "rtk", f"v{rtk_version}")

    return {
        "playwrightVersion": parse_semver(playwright_spec, "dependencies.playwright"),
        "rtkVersion": rtk_version,
        "rtkSrcHash": rtk_source["hash"],
        "rootNpmDepsHash": prefetch_npm_deps(source_root / "package-lock.json"),
        "webNpmDepsHash": prefetch_npm_deps(source_root / "web" / "package-lock.json"),
    }
