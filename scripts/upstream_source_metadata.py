from __future__ import annotations

import json
import os
import re
import subprocess
import tempfile
from pathlib import Path


SEMVER_RE = re.compile(r"\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?")
RTK_VERSION_RE = re.compile(r'export const RTK_VERSION = "([^"]+)"')
EMNAPI_RUNTIME_LOCK_KEY = '    "node_modules/@emnapi/runtime": {'
EMNAPI_WASI_THREADS_LOCK_KEY = '    "node_modules/@emnapi/wasi-threads": {'
EMNAPI_RUNTIME_LOCK_ENTRY = """    "node_modules/@emnapi/runtime": {
      "version": "1.10.0",
      "resolved": "https://registry.npmjs.org/@emnapi/runtime/-/runtime-1.10.0.tgz",
      "integrity": "sha512-ewvYlk86xUoGI0zQRNq/mC+16R1QeDlKQy21Ki3oSYXNgLb45GV1P6A0M+/s6nyCuNDqe5VpaY84BzXGwVbwFA==",
      "license": "MIT",
      "optional": true,
      "dependencies": {
        "tslib": "^2.4.0"
      }
    },
"""


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


def prefetch_npm_deps(lockfile_path: Path, fetcher_version: int = 1) -> str:
    env = None
    if fetcher_version != 1:
        env = os.environ.copy()
        env["NPM_FETCHER_VERSION"] = str(fetcher_version)
    result = subprocess.run(
        ["nix", "run", "nixpkgs#prefetch-npm-deps", "--", str(lockfile_path)],
        check=True,
        capture_output=True,
        text=True,
        env=env,
    )

    for stream in (result.stdout, result.stderr):
        for line in reversed(stream.splitlines()):
            candidate = line.strip()
            if candidate.startswith("sha256-"):
                return candidate

    raise RuntimeError(f"prefetch-npm-deps did not return a hash for {lockfile_path}")


def prefetch_root_npm_deps(source_root: Path) -> str:
    lockfile_path = source_root / "package-lock.json"
    lock_text = lockfile_path.read_text(encoding="utf-8")
    patched_lock_text = patch_root_package_lock(lock_text)

    if patched_lock_text == lock_text:
        return prefetch_npm_deps(lockfile_path, fetcher_version=2)

    with tempfile.TemporaryDirectory() as tmp_dir:
        patched_lockfile = Path(tmp_dir) / "package-lock.json"
        patched_lockfile.write_text(patched_lock_text, encoding="utf-8")
        return prefetch_npm_deps(patched_lockfile, fetcher_version=2)


def patch_root_package_lock(lock_text: str) -> str:
    if EMNAPI_RUNTIME_LOCK_KEY in lock_text:
        return lock_text

    lock_info = json.loads(lock_text)
    packages = lock_info.get("packages")
    if not isinstance(packages, dict):
        raise RuntimeError("root package-lock.json did not include packages")

    required_versions = {
        dependencies.get("@emnapi/runtime")
        for package in packages.values()
        if isinstance(package, dict)
        for dependencies in [package.get("dependencies")]
        if isinstance(dependencies, dict)
        and isinstance(dependencies.get("@emnapi/runtime"), str)
    }
    if "1.10.0" not in required_versions:
        raise RuntimeError(
            "root package-lock.json references @emnapi/runtime but the "
            f"known lockfile patch does not cover {sorted(required_versions)!r}"
        )
    if EMNAPI_WASI_THREADS_LOCK_KEY not in lock_text:
        raise RuntimeError("could not find insertion point for @emnapi/runtime")

    return lock_text.replace(
        EMNAPI_WASI_THREADS_LOCK_KEY,
        EMNAPI_RUNTIME_LOCK_ENTRY + EMNAPI_WASI_THREADS_LOCK_KEY,
        1,
    )


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
    package_json = json.loads(
        (source_root / "package.json").read_text(encoding="utf-8")
    )
    package_version = package_json.get("version")
    if not isinstance(package_version, str):
        raise RuntimeError("package.json did not include version")

    playwright_spec = package_json.get("dependencies", {}).get("playwright")
    if not isinstance(playwright_spec, str):
        raise RuntimeError("package.json did not include dependencies.playwright")

    rtk_version = parse_rtk_version(source_root)
    rtk_source = prefetch_github_source("rtk-ai", "rtk", f"v{rtk_version}")

    return {
        "upstreamVersion": parse_semver(package_version, "package.json version"),
        "playwrightVersion": parse_semver(playwright_spec, "dependencies.playwright"),
        "rtkVersion": rtk_version,
        "rtkSrcHash": rtk_source["hash"],
        "rootNpmDepsHash": prefetch_root_npm_deps(source_root),
        "webNpmDepsHash": prefetch_npm_deps(source_root / "web" / "package-lock.json"),
    }
