#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import urllib.request
from urllib.parse import urlencode
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE_FILE = ROOT / "pkgs" / "gsd-2" / "source.json"
UPSTREAM_RELEASE_URL = "https://api.github.com/repos/gsd-build/gsd-2/releases/latest"
DISPATCH_URL_TEMPLATE = "https://api.github.com/repos/{repo}/dispatches"
PULLS_URL_TEMPLATE = "https://api.github.com/repos/{repo}/pulls"
DISPATCH_EVENT_TYPE = "upstream-release-update"


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

    return {
        "tag_name": tag_name,
        "version": tag_name.lstrip("vV"),
        "html_url": payload.get("html_url", ""),
    }


def dispatch_update(payload: dict[str, str]) -> None:
    repo = os.environ.get("GITHUB_REPOSITORY")
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if not repo:
        raise RuntimeError("GITHUB_REPOSITORY is not set")
    if not token:
        raise RuntimeError("GITHUB_TOKEN is not set")

    request = urllib.request.Request(
        DISPATCH_URL_TEMPLATE.format(repo=repo),
        data=json.dumps(
            {
                "event_type": DISPATCH_EVENT_TYPE,
                "client_payload": payload,
            }
        ).encode("utf-8"),
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "User-Agent": "gsd-2-nix-release-bot",
        },
        method="POST",
    )
    with urllib.request.urlopen(request):
        pass


def has_open_release_pr(target_version: str) -> bool:
    repo = os.environ.get("GITHUB_REPOSITORY")
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if not repo:
        raise RuntimeError("GITHUB_REPOSITORY is not set")
    if not token:
        raise RuntimeError("GITHUB_TOKEN is not set")

    owner, _ = repo.split("/", 1)
    branch = f"bot/upstream-gsd-2-{target_version}"
    query = urlencode(
        {
            "state": "open",
            "head": f"{owner}:{branch}",
        }
    )
    request = urllib.request.Request(
        f"{PULLS_URL_TEMPLATE.format(repo=repo)}?{query}",
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "User-Agent": "gsd-2-nix-release-bot",
        },
    )
    with urllib.request.urlopen(request) as response:
        payload = json.load(response)
    return bool(payload)


def main() -> int:
    current_info = json.loads(SOURCE_FILE.read_text(encoding="utf-8"))
    current_version = current_info.get("version")
    if not current_version:
        raise RuntimeError("could not find version assignment in source.json")

    release = fetch_latest_release()
    target_version = release["version"]

    if current_version == target_version:
        print(
            json.dumps(
                {
                    "updated": False,
                    "current_version": current_version,
                    "target_version": target_version,
                    "tag_name": release["tag_name"],
                }
            )
        )
        return 0

    if has_open_release_pr(target_version):
        print(
            json.dumps(
                {
                    "updated": False,
                    "reason": "open-pr-exists",
                    "current_version": current_version,
                    "target_version": target_version,
                    "tag_name": release["tag_name"],
                    "release_url": release["html_url"],
                }
            )
        )
        return 0

    dispatch_update(
        {
            "current_version": current_version,
            "target_version": target_version,
            "tag_name": release["tag_name"],
            "release_url": release["html_url"],
        }
    )
    print(
        json.dumps(
            {
                "updated": True,
                "current_version": current_version,
                "target_version": target_version,
                "tag_name": release["tag_name"],
                "release_url": release["html_url"],
            }
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
