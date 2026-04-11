#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import urllib.request
from pathlib import Path

from upstream_source_metadata import collect_upstream_source_metadata, prefetch_github_source


ROOT = Path(__file__).resolve().parents[1]
SOURCE_FILE = ROOT / "pkgs" / "gsd-2" / "source.json"
UPSTREAM_RELEASE_URL = "https://api.github.com/repos/gsd-build/gsd-2/releases/latest"


def fetch_latest_release() -> dict[str, str]:
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "gsd-2-nix-release-bot",
    }
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"

    request = urllib.request.Request(UPSTREAM_RELEASE_URL, headers=headers)
    with urllib.request.urlopen(request) as response:
        payload = json.load(response)

    tag_name = payload.get("tag_name")
    if not tag_name:
        raise RuntimeError("upstream latest release payload did not include tag_name")

    html_url = payload.get("html_url", "")
    return {
        "tag_name": tag_name,
        "version": tag_name.lstrip("vV"),
        "html_url": html_url,
    }


def emit_outputs(path: Path | None, values: dict[str, str]) -> None:
    if path is None:
        return

    lines = [f"{key}={value}" for key, value in values.items()]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Refresh gsd-2 upstream release metadata.")
    parser.add_argument(
        "--output-file",
        type=Path,
        help="Write GitHub Actions outputs to this file",
    )
    args = parser.parse_args()

    release = fetch_latest_release()
    current_info = json.loads(SOURCE_FILE.read_text(encoding="utf-8"))

    current_version = current_info.get("version")
    if not current_version:
        raise RuntimeError("could not find version assignment in source.json")

    target_version = release["version"]
    tag_name = release["tag_name"]
    source = prefetch_github_source("gsd-build", "gsd-2", tag_name)
    source_root = Path(source["storePath"])
    target_info = dict(current_info)
    target_info["version"] = target_version
    target_info["srcHash"] = source["hash"]
    target_info.update(collect_upstream_source_metadata(source_root))

    if current_info == target_info:
        emit_outputs(
            args.output_file,
            {
                "updated": "false",
                "current_version": current_version,
                "target_version": target_version,
                "tag_name": tag_name,
                "release_url": release["html_url"],
                "hash": "",
            },
        )
        print(json.dumps({"updated": False, "version": current_version, "tag_name": tag_name}))
        return 0

    SOURCE_FILE.write_text(
        json.dumps(target_info, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    emit_outputs(
        args.output_file,
        {
            "updated": "true",
            "current_version": current_version,
            "target_version": target_version,
            "tag_name": tag_name,
            "release_url": release["html_url"],
            "hash": source["hash"],
        },
    )
    print(
        json.dumps(
            {
                "updated": True,
                "current_version": current_version,
                "target_version": target_version,
                "tag_name": tag_name,
                "hash": source["hash"],
            }
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
