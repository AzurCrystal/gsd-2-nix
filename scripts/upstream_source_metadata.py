from __future__ import annotations

import json
import os
import re
import subprocess
import urllib.request
from pathlib import Path


SEMVER_RE = re.compile(r"\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?")


def github_api_headers() -> dict[str, str]:
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "gsd-2-nix-release-bot",
    }
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    return headers


def fetch_latest_github_release(owner: str, repo: str) -> dict[str, str]:
    request = urllib.request.Request(
        f"https://api.github.com/repos/{owner}/{repo}/releases/latest",
        headers=github_api_headers(),
    )
    with urllib.request.urlopen(request) as response:
        payload = json.load(response)

    tag_name = payload.get("tag_name")
    if not tag_name:
        raise RuntimeError(
            f"{owner}/{repo} latest release payload did not include tag_name"
        )

    version = tag_name.lstrip("vV")
    return {
        "tag_name": tag_name,
        "version": version,
        "html_url": payload.get("html_url", ""),
    }


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
    return prefetch_npm_deps(source_root / "package-lock.json", fetcher_version=2)


def parse_semver(raw_value: str, field_name: str) -> str:
    match = SEMVER_RE.search(raw_value)
    if not match:
        raise RuntimeError(f"could not parse semver from {field_name}: {raw_value!r}")
    return match.group(0)


def collect_latest_rtk_source_metadata(
    release: dict[str, str] | None = None,
) -> dict[str, str]:
    release = release or fetch_latest_github_release("rtk-ai", "rtk")
    rtk_version = parse_semver(release["version"], "rtk latest release")
    rtk_source = prefetch_github_source("rtk-ai", "rtk", release["tag_name"])
    return {
        "rtkVersion": rtk_version,
        "rtkSrcHash": rtk_source["hash"],
    }


def collect_upstream_source_metadata(
    source_root: Path,
    rtk_release: dict[str, str] | None = None,
) -> dict[str, str]:
    package_json = json.loads(
        (source_root / "package.json").read_text(encoding="utf-8")
    )
    package_version = package_json.get("version")
    if not isinstance(package_version, str):
        raise RuntimeError("package.json did not include version")

    playwright_spec = package_json.get("dependencies", {}).get("playwright")
    if not isinstance(playwright_spec, str):
        raise RuntimeError("package.json did not include dependencies.playwright")

    metadata = {
        "upstreamVersion": parse_semver(package_version, "package.json version"),
        "playwrightVersion": parse_semver(playwright_spec, "dependencies.playwright"),
        "rootNpmDepsHash": prefetch_root_npm_deps(source_root),
        "webNpmDepsHash": prefetch_npm_deps(source_root / "web" / "package-lock.json"),
    }
    metadata.update(collect_latest_rtk_source_metadata(rtk_release))
    return metadata
