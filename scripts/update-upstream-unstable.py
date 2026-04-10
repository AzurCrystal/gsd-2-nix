#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import subprocess
import urllib.request
from pathlib import Path
from urllib.parse import urlencode


ROOT = Path(__file__).resolve().parents[1]
SOURCE_FILE = ROOT / "pkgs" / "gsd-2" / "source-unstable.json"
UPSTREAM_COMMITS_URL = "https://api.github.com/repos/gsd-build/gsd-2/commits"


def fetch_latest_commit() -> dict[str, str]:
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "gsd-2-nix-release-bot",
    }
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"

    query = urlencode({"sha": "main", "per_page": 1})
    request = urllib.request.Request(f"{UPSTREAM_COMMITS_URL}?{query}", headers=headers)
    with urllib.request.urlopen(request) as response:
        payload = json.load(response)

    if not payload:
        raise RuntimeError("upstream main commits payload was empty")

    commit = payload[0]
    sha = commit.get("sha")
    if not sha:
        raise RuntimeError("upstream latest commit payload did not include sha")

    return {
        "sha": sha,
        "short_sha": sha[:7],
        "html_url": commit.get("html_url", ""),
        "commit_date": commit.get("commit", {}).get("committer", {}).get("date", ""),
    }


def prefetch_hash(rev: str) -> str:
    result = subprocess.run(
        ["nix", "flake", "prefetch", "--json", f"github:gsd-build/gsd-2/{rev}"],
        check=True,
        capture_output=True,
        text=True,
    )
    payload = json.loads(result.stdout)
    hash_value = payload.get("hash")
    if not hash_value:
        raise RuntimeError("nix flake prefetch did not return a hash")
    return hash_value


def emit_outputs(path: Path | None, values: dict[str, str]) -> None:
    if path is None:
        return

    lines = [f"{key}={value}" for key, value in values.items()]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Refresh gsd-2 unstable upstream metadata.")
    parser.add_argument(
        "--output-file",
        type=Path,
        help="Write GitHub Actions outputs to this file",
    )
    args = parser.parse_args()

    current_info = json.loads(SOURCE_FILE.read_text(encoding="utf-8"))
    current_rev = current_info.get("rev")
    if not current_rev:
        raise RuntimeError("could not find rev assignment in source-unstable.json")

    commit = fetch_latest_commit()
    target_rev = commit["sha"]

    if current_rev == target_rev:
        emit_outputs(
            args.output_file,
            {
                "updated": "false",
                "current_rev": current_rev,
                "target_rev": target_rev,
                "short_sha": commit["short_sha"],
                "commit_url": commit["html_url"],
                "commit_date": commit["commit_date"],
                "hash": "",
            },
        )
        print(json.dumps({"updated": False, "current_rev": current_rev, "target_rev": target_rev}))
        return 0

    new_hash = prefetch_hash(target_rev)
    current_info["rev"] = target_rev
    current_info["version"] = f"unstable-{commit['short_sha']}"
    current_info["srcHash"] = new_hash
    SOURCE_FILE.write_text(
        json.dumps(current_info, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    emit_outputs(
        args.output_file,
        {
            "updated": "true",
            "current_rev": current_rev,
            "target_rev": target_rev,
            "short_sha": commit["short_sha"],
            "commit_url": commit["html_url"],
            "commit_date": commit["commit_date"],
            "hash": new_hash,
        },
    )
    print(
        json.dumps(
            {
                "updated": True,
                "current_rev": current_rev,
                "target_rev": target_rev,
                "short_sha": commit["short_sha"],
                "commit_url": commit["html_url"],
                "hash": new_hash,
            }
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
